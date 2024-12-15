import TecoCodeGeneratorTestHelpers
import XCTest

#if Xcode // Works around FB11980900
@testable import teco_date_wrapper_generator
#else
@testable import TecoDateWrapperGenerator
#endif

final class TecoDateWrapperGeneratorTests: XCTestCase {
    func testImportDeclsBuilder() {
        AssertBuilder(buildImportDecls(for: .date), contains: [
            "import struct Foundation.Date",
            "import class Foundation.DateFormatter"
        ])
        AssertBuilder(buildImportDecls(for: .timestamp), contains: [
            "import struct Foundation.Date",
            "import class Foundation.DateFormatter"
        ])
        AssertBuilder(buildImportDecls(for: .timestamp_iso8601), contains: [
            "import struct Foundation.Date",
            "import class Foundation.ISO8601DateFormatter"
        ])
    }

    func testDateWrapperNames() {
        let expected: Set = ["TCDateEncoding", "TCTimestampEncoding", "TCTimestampISO8601Encoding"]
        XCTAssertEqual(Set(DateEncoding.all.map(\.rawValue)), expected)
    }
}
