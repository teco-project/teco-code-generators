import ArgumentParser
import SwiftSyntaxBuilder
import Foundation
import TecoCodeGeneratorCommons

@main
struct TecoDateWrapperGenerator: ParsableCommand {
    @Option(name: .shortAndLong, completion: .directory, transform: URL.init(fileURLWithPath:))
    var outputDir: URL

    func run() throws {
        let encodings: [any DateEncodingProtocol] = DateEncoding.all + OptionalDateEncoding.all

        for encoding in encodings {
            let sourceFile = SourceFile {
                buildImportDecls(for: encoding)

                StructDecl("""
                    @propertyWrapper
                    public struct \(encoding.propertyWrapperType): Codable
                    """) {
                    if encoding.optional {
                        VariableDecl("""
                            public var wrappedValue: Date\(raw: encoding.optionalMark) {
                                didSet {
                                    if let wrappedValue {
                                        self._stringValue = Self.formatter.string(from: wrappedValue)
                                    } else {
                                        self._stringValue = nil
                                    }
                                }
                            }
                            """)
                    } else {
                        VariableDecl("""
                            public var wrappedValue: Date\(raw: encoding.optionalMark) {
                                didSet {
                                    self._stringValue = Self.formatter.string(from: wrappedValue)
                                }
                            }
                            """)
                    }
                    VariableDecl("private var _stringValue: String\(raw: encoding.optionalMark)")
                    VariableDecl("""
                        public var stringValue: String\(raw: encoding.optionalMark) {
                            self._stringValue
                        }
                        """)


                    buildDateFormatterDecl(for: encoding)

                    if encoding.optional {
                        InitializerDecl("""
                            public init(wrappedValue: Date?) {
                                self.wrappedValue = wrappedValue
                                if let wrappedValue {
                                    self._stringValue = Self.formatter.string(from: wrappedValue)
                                } else {
                                    self._stringValue = nil
                                }
                            }
                            """)
                    } else {
                        InitializerDecl("""
                            public init(wrappedValue: Date) {
                                self.wrappedValue = wrappedValue
                                self._stringValue = Self.formatter.string(from: wrappedValue)
                            }
                            """)
                    }

                    InitializerDecl("public init(from decoder: Decoder) throws") {
                        if encoding.optional {
                            GuardStmt("""
                                guard let container = try? decoder.singleValueContainer() else {
                                    self.wrappedValue = nil
                                    self._stringValue = nil
                                    return
                                }
                                """)
                        } else {
                            VariableDecl("let container = try decoder.singleValueContainer()")
                        }
                        VariableDecl("let stringValue = try container.decode(String.self)")
                        GuardStmt(#"""
                            guard let date = Self.formatter.date(from: stringValue) else {
                                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid \#(raw: encoding.description): \(stringValue)")
                            }
                            """#)
                        SequenceExpr("self._stringValue = stringValue")
                        SequenceExpr("self.wrappedValue = date")
                    }

                    FunctionDecl("""
                        public func encode(to encoder: Encoder) throws {
                            try self.stringValue\(raw: encoding.optionalMark).encode(to: encoder)
                        }
                        """)
                }
            }.withCopyrightHeader(generator: Self.self)

            try sourceFile.save(to: outputDir.appendingPathComponent(encoding.propertyWrapperType + ".swift"))
        }
    }
}
