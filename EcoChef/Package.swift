// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EcoChef",
    defaultLocalization: "en",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "EcoChef",
            targets: ["AppModule"],
            teamIdentifier: "0000000000",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
            supportedDeviceFamilies: [
                .phone,
                .pad
            ],
            supportedInterfaceOrientations: [
                .portrait
            ],
            capabilities: []
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "EcoChef",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
