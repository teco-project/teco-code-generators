@_implementationOnly import RegexBuilder
import SwiftSyntax

enum ServiceContext {
    @TaskLocal
    static var objects: [String : APIObject] = [:]
}

func skipAuthorizationParameter(for action: String) -> String {
    // Special rule for sts:AssumeRoleWithSAML & sts:AssumeRoleWithWebIdentity
    return action.hasPrefix("AssumeRoleWith") ? ", skipAuthorization: true" : ""
}

func formatDocumentation(_ documentation: Substring?) -> String? {
    formatDocumentation(documentation.map(String.init))
}

func zipMarkdownLine(_ text: Substring) -> Substring {
    text.replacing(.newlineSequence, with: " ")
}

@RegexComponentBuilder
func htmlOpeningTagCapturingAttributesRegex(for name: some RegexComponent<Substring>) -> some RegexComponent<(Substring, Substring?)> {
    "<"
    name
    ChoiceOf {
        Lookahead(">")
        Regex {
            OneOrMore(.whitespace)
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
        }
    }
    ">"
}

@RegexComponentBuilder
func htmlOpeningTagRegex(for name: some RegexComponent<Substring>) -> some RegexComponent<Substring> {
    "<"
    name
    ChoiceOf {
        Lookahead(">")
        Regex {
            OneOrMore(.whitespace)
            ZeroOrMore(.any, .reluctant)
        }
    }
    ">"
}

@RegexComponentBuilder
func htmlClosingTagRegex(for name: some RegexComponent<Substring>) -> some RegexComponent<Substring> {
    "</"
    name
    ">"
}

@RegexComponentBuilder
func htmlAttributeRegex(named name: some RegexComponent<Substring>) -> some RegexComponent<(Substring, Substring)> {
    name
    "="
    Capture {
        ChoiceOf {
            Regex {
                NegativeLookahead("\"")
                ZeroOrMore(.any, .reluctant)
                Lookahead {
                    ChoiceOf {
                        One(.whitespace)
                        Anchor.endOfLine
                    }
                }
            }
            Regex {
                "\""
                ZeroOrMore(.any, .reluctant)
                "\""
            }
        }
    } transform: { value -> Substring in
        let quotedRegex = Regex {
            "\""
            Capture {
                ZeroOrMore(.any)
            } transform: { match in
                match.replacing(#"\""#, with: "\"")
            }
            "\""
        }
        if let quoted = value.wholeMatch(of: quotedRegex) {
            return quoted.1
        } else {
            return value
        }
    }
}

@RegexComponentBuilder
func htmlClosingTagRegex(for name: some RegexComponent<Substring>, @AlternationBuilder alternativeLookaheads: () -> some RegexComponent<Substring>) -> some RegexComponent<Substring> {
    let tagRegex = htmlClosingTagRegex(for: name)
    Lookahead {
        ChoiceOf {
            tagRegex
            alternativeLookaheads()
        }
    }
    Optionally(tagRegex)
}

func formatDocumentation(_ documentation: String?) -> String? {
    guard var documentation, !documentation.isEmpty, documentation != "无" else {
        return nil
    }

    let newlineAndWhitespaceRegex = ChoiceOf {
        One(.newlineSequence)
        One(.whitespace)
    }

    // Strip <div> tags
    do {
        let divTagRegex = Regex {
            htmlOpeningTagRegex(for: "div")
            ZeroOrMore(newlineAndWhitespaceRegex)
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            ZeroOrMore(newlineAndWhitespaceRegex)
            htmlClosingTagRegex(for: "div")
        }
        // Do this one by one to handle nested <div>
        while let match = documentation.firstMatch(of: divTagRegex) {
            documentation.replaceSubrange(match.range, with: match.1)
        }
        // Handle unclosed <div> tags
        documentation.replace(htmlOpeningTagRegex(for: "div"), with: "")
    }

    // Strip <pre> tags
    do {
        let preTagRegex = Regex {
            htmlOpeningTagRegex(for: "pre")
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            htmlClosingTagRegex(for: "pre")
        }
        documentation.replace(preTagRegex, with: \.1)
    }

    // Convert <br> to new paragraph
    do {
        let brTagsWithTrailingWhitespacesRegex = Regex {
            "<"
            ChoiceOf {
                Regex {
                    "br"
                    ZeroOrMore(.whitespace)
                    Optionally("/")
                }
                // Special handling for typo...
                "/br"
            }
            ">"
            ZeroOrMore(.whitespace)
        }
        documentation.replace(brTagsWithTrailingWhitespacesRegex, with: "\n\n")
    }

    // Convert <ul> and <li> to list
    do {
        func firstTagToTransform(in text: String) -> (range: Range<String.Index>, content: Substring)? {
            let ulTag = firstULTag(from: .init(text))
            let liTag = firstLITag(from: .init(text))
            switch (ulTag, liTag) {
            case (.some(let ulTag), .some(var liTag)):
                liTag.content = documentation[liTag.range]
                let tag = liTag.range.lowerBound < ulTag.range.lowerBound ? liTag : ulTag
                return (tag.range, tag.content)
            case (.some(let ulTag), nil):
                return ulTag
            case (nil, .some(let liTag)):
                return (liTag.range, documentation[liTag.range])
            case (nil, nil):
                return nil
            }
        }
        while let tag = firstTagToTransform(in: documentation) {
            documentation.replaceSubrange(tag.range, with: formatList(tag.content))
        }
    }

    // Strip blank lines between sibling list items
    do {
        let siblingListItemRegex = Regex {
            One(.newlineSequence)
            Capture {
                "- "
                ZeroOrMore(.anyNonNewline)
            }
            One(.newlineSequence)
            ZeroOrMore(.whitespace)
            One(.newlineSequence)
            Capture {
                "- "
                ZeroOrMore(.anyNonNewline)
            }
        }
        while let match = try? siblingListItemRegex.firstMatch(in: documentation) {
            documentation.replaceSubrange(match.range, with: "\n\(match.1)\n\(match.2)")
        }
    }

    // Convert <code> to code block
    do {
        let codeTagRegex = Regex {
            Capture {
                ZeroOrMore(newlineAndWhitespaceRegex)
            }
            htmlOpeningTagRegex(for: "code")
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            htmlClosingTagRegex(for: "code")
        }
        documentation.replace(codeTagRegex) { match in
            let leadingBlank = match.1
            let code = match.2.trimmingCharacters(in: .whitespacesAndNewlines)
            if code.contains(where: \.isNewline) || leadingBlank.contains(where: \.isNewline) {
                return """
                
                ```
                \(code)
                ```
                
                """
            } else {
                return "\(leadingBlank)`\(match.2)`"
            }
        }
    }

    // Convert <p> to new paragraph
    do {
        let pTagRegex = Regex {
            htmlOpeningTagCapturingAttributesRegex(for: "p")
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            htmlClosingTagRegex(for: "p") {
                htmlOpeningTagRegex(for: "p")
                Anchor.endOfSubject
            }
        }
        let colorCSSRegex = Regex {
            ZeroOrMore(.whitespace)
            "color"
            ZeroOrMore(.whitespace)
            ":"
            ZeroOrMore(.whitespace)
            OneOrMore(.any, .reluctant)
            ZeroOrMore(.whitespace)
        }
        documentation.replace(pTagRegex) { match in
            var content = match.2.trimmingCharacters(in: .whitespacesAndNewlines)
            // Only apply style if there's color CSS style
            if let styleMatch = match.1?.firstMatch(of: htmlAttributeRegex(named: "style")),
               case let styles = styleMatch.1.split(separator: ";"),
               styles.contains(where: { (try? colorCSSRegex.wholeMatch(in: $0)) != nil }) {
                content = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                    .map { $0.allSatisfy(\.isWhitespace) ? $0 : "_\($0)_" }
                    .joined(separator: "\n")
            }
            return "\n\n\(content)\n\n"
        }
    }

    // Convert <a> to [text](link)
    do {
        let aTagRegex = Regex {
            htmlOpeningTagCapturingAttributesRegex(for: "a")
            Optionally("[")
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            Optionally("]")
            htmlClosingTagRegex(for: "a")
        }
        documentation.replace(aTagRegex) { match in
            if match.2.isEmpty {
                return ""
            }
            guard let hrefMatch = match.1?.firstMatch(of: htmlAttributeRegex(named: "href")),
                  case let href = hrefMatch.1.trimmingCharacters(in: .whitespacesAndNewlines),
                  !href.isEmpty, !href.hasPrefix("#") else {
                return "\(match.2)"
            }
            return "[\(zipMarkdownLine(match.2))](\(href))"
        }
    }

    // Convert <del> to ~~deleted~~
    do {
        let delTagRegex = Regex {
            htmlOpeningTagRegex(for: "del")
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            htmlClosingTagRegex(for: "del")
        }
        documentation.replace(delTagRegex) { match in
            match.1.isEmpty ? "" : "~~\(zipMarkdownLine(match.1))~~"
        }
    }

    // Convert <font> to _italic_
    do {
        let fontTagRegex = Regex {
            htmlOpeningTagCapturingAttributesRegex(for: "font")
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            htmlClosingTagRegex(for: "font")
        }
        documentation.replace(fontTagRegex) { match in
            // Only apply style if there's "color" attribute on <font>
            guard match.1?.contains(htmlAttributeRegex(named: "color")) == true, !match.2.isEmpty else {
                return match.2
            }
            return "_\(zipMarkdownLine(match.2))_"
        }
    }

    // Convert <b> and <strong> to **bold**
    do {
        let bTagRegex = Regex {
            htmlOpeningTagRegex(for: "b")
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            htmlClosingTagRegex(for: "b")
        }
        let strongTagRegex = Regex {
            htmlOpeningTagRegex(for: "strong")
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            htmlClosingTagRegex(for: "strong")
        }
        for tagRegex in [bTagRegex, strongTagRegex] {
            documentation.replace(tagRegex) { match in
                match.1.isEmpty ? "" : "**\(zipMarkdownLine(match.1))**"
            }
        }
    }

    // Convert <h1> - <h5> to #
    do {
        for level in 1...5 {
            let hTagRegex = Regex {
                htmlOpeningTagRegex(for: "h\(level)")
                Capture {
                    ZeroOrMore(.any, .reluctant)
                }
                htmlClosingTagRegex(for: "h\(level)")
            }
            documentation.replace(hTagRegex) { match in
                return "\n\(String(repeating: "#", count: level)) \(zipMarkdownLine(match.1))\n"
            }
        }
    }

    // Convert <table> to GFM table
    do {
        let tableTagRegex = Regex {
            htmlOpeningTagRegex(for: "table")
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            htmlClosingTagRegex(for: "table")
        }
        let tableHeadTagRegex = Regex {
            ChoiceOf {
                htmlOpeningTagRegex(for: "thead")
                // Special handling for typo...
                "<thread>"
            }
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            ChoiceOf {
                htmlClosingTagRegex(for: "thead")
                // Special handling for typo...
                "</thread>"
            }
        }
        let tableBodyTagRegex = Regex {
            htmlOpeningTagRegex(for: "tbody")
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            htmlClosingTagRegex(for: "tbody")
        }
        let tableRowRegex = Regex {
            htmlOpeningTagRegex(for: "tr")
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            htmlClosingTagRegex(for: "tr")
        }
        let tableCellRegex = Regex {
            let tagName = ChoiceOf {
                "td"
                "th"
            }
            htmlOpeningTagCapturingAttributesRegex(for: tagName)
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            htmlClosingTagRegex(for: tagName)
        }
        func getTableRows(from text: Substring) -> [[Substring]] {
            let content = text
                .replacing(tableHeadTagRegex, with: \.1)
                .replacing(tableBodyTagRegex, with: \.1)
            var matches = content.matches(of: tableRowRegex).map(\.1)
            if let lowerBound = matches.first?.startIndex, content[..<lowerBound].contains(tableCellRegex) {
                matches.insert(content[..<lowerBound], at: 0)
            }
            var result: [[Substring]] = []
            var rowspans: [(Substring, at: Int, upTo: Int)] = []
            for (rowId, rowContent) in matches.enumerated() {
                var cells: [Substring] = []
                for cellMatch in rowContent.matches(of: tableCellRegex) {
                    while let toInsert = rowspans.first(where: { $0.at == cells.count && $0.upTo > rowId }) {
                        cells.append(toInsert.0)
                    }
                    if let rowspanMatch = cellMatch.1?.firstMatch(of: htmlAttributeRegex(named: "rowspan")),
                       let rowspan = Int(rowspanMatch.1) {
                        rowspans.append((cellMatch.2, cells.count, rowId + rowspan))
                    }
                    cells.append(cellMatch.2)
                }
                result.append(cells)
            }
            return result
        }
        func buildRow(from cells: [Substring]) -> String {
            let twoOrMoreNewlinesRegex = Regex {
                ZeroOrMore(.whitespace)
                Repeat(1...) {
                    ZeroOrMore(.whitespace)
                    One(.newlineSequence)
                }
            }
            let cellContents = cells.map { content in
                content.trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(separator: twoOrMoreNewlinesRegex)
                    .map { line in
                        line.trimmingCharacters(in: .whitespaces)
                            .split(whereSeparator: \.isNewline)
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .joined(separator: " ")
                    }
                    .joined(separator: "<br>")
            }
            return "|\(cellContents.map({ $0.isEmpty ? " " : " \($0) " }).joined(separator: "|"))|"
        }
        documentation.replace(tableTagRegex) { match in
            let rows = getTableRows(from: match.1)
            return """
                
                \(buildRow(from: rows[0]))
                |\([String](repeating: "---", count: rows[0].count).joined(separator: "|"))|
                \(rows[1...].map(buildRow).joined(separator: "\n"))
                
                """
        }
    }

    // Convert `>?` to attention block
    do {
        let attentionMarkRegex = Regex {
            Optionally(.newlineSequence)
            ">?"
            Capture {
                ZeroOrMore(.anyNonNewline)
            }
        }
        let attentionPrefixRegex = Regex {
            ZeroOrMore(.whitespace)
            ZeroOrMore {
                ChoiceOf {
                    ">"
                    "-"
                }
            }
            ZeroOrMore(.whitespace)
            Capture {
                ZeroOrMore(.anyNonNewline)
            }
        }
        documentation.replace(attentionMarkRegex) { match in
            if match.1.allSatisfy(\.isWhitespace) {
                return "\n#### Attention\n"
            }
            guard let contentMatch = try? attentionPrefixRegex.wholeMatch(in: match.1) else {
                assertionFailure("Unable to extract content in attention block.")
                return "\(match.1)"
            }
            return "\n- Attention: \(contentMatch.1)"
        }
    }

    // Remove extra "\n>\n" sequence
    do {
        let unwantedAngleRegex = Regex {
            One(.newlineSequence)
            ">"
            ZeroOrMore(.whitespace, .reluctant)
            One(.newlineSequence)
        }
        let documentationCopy = documentation
        documentation.replace(unwantedAngleRegex) { match in
            guard match.endIndex < documentationCopy.endIndex, documentationCopy[match.endIndex] == ">" else {
                if documentationCopy[documentationCopy.index(before: match.startIndex)].isNewline {
                    return ""
                } else {
                    return "\n"
                }
            }
            return .init(match.output)
        }
    }

    // Merge three or more newlines to two
    do {
        let threeOrMoreNewlinesRegex = Regex {
            One(.newlineSequence)
            Repeat(2...) {
                ZeroOrMore(.whitespace)
                One(.newlineSequence)
            }
        }
        documentation.replace(threeOrMoreNewlinesRegex, with: "\n\n")
    }
    return documentation.trimmingCharacters(in: .whitespacesAndNewlines)
}

func firstULTag(from text: Substring, ignoreLevel: Bool = false, consumeLeadingNewlines: Bool = false) -> (range: Range<String.Index>, content: Substring)? {
    // Fold leading newlines on demand
    let ulTagWithLeadingNewlinesRegex = Regex {
        ZeroOrMore {
            ChoiceOf {
                One(.newlineSequence)
                One(.whitespace)
            }
        }
        htmlOpeningTagRegex(for: "ul")
    }
    guard let opening = text.firstRange(of: consumeLeadingNewlines ? ulTagWithLeadingNewlinesRegex : htmlOpeningTagRegex(for: "ul").regex) else {
        return nil
    }
    // This indicates a nested context which is closed before new <ul> tags
    if let closing = text.firstRange(of: htmlClosingTagRegex(for: "ul")), closing.lowerBound < opening.lowerBound {
        return nil
    }
    // This indicates the <ul> is nested in deeper context inside a <li> tag
    if !ignoreLevel, let liTag = text.firstRange(of: htmlOpeningTagRegex(for: "li")), liTag.lowerBound < opening.lowerBound {
        return nil
    }
    // Bump the pointer to the end of nested <ul> lists
    var pointer = opening.upperBound
    while let ulTag = firstULTag(from: text[pointer...], ignoreLevel: true) {
        pointer = ulTag.range.upperBound
    }
    // Search for the real closing tag
    let closingTagRegex = ChoiceOf {
        htmlClosingTagRegex(for: "ul")
        // Special handling for typo...
        "</u>"
    }
    guard let closing = text[pointer...].firstRange(of: closingTagRegex) else {
        let bound = text[pointer...].firstIndex(where: \.isNewline) ?? text.endIndex
        return (opening.lowerBound..<bound, text[opening.upperBound..<bound])
    }
    return (opening.lowerBound..<closing.upperBound, text[opening.upperBound..<closing.lowerBound])
}

func firstLITag(from text: Substring) -> (range: Range<String.Index>, content: Substring)? {
    // Find the first </li> tag
    func closeLITag(from text: Substring) -> Range<String.Index> {
        let closingTagRegex = ChoiceOf {
            htmlClosingTagRegex(for: "li")
            // Special handling for typo...
            "<l/i>"
        }
        guard let closing = text.firstRange(of: closingTagRegex) else {
            let bound = text.firstIndex(where: \.isNewline) ?? text.endIndex
            return bound..<bound
        }
        return closing
    }
    // Find all leading newlines
    let liTagWithLeadingNewlineRegex = Regex {
        ZeroOrMore {
            ChoiceOf {
                One(.newlineSequence)
                One(.whitespace)
            }
        }
        htmlOpeningTagRegex(for: "li")
    }
    guard var opening = text.firstRange(of: liTagWithLeadingNewlineRegex) else {
        return nil
    }
    // Only consume one line break
    if let newline = text[opening].lastIndex(where: \.isNewline) {
        opening = newline..<opening.upperBound
    }
    // Bump the pointer to the end of nested <ul> lists
    var pointer = opening.upperBound
    while let ulTag = firstULTag(from: text[pointer...], ignoreLevel: true),
          ulTag.range.lowerBound < closeLITag(from: text[pointer...]).lowerBound {
        pointer = ulTag.range.upperBound
    }
    // Search for the closing tag or newline
    let closing = closeLITag(from: text[pointer...])
    return (opening.lowerBound..<closing.upperBound, text[opening.upperBound..<closing.lowerBound])
}

func formatList(_ list: Substring, level: Int = 0) -> String {
    var list = list
    while let match = firstLITag(from: list) {
        var content = match.content
        while let match = firstULTag(from: content, consumeLeadingNewlines: true) {
            content.replaceSubrange(match.range, with: formatList(match.content, level: level + 1))
        }
        list.replaceSubrange(match.range, with: "\n\(String(repeating: " ", count: level * 2))- \(content.trimmingPrefix(while: \.isWhitespace))")
    }
    return String(list)
}
