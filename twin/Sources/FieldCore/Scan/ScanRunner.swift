import Foundation

/// A gate of the earlier six-gate machine, as the app draws it. The FDTD
/// pulse-echo scan that lived here went with `fieldc scan` (tag
/// `twin-before-first-cut`); the open-air scan is `ScanCore.swift`.
public enum Scan {

    /// A gate on the chamber boundary: where it sits and which way it faces.
    public struct Gate: Sendable, Codable {
        public var position: Vec3
        public var normal: Vec3
        public init(position: Vec3, normal: Vec3) {
            self.position = position; self.normal = normal
        }
    }
}
