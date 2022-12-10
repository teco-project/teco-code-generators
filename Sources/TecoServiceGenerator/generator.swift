import ArgumentParser
@_implementationOnly import OrderedCollections
import SwiftSyntaxBuilder
import Foundation
import TecoCodeGeneratorCommons

@main
struct TecoServiceGenerator: ParsableCommand {
    @Option(name: .shortAndLong, completion: .file(extensions: ["json"]), transform: URL.init(fileURLWithPath:))
    var source: URL
    
    @Option(name: .shortAndLong, completion: .file(extensions: ["json"]), transform: URL.init(fileURLWithPath:))
    var errorFile: URL?

    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var outputDir: URL

    func run() throws {
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
            assert(Set(allModelNames).count == service.objects.count)

            // Validate request/response models.
            let requestResponseModelNames = Set(service.actions.map(\.value).flatMap { [$0.input, $0.output] })
            for modelName in requestResponseModelNames {
                assert(service.objects[modelName] != nil)
                assert(service.objects[modelName]?.usage == nil)
                models.removeValue(forKey: modelName)
            }

            // Validate model fragments.
            for model in models.values {
                assert(model.usage != nil)
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
            let sourceFile = SourceFile {
                ImportDecl("@_exported import TecoCore")
                buildServiceDecl(with: service, withErrors: !errors.isEmpty)
                buildServicePatchSupportDecl(for: qualifiedName)
            }.withCopyrightHeader(generator: Self.self)

            try sourceFile.save(to: outputDir.appendingPathComponent("client.swift"))
        }

        // MARK: Generate model sources

        do {
            let hasDateField = models.flatMap(\.value.members).contains { model in
                model.member.contains("date") || model.member.contains("time")
            }

            let sourceFile = SourceFile {
                if hasDateField {
                    ImportDecl("@_exported import struct Foundation.Date")
                }
                ExtensionDecl("extension \(qualifiedName)") {
                    for (model, metadata) in models {
                        StructDecl("""
                                \(docComment(metadata.document))
                                public struct \(model): \(metadata.protocols.joined(separator: ", "))
                                """) {
                            for member in metadata.members {
                                VariableDecl("""
                                    \(raw: docComment(member.document))
                                    \(raw: codableFixme(member, usage: metadata.usage))public let \(raw: member.identifier): \(raw: getSwiftType(for: member, usage: metadata.usage))
                                    """)
                            }

                            if metadata.protocols.contains("TCInputModel") {
                                let parameters = metadata.members.map {
                                    "\($0.identifier): \(getSwiftType(for: $0, usage: .in, isInitializer: true))"
                                }
                                InitializerDecl("public init(\(parameters.joined(separator: ", ")))") {
                                    for member in metadata.members.map(\.identifier) {
                                        SequenceExpr("self.\(raw: member) = \(raw: member)")
                                    }
                                }
                            }

                            if !metadata.members.isEmpty {
                                EnumDecl("enum CodingKeys: String, CodingKey") {
                                    for member in metadata.members {
                                        EnumCaseDecl("case \(raw: member.identifier) = \(literal: member.name)")
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
                    fatalError()
                }

                // FIXME: Skip Multipart-only API for now
                if !input.members.isEmpty, input.members.allSatisfy({ $0.type == .binary }) {
                    continue
                }

                let hasDateField = (input.members + output.members).contains { model in
                    model.member.contains("date") || model.member.contains("time")
                }

                let sourceFile = SourceFile {
                    if hasDateField {
                        ImportDecl("@_exported import struct Foundation.Date")
                    }

                    ExtensionDecl("extension \(qualifiedName)") {
                        buildActionDecl(for: action, metadata: metadata)
                        buildAsyncActionDecl(for: action, metadata: metadata)

                        StructDecl("""
                            \(docComment(input.document))
                            public struct \(metadata.input): TCRequestModel
                            """) {
                            let inputMembers = input.members.filter({ $0.type != .binary })

                            for member in inputMembers {
                                VariableDecl("""
                                    \(raw: docComment(member.document))
                                    \(raw: codableFixme(member, usage: .in))public let \(raw: member.identifier): \(raw: getSwiftType(for: member, usage: .in))
                                    """)
                            }

                            let parameters = inputMembers.map {
                                "\($0.identifier): \(getSwiftType(for: $0, usage: .in, isInitializer: true))"
                            }
                            InitializerDecl("public init(\(parameters.joined(separator: ", ")))") {
                                for member in inputMembers.map(\.identifier) {
                                    SequenceExpr("self.\(raw: member) = \(raw: member)")
                                }
                            }

                            if !inputMembers.isEmpty {
                                EnumDecl("enum CodingKeys: String, CodingKey") {
                                    for member in inputMembers {
                                        EnumCaseDecl("case \(raw: member.identifier) = \(literal: member.name)")
                                    }
                                }
                            }
                        }

                        StructDecl("""
                            \(docComment(output.document))
                            public struct \(metadata.output): TCResponseModel
                            """) {
                            for member in output.members {
                                VariableDecl("""
                                    \(raw: docComment(member.document))
                                    \(raw: codableFixme(member, usage: .out))public let \(raw: member.identifier): \(raw: getSwiftType(for: member, usage: .out))
                                    """)
                            }

                            if !output.members.isEmpty {
                                EnumDecl("enum CodingKeys: String, CodingKey") {
                                    for member in output.members {
                                        EnumCaseDecl("case \(raw: member.identifier) = \(literal: member.name)")
                                    }
                                }
                            }
                        }
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
                let sourceFile = SourceFile {
                    buildErrorStructDecl(errorType, errorMap: generateErrorMap(from: errors))
                    if !errorDomains.isEmpty {
                        buildErrorDomainListDecl(errorType, domains: errorDomains)
                    }
                    buildPartialEquatableDecl(errorType, key: "error")
                    buildErrorCustomStringConvertibleDecl(errorType)
                    buildCommonErrorConversionDecl(errorType)
                }
                
                try sourceFile.save(to: errorOutputDir.appendingPathComponent("\(baseErrorName).swift"))
            }
            
            // MARK: Generate error domain sources
            
            for domain in errorDomains {
                let errorType = "TC\(baseErrorName).\(domain)"
                let sourceFile = SourceFile {
                    ExtensionDecl("extension TC\(baseErrorName)") {
                        buildErrorStructDecl(domain, errorMap: generateDomainedErrorMap(from: errors, for: domain))
                    }
                    buildPartialEquatableDecl(errorType, key: "error")
                    buildErrorCustomStringConvertibleDecl(errorType)
                    buildBaseErrorConversionDecl(errorType, baseErrorShortname: baseErrorName)
                    buildCommonErrorConversionDecl(errorType)
                }.withCopyrightHeader(generator: Self.self)
                
                try sourceFile.save(to: errorOutputDir.appendingPathComponent("\(baseErrorName).\(domain).swift"))
            }
        }
    }
}
