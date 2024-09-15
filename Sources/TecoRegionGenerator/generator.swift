#if compiler(>=6.0)
private import ArgumentParser
private import struct Foundation.URL
private import SwiftSyntax
private import TecoCodeGeneratorCommons
#else
import ArgumentParser
import struct Foundation.URL
import SwiftSyntax
import TecoCodeGeneratorCommons
#endif

@main
private struct TecoRegionGenerator: TecoCodeGenerator {
    static let startingYear = 2022

    @Option(name: .shortAndLong, completion: .file(extensions: ["swift"]), transform: URL.init(fileURLWithPath:))
    var output: URL

    @Flag
    var dryRun: Bool = false

    func generate() throws {
        let sourceFile = try SourceFileSyntax {
            try StructDeclSyntax("""
                /// Tencent Cloud region identified by Region ID.
                public struct TCRegion: Equatable, Sendable
                """) {
                DeclSyntax("""
                    /// Raw region ID.
                    public var rawValue: String
                    """)

                DeclSyntax("""
                    /// Tencent Cloud service region kind.
                    public enum Kind: Equatable, Sendable {
                        /// Global service regions that are open and accessible within each other.
                        case global
                        /// Financial service regions that are isolated, yet accessible within each other.
                        case financial
                        /// Special service regions that are assumed to be fully isolated.
                        case `internal`
                    }
                    """)
                DeclSyntax("""
                    /// Region type by data isolation.
                    public var kind: Kind
                    """)

                DeclSyntax("""
                    public init(id: String, kind: Kind = .global) {
                        self.rawValue = id
                        self.kind = kind
                    }
                    """)

                for region in regions {
                    DeclSyntax("""
                        /// \(raw: region.description)
                        public static var \(raw: region.identifier): TCRegion {
                            \(buildRegionExpr(for: region))
                        }
                        """)
                }

                DeclSyntax("""
                    /// Returns a ``TCRegion`` with custom Region ID.
                    ///
                    /// - Parameters:
                    ///   - id: Region ID.
                    ///   - kind: Region type by data isolation. Defaults to `.financial` if region ID is suffixed with `-fsi`, else defaults to `.internal`.
                    public static func custom(_ id: String, kind: Kind? = nil) -> TCRegion {
                        TCRegion(id: id, kind: kind ?? Self.defaultKind(from: id))
                    }
                    """)

                DeclSyntax("""
                    public static func == (lhs: TCRegion, rhs: TCRegion) -> Bool {
                        lhs.rawValue == rhs.rawValue
                    }
                    """)
            }

            DeclSyntax("""
                extension TCRegion: CustomStringConvertible {
                    public var description: String { self.rawValue }
                }
                """)

            try ExtensionDeclSyntax("extension TCRegion") {
                DeclSyntax("""
                    /// Returns a Boolean value indicating whether a region is accessible from another.
                    public func isAccessible(from region: TCRegion) -> Bool {
                        self == region || (self.kind == region.kind && self.kind != .internal)
                    }
                    """)

                DeclSyntax("""
                    /// Returns the default region kind inferred from region ID.
                    private static func defaultKind(from regionId: String) -> Kind {
                        regionId.hasSuffix("-fsi") ? .financial : .internal
                    }
                    """)
            }
        }.withCopyrightHeader()

        try sourceFile.save(to: self.output)
    }
}
