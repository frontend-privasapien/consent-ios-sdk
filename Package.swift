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
       .binaryTarget(
      name: "ConsentSDK",
      url: "https://consent-manager-sdk.s3.us-east-1.amazonaws.com/ios-sdk/1.0.2/ConsentSDK.xcframework.zip",
      checksum: "164df5d838f98397bf22c22128037463367ba79a8975cbe66dd6e4933e2f6758"
        )
    ]
)
