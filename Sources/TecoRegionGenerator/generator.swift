import Foundation
import ArgumentParser
import SwiftSyntax
import TecoCodeGeneratorCommons

@main
struct TecoRegionGenerator: ParsableCommand {
    @Option(name: .shortAndLong, completion: .file(extensions: ["swift"]), transform: URL.init(fileURLWithPath:))
    var output: URL

    func run() throws {
        let tcRegionMap = getRegionMap(from: tcRegions)
        let tcIntlRegionMap = getRegionMap(from: tcIntlRegions)
        let regions = getRegionDescriptionMaps(from: tcIntlRegionMap, tcRegionMap)

        let sourceFile = SourceFileSyntax {
            StructDeclSyntax("""
                /// Tencent Cloud region identified by Region ID.
                public struct TCRegion: Equatable, Sendable
                """) {
                VariableDeclSyntax("""
                    /// Raw region ID.
                    public var rawValue: String
                    """)

                EnumDeclSyntax("""
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
                VariableDeclSyntax("""
                    /// Region type by data isolation.
                    public var kind: Kind
                    """)

                InitializerDeclSyntax("""
                    public init(id: String, kind: Kind = .global) {
                        self.rawValue = id
                        self.kind = kind
                    }
                    """)

                for (region, names) in regions {
                    let identifier = region.replacingOccurrences(of: "-", with: "_")
                    let description = Array(names).joined(separator: " / ")
                    VariableDeclSyntax("""
                        /// \(raw: description)
                        public static var \(raw: identifier): TCRegion {
                            \(buildRegionExpr(for: region))
                        }
                        """)
                }

                FunctionDeclSyntax("""
                    /// Returns a ``TCRegion`` with custom Region ID.
                    ///
                    /// - Parameters:
                    ///   - id: Region ID.
                    ///   - kind: Region type by data isolation. Defaults to `.financial` if region ID is suffixed with `-fsi`, else defaults to `.internal`.
                    public static func custom(_ id: String, kind: Kind? = nil) -> TCRegion {
                        TCRegion(id: id, kind: kind ?? Self.defaultKind(from: id))
                    }
                    """)

                FunctionDeclSyntax("""
                    public static func == (lhs: TCRegion, rhs: TCRegion) -> Bool {
                        lhs.rawValue == rhs.rawValue
                    }
                    """)
            }

            ExtensionDeclSyntax("""
                extension TCRegion: CustomStringConvertible {
                    public var description: String { self.rawValue }
                }
                """)

            ExtensionDeclSyntax(extendedType: TypeSyntax("TCRegion")) {
                FunctionDeclSyntax("""
                    /// Returns a Boolean value indicating whether a region is accessible from another.
                    public func isAccessible(from region: TCRegion) -> Bool {
                        self == region || (self.kind == region.kind && self.kind != .internal)
                    }
                    """)

                FunctionDeclSyntax("""
                    /// Returns the default region kind inferred from region ID.
                    private static func defaultKind(from regionId: String) -> Kind {
                        return regionId.hasSuffix("-fsi") ? .financial : .internal
                    }
                    """)
            }
        }.withCopyrightHeader(generator: Self.self)

        try sourceFile.save(to: self.output)
    }
}
