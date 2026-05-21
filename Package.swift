// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenAudient",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "OpenAudient", targets: ["OpenAudient"]),
        .executable(name: "oa", targets: ["oa"]),
    ],
    targets: [
        .target(
            name: "OpenAudient",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("IOUSBHost"),
            ]
        ),
        .executableTarget(
            name: "oa",
            dependencies: ["OpenAudient"]
        ),
        .testTarget(
            name: "OpenAudientTests",
            dependencies: ["OpenAudient"]
        ),
    ]
)
