#if compiler(>=6.0)
private import ArgumentParser
private import struct Foundation.URL
private import SwiftSyntax
private import SwiftSyntaxBuilder
private import TecoCodeGeneratorCommons
#else
import ArgumentParser
import struct Foundation.URL
import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons
#endif

@main
private struct TecoDateWrapperGenerator: TecoCodeGenerator {
    static let startingYear = 2022

    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var outputDir: URL

    @Flag
    var dryRun: Bool = false

    func generate() throws {
        for encoding in DateEncoding.all {
            let sourceFile = try SourceFileSyntax {
                buildImportDecls(for: encoding)

                try StructDeclSyntax("""
                    @propertyWrapper
                    public struct \(raw: encoding.rawValue)<WrappedValue: TCDateValue>: Codable
                    """) {
                    DeclSyntax("public var wrappedValue: WrappedValue { self.date }")

                    DeclSyntax("""
                        public var projectedValue: StorageValue {
                            get { self.string.withLockedValue { $0 } }
                            nonmutating set {
                                self.string.withLockedValue { $0 = newValue }
                            }
                        }
                        """)

                    DeclSyntax("private let date: WrappedValue")
                    DeclSyntax("private let string: NIOLockedValueBox<StorageValue>")

                    DeclSyntax("""
                        public init(wrappedValue: WrappedValue) {
                            self.date = wrappedValue
                            self.string = NIOLockedValueBox(wrappedValue.encode(formatter: Self._formatter))
                        }
                        """)

                    DeclSyntax("""
                        public init(from decoder: Decoder) throws {
                            let container = try decoder.singleValueContainer()
                            let dateString = try container.decode(StorageValue.self)
                            self.date = try WrappedValue.decode(from: dateString, formatter: Self._formatter, container: container, wrapper: Self.self)
                            self.string = NIOLockedValueBox(dateString)
                        }
                        """)
                }

                try ExtensionDeclSyntax("extension \(raw: encoding.rawValue): TCDateWrapper") {
                    DeclSyntax("""
                        @_spi(_TecoInternals) public static var _valueDescription: StaticString {
                            \(literal: encoding.valueDescription)
                        }
                        """)

                    buildDateFormatterDecl(for: encoding)
                }
            }.withCopyrightHeader()

            try sourceFile.save(to: outputDir.appendingPathComponent("\(encoding.rawValue).swift"))
        }
    }
}
