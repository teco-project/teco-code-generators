import ArgumentParser
import SwiftSyntaxBuilder
import Foundation
import TecoCodeGeneratorCommons

@main
struct TecoDateWrapperGenerator: ParsableCommand {
    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var outputDir: URL

    func run() throws {
        for encoding in DateEncoding.all {
            let sourceFile = SourceFile {
                buildImportDecls(for: encoding)

                StructDecl("""
                    @propertyWrapper
                    public struct \(encoding.rawValue)<WrappedValue: TCDateValue>: Codable
                    """) {
                    VariableDecl("public var wrappedValue: WrappedValue { self._dateValue }")

                    VariableDecl("""
                        public var projectedValue: StorageValue {
                            get { self._stringValue }
                            set { self._stringValue = newValue }
                        }
                        """)

                    VariableDecl("private var _dateValue: WrappedValue")
                    VariableDecl("private var _stringValue: StorageValue")

                    InitializerDecl("""
                        public init(wrappedValue: WrappedValue) {
                            self._dateValue = wrappedValue
                            self._stringValue = wrappedValue.encode(formatter: Self._formatter)
                        }
                        """)

                    InitializerDecl("""
                        public init(from decoder: Decoder) throws {
                            let container = try decoder.singleValueContainer()
                            self._stringValue = try container.decode(StorageValue.self)
                            self._dateValue = try WrappedValue.decode(from: self._stringValue, formatter: Self._formatter, container: container, wrapper: Self.self)
                        }
                        """)
                }

                ExtensionDecl("extension \(encoding.rawValue): TCDateWrapper") {
                    VariableDecl("""
                        public static var _valueDescription: String {
                            \(literal: encoding.valueDescription)
                        }
                        """)

                    buildDateFormatterDecl(for: encoding)
                }
            }.withCopyrightHeader(generator: Self.self)

            try sourceFile.save(to: outputDir.appendingPathComponent(encoding.rawValue + ".swift"))
        }
    }
}
