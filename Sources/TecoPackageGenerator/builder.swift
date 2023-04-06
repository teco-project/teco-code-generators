import SwiftSyntax
import SwiftSyntaxBuilder

func buildProductExpr(name: String, trailingComma: Bool = false) -> ArrayElementSyntax {
    let valueExpr = ExprSyntax(".library(name: \(literal: name), targets: [\(literal: name)])")
    return ArrayElementSyntax(expression: valueExpr, trailingComma: trailingComma ? .commaToken() : nil)
}

func buildProductListExpr(for targets: [(service: String, version: String)]) -> ArrayExprSyntax {
    ArrayExprSyntax {
        for (index, target) in targets.enumerated() {
            buildProductExpr(name: "Teco\(target.service)\(target.version)", trailingComma: true)
                .with(\.trailingTrivia, .newline)
                .with(\.leadingTrivia, index == 0 ? .newline : nil)
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
    ArrayExprSyntax {
        for target in targets {
            buildTargetExpr(
                name: "Teco\(target.service)\(target.version)",
                path: "./Sources/Teco/\(target.service)/\(target.version)",
                trailingComma: true
            ).with(\.trailingTrivia, .newline)
        }
    }.with(\.leadingTrivia, .newline)
}
