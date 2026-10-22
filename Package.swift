// swift-tools-version: 5.9
import PackageDescription

// The iOS SDK as an app adds it: this repository's URL and a version tag (D39). Swift Package Manager reads this file
// from the root of the repository. The Swift sources are the ones in ios-sdk/, and ConsentCore is the zip that
// ios-sdk/scripts/release.sh builds and whose URL and checksum it writes below. Until the first release they are
// placeholders, so do not tag a commit that still has them.
// ios-sdk/Package.swift is the same package with a local framework, for working in this repository.
let package = Package(
    name: "ConsentSDK",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "ConsentSDK", targets: ["ConsentSDK"]),
    ],
    targets: [
        .binaryTarget(
            name: "ConsentCore",
            url: "https://consent-manager-sdk.s3.us-east-1.amazonaws.com/ios-sdk/2.0.2/ConsentCore.xcframework.zip",
            checksum: "5795b8474cdddcfb5f2c223dffa24143dec981903b491a4d33be16f58b069cdb"
        ),
        .target(name: "ConsentSDK", dependencies: ["ConsentCore"], path: "ios-sdk/Sources/ConsentSDK"),
    ]
)
