import SwiftSyntax
import SwiftSyntaxBuilder

@CodeBlockItemListBuilder
func buildImportDecls(for encoding: DateEncoding) -> CodeBlockItemListSyntax {
    switch encoding {
    case .date, .timestamp:
        DeclSyntax("import struct Foundation.Date")
        DeclSyntax("import struct Foundation.Locale")
        DeclSyntax("import struct Foundation.TimeZone")
        DeclSyntax("import class Foundation.DateFormatter")
    case .timestamp_iso8601:
        DeclSyntax("import struct Foundation.Date")
        DeclSyntax("import class Foundation.ISO8601DateFormatter")
    }
    DeclSyntax("@_implementationOnly import struct NIOConcurrencyHelpers.NIOLockedValueBox")
}

func buildDateFormatterDecl(for encoding: DateEncoding) -> some DeclSyntaxProtocol {
    let dateFormat: String
    switch encoding {
    case .date:
        dateFormat = "yyyy-MM-dd"
    case .timestamp:
        dateFormat = "yyyy-MM-dd HH:mm:ss"
    case .timestamp_iso8601:
        return DeclSyntax("""
            @_spi(_TecoInternals) public static var _formatter: ISO8601DateFormatter {
                ISO8601DateFormatter()
            }
            """)
    }
    return DeclSyntax("""
        @_spi(_TecoInternals) public static var _formatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = \(literal: dateFormat)
            formatter.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)
            return formatter
        }
        """)
}
