import ArgumentParser
import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

@main
struct TecoCommonErrorGenerator: TecoCodeGenerator {
    static let startingYear = 2022

    @Option(name: .shortAndLong, completion: .file(extensions: ["swift"]), transform: URL.init(fileURLWithPath:))
    var output: URL

    @Option(name: .shortAndLong, completion: .file(extensions: ["json"]), transform: URL.init(fileURLWithPath:))
    var errorFile: URL?

    @Flag
    var dryRun: Bool = false

    func generate() throws {
        let apiErrors = try getAPIErrors(from: errorFile)
        let errors = getCommonErrors(with: apiErrors)

        let sourceFile = try SourceFileSyntax {
            try buildCommonErrorStructDecl(from: errors)

            DeclSyntax(#"""
                extension TCCommonError {
                    /// Returns a Boolean value indicating whether a ``TCCommonError`` belongs to another.
                    internal static func ~= (lhs: Self, rhs: Self) -> Bool {
                        lhs.errorCode.hasPrefix("\(rhs.errorCode).")
                    }
                }
                """#)
        }.withCopyrightHeader()

        try sourceFile.save(to: self.output)
    }
}
