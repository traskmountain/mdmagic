// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MDMagic",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MDMagic",
            path: "Sources/MDMagic"
        )
    ]
)
