import Foundation

/// Presets that exist to test the SOLVER rather than a machine.
///
/// The distinction matters and cost a debugging cycle to see clearly. RH-1 has
/// 24 acoustic channels. A 24-degree-of-freedom aperture cannot form a tight
/// focus in a 280 mm volume at lambda = 8.6 mm — that is a property of the
/// channel budget, not of the inverse solver. Running G9 against RH-1 therefore
/// measures the wrong thing and fails for the right reason.
///
/// So: G9 runs against `denseOpposedArray`, the standard acoustic-levitation
/// geometry where every transducer is its own gate. RH-1's actual focusing
/// ability is reported separately, as an informational number.
public enum TestPresets {

    /// Two opposed N x N planar arrays — the canonical levitation rig
    /// (TinyLev / Ultraino class). Every transducer is independently
    /// addressable, so this exercises the solver at realistic DOF.
    public static func denseOpposedArray(n: Int = 16,
                                         separation: Double = 0.12,
                                         frequency: Double = 40_000,
                                         medium: Medium = .air) -> MachinePreset {
        let lambda = medium.wavelength(at: frequency)
        let pitch = lambda / 2
        let extent = Double(n - 1) * pitch
        var elements: [Element] = []
        var gate = 0
        for (plate, z) in [(0, 0.0), (1, separation)] {
            let normal = Vec3(0, 0, plate == 0 ? 1 : -1)
            for j in 0..<n {
                for i in 0..<n {
                    let x = -extent / 2 + Double(i) * pitch
                    let y = -extent / 2 + Double(j) * pitch
                    elements.append(Element(position: Vec3(x, y, z), normal: normal,
                                            area: pitch * pitch, surface: .panel,
                                            gateIndex: gate))
                    gate += 1
                }
            }
        }
        let bv = BuildVolume(radius: extent / 2, height: separation)
        return MachinePreset(id: "dense-opposed-\(n)x\(n)",
                             displayName: "Dense opposed \(n)x\(n)",
                             elements: elements, gateCount: gate,
                             buildVolume: bv, medium: medium)
    }

    /// Single planar array — the half-space / "table" rung of the boundary
    /// ladder, licensed by Rayleigh-Sommerfeld.
    public static func singlePlate(n: Int = 16, frequency: Double = 40_000,
                                   medium: Medium = .air) -> MachinePreset {
        let lambda = medium.wavelength(at: frequency)
        let pitch = lambda / 2
        let extent = Double(n - 1) * pitch
        var elements: [Element] = []
        var gate = 0
        for j in 0..<n {
            for i in 0..<n {
                elements.append(Element(
                    position: Vec3(-extent / 2 + Double(i) * pitch,
                                   -extent / 2 + Double(j) * pitch, 0),
                    normal: Vec3(0, 0, 1), area: pitch * pitch,
                    surface: .panel, gateIndex: gate))
                gate += 1
            }
        }
        return MachinePreset(id: "single-plate-\(n)x\(n)",
                             displayName: "Single plate \(n)x\(n)",
                             elements: elements, gateCount: gate,
                             buildVolume: BuildVolume(radius: extent / 2, height: 0.10),
                             medium: medium)
    }
}
