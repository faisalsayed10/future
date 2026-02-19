// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FutureShared",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "FutureShared", targets: ["FutureShared"]),
    ],
    targets: [
        .target(name: "FutureShared"),
    ]
)
