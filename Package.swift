// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "QSParser",
    products: [
        .library(
            name: "QSParser",
            targets: ["QSParser"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "QSParser",
            dependencies: []),
        .testTarget(
            name: "QSParserTests",
            dependencies: ["QSParser"]),
    ]
)
