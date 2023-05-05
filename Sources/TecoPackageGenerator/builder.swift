import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

func buildProductExpr(name: String, trailingComma: Bool = false) -> ArrayElementSyntax {
    let valueExpr = ExprSyntax(".library(name: \(literal: name), targets: [\(literal: name)])")
    return ArrayElementSyntax(expression: valueExpr, trailingComma: trailingComma ? .commaToken() : nil)
}

func buildProductListExpr(for targets: [(service: String, version: String)]) -> ArrayExprSyntax {
    ArrayExprSyntax.multiline {
        for target in targets {
            buildProductExpr(name: "Teco\(target.service)\(target.version)", trailingComma: true)
        }
    }
}

func buildTargetExpr(name: String, path: String, trailingComma: Bool = false) -> ArrayElementSyntax {
    let valueExpr = ExprSyntax("""
        .target(name: \(literal: name), dependencies: [.product(name: "TecoCore", package: "teco-core")], path: \(literal: path))
        """)
    return ArrayElementSyntax(expression: valueExpr, trailingComma: trailingComma ? .commaToken() : nil)
}

func buildTargetListExpr(for targets: [(service: String, version: String)]) -> ArrayExprSyntax {
    ArrayExprSyntax.multiline {
        for target in targets {
            buildTargetExpr(
                name: "Teco\(target.service)\(target.version)",
                path: "./Sources/Teco/\(target.service)/\(target.version)",
                trailingComma: true
            )
        }
    }
}
