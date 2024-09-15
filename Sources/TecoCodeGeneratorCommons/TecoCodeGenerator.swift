#if compiler(>=6.0)
public import ArgumentParser
private import struct Foundation.Calendar
private import struct Foundation.Date
private import class Foundation.FileManager
private import struct Foundation.URL
#else
import ArgumentParser
import struct Foundation.Calendar
import struct Foundation.Date
import class Foundation.FileManager
import struct Foundation.URL
#endif

public struct GeneratorContext {
    @TaskLocal
    public static var generator: String = "TecoCodeGenerator"

    @TaskLocal
    public static var developingYears: String = "\(Date().year)"

    @TaskLocal
    public static var dryRun: Bool = false
}

public protocol TecoCodeGenerator: AsyncParsableCommand {
    static var startingYear: Int { get }
    var dryRun: Bool { get }

    var startingYear: Int { get }

    func generate() async throws
}

extension TecoCodeGenerator {
    public var startingYear: Int { Self.startingYear }

    public func run() async throws {
        try await GeneratorContext.$generator.withValue("\(Self.self)") {
            try await GeneratorContext.$developingYears.withValue(self.developingYears) {
                if dryRun {
                    try await GeneratorContext.$dryRun.withValue(true, operation: generate)
                } else {
                    try await generate()
                }
            }
        }
    }

    private var developingYears: String {
        let startingYear = max(self.startingYear, Self.startingYear)
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
