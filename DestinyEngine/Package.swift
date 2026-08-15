// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "DestinyEngine",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "DestinyEngine",
            targets: ["DestinyEngine"]
        ),
    ],
    targets: [
        // Vendored Swiss Ephemeris C library. See VENDOR.md for provenance
        // and LICENSE-swisseph / agpl-3.0.txt for licensing.
        .target(
            name: "CSwissEphemeris",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                // Vendored, unmodified C source (see VENDOR.md) written
                // before 64-vs-32-bit `long`/int32 conversions were
                // flagged this strictly -- silence just this warning
                // class for this target rather than hand-editing the
                // vendored files to add casts they were never written
                // with. The values involved (Julian day numbers, small
                // array indices) never approach the int32 range limit,
                // so this is cosmetic, not a real precision bug.
                .unsafeFlags(["-Wno-shorten-64-to-32"]),
            ]
        ),
        .target(
            name: "DestinyEngine",
            dependencies: ["CSwissEphemeris"],
            resources: [
                .copy("Resources/Ephemeris")
            ]
        ),
        .testTarget(
            name: "DestinyEngineTests",
            dependencies: ["DestinyEngine"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
