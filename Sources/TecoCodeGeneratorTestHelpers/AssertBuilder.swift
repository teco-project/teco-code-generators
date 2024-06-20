import SwiftSyntax
@_implementationOnly import TecoCodeGeneratorCommons
import XCTest

private func buildSyntax(_ buildable: some SyntaxProtocol) -> [String] {
    // Format the code.
    let source = buildable.formatted(using: CodeGenerationFormat())

    // Work around styling issues regarding blank lines.
    let code = source.description.trimmingCharacters(in: .whitespacesAndNewlines)

    // Work around styling issues regarding trailing whitespaces.
    return code.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map {
        var line = $0
        while line.last?.isWhitespace == true {
            line.removeLast()
        }
        return String(line)
    }
}

public func AssertBuilder(_ buildable: some SyntaxProtocol, _ result: String) {
    // Format the code.
    let code = buildSyntax(buildable).joined(separator: "\n")

    // Assert build result
    XCTAssertEqual(code, result)
}

public func AssertBuilder(_ buildable: some SyntaxProtocol, contains lines: [String]) {
    // Format the code.
    let code = buildSyntax(buildable)

    // Assert build result
    for line in lines {
        XCTAssertTrue(code.contains(line))
    }
}
