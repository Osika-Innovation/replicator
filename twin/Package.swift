// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "field-compiler",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FieldCore", targets: ["FieldCore"]),
        .executable(name: "fieldc", targets: ["fieldc"]),
        .executable(name: "FieldCompilerApp", targets: ["FieldCompilerApp"]),
    ],
    targets: [
        .target(name: "FieldCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "FieldGPU", dependencies: ["FieldCore"],
                resources: [.copy("Shaders")],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "FieldUI", dependencies: ["FieldCore", "FieldGPU"],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "FieldCompilerApp",
                dependencies: ["FieldCore", "FieldGPU", "FieldUI"],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "fieldc", dependencies: ["FieldCore", "FieldGPU", "FieldUI"],
                swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
