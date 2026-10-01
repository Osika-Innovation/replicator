import Foundation

/// Where overdamped powder ends, without stepping a single grain (ENGINE.md).
///
/// A 40 µm grain in air relaxes in ~6 ms: it does not swing, it slides down
/// U_eff = P·U + m g z and stops in a minimum. So its end is a property of
/// the landscape, not of a trajectory: every lattice cell points to its
/// steepest-descent neighbour (26-neighbourhood, slope per unit distance), a
/// cell with no lower neighbour is a sink, and following the pointers gives
/// every start's destination in one pass. A boundary cell whose descent leads
/// out of the box (its outward slope continued linearly is the steepest) is
/// an exit: the grain falls or drifts out.
///
/// Recirculation closes in one line. Grains that exit are sprinkled in again
/// on the release box's top layer; if a fraction q_s of top-layer cells drain
/// to sink s and q_out exit again, the re-sprinkled powder ends at s with
/// probability q_s / (1 − q_out). So each sink's final share of a uniform
/// release is p_s + p_out · q_s / (1 − q_out).
public struct BasinMap: Sendable {
    /// Destination of every cell: a sink's cell index, or −1 for an exit.
    public var destination: [Int]
    /// The sinks (cell indices).
    public var sinks: [Int]
    /// Share of the release box draining to each sink directly, and to exits.
    public var direct: [Int: Double]
    public var directOut: Double
    /// The same for the release box's top layer (where grains re-enter).
    public var top: [Int: Double]
    public var topOut: Double

    /// Final share at each sink with recirculation (sums to 1 − the share that
    /// never lands, which is 0 unless every top-layer cell exits).
    public var recirculated: [Int: Double] {
        var out = direct
        guard topOut < 1 - 1e-12 else { return out }
        for (s, q) in top { out[s, default: 0] += directOut * q / (1 - topOut) }
        return out
    }

    /// - Parameters:
    ///   - U: potential per unit drive power on the lattice.
    ///   - power: drive power (U · power is in joules).
    ///   - weight: m·g of a grain (N); 0 = no gravity.
    ///   - release: the release box, inclusive cell-index ranges (i, j, k).
    public init(U: [Double], lattice lat: FieldLattice, power: Double, weight: Double,
                release: (i: ClosedRange<Int>, j: ClosedRange<Int>, k: ClosedRange<Int>)) {
        let nx = lat.nx, ny = lat.ny, nz = lat.nz, h = lat.spacing
        let n = lat.count
        let E: [Double] = (0..<n).map { c in
            let k = c / (nx * ny)
            return power * U[c] + weight * (lat.origin.z + Double(k) * h)
        }
        // Steepest descent pointer per cell (−2 = exit, else neighbour or self).
        var next = [Int](repeating: 0, count: n)
        let offsets: [(Int, Int, Int, Double)] = {
            var o: [(Int, Int, Int, Double)] = []
            for dk in -1...1 { for dj in -1...1 { for di in -1...1 where !(di == 0 && dj == 0 && dk == 0) {
                o.append((di, dj, dk, (Double(di * di + dj * dj + dk * dk)).squareRoot() * h))
            } } }
            return o
        }()
        next.withUnsafeMutableBufferPointer { nb in
            DispatchQueue.concurrentPerform(iterations: nz) { k in
                for j in 0..<ny {
                    for i in 0..<nx {
                        let c = lat.index(i, j, k)
                        var best = c, bestSlope = 0.0
                        for (di, dj, dk, d) in offsets {
                            let ii = i + di, jj = j + dj, kk = k + dk
                            let s: Double
                            if ii < 0 || jj < 0 || kk < 0 || ii >= nx || jj >= ny || kk >= nz {
                                // Outside: continue the slope from the inward neighbour.
                                let ri = i - di, rj = j - dj, rk = k - dk
                                guard ri >= 0, rj >= 0, rk >= 0, ri < nx, rj < ny, rk < nz else { continue }
                                s = (E[c] - E[lat.index(ri, rj, rk)]) / d
                                if s < bestSlope { bestSlope = s; best = -2 }
                                continue
                            }
                            s = (E[lat.index(ii, jj, kk)] - E[c]) / d
                            if s < bestSlope { bestSlope = s; best = lat.index(ii, jj, kk) }
                        }
                        nb[c] = best
                    }
                }
            }
        }
        // Follow the pointers (memoised).
        var dest = [Int](repeating: -3, count: n)          // −3 = not yet resolved
        for start in 0..<n where dest[start] == -3 {
            var path: [Int] = []
            var c = start, d = -3
            while true {
                if dest[c] != -3 { d = dest[c]; break }
                path.append(c)
                let nx2 = next[c]
                if nx2 == -2 { d = -1; break }
                if nx2 == c { d = c; break }
                c = nx2
                if path.count > n { d = c; break }          // cannot happen on a strict descent; guard anyway
            }
            for p in path { dest[p] = d }
        }
        destination = dest
        sinks = Array(Set(dest.filter { $0 >= 0 })).sorted()
        func shares(_ cells: [Int]) -> ([Int: Double], Double) {
            var m: [Int: Double] = [:]
            var out = 0.0
            let w = 1 / Double(max(1, cells.count))
            for c in cells {
                if dest[c] < 0 { out += w } else { m[dest[c], default: 0] += w }
            }
            return (m, out)
        }
        var box: [Int] = [], topLayer: [Int] = []
        for k in release.k { for j in release.j { for i in release.i {
            box.append(lat.index(i, j, k))
            if k == release.k.upperBound { topLayer.append(lat.index(i, j, k)) }
        } } }
        (direct, directOut) = shares(box)
        (top, topOut) = shares(topLayer)
    }
}
