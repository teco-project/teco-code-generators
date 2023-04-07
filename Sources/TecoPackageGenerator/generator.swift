import ArgumentParser
import SwiftSyntax
import SwiftSyntaxBuilder
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

    @Flag
    var dryRun: Bool = false

    func generate() async throws {
        let serviceDirectories = try contentsOfDirectory(at: modelDir.appendingPathComponent("services"), subdirectoryOnly: true)

        if serviceGenerator != nil {
            try ensureDirectory(at: packageDir.appendingPathComponent("Sources"), empty: true)
        }

        let errorFile = {
            let url = modelDir.appendingPathComponent("error-codes.json")
            return fileExists(at: url) ? url : nil
        }()

        let targets: [Target] = try await withThrowingTaskGroup(of: Target.self) { taskGroup in
            for service in serviceDirectories {
                let versionedDirectories = try contentsOfDirectory(at: service, subdirectoryOnly: true)
                for version in versionedDirectories {
                    let manifestJSON = version.appendingPathComponent("api.json")
                    guard fileExists(at: manifestJSON) else {
                        fatalError("api.json not found in \(version.path)")
                    }

                    if let serviceGenerator {
                        let sourceDirectory = packageDir
                            .appendingPathComponent("Sources")
                            .appendingPathComponent("Teco")
                            .appendingPathComponent(service.lastPathComponent.upperFirst())
                            .appendingPathComponent(version.lastPathComponent.upperFirst())

                        taskGroup.addTask {
                            try await generateService(with: serviceGenerator, manifest: manifestJSON, to: sourceDirectory, errorFile: errorFile)
                        }
                    } else {
                        taskGroup.addTask {
                            (service.lastPathComponent.upperFirst(), version.lastPathComponent.upperFirst())
                        }
                    }
                }
            }
            return try await taskGroup.reduce(into: [], { $0.append($1) })
                .sorted { $0.service == $1.service ? $0.version > $1.version : $0.service < $1.service }
        }

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
    }
}
