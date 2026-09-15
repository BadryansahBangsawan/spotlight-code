// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpotlightCode",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SpotlightCode", targets: ["SpotlightCode"])
    ],
    targets: [
        .executableTarget(name: "SpotlightCode", path: "Sources")
    ]
)
