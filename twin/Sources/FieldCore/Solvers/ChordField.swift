import Foundation

/// Evaluating a chord: the three verbs of Principles §5 over a multi-tone drive.
public enum ChordField {

    /// Gor'kov potential of a whole chord.
    ///
    /// Per-tone potentials ADD. For well-separated tones the cross terms
    /// oscillate at the difference frequency and time-average to zero over the
    /// mechanical response time of a particle, so the force landscape is the
    /// sum of the per-tone landscapes. This is what lets a chord place traps
    /// that no single tone could: co-locate the main lobes and the sidelobes
    /// land in different places and average down.
    public static func potential(drive: ChordDrive,
                                 preset: MachinePreset,
                                 lattice: FieldLattice,
                                 particle: ParticleMaterial = .pla(),
                                 walls: Propagator.Walls = .none,
                                 rainbow: RainbowMap? = RainbowMap(),
                                 panelHeight: Double = 0.300) -> [Double] {
        let applied = drive.applied()
        var U = [Double](repeating: 0, count: lattice.count)
        let g = Gorkov(medium: preset.medium, particle: particle)

        for tone in applied.tones {
            let w = rainbow.map {
                preset.rainbowWeights(frequency: tone.frequency, map: $0,
                                      panelHeight: panelHeight)
            }
            let prop = Propagator(elements: preset.elements, lattice: lattice,
                                  frequency: tone.frequency, medium: preset.medium,
                                  gateCount: preset.gateCount,
                                  elementWeights: w, walls: walls)
            let field = prop.forward(tone.gates)
            let omega = 2 * Double.pi * tone.frequency
            let coef = 1.0 / (omega * preset.medium.density * lattice.spacing * 2)
            for k in 0..<lattice.nz {
                for j in 0..<lattice.ny {
                    for i in 0..<lattice.nx {
                        let n = lattice.index(i, j, k)
                        func d(_ a: Int, _ b: Int, _ c: Int,
                               _ a2: Int, _ b2: Int, _ c2: Int) -> Complex {
                            let lo = lattice.index(max(0, a), max(0, b), max(0, c))
                            let hi = lattice.index(min(lattice.nx - 1, a2),
                                                   min(lattice.ny - 1, b2),
                                                   min(lattice.nz - 1, c2))
                            return field[hi] - field[lo]
                        }
                        let gx = d(i-1, j, k, i+1, j, k)
                        let gy = d(i, j-1, k, i, j+1, k)
                        let gz = d(i, j, k-1, i, j, k+1)
                        U[n] += g.potential(
                            p: field[n],
                            v: (Complex(-gx.im, gx.re) * coef,
                                Complex(-gy.im, gy.re) * coef,
                                Complex(-gz.im, gz.re) * coef))
                    }
                }
            }
        }
        return U
    }

    /// Complex pressure of a chord at one point, per tone.
    public static func pressures(drive: ChordDrive, preset: MachinePreset,
                                 at x: Vec3, lattice: FieldLattice)
        -> [(frequency: Double, p: Complex)] {
        let applied = drive.applied()
        return applied.tones.map { tone in
            let prop = Propagator(elements: preset.elements, lattice: lattice,
                                  frequency: tone.frequency, medium: preset.medium,
                                  gateCount: preset.gateCount)
            return (tone.frequency, prop.pressure(at: x, drive: tone.gates))
        }
    }

    /// DISSOLVE, measured rather than asserted.
    ///
    /// §5 claims assemble and dissolve are one sign flip. That is a claim about
    /// ENERGY FLOW, so it has to be checked as one: the net acoustic intensity
    /// through a surface around the workpiece must reverse sign between the two
    /// verbs. A sign flip that does not reverse the power flux is not a drain,
    /// it is a relabelled pump.
    ///
    /// Intensity I = (1/2) Re{p v*}; integrate I·n over a closed box.
    public static func netFlux(drive: ChordDrive, preset: MachinePreset,
                               lattice: FieldLattice,
                               about centre: Vec3, halfSize: Double) -> Double {
        let applied = drive.applied()
        var total = 0.0
        for tone in applied.tones {
            let prop = Propagator(elements: preset.elements, lattice: lattice,
                                  frequency: tone.frequency, medium: preset.medium,
                                  gateCount: preset.gateCount)
            let omega = 2 * Double.pi * tone.frequency
            let rho = preset.medium.density
            let h = halfSize / 6
            // Six faces of a box, sampled on a coarse grid.
            let axes: [(Vec3, Vec3, Vec3)] = [
                (Vec3(1,0,0), Vec3(0,1,0), Vec3(0,0,1)),
                (Vec3(0,1,0), Vec3(1,0,0), Vec3(0,0,1)),
                (Vec3(0,0,1), Vec3(1,0,0), Vec3(0,1,0)),
            ]
            for (nrm, u, v) in axes {
                for sign in [-1.0, 1.0] {
                    let outward = nrm * sign
                    for a in -3...3 {
                        for b in -3...3 {
                            let pt = centre + outward * halfSize
                                   + u * (Double(a) * h) + v * (Double(b) * h)
                            let p = prop.pressure(at: pt, drive: tone.gates)
                            // v = (i / (omega rho)) grad p, along the normal
                            let d = 1e-4
                            let pf = prop.pressure(at: pt + outward * d, drive: tone.gates)
                            let pb = prop.pressure(at: pt - outward * d, drive: tone.gates)
                            let grad = (pf - pb) / (2 * d)
                            let vn = Complex(-grad.im, grad.re) / (omega * rho)
                            // I·n = (1/2) Re{p conj(v_n)}
                            total += 0.5 * (p * vn.conjugate).re * h * h
                        }
                    }
                }
            }
        }
        return total
    }
}
