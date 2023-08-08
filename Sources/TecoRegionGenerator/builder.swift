import SwiftSyntax
import SwiftSyntaxBuilder

func buildRegionExpr(for region: Region) -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(callee: ExprSyntax("TCRegion")) {
        LabeledExprSyntax(label: "id", expression: ExprSyntax(literal: region.id))
        if let kind = region.kind {
            LabeledExprSyntax(label: "kind", expression: ExprSyntax(".\(raw: kind)"))
        }
    }
}
