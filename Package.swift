// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Nimbus",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Nimbus", targets: ["Nimbus"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Nimbus",
            dependencies: [],
            path: "Sources/Nimbus"
        )
    ]
)
