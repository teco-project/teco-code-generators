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

    // Convert <br> to new paragraph
    do {
        let brTagsWithNewlinesAndWhitespacesRegex = Regex {
            ZeroOrMore {
                One(.newlineSequence)
                ZeroOrMore(.whitespace)
            }
            OneOrMore {
                "<br"
                ZeroOrMore(.whitespace)
                Optionally("/")
                ">"
                ZeroOrMore(.whitespace)
            }
            ZeroOrMore {
                ZeroOrMore(.whitespace)
                One(.newlineSequence)
            }
        }
        documentation.replace(brTagsWithNewlinesAndWhitespacesRegex) { _ in "\n\n" }
    }

    // Strip <div> tags
    do {
        let divTagRegex = Regex {
            "<div"
            ZeroOrMore(.any, .reluctant)
            ">"
            Capture {
                ZeroOrMore(.anyNonNewline, .reluctant)
            }
            Capture {
                ChoiceOf {
                    "</div>"
                    One(.newlineSequence)
                }
            }
        }
        documentation.replace(divTagRegex) { match in
            match.2 == "</div>" ? match.1 : "\(match.1)\n"
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
                let content = match.1
                return content.isEmpty ? "" : "**\(content)**"
            }
        }
    }

    // Merge three or more newlines to two
    do {
        let threeOrMoreNewlinesRegex = Regex {
            Repeat(.newlineSequence, count: 3)
            ZeroOrMore(.newlineSequence)
        }
        documentation.replace(threeOrMoreNewlinesRegex) { _ in "\n\n" }
    }
    return documentation.trimmingCharacters(in: .whitespacesAndNewlines)
}


