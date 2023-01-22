import ArgumentParser
import SwiftSyntax
import SwiftSyntaxBuilder
import Foundation
import TecoCodeGeneratorCommons

@main
struct TecoCommonErrorGenerator: ParsableCommand {
    @Option(name: .shortAndLong, completion: .file(extensions: ["swift"]), transform: URL.init(fileURLWithPath:))
    var output: URL

    @Option(name: .shortAndLong, completion: .file(extensions: ["json"]), transform: URL.init(fileURLWithPath:))
    var errorFile: URL?

    func run() throws {
        let codes = getErrorCodes()

        let apiErrors: [APIError]
        if let errorFile {
            apiErrors = try JSONDecoder().decode([APIError].self, from: .init(contentsOf: errorFile))
                .filter { $0.productShortName == "PLATFORM" }
        } else {
            apiErrors = []
        }

        let errors = getErrorDefinitions(from: codes, apiErrors: apiErrors)

        let sourceFile = SourceFileSyntax {
            buildCommonErrorStructDecl("TCCommonError", errors: errors)

            ExtensionDeclSyntax(#"""
                extension TCCommonError {
                    /// Returns a Boolean value indicating whether a ``TCCommonError`` belongs to another.
                    internal static func ~= (lhs: Self, rhs: Self) -> Bool {
                        lhs.errorCode.hasPrefix("\(rhs.errorCode).")
                    }
                }
                """#)
        }.withCopyrightHeader(generator: Self.self)

        try sourceFile.save(to: self.output)
    }
}
