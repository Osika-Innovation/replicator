import Foundation

/// §6 — call-and-response: the build loop that listens.
///
/// WHAT THIS ADDS. The compile path was open-loop: solve once, emit a drive,
/// stop. But Principles §6 makes the loop the machine's central operation —
/// *"building drives the field and keeps listening: the growing object shifts
/// S(f), and the build is finished when it rings true — the chord list is
/// simultaneously the drive recipe and the acceptance criterion."*
///
/// The asymmetry that gave the gap away: the chord list was only ever an
/// OUTPUT of scan, never an INPUT to build. Here it is the input, the target,
/// and the stopping test.
///
/// Listening is milliwatt-class (`ChordDrive.Verb.listen` scales by 1e-3), so
/// every iteration of building is also a scan — which is why the loop costs
/// almost nothing in drive power and why verification is continuous.
public struct CallAndResponse: Sendable {

    public struct Step: Sendable {
        public var iteration: Int
        /// ||S_measured − S_target|| / ||S_target|| — the "rings true" metric.
        public var chordError: Double
        public var trappedFraction: Double
        public var converged: Bool
        public var stalled: Bool
    }

    public struct Outcome: Sendable {
        public var steps: [Step]
        public var finalError: Double
        public var iterations: Int
        public var reason: String
        public var rungTrue: Bool
    }

    public let target: [MatrixPencil.Chord]
    public let tolerance: Double
    public let maxIterations: Int
    /// Stop if the error stops improving — a build that cannot converge should
    /// say so rather than run to the iteration cap and look finished.
    public let stallPatience: Int

    public init(target: [MatrixPencil.Chord], tolerance: Double = 0.15,
                maxIterations: Int = 24, stallPatience: Int = 4) {
        self.target = target
        self.tolerance = tolerance
        self.maxIterations = maxIterations
        self.stallPatience = stallPatience
    }

    /// How far the workpiece is from ringing true.
    ///
    /// Compares the response the growing object gives against the target chord
    /// list, over the union of both pole sets so that a MISSING resonance costs
    /// as much as a wrong one — otherwise a workpiece that rings at nothing
    /// would score perfectly.
    public static func chordError(measured: [MatrixPencil.Chord],
                                  target: [MatrixPencil.Chord]) -> Double {
        guard !target.isEmpty else { return 0 }
        var num = 0.0, den = 0.0
        for t in target {
            den += t.weight * t.weight
            // Nearest measured resonance in frequency.
            let match = measured.min {
                abs($0.frequencyHz - t.frequencyHz) < abs($1.frequencyHz - t.frequencyHz)
            }
            if let m = match,
               abs(m.frequencyHz - t.frequencyHz) < 0.05 * max(t.frequencyHz, 1) {
                num += pow(m.weight - t.weight, 2)
            } else {
                num += t.weight * t.weight        // absent = fully wrong
            }
        }
        // Spurious resonances the target does not call for also count against.
        for m in measured {
            let wanted = target.contains {
                abs($0.frequencyHz - m.frequencyHz) < 0.05 * max(m.frequencyHz, 1)
            }
            if !wanted { num += m.weight * m.weight }
        }
        guard den > 0 else { return num > 0 ? .infinity : 0 }
        return (num / den).squareRoot()
    }

    /// Run the loop. `drive` produces the assemble drive for an iteration,
    /// `advance` steps the physical state under it, and `listen` returns what
    /// the boundary currently hears — the three halves of call-and-response.
    public func run(drive: (Int) -> ChordDrive,
                    advance: (ChordDrive) -> Double,
                    listen: () -> [MatrixPencil.Chord]) -> Outcome {
        var steps: [Step] = []
        var best = Double.infinity
        var sinceImprovement = 0

        for i in 0..<maxIterations {
            let build = drive(i)
            let trapped = advance(build)
            // The listen verb: same field, a millionth of the power (§5/§6).
            _ = ChordDrive(tones: build.tones, verb: .listen).applied()
            let heard = listen()
            let err = CallAndResponse.chordError(measured: heard, target: target)

            if err < best - 1e-4 { best = err; sinceImprovement = 0 }
            else { sinceImprovement += 1 }

            let converged = err <= tolerance
            let stalled = sinceImprovement >= stallPatience
            steps.append(Step(iteration: i, chordError: err,
                              trappedFraction: trapped,
                              converged: converged, stalled: stalled))
            if converged {
                return Outcome(steps: steps, finalError: err, iterations: i + 1,
                               reason: "rings true", rungTrue: true)
            }
            if stalled {
                return Outcome(steps: steps, finalError: err, iterations: i + 1,
                               reason: "stalled — error stopped improving after "
                                     + "\(stallPatience) iterations", rungTrue: false)
            }
        }
        return Outcome(steps: steps, finalError: best, iterations: maxIterations,
                       reason: "hit iteration cap without converging",
                       rungTrue: false)
    }
}
