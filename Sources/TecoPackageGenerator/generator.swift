import ArgumentParser
import SwiftSyntax
import SwiftSyntaxBuilder
import class Foundation.Process
import class Foundation.ProcessInfo
import TecoCodeGeneratorCommons

@main
struct TecoPackageGenerator: TecoCodeGenerator {
    static let startingYear = 2022

    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var modelDir: URL

    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var packageDir: URL

    @Option(name: .long, completion: .file(), transform: URL.init(fileURLWithPath:))
    var serviceGenerator: URL?

    @Option(name: .long)
    var tecoCoreRequirement: String = #".upToNextMinor(from: "0.5.0-beta.1")"#

    @Option(name: .short, help: "Maximum jobs to execute in parallel")
    var jobs: Int = ProcessInfo().processorCount

    @Flag
    var dryRun: Bool = false

    func generate() throws {
        var targets: [(service: String, version: String)] = []

        let serviceDirectories = try contentsOfDirectory(at: modelDir.appendingPathComponent("services"), subdirectoryOnly: true)

        if serviceGenerator != nil {
            try ensureDirectory(at: packageDir.appendingPathComponent("Sources"), empty: true)
        }

        var generatorProcesses: [Process] = []

        for (index, service) in serviceDirectories.enumerated() {
            let versionedDirectories = try contentsOfDirectory(at: service, subdirectoryOnly: true)
            for version in versionedDirectories {
                let manifestJSON = version.appendingPathComponent("api.json")
                guard fileExists(at: manifestJSON) else {
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
                    if dryRun {
                        process.arguments?.append("--dry-run")
                    }

                    let errorFilePath = modelDir.appendingPathComponent("error-codes.json")
                    if fileExists(at: errorFilePath) {
                        process.arguments?.append("--error-file=\(errorFilePath.path)")
                    }

                    process.terminationHandler = { process in
                        if process.terminationStatus != 0 {
                            print(process.arguments ?? [], process.terminationReason)
                        }
                    }

                    if index >= self.jobs {
                        generatorProcesses.removeFirst().waitUntilExit()
                    }

                    try process.run()
                    generatorProcesses.append(process)
                }
            }
        }

        targets.sort { $0.service == $1.service ? $0.version > $1.version : $0.service < $1.service }

        let packageSwiftFile = SourceFileSyntax {
            DeclSyntax("""
                // swift-tools-version:5.5
                //===----------------------------------------------------------------------===//
                //
                // This source file is part of the Teco open source project
                //
                // Copyright (c) \(raw: GeneratorContext.developingYears) the Teco project authors
                // Licensed under Apache License v2.0
                //
                // See LICENSE.txt for license information
                //
                // SPDX-License-Identifier: Apache-2.0
                //
                //===----------------------------------------------------------------------===//

                import PackageDescription
                """)

            DeclSyntax("""
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
