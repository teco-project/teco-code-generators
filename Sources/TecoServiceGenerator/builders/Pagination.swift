import SwiftSyntax
import SwiftSyntaxBuilder

func buildGetItemsDecl(with field: APIObject.Field) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        /// Extract the total count from the paginated response.
        public func getItems() -> [\(raw: field.metadata.member)] {
            self.\(raw: field.key)\(raw: field.metadata.nullable ? " ?? []" : "")
        }
        """)
}

func getItemsField(for output: APIObject, service: APIModel) -> APIObject.Field? {
    output.getFieldExactly({ $0.type == .list }, service: service)
}

func getTotalCountField(for output: APIObject, service: APIModel) -> APIObject.Field? {
    // The output contains total count field.
    if let field = output.getFieldExactly({
        ["TotalCount", "TotalCnt", "TotalNum", "TotalElements", "Total"].contains($0.name) && $0.type == .int
    }, service: service) {
        return field
    }
    // The output contains a single integer, which we assume to be total count.
    if let field = output.getFieldExactly({ $0.type == .int }, service: service),
       case let name = field.metadata.name,
       name == "Count" || name.hasPrefix("Total") || name.hasSuffix("Num")
    {
        return field
    }
    // Else...
    return nil
}

func buildGetTotalCountDecl(with field: APIObject.Field) -> FunctionDeclSyntax {
    return FunctionDeclSyntax("""
        /// Extract the total count from the paginated response.
        public func getTotalCount() -> \(raw: getSwiftType(for: field.metadata, forceOptional: true)) {
            self.\(raw: field.key)
        }
        """)
}
