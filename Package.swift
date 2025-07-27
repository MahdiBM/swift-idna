//swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-idna",
    products: [
        .library(name: "SwiftIDNA", targets: ["SwiftIDNA"])
    ],
    targets: [
        .target(
            name: "SwiftIDNA",
            dependencies: [
                "CSwiftIDNA"
            ],
            swiftSettings: settings
        ),
        .target(name: "CSwiftIDNA"),
        .target(
            name: "CSwiftIDNATesting",
            cSettings: cSettingsIgnoringInvalidSourceCharacters
        ),
        .testTarget(
            name: "IDNATests",
            dependencies: [
                "SwiftIDNA",
                "CSwiftIDNATesting",
            ],
            swiftSettings: settings
        ),
    ]
)

var settings: [SwiftSetting] {
    [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("StrictMemorySafety"),
    ]
}

var cSettingsIgnoringInvalidSourceCharacters: [CSetting] {
    [
        .unsafeFlags(
            [
                "-Wno-unknown-escape-sequence",
                "-Wno-invalid-source-encoding",
            ]
        )
    ]
}
