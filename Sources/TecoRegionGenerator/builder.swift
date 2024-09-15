#if compiler(>=6.0)
internal import SwiftSyntax
private import SwiftSyntaxBuilder
#else
import SwiftSyntax
import SwiftSyntaxBuilder
#endif

func buildRegionExpr(for region: Region) -> some ExprSyntaxProtocol {
    FunctionCallExprSyntax(callee: ExprSyntax("TCRegion")) {
        LabeledExprSyntax(label: "id", expression: ExprSyntax(literal: region.id))
        if let kind = region.kind {
            LabeledExprSyntax(label: "kind", expression: ExprSyntax(".\(raw: kind)"))
        }
    }
}
