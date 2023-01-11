import Foundation
import SwiftSyntax

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
}

extension FileManager {
    public func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let isFile = self.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isFile && isDirectory.boolValue
    }
}

extension SourceFile {
    public func withCopyrightHeader(generator: ParsableCommand.Type?) -> SourceFile {
        let header = """
            //===----------------------------------------------------------------------===//
            //
            // This source file is part of the Teco open source project.
            //
            // Copyright (c) 2022 the Teco project authors
            // Licensed under Apache License v2.0
            //
            // See LICENSE.txt for license information
            //
            // SPDX-License-Identifier: Apache-2.0
            //
            //===----------------------------------------------------------------------===//

            // THIS FILE IS AUTOMATICALLY GENERATED\(generator != nil ? " by \(generator!.self)" : "").
            // DO NOT EDIT.
            
            
            """
        if let leadingTrivia = self.leadingTrivia {
            return self.withLeadingTrivia(.init(pieces: [.docBlockComment(header)] + leadingTrivia.pieces))
        } else {
            return self.withLeadingTrivia(.lineComment(header))
        }
    }

    public func save(to url: URL) throws {
        // Format the code.
        let source = self.formatted(using: CodeGenerationFormat())

        // Validate the generated code.
        guard SourceFile(source)?.hasError == false else {
            print("Syntax tree validation error!")
            throw ExitCode(100)
        }

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
