// swift-tools-version: 6.0
import PackageDescription

// Platform-független logikai réteg. NEM importál HealthKitet.
// Windows-on is fordul és tesztelhető:  cd Packages/HealthCore && swift test
let package = Package(
    name: "HealthCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "HealthCore", targets: ["HealthCore"])
    ],
    targets: [
        .target(name: "HealthCore"),
        .testTarget(name: "HealthCoreTests", dependencies: ["HealthCore"])
    ]
)
