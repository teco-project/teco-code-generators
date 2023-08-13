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
            "<br"
            ZeroOrMore(.whitespace)
            Optionally("/")
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
                let content = match.1
                return content.isEmpty ? "" : "**\(content)**"
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
