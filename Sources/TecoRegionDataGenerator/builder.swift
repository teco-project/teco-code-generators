import SwiftSyntax
import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections

func buildRegionExpr(id: String, names: [String], trailingComma: Bool = false) -> ArrayElementSyntax {
    precondition(!names.isEmpty)
    let valueExpr = FunctionCallExprSyntax(callee: ExprSyntax("Region")) {
        TupleExprElementSyntax(label: "id", expression: ExprSyntax("\(literal: id)"))
        TupleExprElementSyntax(label: "localizedNames", expression: ExprSyntax("\(literal: names[0])"))
        for name in names[1...] {
            TupleExprElementSyntax(expression: ExprSyntax("\(literal: name)"))
        }
    }
    return ArrayElementSyntax(expression: valueExpr, trailingComma: trailingComma ? .commaToken() : nil)
}

func buildRegionListExpr(from maps: OrderedDictionary<String, String>...) -> ArrayExprSyntax {
    let baseKeys = maps[0].keys
    if maps.count > 1 {
        for map in maps[1...] {
            precondition(map.keys == baseKeys)
        }
    }
    return ArrayExprSyntax(elements: ArrayElementListSyntax {
        for id in baseKeys {
            buildRegionExpr(id: id, names: maps.map { $0[id]! }, trailingComma: true)
                .withTrailingTrivia(.newline)
        }
    }.withLeadingTrivia(.newline))
}
