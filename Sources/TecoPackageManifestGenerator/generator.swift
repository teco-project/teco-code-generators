import ArgumentParser
import SwiftSyntaxBuilder
import Foundation
import TecoCodeGeneratorCommons

@main
struct TecoPackageManifestGenerator: ParsableCommand {
    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var serviceManifests: URL

    @Option(name: .shortAndLong, completion: .file(extensions: ["swift"]), transform: URL.init(fileURLWithPath:))
    var packageManifest: URL

    func run() throws {
        var targets: [(service: String, version: String)] = []

        let serviceDirectories = try FileManager.default.contentsOfDirectory(at: serviceManifests, includingPropertiesForKeys: nil)
        for service in serviceDirectories {
            let versionedDirectories = try FileManager.default.contentsOfDirectory(at: service, includingPropertiesForKeys: nil)
            for version in versionedDirectories {
                guard FileManager().isReadableFile(atPath: version.appendingPathComponent("api.json").path) else {
                    fatalError("api.json not found in \(version.path)")
                }
                targets.append((service.lastPathComponent.upperFirst(), version.lastPathComponent.upperFirst()))
            }
        }
        let packageSwiftFile = SourceFile {
            ImportDecl("""
                // swift-tools-version:5.5
                //===----------------------------------------------------------------------===//
                //
                // This source file is part of the Teco open source project
                //
                // Copyright (c) 2022 the Teco project authors
                // Licensed under Apache License v2.0
                //
                // See LICENSE.txt for license information
                //
                // SPDX-License-Identifier: Apache-2.0
                //
                //===----------------------------------------------------------------------===//

                import PackageDescription
                """)
 
            VariableDecl("""
                let package = Package(
                    name: "teco",
                        platforms: [.macOS(.v11)],
                        products: [\(ArrayElementList {
                            for target in targets {
                                let identifier = "Teco\(target.service)\(target.version)"
                                ArrayElement(expression: FunctionCallExpr(".library(name: \(literal: identifier), targets: [\(literal: identifier)])"))
                            }
                        })],
                        dependencies: [
                            .package(url: "https://github.com/teco-project/teco-core.git", .branch("main"))
                        ],
                        targets: [\(ArrayElementList {
                            let dependency = #"[.product(name: "TecoCore", package: "teco-core")]"#
                            for target in targets {
                                let identifier = "Teco\(target.service)\(target.version)"
                                let path = "./Sources/Teco/\(target.service)/\(target.version)"
                                ArrayElement(expression: FunctionCallExpr(".target(name: \(literal: identifier), dependencies: \(raw: dependency), path: \(literal: path))"))
                            }
                        })]
                )
                """)
        }

        try packageSwiftFile.save(to: packageManifest)
    }
}
