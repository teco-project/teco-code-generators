import class Foundation.Pipe
import class Foundation.Process
import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

typealias Target = (service: String, version: String)

struct ProcessError: Error {
    let commandLine: String?
    let termination: (status: Int32, reason: Process.TerminationReason)
}

func generateService(with generator: URL, manifest: URL, to directory: URL, errorFile: URL?) async throws -> Target {
    // TODO: Service generation with imported API
    let process = Process()
    process.executableURL = generator

    let version = manifest.deletingLastPathComponent().lastPathComponent.dropFirst()
    precondition(version.count == 8, "Invalid manifest version \(manifest.deletingLastPathComponent().lastPathComponent)")

    let arguments = {
        var arguments = [
            "--source=\(manifest.path)",
            "--output-dir=\(directory.path)",
            "--version=\(version)",
        ]
        if let errorFile {
            arguments.append("--error-file=\(errorFile.path)")
        }
        if GeneratorContext.dryRun {
            arguments.append("--dry-run")
        }
        return arguments
    }()
    process.arguments = arguments

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    try process.run()
    process.waitUntilExit()

    let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
    if let outputString = String(data: output, encoding: .utf8), !outputString.isEmpty {
        print("""
            ======= BEGIN \(manifest.path) =======
            \(outputString.trimmingCharacters(in: .whitespacesAndNewlines))
            ======= END \(manifest.path) =======
            
            """)
    }

    guard process.terminationStatus == 0 else {
        throw ProcessError(
            commandLine: arguments.joined(separator: " "),
            termination: (process.terminationStatus, process.terminationReason)
        )
    }
    return (directory.deletingLastPathComponent().lastPathComponent, directory.lastPathComponent)
}

func parseLabeledExprSyntax(from source: String) throws -> LabeledExprSyntax {
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
