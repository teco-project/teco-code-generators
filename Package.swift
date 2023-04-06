// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "teco-code-generators",
    platforms: [.macOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(
            name: "teco-common-error-generator",
            targets: ["TecoCommonErrorGenerator"]),
        .executable(
            name: "teco-region-data-generator",
            targets: ["TecoRegionDataGenerator"]),
        .executable(
            name: "teco-region-generator",
            targets: ["TecoRegionGenerator"]),
        .executable(
            name: "teco-service-generator",
            targets: ["TecoServiceGenerator"]),
        .executable(
            name: "teco-package-generator",
            targets: ["TecoPackageGenerator"]),
        .executable(
            name: "teco-date-wrapper-generator",
            targets: ["TecoDateWrapperGenerator"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-syntax.git", exact: "509.0.0-swift-5.9-DEVELOPMENT-SNAPSHOT-2023-03-27-a"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/teco-project/teco-core.git", from: "0.4.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(name: "TecoCodeGeneratorCommons", dependencies: [
            .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "OrderedCollections", package: "swift-collections"),
        ]),
        .executableTarget(
            name: "TecoRegionDataGenerator",
            dependencies: [
                .byName(name: "TecoCodeGeneratorCommons"),
                .product(name: "TecoCore", package: "teco-core"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]),
        .executableTarget(
            name: "TecoCommonErrorGenerator",
            dependencies: [
                .byName(name: "TecoCodeGeneratorCommons"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]),
        .executableTarget(
            name: "TecoRegionGenerator",
            dependencies: [
                .byName(name: "TecoCodeGeneratorCommons"),
            ]),
        .executableTarget(
            name: "TecoServiceGenerator",
            dependencies: [
                .byName(name: "TecoCodeGeneratorCommons"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]),
        .executableTarget(
            name: "TecoPackageGenerator",
            dependencies: [
                .byName(name: "TecoCodeGeneratorCommons"),
            ]),
        .executableTarget(
            name: "TecoDateWrapperGenerator",
            dependencies: [
                .byName(name: "TecoCodeGeneratorCommons"),
            ]),
    ]
)
