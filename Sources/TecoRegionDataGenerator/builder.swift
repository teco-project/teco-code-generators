import SwiftSyntax
import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections

func buildRegionExpr(id: String, names: OrderedSet<String>, trailingComma: Bool = false) -> ArrayElementSyntax {
    precondition(names.isEmpty == false)
    let valueExpr = ExprSyntax("Region(id: \(literal: id), localized: \(literal: Array(names)))")
    return ArrayElementSyntax(expression: valueExpr, trailingComma: trailingComma ? .commaToken() : nil)
}

func buildRegionListExpr(from maps: OrderedDictionary<String, String>...) -> ArrayExprSyntax {
    precondition(Set(maps.map(\.keys)).count == 1)
    return ArrayExprSyntax {
        for (index, region) in maps[0].keys.enumerated() {
            buildRegionExpr(id: region, names: .init(maps.map { $0[region]! }), trailingComma: true)
                .with(\.trailingTrivia, .newline)
                .with(\.leadingTrivia, index == 0 ? .newline : [])
        }
    }
}
