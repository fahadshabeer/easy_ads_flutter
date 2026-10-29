// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "easy_ads_sdk",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "easy-ads-sdk", targets: ["easy_ads_sdk"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "easy_ads_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ]
        )
    ]
)
