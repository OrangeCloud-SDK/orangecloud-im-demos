// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrangeCloudIMDemo",
    platforms: [.iOS(.v16), .macOS(.v13)],
    dependencies: [
        .package(path: "../../ios/OrangeCloudIMClient"),
    ],
    targets: [
        .executableTarget(
            name: "OrangeCloudIMDemo",
            dependencies: ["OrangeCloudIMClient"],
            path: "Sources"
        ),
    ]
)
