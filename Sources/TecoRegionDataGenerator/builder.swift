#if compiler(>=6.0)
internal import OrderedCollections
internal import SwiftSyntax
private import SwiftSyntaxBuilder
private import TecoCodeGeneratorCommons
#else
@_implementationOnly import OrderedCollections
import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons
#endif

func buildRegionExpr(id: String, names: OrderedSet<String>, trailingComma: Bool = false) -> ArrayElementSyntax {
    precondition(names.isEmpty == false)
    let valueExpr = ExprSyntax("Region(id: \(literal: id), localized: \(literal: Array(names)))")
    return ArrayElementSyntax(expression: valueExpr, trailingComma: trailingComma ? .commaToken() : nil)
}

func buildRegionListExpr(from maps: OrderedDictionary<String, String>...) -> ArrayExprSyntax {
    precondition(Set(maps.map(\.keys)).count == 1)
    return ArrayExprSyntax {
        for region in maps[0].keys {
            buildRegionExpr(id: region, names: .init(maps.map { $0[region]! }), trailingComma: true)
        }
    }
}
