import SwiftSyntax
import SwiftSyntaxBuilder

func buildRegionExpr(for region: Region) -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(callee: ExprSyntax("TCRegion")) {
        TupleExprElementSyntax(label: "id", expression: StringLiteralExprSyntax(content: region.id))
        if let kind = region.kind {
            TupleExprElementSyntax(label: "kind", expression: MemberAccessExprSyntax(name: kind))
        }
    }
}
