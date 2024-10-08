#if compiler(>=6.0)
private import ArgumentParser
private import class Foundation.JSONDecoder
private import struct Foundation.URL
private import OrderedCollections
private import SwiftSyntax
private import SwiftSyntaxBuilder
private import TecoCodeGeneratorCommons
#else
import ArgumentParser
import class Foundation.JSONDecoder
import struct Foundation.URL
@_implementationOnly import OrderedCollections
import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons
#endif

@main
private struct TecoServiceGenerator: TecoCodeGenerator {
    static let startingYear = 2022

    @Option(name: .shortAndLong, completion: .file(extensions: ["json"]), transform: URL.init(fileURLWithPath:))
    var source: URL

    @Option(name: .shortAndLong, completion: .file(extensions: ["json"]), transform: URL.init(fileURLWithPath:))
    var errorFile: URL?

    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var outputDir: URL

    @Flag
    var dryRun: Bool = false

    @Option(name: .long)
    var version: Int?

    func generate() throws {
        // Check for Regex support
        if #unavailable(macOS 13) {
            print("warning: Documentation may look uglier because the platform doesn't support Regex...")
        }

        let decoder = JSONDecoder()
        let service = try decoder.decode(APIModel.self, from: .init(contentsOf: source))
        let serviceName = service.namespace
        let errors: [APIError]

        if let errorFile {
            errors = try decoder.decode([APIError].self, from: .init(contentsOf: errorFile))
                .filter { $0.productShortName == service.metadata.shortName && $0.productVersion == service.metadata.version }
        } else {
            errors = []
        }

        try ensureDirectory(at: outputDir, empty: true)

        try ServiceContext.$objects.withValue(service.objects) {

            // MARK: Verify data model

            var models: OrderedDictionary<String, APIObject> = .init(uniqueKeysWithValues: ServiceContext.objects)
            do {
                let allModelNames = Set(ServiceContext.objects.keys)
                precondition(Set(allModelNames).count == ServiceContext.objects.count)

                // Validate request/response models.
                let requestResponseModelNames = Set(service.actions.map(\.value).flatMap { [$0.input, $0.output] })
                for modelName in requestResponseModelNames {
                    precondition(ServiceContext.objects[modelName] != nil)
                    models.removeValue(forKey: modelName)
                }

                // Validate model components.
                for model in models.values {
                    precondition(model.usage != nil)
                }

                // Sort models.
                models.sort()
            }

            // MARK: Generate re-exported interface

            do {
                let sourceFile = SourceFileSyntax {
                    let imports = buildTecoCoreImportDecls(for: .exports(ServiceContext.objects.values))
                    IfConfigDeclSyntax(clauses: [.init(poundKeyword: .poundIfToken(), condition: ExprSyntax("!BUILDING_DOCC"), elements: .statements(imports))])
                }.withCopyrightHeader()

                try sourceFile.save(to: outputDir.appendingPathComponent("exports.swift"))
            }

            // MARK: Generate client source

            do {
                let sourceFile = try SourceFileSyntax {
                    buildTecoCoreImportDecls(for: .client)
                    try buildServiceDecl(with: service, withErrors: !errors.isEmpty)
                    try buildServicePatchSupportDecl(for: serviceName)
                }.withCopyrightHeader()

                try sourceFile.save(to: outputDir.appendingPathComponent("client.swift"))
            }

            // MARK: Generate model sources

            if !models.isEmpty {
                let sourceFile = try SourceFileSyntax {
                    buildTecoCoreImportDecls(for: .models(models.values))

                    try ExtensionDeclSyntax("extension \(raw: serviceName)") {
                        for (model, metadata) in models {
                            try buildGeneralModelDecl(for: model, metadata: metadata)
                        }
                    }
                }.withCopyrightHeader()

                try sourceFile.save(to: outputDir.appendingPathComponent("models.swift"))
            }

            // MARK: Generate actions sources

            do {
                let outputDir = outputDir.appendingPathComponent("actions", isDirectory: true)
                try ensureDirectory(at: outputDir)

                for (action, metadata) in service.actions {
                    guard let input = ServiceContext.objects[metadata.input], input.type == .object,
                          let output = ServiceContext.objects[metadata.output],
                          output.usage == .out || output.type == .object && output.members.contains(where: { $0.name == "RequestId" })
                    else {
                        fatalError("broken API metadata")
                    }

                    let pagination = computePaginationKind(input: input, output: output, service: service, action: metadata)

                    let sourceFile = try SourceFileSyntax {
                        buildTecoCoreImportDecls(for: .action(input: input, output: output))

                        try ExtensionDeclSyntax("extension \(raw: serviceName)") {
                            try buildRequestModelDecl(for: metadata.input, metadata: input, pagination: pagination, output: (metadata.output, output))
                            try buildResponseModelDecl(for: metadata.output, metadata: output, wrapped: output.usage != nil, paginated: pagination != nil)

                            try buildActionDecl(for: action, metadata: metadata, discardable: output.discardable)
                            try buildActionDecl(for: action, metadata: metadata, discardable: output.discardable, async: true)

                            try buildUnpackedActionDecls(for: action, metadata: metadata, unpacking: input.members, discardable: output.discardable)
                            try buildUnpackedActionDecls(for: action, metadata: metadata, unpacking: input.members, discardable: output.discardable, async: true)

                            if pagination != nil {
                                try buildPaginatedActionDecl(for: action, metadata: metadata, output: output)
                                try buildPaginatedActionWithCallbackDecl(for: action, metadata: metadata, output: output)

                                try buildActionPaginatorDecl(for: action, metadata: metadata, output: output)
                            }
                        }
                    }.withCopyrightHeader()

                    try sourceFile.save(to: outputDir.appendingPathComponent("\(action).swift"))
                }
            }

            if !errors.isEmpty {

                // MARK: Generate base error source

                let errorOutputDir = outputDir.appendingPathComponent("errors", isDirectory: true)
                try ensureDirectory(at: errorOutputDir)

                let errorDomains = getErrorDomains(from: errors)
                do {
                    let sourceFile = try SourceFileSyntax {
                        buildTecoCoreImportDecls(for: .error)

                        try buildServiceErrorTypeDecl(serviceName)
                        try buildErrorStructDecl("TC\(serviceName)Error", domains: errorDomains, errorMap: generateErrorMap(from: errors), serviceName: serviceName)
                    }.withCopyrightHeader()

                    try sourceFile.save(to: errorOutputDir.appendingPathComponent("\(serviceName)Error.swift"))
                }

                // MARK: Generate error domain sources

                for domain in errorDomains {
                    let errorMap = generateDomainedErrorMap(from: errors, for: domain)
                    let sourceFile = try SourceFileSyntax {
                        buildTecoCoreImportDecls(for: .error)

                        try ExtensionDeclSyntax("extension TC\(raw: serviceName)Error") {
                            try buildErrorStructDecl(domain, errorMap: errorMap, serviceName: serviceName)
                        }
                    }.withCopyrightHeader()

                    try sourceFile.save(to: errorOutputDir.appendingPathComponent("\(serviceName)Error.\(domain).swift"))
                }
            }
        }
    }
}

extension TecoServiceGenerator {
    var startingYear: Int {
        if let version {
            precondition(version.signum() > 0 && "\(version)".count == 8, "Invalid manifest version")
            return version / 10000
        }
        return Self.startingYear
    }
}
