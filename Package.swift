// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PerformancePulse",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(
            name: "PerformancePulse",
            targets: ["PerformancePulse"]),
    ],
    targets: [
        .executableTarget(
            name: "PerformancePulse"),
        .testTarget(
            name: "PerformancePulseTests",
            dependencies: ["PerformancePulse"]),
    ],
    swiftLanguageModes: [.v6]
)
