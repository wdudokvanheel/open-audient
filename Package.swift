// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenAudient",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "OpenAudient", targets: ["OpenAudient"]),
        // The app: launch with no arguments for the GUI, or pass a subcommand
        // (e.g. `oa cut on`) to run headless.
        .executable(name: "oa", targets: ["OpenAudientApp"]),
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
            name: "OpenAudientApp",
            dependencies: ["OpenAudient"]
        ),
        .testTarget(
            name: "OpenAudientTests",
            dependencies: ["OpenAudient"]
        ),
    ]
)
