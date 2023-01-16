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
                public struct \(primaryType): RawRepresentable, Equatable, Sendable, Codable
                """) {
                VariableDeclSyntax("public var rawValue: String")
                InitializerDeclSyntax("""
                    public init(rawValue: String) {
                        self.rawValue = rawValue
                    }
                    """)

                for (region, names) in regions {
                    let identifier = region.replacingOccurrences(of: "-", with: "_")
                    let description = Array(names).joined(separator: " / ")
                    VariableDeclSyntax("""
                        /// \(raw: description)
                        public static var \(raw: identifier): \(raw: primaryType) {
                            \(raw: primaryType)(rawValue: \(literal: region))
                        }
                        """)
                }

                FunctionDeclSyntax("""
                    /// Constructs a ``TCRegion`` with custom Region ID.
                    public static func other(_ id: String) -> \(raw: primaryType) {
                        \(raw: primaryType)(rawValue: id)
                    }
                    """)
            }

            ExtensionDeclSyntax("extension \(primaryType): CustomStringConvertible") {
                VariableDeclSyntax("""
                    public var description: String {
                        return self.rawValue
                    }
                    """)
            }

            ExtensionDeclSyntax("""
                // Isolation and domain helpers.
                extension \(primaryType)
                """) {
                VariableDeclSyntax("""
                    // FSI regions are isolated, which means they can only be accessed with region-specific domains.
                    internal var isolated: Bool {
                        self.rawValue.hasSuffix("-fsi")
                    }
                    """)
                FunctionDeclSyntax(#"""
                    internal func hostname(for service: String, preferringRegional: Bool = false) -> String {
                        guard self.isolated || preferringRegional else {
                            return "tencentcloudapi.com"
                        }
                        return "\(self.rawValue).tencentcloudapi.com"
                    }
                    """#)
            }
        }.withCopyrightHeader(generator: Self.self)

        try sourceFile.save(to: self.output)
    }
}
