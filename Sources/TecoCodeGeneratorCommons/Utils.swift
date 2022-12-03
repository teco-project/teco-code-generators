import Foundation

extension String {
    public func lowerFirst() -> String {
        var startIndex = self.index(before: self.firstIndex(where: \.isLowercase)!)
        if startIndex != self.startIndex {
            startIndex = self.index(before: startIndex)
        }
        return String(self[...startIndex]).lowercased() + self[index(after: startIndex)...]
    }
}
