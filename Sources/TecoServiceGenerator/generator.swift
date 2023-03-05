import ArgumentParser
import class Foundation.JSONDecoder
@_implementationOnly import OrderedCollections
import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

@main
struct TecoServiceGenerator: TecoCodeGenerator {
    static let startingYear = 2022

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

        try ensureDirectory(at: outputDir, empty: true)
        
        try ServiceContext.$objects.withValue(service.objects) {

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

            // MARK: Generate client source

            do {
                let sourceFile = SourceFileSyntax {
                    ImportDeclSyntax("@_exported import TecoCore")
                    buildServiceDecl(with: service, withErrors: !errors.isEmpty)
                    buildServicePatchSupportDecl(for: qualifiedName)
                }.withCopyrightHeader()

                try sourceFile.save(to: outputDir.appendingPathComponent("client.swift"))
            }

            // MARK: Generate model sources

            do {
                let sourceFile = SourceFileSyntax {
                    buildDateHelpersImportDecl(for: models.values)

                    ExtensionDeclSyntax("extension \(qualifiedName)") {
                        for (model, metadata) in models {
                            buildGeneralModelDecl(for: model, metadata: metadata)
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
                    guard let input = service.objects[metadata.input], input.type == .object,
                          let output = service.objects[metadata.output], output.type == .object else {
                        fatalError("broken API metadata")
                    }

                    // Skip Multipart-only API
                    if !input.members.isEmpty, input.members.allSatisfy({ $0.type == .binary }) {
                        continue
                    }

                    // TODO: Validate paginated APIs
                    let sourceFile = SourceFileSyntax {
                        buildDateHelpersImportDecl(for: [input, output])
                        ImportDeclSyntax("import TecoPaginationHelpers")
                        
                        let inputMembers = input.members.filter({ $0.type != .binary })
                        let discardableOutput = output.members.count == 1
                        
                        ExtensionDeclSyntax("extension \(qualifiedName)") {
                            buildRequestModelDecl(for: metadata.input, metadata: input)
                            buildResponseModelDecl(for: metadata.output, metadata: output)
                            
                            buildActionDecl(for: action, metadata: metadata, discardableResult: discardableOutput)
                            buildAsyncActionDecl(for: action, metadata: metadata, discardableResult: discardableOutput)
                            
                            buildUnpackedActionDecl(for: action, metadata: metadata, inputMembers: inputMembers, discardableResult: discardableOutput)
                            buildUnpackedAsyncActionDecl(for: action, metadata: metadata, inputMembers: inputMembers, discardableResult: discardableOutput)
                        }
                    }.withCopyrightHeader()

                    try sourceFile.save(to: outputDir.appendingPathComponent("\(action).swift"))
                }
            }

            if !errors.isEmpty {

                // MARK: Generate base error source

                let baseErrorName = "\(qualifiedName)Error"
                let errorOutputDir = outputDir.appendingPathComponent("errors", isDirectory: true)
                try ensureDirectory(at: errorOutputDir)

                let errorDomains = getErrorDomains(from: errors)
                do {
                    let errorType = "TC\(baseErrorName)"
                    let sourceFile = SourceFileSyntax {
                        buildServiceErrorTypeDecl(qualifiedName)
                        buildErrorStructDecl(errorType, domains: errorDomains, errorMap: generateErrorMap(from: errors), baseErrorShortname: baseErrorName)
                    }.withCopyrightHeader()

                    try sourceFile.save(to: errorOutputDir.appendingPathComponent("\(baseErrorName).swift"))
                }

                // MARK: Generate error domain sources
                
                for domain in errorDomains {
                    let errorMap = generateDomainedErrorMap(from: errors, for: domain)
                    let sourceFile = SourceFileSyntax {
                        ExtensionDeclSyntax("extension TC\(baseErrorName)") {
                            buildErrorStructDecl(domain, errorMap: errorMap, baseErrorShortname: baseErrorName)
                        }
                    }.withCopyrightHeader()

                    try sourceFile.save(to: errorOutputDir.appendingPathComponent("\(baseErrorName).\(domain).swift"))
                }
            }
        }
    }
}
