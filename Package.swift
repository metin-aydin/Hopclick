// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Hopclick",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Hopclick", targets: ["Hopclick"])
    ],
    targets: [
        // Pure decision logic (no AppKit, no Accessibility calls) so it can be unit-tested.
        .target(name: "HopclickCore"),
        .executableTarget(
            name: "Hopclick",
            dependencies: ["HopclickCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(name: "HopclickCoreTests", dependencies: ["HopclickCore"])
    ]
)
