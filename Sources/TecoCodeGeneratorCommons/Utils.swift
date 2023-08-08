import Foundation
import ArgumentParser
@_spi(Diagnostics) import SwiftParser
@_spi(RawSyntax) import SwiftSyntax
import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections

extension String {
    public func lowerFirst() -> String {
        guard let secondWordIndex = self.firstIndex(where: \.isLowercase) else {
            return self.lowercased()
        }
        guard self.first?.isLowercase != true else {
            return self
        }
        var startIndex = self.index(before: secondWordIndex)
        if startIndex != self.startIndex {
            startIndex = self.index(before: startIndex)
        }
        return String(self[...startIndex]).lowercased() + self[index(after: startIndex)...]
    }

    public func upperFirst() -> String {
        return String(self[...startIndex]).uppercased() + self[index(after: startIndex)...]
    }

    public var isSwiftKeyword: Bool {
        var string = self
        if let keyword = string.withSyntaxText(Keyword.init) {
            return TokenKind.keyword(keyword).isLexerClassifiedKeyword
        }
        return false
    }

    public func swiftIdentifierEscaped() -> String {
        (self == "init" || self.isSwiftKeyword) ? "`\(self)`" : self
    }
}

extension TecoCodeGenerator {
    public func ensureDirectory(at url: URL, empty: Bool = false) throws {
        if GeneratorContext.dryRun { return }
        if fileExists(at: url) {
            precondition(isDirectory(url), "Unexpectedly find file at \(url.path)")
            if try !empty || contentsOfDirectory(at: url).isEmpty { return }
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func contentsOfDirectory(at url: URL, subdirectoryOnly: Bool = false) throws -> [URL] {
        let result = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        return subdirectoryOnly ? result.filter(isDirectory) : result
    }

    public func fileExists(at url: URL, executable: Bool = false) -> Bool {
        if executable {
            return FileManager.default.isExecutableFile(atPath: url.path)
        } else {
            return FileManager.default.isReadableFile(atPath: url.path)
        }
    }
}

extension SourceFileSyntax {
    public func withCopyrightHeader() -> SourceFileSyntax {
        let header = """
            //===----------------------------------------------------------------------===//
            //
            // This source file is part of the Teco open source project
            //
            // Copyright (c) \(GeneratorContext.developingYears) the Teco project authors
            // Licensed under Apache License v2.0
            //
            // See LICENSE.txt for license information
            //
            // SPDX-License-Identifier: Apache-2.0
            //
            //===----------------------------------------------------------------------===//

            // THIS FILE IS AUTOMATICALLY GENERATED by \(GeneratorContext.generator).
            // DO NOT EDIT.
            
            
            """
        return self.with(\.leadingTrivia, .lineComment(header) + self.leadingTrivia)
    }

    public func save(to url: URL) throws {
        // Format the code.
        let source = self.formatted(using: CodeGenerationFormat())

        // Validate the generated code.
        guard SourceFileSyntax(source)?.hasError == false else {
            print("Syntax tree validation error!")
            print("==== Generated source (\(url.path)) ====")
            print(source)
            throw ExitCode(100)
        }

        // Skip formatting and writing to disk in dry-run mode
        if GeneratorContext.dryRun { return }

        // Work around styling issues regarding blank lines.
        var sourceCode = source.description.trimmingCharacters(in: .whitespacesAndNewlines).appending("\n")

        // Work around styling issues regarding trailing whitespaces.
        sourceCode = sourceCode.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map {
            var line = $0
            while line.last?.isWhitespace == true {
                line.removeLast()
            }
            return line
        }.joined(separator: "\n")

        // Save to file.
        try sourceCode.write(to: url, atomically: true, encoding: .utf8)
    }
}

public func buildDocumentation(summary: String?, discussion: String? = nil) -> String {
    var pieces: [String] = []

    if let summary, !summary.isEmpty {
        pieces.append(buildDocumentation(summary))
    }
    if let discussion, !discussion.isEmpty {
        pieces.append(buildDocumentation(discussion))
    }
    let document = OrderedSet(pieces).joined(separator: "\n///\n")

    return document
}

private func buildDocumentation(_ document: String) -> String {
    guard !document.isEmpty else { return "" }

    return document
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        .map { line in
            var line = String(line)
            while line.last?.isWhitespace == true {
                line.removeLast()
            }
            return line
        }
        .map { $0.isEmpty ? "///" : "/// \($0)" }
        .joined(separator: "\n")
}

private func isDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    let isFile = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    return isFile && isDirectory.boolValue
}
