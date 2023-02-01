import ArgumentParser
import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
@_implementationOnly import TecoCore
import TecoCodeGeneratorCommons

@main
struct TecoRegionDataGenerator: AsyncParsableCommand {
    @Option(name: .shortAndLong, completion: .file(extensions: ["swift"]), transform: URL.init(fileURLWithPath:))
    var output: URL

    @Option(name: .long)
    var product: String = "vpc"

    func run() async throws {
        let client = RegionService()
        defer { try? client.client.syncShutdown() }

        let map = getRegionMap(from: try await client.describeRegions(for: product))
        let intlMap = getRegionMap(from: try await client.with(language: .en_US).describeRegions(for: product))

        let sourceFile = SourceFileSyntax {
            ImportDeclSyntax("""
                // THIS FILE IS AUTOMATICALLY GENERATED by TecoRegionDataGenerator.
                // DO NOT EDIT.
                
                @_implementationOnly import OrderedCollections
                """)

            StructDeclSyntax("""
                struct Region: Hashable {
                    let id: String
                    let localizedNames: OrderedSet<String>
                    init(id: String, localizedNames: String...) {
                        self.id = id
                        self.localizedNames = OrderedSet(localizedNames)
                    }
                }
                """)

            VariableDeclSyntax("let regions = \(buildRegionListExpr(from: intlMap, map))")

        }

        try sourceFile.save(to: self.output)
    }
}
