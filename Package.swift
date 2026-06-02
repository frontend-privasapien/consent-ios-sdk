// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ConsentSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "ConsentSDK",
            targets: ["ConsentSDK"]
        )
    ],
    targets: [
        // MARK: - Binary Target
        // The XCFramework is hosted on AWS S3 and distributed as a prebuilt binary.
        // Update the URL and checksum when publishing a new version.
        .binaryTarget(
            name: "ConsentSDK",
            // TODO: Replace with production AWS S3 URL after infrastructure setup
            // Expected format: https://<bucket>.s3.<region>.amazonaws.com/ios/ConsentSDK-<version>.xcframework.zip
            url: "https://PLACEHOLDER.s3.us-east-1.amazonaws.com/ios/ConsentSDK-1.0.0.xcframework.zip",
            // TODO: Replace with actual checksum generated via: swift package compute-checksum <file>.zip
            checksum: "PLACEHOLDER_CHECKSUM_REPLACE_AFTER_UPLOAD"
        )
    ]
)
