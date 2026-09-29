import Foundation

/// One transducer element on the boundary. The unit the propagator sums over.
/// How an element radiates. A pressure injection at a single FDTD cell is a
/// MONOPOLE (omnidirectional); a real transducer face is a baffled piston. G5
/// compares T0 against T1 driven by a point source, so it needs the monopole
/// model — using the piston form there would compare two different sources and
/// report a propagator error that is really a source-model mismatch.
public enum Directivity: String, Sendable, Codable {
    case piston, monopole
}

public struct Element: Sendable, Codable {
    public var position: Vec3          // metres, RH-1 frame (origin = lower cap face)
    public var normal: Vec3            // outward from the surface, into the volume
    public var area: Double            // m^2
    public var surface: SurfaceID
    public var gateIndex: Int          // which addressable gate this belongs to
    public var isTX: Bool
    public var isRX: Bool
    public var directivity: Directivity

    public init(position: Vec3, normal: Vec3, area: Double, surface: SurfaceID,
                gateIndex: Int, isTX: Bool = true, isRX: Bool = true,
                directivity: Directivity = .piston) {
        self.position = position; self.normal = normal; self.area = area
        self.surface = surface; self.gateIndex = gateIndex
        self.isTX = isTX; self.isRX = isRX
        self.directivity = directivity
    }

    /// Equivalent radius of a disc of the same area — the piston directivity parameter.
    public var equivalentRadius: Double { (area / Double.pi).squareRoot() }
}

public enum SurfaceID: String, Sendable, Codable, CaseIterable {
    case lowerCap, upperCap, panel, column, glass, sphereGate
}

/// A cylindrical build volume: r <= radius, z in [0, height].
public struct BuildVolume: Sendable, Codable {
    public var radius: Double
    public var height: Double
    public init(radius: Double, height: Double) { self.radius = radius; self.height = height }

    public func contains(_ p: Vec3) -> Bool {
        p.z >= 0 && p.z <= height && p.radiusXY <= radius
    }
    public var boundsMin: Vec3 { Vec3(-radius, -radius, 0) }
    public var boundsMax: Vec3 { Vec3(radius, radius, height) }
}

/// A machine configuration. §10: the gate count and gate geometry are preset
/// DATA, never a hard-coded 12 — three different "12"s exist in this document
/// family and conflating them has bitten the project before.
public struct MachinePreset: Sendable, Codable {
    public var id: String
    public var displayName: String
    public var elements: [Element]
    public var gateCount: Int
    public var buildVolume: BuildVolume
    public var medium: Medium
    public var defaultBand: ClosedRange<Double>   // Hz

    public init(id: String, displayName: String, elements: [Element], gateCount: Int,
                buildVolume: BuildVolume, medium: Medium = .air,
                defaultBand: ClosedRange<Double> = 20_000...80_000) {
        self.id = id; self.displayName = displayName; self.elements = elements
        self.gateCount = gateCount; self.buildVolume = buildVolume
        self.medium = medium; self.defaultBand = defaultBand
    }

    public var txElements: [Element] { elements.filter(\.isTX) }
    public var rxElements: [Element] { elements.filter(\.isRX) }

    /// Element indices belonging to each gate, in gate order.
    public func elementIndices(forGate g: Int) -> [Int] {
        elements.indices.filter { elements[$0].gateIndex == g }
    }
}

public struct Medium: Sendable, Codable {
    public var density: Double        // rho0, kg/m^3
    public var soundSpeed: Double     // c0, m/s
    /// The thermodynamic state when the medium is air. nil for the fixed §12
    /// presets, whose absorption is taken as zero (every legacy gate and
    /// receipt was computed that way and stays reproducible).
    public var air: AirState?
    /// Extra amplitude loss (Np/m) on top of the air's own — an effective
    /// chamber loss, or a test's way of silencing distant walls.
    public var extraAbsorption: Double = 0
    public init(density: Double, soundSpeed: Double, air: AirState? = nil) {
        self.density = density; self.soundSpeed = soundSpeed; self.air = air
    }
    /// §12 material presets: air at 20 C.
    public static let air = Medium(density: 1.204, soundSpeed: 343.0)
    public static let water = Medium(density: 998.0, soundSpeed: 1481.0)

    /// Humid air in a given state. Sound speed, density and absorption all
    /// follow the room: a hologram compiled at one temperature is a different
    /// field one kelvin later (0.18 %/K in c), so temperature is a model input,
    /// not a constant.
    public static func air(temperatureC: Double, humidity: Double = 50,
                           pressure: Double = 101_325) -> Medium {
        let s = AirState(temperatureC: temperatureC, humidity: humidity, pressure: pressure)
        return Medium(density: s.density, soundSpeed: s.soundSpeed, air: s)
    }

    /// The same medium, warmer or colder by `dT` kelvin (fixed media unchanged).
    public func shifted(byKelvin dT: Double) -> Medium {
        guard let s = air else { return self }
        var m = Medium.air(temperatureC: s.temperatureC + dT, humidity: s.humidity,
                           pressure: s.pressure)
        m.extraAbsorption = extraAbsorption
        return m
    }

    public func wavelength(at f: Double) -> Double { soundSpeed / f }
    public func wavenumber(at f: Double) -> Double { 2 * .pi * f / soundSpeed }
    /// Amplitude absorption, nepers per metre: ISO 9613-1 for air, 0 otherwise.
    public func absorption(at f: Double) -> Double { (air?.absorptionNp(at: f) ?? 0) + extraAbsorption }
}

/// Humid air: temperature, relative humidity, static pressure — and the sound
/// speed, density and absorption that follow from them.
public struct AirState: Sendable, Codable, Equatable {
    public var temperatureC: Double
    public var humidity: Double       // relative humidity, %
    public var pressure: Double       // Pa

    public init(temperatureC: Double, humidity: Double = 50, pressure: Double = 101_325) {
        self.temperatureC = temperatureC; self.humidity = humidity; self.pressure = pressure
    }

    static let gasConstant = 8.314462618
    static let referencePressure = 101_325.0

    public var temperatureK: Double { temperatureC + 273.15 }

    /// Mole fraction of water vapour, with the ISO 9613-1 saturation-pressure
    /// formula.
    public var waterMoleFraction: Double {
        let c = -6.8346 * pow(273.16 / temperatureK, 1.261) + 4.6151
        return humidity / 100 * pow(10, c) * AirState.referencePressure / pressure
    }

    var molarMass: Double {
        let x = waterMoleFraction
        return 0.0289647 * (1 - x) + 0.01801528 * x
    }

    /// Ideal-gas mixture of dry air (Cp = 7R/2) and water vapour (Cp = 4R):
    /// 343.24 m/s dry at 20 °C, 343.87 at 50 % RH; +0.18 %/K.
    public var soundSpeed: Double {
        let x = waterMoleFraction
        let gamma = (3.5 * (1 - x) + 4.0 * x) / (2.5 * (1 - x) + 3.0 * x)
        return (gamma * AirState.gasConstant * temperatureK / molarMass).squareRoot()
    }

    public var density: Double { pressure * molarMass / (AirState.gasConstant * temperatureK) }

    /// ISO 9613-1 atmospheric absorption, dB/m: classical plus the oxygen and
    /// nitrogen vibrational relaxations. 4.66 dB/km at 1 kHz (20 °C, 50 %),
    /// 1.32 dB/m at 40 kHz, 3.28 at 100 kHz, 8.23 at 200 kHz.
    public func absorptionDB(at f: Double) -> Double {
        let T = temperatureK, T0 = 293.15
        let pr = AirState.referencePressure, pa = pressure
        let h = 100 * waterMoleFraction                  // ISO uses per cent
        let frO = pa / pr * (24 + 4.04e4 * h * (0.02 + h) / (0.391 + h))
        let frN = pa / pr * pow(T / T0, -0.5)
            * (9 + 280 * h * exp(-4.170 * (pow(T / T0, -1.0 / 3) - 1)))
        let f2 = f * f
        return 8.686 * f2 * (1.84e-11 * (pr / pa) * pow(T / T0, 0.5)
            + pow(T / T0, -2.5) * (0.01275 * exp(-2239.1 / T) / (frO + f2 / frO)
                                   + 0.1068 * exp(-3352.0 / T) / (frN + f2 / frN)))
    }

    public func absorptionNp(at f: Double) -> Double { absorptionDB(at: f) / 8.685889638 }
}
