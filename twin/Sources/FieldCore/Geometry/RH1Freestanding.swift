import Foundation

/// The free-standing RH-1's surroundings, as the engine assumes them.
public enum RH1Freestanding {
    /// Room air the app and CLI simulate unless told otherwise.
    public static let roomAir = Medium.air(temperatureC: 20, humidity: 50)
}
