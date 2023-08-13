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
