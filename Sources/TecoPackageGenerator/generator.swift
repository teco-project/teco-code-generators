import ArgumentParser
import SwiftSyntaxBuilder
import Foundation
import TecoCodeGeneratorCommons

@main
struct TecoPackageGenerator: ParsableCommand {
    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var serviceManifests: URL

    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var packageDir: URL

    @Option(name: .long, completion: .file(), transform: URL.init(fileURLWithPath:))
    var serviceGenerator: URL?

    func run() throws {
        var targets: [(service: String, version: String)] = []

        let serviceDirectories = try FileManager.default.contentsOfDirectory(at: serviceManifests, includingPropertiesForKeys: nil)

        if serviceGenerator != nil {
            try FileManager.default.removeItem(at: packageDir.appendingPathComponent("Sources"))
        }

        var generatorProcesses: [Process] = []

        for service in serviceDirectories {
            let versionedDirectories = try FileManager.default.contentsOfDirectory(at: service, includingPropertiesForKeys: nil)
            for version in versionedDirectories {
                let manifestJSON = version.appendingPathComponent("api.json")
                guard FileManager().isReadableFile(atPath: manifestJSON.path) else {
                    fatalError("api.json not found in \(version.path)")
                }
                targets.append((service.lastPathComponent.upperFirst(), version.lastPathComponent.upperFirst()))

                // Experimental service generation
                if let serviceGenerator {
                    let sourceDirectory = packageDir
                        .appendingPathComponent("Sources")
                        .appendingPathComponent("Teco")
                        .appendingPathComponent(service.lastPathComponent.upperFirst())
                        .appendingPathComponent(version.lastPathComponent.upperFirst())

                    let process = Process()
                    process.executableURL = serviceGenerator
                    process.arguments = [
                        "--source=\(manifestJSON.path)",
                        "--error-file=\(serviceManifests.deletingLastPathComponent().path)/error-codes.json",
                        "--output-dir=\(sourceDirectory.path)",
                    ]
                    process.terminationHandler = { process in
                        if process.terminationStatus != 0 {
                            print(process.arguments ?? [], process.terminationReason)
                        }
                    }
                    try process.run()
                    generatorProcesses.append(process)
                }
            }
        }

        targets.sort { $0.service == $1.service ? $0.version > $1.version : $0.service < $1.service }

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
                        platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
                        products: [\(ArrayElementList {
                            for target in targets {
                                let identifier = "Teco\(target.service)\(target.version)"
                                ArrayElement(expression: FunctionCallExpr(".library(name: \(literal: identifier), targets: [\(literal: identifier)])"))
                            }
                        })],
                        dependencies: [
                            .package(url: "https://github.com/teco-project/teco-core.git", .upToNextMinor(from: "0.2.1"))
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

        try packageSwiftFile.save(to: packageDir.appendingPathComponent("Package.swift"))

        // Wait for service generation to complete.
        for process in generatorProcesses {
            process.waitUntilExit()
        }
    }
}
