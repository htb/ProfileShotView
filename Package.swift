// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "ProfileShotView",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "ProfileShotView", targets: ["ProfileShotView"]),
    ],
    dependencies: [ ],
    targets: [
        .target(name: "ProfileShotView", dependencies: [], path: "Sources"),
        .testTarget(name: "ProfileShotViewTests", dependencies: ["ProfileShotView"]),
    ]
)
