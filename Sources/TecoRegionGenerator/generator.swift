import Foundation
import SwiftSyntax
import TecoCodeGeneratorCommons

@main
struct TecoRegionGenerator: ParsableCommand {
    @Option(name: .shortAndLong, completion: .file(extensions: ["swift"]), transform: URL.init(fileURLWithPath:))
    var output: URL

    func run() throws {
        let tcRegionMap = getRegionMap(from: tcRegions)
        let tcIntlRegionMap = getRegionMap(from: tcIntlRegions)
        let regions = getRegionDescriptionMaps(from: tcRegionMap, tcIntlRegionMap)
        
        let primaryType = "TCRegion"

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
                    public enum Kind: Equatable, Sendable {
                        /// Global service regions that are open and accessible within each other.
                        case global
                        /// Financial service regions that are isolated, yet accessible within each other.
                        case financial
                        /// Financial service regions that are fully isolated.
                        case autoDriving
                        /// Special service regions that are assumed to be fully isolated.
                        case `internal`
                    }
                    """)
                VariableDeclSyntax("public var kind: Kind")

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
                    /// Constructs a ``TCRegion`` with custom Region ID.
                    public static func other(_ id: String, kind: Kind = .internal) -> TCRegion {
                        TCRegion(id: id, kind: kind)
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
                    public var description: String {
                        return self.rawValue
                    }
                }
                """)

            ExtensionDeclSyntax("""
                extension TCRegion {
                    /// Whether a region is accessible from another.
                    public func isAccessible(from region: TCRegion) -> Bool {
                        if self == region {
                            return true
                        }
                        guard self.kind == region.kind else {
                            return false
                        }
                        return self.kind == .global || self.kind == .financial
                    }
                }
                """)
        }.withCopyrightHeader(generator: Self.self)

        try sourceFile.save(to: self.output)
    }
}
