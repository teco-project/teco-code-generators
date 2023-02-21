import ArgumentParser
@_implementationOnly import OrderedCollections
import SwiftSyntax
import SwiftSyntaxBuilder
import Foundation
import TecoCodeGeneratorCommons

@main
struct TecoServiceGenerator: TecoCodeGenerator {
    @Option(name: .shortAndLong, completion: .file(extensions: ["json"]), transform: URL.init(fileURLWithPath:))
    var source: URL
    
    @Option(name: .shortAndLong, completion: .file(extensions: ["json"]), transform: URL.init(fileURLWithPath:))
    var errorFile: URL?

    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var outputDir: URL

    @Flag
    var dryRun: Bool = false

    func generate() throws {
        // Check for Regex support
        if #unavailable(macOS 13) {
            print("warning: Documentation may look uglier because the platform doesn't support Regex...")
        }

        let decoder = JSONDecoder()
        let service = try decoder.decode(APIModel.self, from: .init(contentsOf: source))
        let qualifiedName = service.namespace
        let errors: [APIError]

        if let errorFile {
            errors = try decoder.decode([APIError].self, from: .init(contentsOf: errorFile))
                .filter { $0.productShortName == service.metadata.shortName && $0.productVersion == service.metadata.version }
        } else {
            errors = []
        }

        // MARK: Verify data model
        
        var models: OrderedDictionary<String, APIObject> = .init(uniqueKeysWithValues: service.objects)
        do {
            let allModelNames = Set(service.objects.keys)
            precondition(Set(allModelNames).count == service.objects.count)

            // Validate request/response models.
            let requestResponseModelNames = Set(service.actions.map(\.value).flatMap { [$0.input, $0.output] })
            for modelName in requestResponseModelNames {
                precondition(service.objects[modelName] != nil)
                precondition(service.objects[modelName]?.usage == nil)
                models.removeValue(forKey: modelName)
            }

            // Validate model fragments.
            for model in models.values {
                precondition(model.usage != nil)
            }

            // Sort models.
            models.sort()
        }

        // MARK: Clean up output directory

        do {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: outputDir.path, isDirectory: &isDirectory) {
                guard isDirectory.boolValue == true else {
                    fatalError("Unexpectedly find file at \(outputDir.path)!")
                }
                try FileManager.default.removeItem(at: outputDir)
            }
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        }

        // MARK: Generate client source

        do {
            let sourceFile = SourceFileSyntax {
                ImportDeclSyntax("@_exported import TecoCore")
                buildServiceDecl(with: service, withErrors: !errors.isEmpty)
                buildServicePatchSupportDecl(for: qualifiedName)
            }.withCopyrightHeader(generator: Self.self)

            try sourceFile.save(to: outputDir.appendingPathComponent("client.swift"))
        }

        // MARK: Generate model sources

        do {
            let sourceFile = SourceFileSyntax {
                buildDateHelpersImportDecl(for: models.values)

                ExtensionDeclSyntax("extension \(qualifiedName)") {
                    for (model, metadata) in models {
                        StructDeclSyntax("""
                                \(buildDocumentation(summary: metadata.document))
                                public struct \(model): \(metadata.protocols.joined(separator: ", "))
                                """) {
                            for member in metadata.members {
                                VariableDeclSyntax("""
                                    \(raw: buildDocumentation(summary: member.document))
                                    \(raw: publicLetWithWrapper(for: member)) \(raw: member.escapedIdentifier): \(raw: getSwiftType(for: member))
                                    """)
                            }

                            if metadata.protocols.contains("TCInputModel") {
                                buildModelInitializerDeclSyntax(with: metadata.members)
                            }

                            if !metadata.members.isEmpty {
                                EnumDeclSyntax("enum CodingKeys: String, CodingKey") {
                                    for member in metadata.members {
                                        EnumCaseDeclSyntax("case \(raw: member.escapedIdentifier) = \(literal: member.name)")
                                    }
                                }
                            }
                        }
                    }
                }
            }.withCopyrightHeader(generator: Self.self)

            try sourceFile.save(to: outputDir.appendingPathComponent("models.swift"))
        }
        
        // MARK: Generate actions sources
        
        do {
            let outputDir = outputDir.appendingPathComponent("actions", isDirectory: true)
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: false)

            for (action, metadata) in service.actions {
                guard let input = service.objects[metadata.input], input.type == .object,
                      let output = service.objects[metadata.output], output.type == .object else {
                    fatalError("broken API metadata")
                }

                // Skip Multipart-only API
                if !input.members.isEmpty, input.members.allSatisfy({ $0.type == .binary }) {
                    continue
                }

                let sourceFile = SourceFileSyntax {
                    buildDateHelpersImportDecl(for: [input, output])

                    let inputMembers = input.members.filter({ $0.type != .binary })

                    ExtensionDeclSyntax("extension \(qualifiedName)") {
                        StructDeclSyntax("""
                            \(buildDocumentation(summary: input.document))
                            public struct \(metadata.input): TCRequestModel
                            """) {

                            for member in inputMembers {
                                VariableDeclSyntax("""
                                    \(raw: buildDocumentation(summary: member.document))
                                    \(raw: publicLetWithWrapper(for: member)) \(raw: member.escapedIdentifier): \(raw: getSwiftType(for: member))
                                    """)
                            }

                            buildModelInitializerDeclSyntax(with: inputMembers)

                            if !inputMembers.isEmpty {
                                EnumDeclSyntax("enum CodingKeys: String, CodingKey") {
                                    for member in inputMembers {
                                        EnumCaseDeclSyntax("case \(raw: member.escapedIdentifier) = \(literal: member.name)")
                                    }
                                }
                            }
                        }

                        StructDeclSyntax("""
                            \(buildDocumentation(summary: output.document))
                            public struct \(metadata.output): TCResponseModel
                            """) {

                            for member in output.members {
                                VariableDeclSyntax("""
                                    \(raw: buildDocumentation(summary: member.document))
                                    \(raw: publicLetWithWrapper(for: member)) \(raw: member.escapedIdentifier): \(raw: getSwiftType(for: member))
                                    """)
                            }

                            if !output.members.isEmpty {
                                EnumDeclSyntax("enum CodingKeys: String, CodingKey") {
                                    for member in output.members {
                                        EnumCaseDeclSyntax("case \(raw: member.escapedIdentifier) = \(literal: member.name)")
                                    }
                                }
                            }
                        }

                        let discardableResult = output.members.count == 1

                        buildActionDecl(for: action, metadata: metadata, discardableResult: discardableResult)
                        buildAsyncActionDecl(for: action, metadata: metadata, discardableResult: discardableResult)

                        buildUnpackedActionDecl(for: action, metadata: metadata, inputMembers: inputMembers, discardableResult: discardableResult)
                        buildUnpackedAsyncActionDecl(for: action, metadata: metadata, inputMembers: inputMembers, discardableResult: discardableResult)
                    }
                }.withCopyrightHeader(generator: Self.self)
                
                try sourceFile.save(to: outputDir.appendingPathComponent("\(action).swift"))
            }
        }
        
        if !errors.isEmpty {
            // MARK: Generate base error source
            
            let baseErrorName = "\(qualifiedName)Error"
            let errorOutputDir = outputDir.appendingPathComponent("errors", isDirectory: true)
            try FileManager.default.createDirectory(at: errorOutputDir, withIntermediateDirectories: false)
            
            let errorDomains = getErrorDomains(from: errors)
            do {
                let errorType = "TC\(baseErrorName)"
                let sourceFile = SourceFileSyntax {
                    buildServiceErrorTypeDecl(qualifiedName)
                    buildErrorStructDecl(errorType, domains: errorDomains, errorMap: generateErrorMap(from: errors), baseErrorShortname: baseErrorName)
                }.withCopyrightHeader(generator: Self.self)
                
                try sourceFile.save(to: errorOutputDir.appendingPathComponent("\(baseErrorName).swift"))
            }
            
            // MARK: Generate error domain sources
            
            for domain in errorDomains {
                let errorMap = generateDomainedErrorMap(from: errors, for: domain)
                let sourceFile = SourceFileSyntax {
                    ExtensionDeclSyntax("extension TC\(baseErrorName)") {
                        buildErrorStructDecl(domain, errorMap: errorMap, baseErrorShortname: baseErrorName)
                    }
                }.withCopyrightHeader(generator: Self.self)
                
                try sourceFile.save(to: errorOutputDir.appendingPathComponent("\(baseErrorName).\(domain).swift"))
            }
        }
    }
}
