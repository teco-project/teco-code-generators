import TecoCodeGeneratorTestHelpers
import XCTest

#if Xcode // Works around FB11980900
@testable import teco_package_generator
#else
@testable import TecoPackageGenerator
#endif

final class TecoPackageGeneratorTests: XCTestCase {
    private let services: [(service: String, version: String)] = [
        ("Aa", "V20200224"), ("Ams", "V20200608"), ("Ams", "V20201229"),
    ]

    func testProductExprBuilder() {
        AssertBuilder(buildProductExpr(name: "TecoDemo"), """
            .library(name: "TecoDemo", targets: ["TecoDemo"])
            """)
        AssertBuilder(buildProductExpr(name: "TecoDemo", trailingComma: true), """
            .library(name: "TecoDemo", targets: ["TecoDemo"]),
            """)
    }

    func testProductExprListBuilder() {
        AssertBuilder(buildProductListExpr(for: services), contains: [
            #"    .library(name: "TecoAaV20200224", targets: ["TecoAaV20200224"]),"#,
            #"    .library(name: "TecoAmsV20200608", targets: ["TecoAmsV20200608"]),"#,
            #"    .library(name: "TecoAmsV20201229", targets: ["TecoAmsV20201229"]),"#,
        ])
    }

    func testTargetExprBuilder() {
        AssertBuilder(buildTargetExpr(name: "TecoDemo", path: "./Demo"), """
            .target(name: "TecoDemo", dependencies: [.product(name: "TecoCore", package: "teco-core")], path: "./Demo")
            """)
        AssertBuilder(buildTargetExpr(name: "TecoDemo", path: "./Demo", trailingComma: true), """
            .target(name: "TecoDemo", dependencies: [.product(name: "TecoCore", package: "teco-core")], path: "./Demo"),
            """)
    }

    func testTargetExprListBuilder() {
        AssertBuilder(buildTargetListExpr(for: services), contains: [
            #"    .target(name: "TecoAaV20200224", dependencies: [.product(name: "TecoCore", package: "teco-core")], path: "./Sources/Teco/Aa/V20200224"),"#,
            #"    .target(name: "TecoAmsV20201229", dependencies: [.product(name: "TecoCore", package: "teco-core")], path: "./Sources/Teco/Ams/V20201229"),"#,
            #"    .target(name: "TecoAmsV20200608", dependencies: [.product(name: "TecoCore", package: "teco-core")], path: "./Sources/Teco/Ams/V20200608"),"#,
        ])
    }
}
