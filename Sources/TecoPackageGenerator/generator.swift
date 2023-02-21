import ArgumentParser
import SwiftSyntax
import SwiftSyntaxBuilder
import Foundation
import TecoCodeGeneratorCommons

@main
struct TecoPackageGenerator: TecoCodeGenerator {
    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var modelDir: URL

    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var packageDir: URL

    @Option(name: .long, completion: .file(), transform: URL.init(fileURLWithPath:))
    var serviceGenerator: URL?

    @Option(name: .long)
    var tecoCoreRequirement: String = #".upToNextMinor(from: "0.4.0")"#

    @Flag
    var dryRun: Bool = false

    func generate() throws {
        var targets: [(service: String, version: String)] = []

        let serviceDirectories = try FileManager.default.contentsOfDirectory(
            at: modelDir.appendingPathComponent("services"),
            includingPropertiesForKeys: nil
        )

        if serviceGenerator != nil {
            try FileManager.default.removeItem(at: packageDir.appendingPathComponent("Sources"))
        }

        var generatorProcesses: [Process] = []

        for service in serviceDirectories where FileManager.default.isDirectory(service) {
            let versionedDirectories = try FileManager.default.contentsOfDirectory(at: service, includingPropertiesForKeys: nil)
            for version in versionedDirectories where FileManager.default.isDirectory(version) {
                let manifestJSON = version.appendingPathComponent("api.json")
                guard FileManager().isReadableFile(atPath: manifestJSON.path) else {
                    fatalError("api.json not found in \(version.path)")
                }
                targets.append((service.lastPathComponent.upperFirst(), version.lastPathComponent.upperFirst()))

                // TODO: Service generation with imported API
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
                        "--output-dir=\(sourceDirectory.path)",
                    ]

                    let errorFilePath = modelDir.appendingPathComponent("error-codes.json")
                    if FileManager().isReadableFile(atPath: errorFilePath.path) {
                        process.arguments?.append("--error-file=\(errorFilePath.path)")
                    }

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

        let packageSwiftFile = SourceFileSyntax {
            ImportDeclSyntax("""
                // swift-tools-version:5.5
                //===----------------------------------------------------------------------===//
                //
                // This source file is part of the Teco open source project
                //
                // Copyright (c) 2022-2023 the Teco project authors
                // Licensed under Apache License v2.0
                //
                // See LICENSE.txt for license information
                //
                // SPDX-License-Identifier: Apache-2.0
                //
                //===----------------------------------------------------------------------===//

                import PackageDescription
                """)

            VariableDeclSyntax("""
                let package = Package(
                    name: "teco",
                    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
                    products: \(buildProductListExpr(for: targets)),
                    dependencies: [
                        .package(url: "https://github.com/teco-project/teco-core.git", \(raw: tecoCoreRequirement))
                    ],
                    targets: \(buildTargetListExpr(for: targets))
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
