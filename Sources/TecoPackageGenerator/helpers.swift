import class Foundation.Process
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

    let arguments = {
        var arguments = [
            "--source=\(manifest.path)",
            "--output-dir=\(directory.path)",
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

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw ProcessError(
            commandLine: arguments.joined(separator: " "),
            termination: (process.terminationStatus, process.terminationReason)
        )
    }
    return (directory.deletingLastPathComponent().lastPathComponent, directory.lastPathComponent)
}
