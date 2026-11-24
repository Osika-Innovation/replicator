import Foundation

/// Where overdamped powder ends, by following the flow itself.
///
/// `BasinMap` answers the same question on the lattice: every cell points to
/// its steepest-descent neighbour among 26. That is fast, and it gets the
/// share on the shape right, but a 26-direction pointer cannot follow a
/// streamline: a grain falling under gravity with a small sideways push goes
/// straight down, cell after cell, until the push exceeds tan 22.5° of the
/// weight. Over a 10 mm fall the real grain has drifted sideways by
/// millimetres. So the lattice map's share PER SITE is not the stepped
/// grains' (2026-11-10: ring mold, lattice 3–9 % per site, grains 0–15 %).
///
/// This traces the streamlines of F = −(P ∇U + m g ẑ) through the same
/// trilinear field the stepped grains see, with no clock: a midpoint step of
/// fixed length while the force is large, shrinking with the force near a
/// rest point. It is the stepped-grain check without time, cheap enough to
/// sit inside the compiler's feedback loop.
public enum FlowMap {

    /// Trilinear interpolation of the central-difference gradient of a lattice
    /// field; nil within a cell of the box's faces (where a grain has left).
    @inline(__always)
    static func gradient(_ U: UnsafePointer<Double>, _ lat: FieldLattice, _ x: Vec3) -> Vec3? {
        let h = lat.spacing, nx = lat.nx, ny = lat.ny, nz = lat.nz
        let fx = (x.x - lat.origin.x) / h, fy = (x.y - lat.origin.y) / h, fz = (x.z - lat.origin.z) / h
        let i0 = Int(fx.rounded(.down)), j0 = Int(fy.rounded(.down)), k0 = Int(fz.rounded(.down))
        guard i0 >= 1, j0 >= 1, k0 >= 1, i0 + 2 < nx, j0 + 2 < ny, k0 + 2 < nz else { return nil }
        let tx = fx - Double(i0), ty = fy - Double(j0), tz = fz - Double(k0)
        let sy = nx, sz = nx * ny
        var gx = 0.0, gy = 0.0, gz = 0.0
        for dk in 0...1 {
            let wz = dk == 0 ? 1 - tz : tz
            for dj in 0...1 {
                let wy = dj == 0 ? 1 - ty : ty
                for di in 0...1 {
                    let w = (di == 0 ? 1 - tx : tx) * wy * wz
                    let n = ((k0 + dk) * ny + (j0 + dj)) * nx + (i0 + di)
                    gx += w * (U[n + 1] - U[n - 1])
                    gy += w * (U[n + sy] - U[n - sy])
                    gz += w * (U[n + sz] - U[n - sz])
                }
            }
        }
        let s = 1 / (2 * h)
        return Vec3(gx * s, gy * s, gz * s)
    }

    /// Follow every start down the flow. Returns where each comes to rest, or
    /// nil if it leaves the box.
    ///
    /// - Parameters:
    ///   - U: potential per unit drive power on the lattice.
    ///   - power: drive power (U · power is in joules).
    ///   - weight: m·g of a grain (N); 0 = no gravity.
    ///   - step: step length while the force is large, in lattice spacings.
    ///   - drag, duration: with both given, a grain is followed for `duration`
    ///     seconds of its own motion (speed = force / drag) and reported where
    ///     it is then — on a shallow slope it may still be sliding, as a
    ///     stepped grain would be. Without them: to rest.
    public static func trace(U: [Double], lattice lat: FieldLattice, power: Double, weight: Double,
                             starts: [Vec3], step: Double = 0.25, maxSteps: Int = 6000,
                             drag: Double? = nil, duration: Double? = nil) -> [Vec3?] {
        let clock = drag != nil && duration != nil
        let gamma = drag ?? 1, tEnd = duration ?? .infinity
        let h = lat.spacing
        var uMax = 0.0
        for v in U { uMax = max(uMax, abs(v)) }
        // The force a step is measured against: a quarter of the weight, or
        // (no gravity) a small fraction of the field's own scale.
        let fRef = weight > 0 ? 0.25 * weight : 1e-3 * power * uMax / h
        var out = [Vec3?](repeating: nil, count: starts.count)
        U.withUnsafeBufferPointer { ub in
            let up = UncheckedSendablePointer(ub.baseAddress!)
            out.withUnsafeMutableBufferPointer { ob in
                let res = UncheckedSendableBuffer(ob)
                DispatchQueue.concurrentPerform(iterations: starts.count) { i in
                    var x = starts[i]
                    var rest: Vec3? = nil
                    func force(_ p: Vec3) -> Vec3? {
                        guard let g = gradient(up.base, lat, p) else { return nil }
                        return Vec3(-power * g.x, -power * g.y, -power * g.z - weight)
                    }
                    var left = maxSteps
                    var elapsed = 0.0
                    while true {
                        guard let f1 = force(x) else { break }                 // left the box
                        let m1 = f1.length
                        let len = step * h * min(1, m1 / fRef)
                        if len < 1e-4 * h || left == 0 { rest = x; break }
                        if clock {
                            elapsed += len * gamma / m1
                            if elapsed >= tEnd { rest = x; break }
                        }
                        // Midpoint: the direction half a step on.
                        guard let f2 = force(x + f1 * (0.5 * len / m1)) else { break }
                        let m2 = f2.length
                        x = m2 > 0 ? x + f2 * (len / m2) : x
                        left -= 1
                    }
                    res.base[i] = rest
                }
            }
        }
        return out
    }

    /// Shares of a uniform release, with recirculation: grains that leave are
    /// sprinkled in again over the release box's top layer, so each start's
    /// final weight is its own plus the fallen fraction × the top layer's
    /// distribution, p_s + p_out · q_s / (1 − q_out) (as `BasinMap`).
    /// Returns every resting point with its share of the release.
    public static func shares(box: [Vec3?], top: [Vec3?], recirculate: Bool) -> [(x: Vec3, share: Double)] {
        let wBox = 1 / Double(max(1, box.count))
        var out: [(x: Vec3, share: Double)] = box.compactMap { $0.map { ($0, wBox) } }
        guard recirculate else { return out }
        let pOut = Double(box.filter { $0 == nil }.count) * wBox
        let landed = top.compactMap { $0 }
        guard pOut > 0, !landed.isEmpty else { return out }
        // Each top-layer start that lands carries pOut · (1/top.count) / (1 − q_out) = pOut / landed.count.
        let w = pOut / Double(landed.count)
        out.append(contentsOf: landed.map { ($0, w) })
        return out
    }
}

/// A read-only base pointer shared by concurrent iterations.
struct UncheckedSendablePointer<T>: @unchecked Sendable {
    let base: UnsafePointer<T>
    init(_ p: UnsafePointer<T>) { base = p }
}
