import SwiftSyntax
import SwiftSyntaxBuilder

func buildProductExpr(name: String, trailingComma: Bool = false) -> ArrayElementSyntax {
    let productNameLiteral = name.makeLiteralSyntax()

    let valueExpr = FunctionCallExprSyntax(callee: ExprSyntax(".library")) {
        TupleExprElementSyntax(label: "name", expression: productNameLiteral)
        TupleExprElementSyntax(label: "targets", expression: ArrayExprSyntax(elements: [.init(expression: productNameLiteral)]))
    }
    return ArrayElementSyntax(expression: valueExpr, trailingComma: trailingComma ? .commaToken() : nil)
}

func buildProductListExpr(for targets: [(service: String, version: String)]) -> ArrayExprSyntax {
    ArrayExprSyntax(elements: ArrayElementListSyntax {
        for target in targets {
            buildProductExpr(name: "Teco\(target.service)\(target.version)", trailingComma: true)
                .withTrailingTrivia(.newline)
        }
    }.withLeadingTrivia(.newline))
}

func buildTargetExpr(name: String, path: String, trailingComma: Bool = false) -> ArrayElementSyntax {
    let targetNameLiteral = name.makeLiteralSyntax()
    let targetPathLiteral = path.makeLiteralSyntax()

    let valueExpr = FunctionCallExprSyntax(callee: ExprSyntax(".target")) {
        TupleExprElementSyntax(label: "name", expression: targetNameLiteral)
        TupleExprElementSyntax(label: "dependencies",
                               expression: ArrayExprSyntax(#"[.product(name: "TecoCore", package: "teco-core")]"#))
        TupleExprElementSyntax(label: "path", expression: targetPathLiteral)
    }
    return ArrayElementSyntax(expression: valueExpr, trailingComma: trailingComma ? .commaToken() : nil)
}

func buildTargetListExpr(for targets: [(service: String, version: String)]) -> ArrayExprSyntax {
    ArrayExprSyntax(elements: ArrayElementListSyntax {
        for target in targets {
            buildTargetExpr(
                name: "Teco\(target.service)\(target.version)",
                path: "./Sources/Teco/\(target.service)/\(target.version)",
                trailingComma: true
            ).withTrailingTrivia(.newline)
        }
    }.withLeadingTrivia(.newline))
}
