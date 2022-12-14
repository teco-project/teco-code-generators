import SwiftSyntaxBuilder

func buildDateFormatterDecl(for encoding: some DateEncodingProtocol) -> VariableDecl {
    let dateFormat: String
    switch encoding {
    case .date:
        dateFormat = "yyyy-MM-dd"
    case .timestamp:
        dateFormat = "yyyy-MM-dd HH:mm:ss"
    case .timestamp_iso8601:
        return VariableDecl("""
            private static var formatter: ISO8601DateFormatter {
                ISO8601DateFormatter()
            }
            """)
    default:
        fatalError()
    }
    return VariableDecl("""
        private static var formatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = \(literal: dateFormat)
            formatter.timeZone = .tencentCloud
            return formatter
        }
        """)
}

func buildImportDecls(for encoding: some DateEncodingProtocol) -> CodeBlockItemList {
    switch encoding {
    case .date, .timestamp:
        return CodeBlockItemList {
            ImportDecl("import struct Foundation.Date")
            ImportDecl("import struct Foundation.Locale")
            ImportDecl("import struct Foundation.TimeZone")
            ImportDecl("import class Foundation.DateFormatter")
        }
    case .timestamp_iso8601:
        return CodeBlockItemList {
            ImportDecl("import struct Foundation.Date")
            ImportDecl("import class Foundation.ISO8601DateFormatter")
        }
    default:
        fatalError()
    }
}
