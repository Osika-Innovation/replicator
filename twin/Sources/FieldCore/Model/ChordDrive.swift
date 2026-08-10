import Foundation

/// The drive, in the language Principles §3 actually specifies.
///
/// WHAT THIS REPLACES AND WHY. The drive was `[Complex]` — one complex number
/// per gate, at one implied frequency. That expresses exactly two of the
/// eleven knobs in the §3 table (amplitude, phase) and cannot represent a
/// CHORD at all. But §6 says the machine "sends a chord" and §3 says frequency
/// IS the address — spectral addressing and rainbow trapping are the machine's
/// core mechanism, not a refinement. A single-frequency drive vector models a
/// plain phased array, not this machine.
///
/// So the drive is a set of TONES, each with its own per-gate complex vector.
/// Per-tone aperture patterns (the rainbow map) then fall out naturally,
/// because each tone can be radiated by a different part of the panel.
public struct ChordDrive: Sendable, Codable {

    /// One tone: a frequency and the gate pattern that plays it.
    public struct Tone: Sendable, Codable {
        public var frequency: Double        // Hz
        public var gates: [Complex]         // one complex amplitude per gate
        /// Orbital angular momentum order (§3: "acoustic vortex beams …
        /// torque, rotation, extra address axis"). Carried so the type can
        /// express it; the solver does not yet synthesise it.
        public var orbitalOrder: Int

        public init(frequency: Double, gates: [Complex], orbitalOrder: Int = 0) {
            self.frequency = frequency; self.gates = gates
            self.orbitalOrder = orbitalOrder
        }
    }

    /// The verb this drive performs (Principles §5).
    ///
    /// "Assemble and dissolve are the same drive separated by one sign flip."
    /// That is literally true here: `dissolve` conjugates every gate amplitude,
    /// which time-reverses the emitted field — the phase-conjugate / coherent
    /// perfect absorption condition, where the boundary pumps energy back OUT
    /// of the volume instead of into it.
    public enum Verb: String, Sendable, Codable, CaseIterable {
        case assemble       // ADD — in-phase pumping, energy into the mold
        case dissolve       // REMOVE — phase-conjugate, CPA drain
        case listen         // scan power, same field a millionth as loud
    }

    public var tones: [Tone]
    public var verb: Verb
    /// Scan gates to record on while this drive plays. §6: listening is
    /// milliwatt-class and always on, so every instant of building is a scan.
    public var rxGates: [Int]

    public init(tones: [Tone], verb: Verb = .assemble, rxGates: [Int] = []) {
        self.tones = tones; self.verb = verb; self.rxGates = rxGates
    }

    /// Single-tone convenience — the old shape, kept so existing call sites
    /// stay honest rather than being silently reinterpreted.
    public init(frequency: Double, gates: [Complex], verb: Verb = .assemble) {
        self.init(tones: [Tone(frequency: frequency, gates: gates)], verb: verb)
    }

    public var gateCount: Int { tones.first?.gates.count ?? 0 }

    /// Apply the verb. This is the one sign flip of §5.
    public func applied() -> ChordDrive {
        switch verb {
        case .assemble:
            return self
        case .dissolve:
            // Phase conjugation: time-reverse the emitted field so the boundary
            // absorbs rather than radiates (CPA). Amplitudes are unchanged —
            // only the phases invert, which is why the paper can call assemble
            // and dissolve "the same drive".
            return ChordDrive(
                tones: tones.map { Tone(frequency: $0.frequency,
                                        gates: $0.gates.map(\.conjugate),
                                        orbitalOrder: -$0.orbitalOrder) },
                verb: verb, rxGates: rxGates)
        case .listen:
            let s = 1e-3          // milliwatt-class relative to build power
            return ChordDrive(
                tones: tones.map { Tone(frequency: $0.frequency,
                                        gates: $0.gates.map { $0 * s },
                                        orbitalOrder: $0.orbitalOrder) },
                verb: verb, rxGates: rxGates)
        }
    }

    /// Total radiated power proxy, summed over tones — the quantity that must
    /// be shared when a chord is played, not stacked.
    public var power: Double {
        tones.reduce(0) { acc, t in
            acc + t.gates.reduce(0) { $0 + $1.magnitudeSquared }
        }
    }

    /// Normalise so a chord of N tones does not simply draw N times the power.
    public func powerNormalised(to target: Double = 1) -> ChordDrive {
        let p = power
        guard p > 0 else { return self }
        let s = (target / p).squareRoot()
        return ChordDrive(
            tones: tones.map { Tone(frequency: $0.frequency,
                                    gates: $0.gates.map { $0 * s },
                                    orbitalOrder: $0.orbitalOrder) },
            verb: verb, rxGates: rxGates)
    }
}
