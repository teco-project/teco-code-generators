import ArgumentParser
import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

@main
struct TecoDateWrapperGenerator: TecoCodeGenerator {
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
                    DeclSyntax("public var wrappedValue: WrappedValue { self._dateValue }")

                    DeclSyntax("""
                        public var projectedValue: StorageValue {
                            get { self._stringValue }
                            set { self._stringValue = newValue }
                        }
                        """)

                    DeclSyntax("private var _dateValue: WrappedValue")
                    DeclSyntax("private var _stringValue: StorageValue")

                    DeclSyntax("""
                        public init(wrappedValue: WrappedValue) {
                            self._dateValue = wrappedValue
                            self._stringValue = wrappedValue.encode(formatter: Self._formatter)
                        }
                        """)

                    DeclSyntax("""
                        public init(from decoder: Decoder) throws {
                            let container = try decoder.singleValueContainer()
                            self._stringValue = try container.decode(StorageValue.self)
                            self._dateValue = try WrappedValue.decode(from: self._stringValue, formatter: Self._formatter, container: container, wrapper: Self.self)
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
