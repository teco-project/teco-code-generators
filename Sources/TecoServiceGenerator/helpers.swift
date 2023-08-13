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

func formatDocumentation(_ documentation: String?) -> String? {
    guard var documentation, !documentation.isEmpty, documentation != "无" else {
        return nil
    }

    let newlineAndWhitespaceRegex = ChoiceOf {
        One(.newlineSequence)
        One(.whitespace)
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
        documentation.replace(brTagsWithTrailingWhitespacesRegex) { _ in "\n\n" }
    }

    // Strip <div> tags
    do {
        let divTagRegex = Regex {
            "<div"
            ZeroOrMore(.any, .reluctant)
            ">"
            ZeroOrMore(newlineAndWhitespaceRegex)
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            ZeroOrMore(newlineAndWhitespaceRegex)
            "</div>"
        }
        let unclosedDivTagRegex = Regex {
            "<div"
            ZeroOrMore(.any, .reluctant)
            ">"
            Capture {
                ZeroOrMore(.anyNonNewline)
                One(.newlineSequence)
            }
        }
        // Do this one by one to handle nested <div>
        while let match = documentation.firstMatch(of: divTagRegex) {
            documentation.replaceSubrange(match.range, with: match.1)
        }
        documentation.replace(unclosedDivTagRegex, with: \.1)
    }

    // Strip <pre> tags
    do {
        let preTagRegex = Regex {
            "<pre>"
            Capture {
                ZeroOrMore(.any, .reluctant)
            }
            "</pre>"
        }
        documentation.replace(preTagRegex, with: \.1)
    }

    // Convert <a> to [text](link)
    do {
        let aTagRegex = Regex {
            "<a "
            ZeroOrMore(.any, .reluctant)
            "href=\""
            Capture {
                OneOrMore(.any, .reluctant)
            }
            "\""
            ZeroOrMore(.any, .reluctant)
            ">"
            Optionally("[")
            Capture {
                OneOrMore(.any, .reluctant)
            }
            Optionally("]")
            "</a>"
        }
        documentation.replace(aTagRegex) { match in
            if match.2.isEmpty {
                return ""
            }
            if match.1.isEmpty || match.1.hasPrefix("#") {
                return String(match.2)
            }
            return "[\(match.2)](\(match.1))"
        }
    }

    // Convert <code> to code block
    do {
        let codeTagRegex = Regex {
            Capture {
                ZeroOrMore(newlineAndWhitespaceRegex)
            }
            "<code>"
            Capture {
                ZeroOrMore(.any)
            }
            "</code>"
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

    // Convert <del> to ~~deleted~~
    do {
        let delTagRegex = Regex {
            "<del>"
            Capture {
                ZeroOrMore(.anyNonNewline, .reluctant)
            }
            "</del>"
        }
        documentation.replace(delTagRegex) { match in
            match.1.isEmpty ? "" : "~~\(match.1)~~"
        }
    }

    // Convert <font> to _italic_
    do {
        let fontTagRegex = Regex {
            "<font"
            Capture {
                ZeroOrMore(.anyNonNewline, .reluctant)
            }
            ">"
            Capture {
                ZeroOrMore(.anyNonNewline, .reluctant)
            }
            "</font>"
        }
        documentation.replace(fontTagRegex) { match in
            // Only apply style if there's attribute on <font>
            guard !match.1.allSatisfy(\.isWhitespace), !match.2.isEmpty else {
                return match.2
            }
            return "_\(match.2)_"
        }
    }

    // Convert <b> and <strong> to **bold**
    do {
        let bTagRegex = Regex {
            "<b>"
            Capture {
                ZeroOrMore(.anyNonNewline, .reluctant)
            }
            "</b>"
        }
        let strongTagRegex = Regex {
            "<strong>"
            Capture {
                ZeroOrMore(.anyNonNewline, .reluctant)
            }
            "</strong>"
        }
        for tagRegex in [bTagRegex, strongTagRegex] {
            documentation.replace(tagRegex) { match in
                match.1.isEmpty ? "" : "**\(match.1)**"
            }
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

    // Merge three or more newlines to two
    do {
        let threeOrMoreNewlinesRegex = Regex {
            One(.newlineSequence)
            Repeat(2...) {
                ZeroOrMore(.whitespace)
                One(.newlineSequence)
            }
        }
        documentation.replace(threeOrMoreNewlinesRegex) { _ in "\n\n" }
    }
    return documentation.trimmingCharacters(in: .whitespacesAndNewlines)
}

func firstULTag(from text: Substring, ignoreLevel: Bool = false, consumeLeadingNewlines: Bool = false) -> (range: Range<String.Index>, content: Substring)? {
    let ulTagRegex = Regex {
        "<ul"
        ZeroOrMore(.any, .reluctant)
        ">"
    }
    // Fold leading newlines on demand
    let ulTagWithLeadingNewlinesRegex = Regex {
        ZeroOrMore {
            ChoiceOf {
                One(.newlineSequence)
                One(.whitespace)
            }
        }
        ulTagRegex
    }
    guard let opening = text.firstRange(of: consumeLeadingNewlines ? ulTagWithLeadingNewlinesRegex : ulTagRegex) else {
        return nil
    }
    // This indicates a nested context which is closed before new <ul> tags
    if let closing = text.firstRange(of: "</ul>"), closing.lowerBound < opening.lowerBound {
        return nil
    }
    // This indicates the <ul> is nested in deeper context inside a <li> tag
    if !ignoreLevel, let liTag = text.firstRange(of: "<li>"), liTag.lowerBound < opening.lowerBound {
        return nil
    }
    // Bump the pointer to the end of nested <ul> lists
    var pointer = opening.upperBound
    while let ulTag = firstULTag(from: text[pointer...], ignoreLevel: true) {
        pointer = ulTag.range.upperBound
    }
    // Search for the real closing tag
    let closingTagRegex = ChoiceOf {
        "</ul>"
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
    // Fold all leading newlines
    let liTagWithLeadingNewlineRegex = Regex {
        ZeroOrMore {
            ChoiceOf {
                One(.newlineSequence)
                One(.whitespace)
            }
        }
        "<li>"
    }
    guard let opening = text.firstRange(of: liTagWithLeadingNewlineRegex) else {
        return nil
    }
    // Bump the pointer to the end of nested <ul> lists
    var pointer = opening.upperBound
    while let ulTag = firstULTag(from: text[pointer...], ignoreLevel: true) {
        pointer = ulTag.range.upperBound
    }
    // Search for the closing tag or newline
    let closingTagRegex = ChoiceOf {
        "</li>"
        // Special handling for typo...
        "<l/i>"
    }
    guard let closing = text[pointer...].firstRange(of: closingTagRegex) else {
        let bound = text[pointer...].firstIndex(where: \.isNewline) ?? text.endIndex
        return (opening.lowerBound..<bound, text[opening.upperBound..<bound])
    }
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
