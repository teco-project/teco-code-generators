import SwiftSyntax
import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections

func buildRegionExpr(id: String, names: OrderedSet<String>, trailingComma: Bool = false) -> ArrayElementSyntax {
    precondition(names.isEmpty == false)
    let valueExpr = FunctionCallExprSyntax(callee: ExprSyntax("Region")) {
        TupleExprElementSyntax(label: "id", expression: ExprSyntax("\(literal: id)"))
        TupleExprElementSyntax(label: "localizedNames", expression: ExprSyntax("\(literal: Array(names))"))
    }
    return ArrayElementSyntax(expression: valueExpr, trailingComma: trailingComma ? .commaToken() : nil)
}

func buildRegionListExpr(from maps: OrderedDictionary<String, String>...) -> ArrayExprSyntax {
    let baseKeys = maps[0].keys
    for map in maps.dropFirst() {
        precondition(map.keys == baseKeys)
    }
    return ArrayExprSyntax(elements: ArrayElementListSyntax {
        for id in baseKeys {
            buildRegionExpr(id: id, names: .init(maps.map { $0[id]! }), trailingComma: true)
                .withTrailingTrivia(.newline)
        }
    }.withLeadingTrivia(.newline))
}
