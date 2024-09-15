#if compiler(>=6.0)
internal import SwiftSyntax
private import SwiftSyntaxBuilder
private import TecoCodeGeneratorCommons
#else
import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons
#endif

func buildRequirementExpr(from source: String) throws -> LabeledExprSyntax {
    let separator = source.firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "_" })
    let (label, expression): (String?, String)
    if let separator, source[separator] == ":" {
        label = .init(source.prefix(upTo: separator))
        expression = source.suffix(from: source.index(after: separator)).trimmingCharacters(in: .whitespaces)
    } else {
        (label, expression) = (nil, source)
    }
    let syntax = LabeledExprSyntax(label: label, expression: ExprSyntax("\(raw: expression)"))
    return try LabeledExprSyntax(validating: syntax)
}

func buildProductExpr(name: String, trailingComma: Bool = false) -> ArrayElementSyntax {
    let valueExpr = ExprSyntax(".library(name: \(literal: name), targets: [\(literal: name)])")
    return ArrayElementSyntax(expression: valueExpr, trailingComma: trailingComma ? .commaToken() : nil)
}

func buildProductListExpr(for targets: [(service: String, version: String)]) -> ArrayExprSyntax {
    ArrayExprSyntax {
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
    ArrayExprSyntax {
        for target in targets {
            buildTargetExpr(
                name: "Teco\(target.service)\(target.version)",
                path: "./Sources/Teco/\(target.service)/\(target.version)",
                trailingComma: true
            )
        }
    }
}
