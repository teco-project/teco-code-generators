import SwiftSyntax
import SwiftSyntaxBuilder

func buildRegionExpr(for region: Region) -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(callee: ExprSyntax("TCRegion")) {
        TupleExprElementSyntax(label: "id", expression: ExprSyntax(literal: region.id))
        if let kind = region.kind {
            TupleExprElementSyntax(label: "kind", expression: ExprSyntax(".\(raw: kind)"))
        }
    }
}
