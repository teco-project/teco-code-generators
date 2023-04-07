import ArgumentParser
import struct Foundation.Calendar
import struct Foundation.Date
import class Foundation.FileManager
@_exported import struct Foundation.URL

public struct GeneratorContext {
    @TaskLocal
    public static var generator: String = "TecoCodeGenerator"

    @TaskLocal
    public static var developingYears: String = "\(Calendar.current.component(.year, from: Date()))"

    @TaskLocal
    public static var dryRun: Bool = false
}

public protocol TecoCodeGenerator: AsyncParsableCommand {
    static var startingYear: Int { get }
    var dryRun: Bool { get }

    func generate() async throws
}

extension TecoCodeGenerator {
    public func run() async throws {
        try await GeneratorContext.$generator.withValue("\(Self.self)") {
            try await GeneratorContext.$developingYears.withValue(Self.developingYears) {
                if dryRun {
                    try await GeneratorContext.$dryRun.withValue(true, operation: generate)
                } else {
                    try await generate()
                }
            }
        }
    }

    private static var developingYears: String {
        if startingYear == Date().year {
            return "\(startingYear)"
        } else {
            return "\(startingYear)-\(Date().year)"
        }
    }
}

extension Date {
    fileprivate var year: Int {
        Calendar.current.component(.year, from: self)
    }
}
