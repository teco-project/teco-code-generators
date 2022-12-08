import Foundation
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

        let sourceFile = SourceFile {
            StructDecl("""
                /// Enumeration for all Tencent Cloud service regions.
                public struct \(primaryType): RawRepresentable, Equatable, Sendable, Codable
                """) {
                VariableDecl("public var rawValue: String")
                InitializerDecl("""
                    public init(rawValue: String) {
                        self.rawValue = rawValue
                    }
                    """)

                for (region, names) in regions {
                    let identifier = region.replacingOccurrences(of: "-", with: "_")
                    let description = Array(names).joined(separator: " / ")
                    VariableDecl("""
                        /// \(raw: description)
                        public static var \(raw: identifier): \(raw: primaryType) {
                            \(raw: primaryType)(rawValue: \(literal: region))
                        }
                        """)
                }

                FunctionDecl("""
                    /// Other region.
                    public static func other(_ name: String) -> \(raw: primaryType) {
                        \(raw: primaryType)(rawValue: name)
                    }
                    """)
            }

            ExtensionDecl("extension \(primaryType): CustomStringConvertible") {
                VariableDecl("""
                    public var description: String {
                        return self.rawValue
                    }
                    """)
            }

            ExtensionDecl("""
                // Isolation and domain helpers.
                extension \(primaryType)
                """) {
                VariableDecl("""
                    // FSI regions are isolated, which means they can only be accessed with region-specific domains.
                    public var isolated: Bool {
                        self.rawValue.hasSuffix("-fsi")
                    }
                    """)
                FunctionDecl(#"""
                    public func hostname(for service: String, preferringRegional: Bool = false) -> String {
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
