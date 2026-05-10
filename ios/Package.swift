// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrangeCloudIMDemo",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/OrangeCloud-SDK-IM/orangecloud-im-ios.git", from: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "OrangeCloudIMDemo",
            dependencies: [
                .product(name: "OrangeCloudIMClient", package: "orangecloud-im-ios")
            ],
            path: "Sources"
        )
    ]
)
