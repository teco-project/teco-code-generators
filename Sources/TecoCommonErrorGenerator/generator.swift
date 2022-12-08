import ArgumentParser
import SwiftSyntaxBuilder
import Foundation
import TecoCodeGeneratorCommons

@main
struct TecoCommonErrorGenerator: ParsableCommand {
    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var output: URL

    func run() throws {
        let codes = getErrorCodes()
        let errors = getErrorDefinitions(from: codes)
        let domains = getErrorDomains(from: codes)

        let primaryType = "TCCommonError"
        do {
            let sourceFile = SourceFile {
                buildErrorStructDecl(primaryType, errors: errors)
                buildErrorDomainListDecl(primaryType, domains: domains)
                buildPartialEquatableDecl(primaryType, key: "error")
                buildErrorCustomStringConvertibleDecl(primaryType)
            }.withCopyrightHeader(generator: Self.self)

            try sourceFile.save(to: self.output.appendingPathComponent("\(primaryType).swift"))
        }

        for domain in domains {
            let qualifiedName = "\(primaryType).\(domain)"
            let errors = getDomainedErrorDefinitions(from: errors, domain: domain)

            let sourceFile = SourceFile {
                ExtensionDecl("extension \(primaryType)") {
                    buildErrorStructDecl(domain, errors: errors)
                }
                buildPartialEquatableDecl(qualifiedName, key: "error")
                buildErrorCustomStringConvertibleDecl(qualifiedName)
                buildBaseErrorConversionDecl(qualifiedName, baseErrorType: primaryType, baseErrorShortname: "CommonError")
            }.withCopyrightHeader(generator: Self.self)

            try sourceFile.save(to: self.output.appendingPathComponent("\(qualifiedName).swift"))
        }
    }
}
