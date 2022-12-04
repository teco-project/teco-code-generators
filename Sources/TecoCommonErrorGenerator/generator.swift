import ArgumentParser
import SwiftSyntaxBuilder
import Foundation
import TecoCodeGeneratorCommons

@main
struct TecoCommonErrorGenerator: ParsableCommand {
    @Option(name: .shortAndLong, completion: .file(extensions: ["swift"]), transform: URL.init(fileURLWithPath:))
    var output: URL?

    @Option(name: .long)
    var type: ErrorType

    func run() throws {
        let errors = commonErrors(for: self.type)
        let errorDomains = errorDomains(from: errors.keys)
        let sourceFile = SourceFile {
            StructDecl("""
                \(self.copyrightHeader())
                public struct \(self.type): TCErrorType
                """) {
                EnumDecl("enum Code: String") {
                    for code in errors.keys {
                        let identifier = code.lowerFirst().replacingOccurrences(of: ".", with: "_")
                        EnumCaseDecl("case \(raw: identifier) = \(literal: code)")
                    }
                }

                VariableDecl("private let error: Code")
                VariableDecl("public let context: TCErrorContext?")
                VariableDecl("""
                    public var errorCode: String {
                        self.error.rawValue
                    }
                    """)

                InitializerDecl("""
                    /// Initialize \(raw: self.type).
                    public init?(errorCode: String, context: TCErrorContext) {
                        guard let error = Code(rawValue: errorCode) else {
                            return nil
                        }
                        self.error = error
                        self.context = context
                    }
                    """)

                InitializerDecl("""
                    internal init(_ error: Code, context: TCErrorContext? = nil) {
                        self.error = error
                        self.context = context
                    }
                    """)

                for (domain, codes) in errorDomains {
                    EnumDecl("public enum \(domain)") {
                        for code in codes {
                            let fullCode = "\(domain).\(code)"
                            let identifier = "\(domain.lowerFirst())_\(code)"
                            let comment = errors[fullCode]!.joined(separator: " / ")
                            VariableDecl("""
                                \(raw: comment.isEmpty ? "" : "/// \(comment)")
                                public static var \(raw: code.lowerFirst()): \(raw: self.type) {
                                    \(raw: self.type)(.\(raw: identifier))
                                }
                                """)
                        }
                    }
                }

                for (code, description) in errors where code.split(separator: ".").count == 1 {
                    let identifier = code.lowerFirst().replacingOccurrences(of: ".", with: "_")
                    let comment = description.joined(separator: " / ")
                    VariableDecl("""
                        \(raw: comment.isEmpty ? "" : "/// \(comment)")
                        public static var \(raw: identifier): \(raw: self.type) {
                            \(raw: self.type)(.\(raw: identifier))
                        }
                        """)
                }
            }

            ExtensionDecl("extension \(self.type): Equatable") {
                FunctionDecl("""
                    public static func == (lhs: \(raw: self.type), rhs: \(raw: self.type)) -> Bool {
                        lhs.error == rhs.error
                    }
                    """)
            }

            ExtensionDecl("extension \(self.type): CustomStringConvertible") {
                VariableDecl(#"""
                    public var description: String {
                        return "\(self.error.rawValue): \(message ?? "")"
                    }
                    """#)
            }
        }

        let source = sourceFile.formatted(using: CodeGenerationFormat())
        guard SourceFile(source)?.hasError == false else {
            print("Can't verify syntax tree!")
            throw ExitCode(100)
        }
        
        // Work around the styling issue which caused a blank line on the top.
        let sourceCode = String(source.description.drop(while: \.isNewline))

        if let outputURL = self.output {
            try sourceCode.write(to: outputURL, atomically: true, encoding: .utf8)
        } else {
            print(sourceCode)
        }
    }
}
