// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "stadia-macos-controller",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "stadia-controller-bridge",
            targets: ["stadia-controller-bridge"]
        )
    ],
    targets: [
        .executableTarget(
            name: "stadia-controller-bridge",
            path: "src"
        )
    ]
)
