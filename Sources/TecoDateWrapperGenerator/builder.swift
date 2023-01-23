import SwiftSyntax
import SwiftSyntaxBuilder

@CodeBlockItemListBuilder
func buildImportDecls(for encoding: DateEncoding) -> CodeBlockItemListSyntax {
    switch encoding {
    case .date, .timestamp:
        ImportDeclSyntax("import struct Foundation.Date")
        ImportDeclSyntax("import struct Foundation.Locale")
        ImportDeclSyntax("import struct Foundation.TimeZone")
        ImportDeclSyntax("import class Foundation.DateFormatter")
    case .timestamp_iso8601:
        ImportDeclSyntax("import struct Foundation.Date")
        ImportDeclSyntax("import class Foundation.ISO8601DateFormatter")
    }
}

func buildDateFormatterDecl(for encoding: DateEncoding) -> VariableDeclSyntax {
    let dateFormat: String
    switch encoding {
    case .date:
        dateFormat = "yyyy-MM-dd"
    case .timestamp:
        dateFormat = "yyyy-MM-dd HH:mm:ss"
    case .timestamp_iso8601:
        return VariableDeclSyntax("""
            public static var _formatter: ISO8601DateFormatter {
                ISO8601DateFormatter()
            }
            """)
    }
    return VariableDeclSyntax("""
        public static var _formatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = \(literal: dateFormat)
            formatter.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)
            return formatter
        }
        """)
}
