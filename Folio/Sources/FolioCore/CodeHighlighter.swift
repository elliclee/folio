import Foundation
import SwiftUI

/// Native single-pass syntax highlighter for fenced code blocks — the
/// counterpart of highlight.js in the Tauri version. Token colors follow
/// the github-dark scheme the Tauri app imports, which works on the dark
/// code-block backgrounds every theme uses.
public enum CodeTokenKind {
    case keyword
    case string
    case comment
    case number
    case literal   // true / false / nil / null / None …
    case type      // capitalized identifiers
}

public struct CodeToken: Equatable {
    public let range: Range<Int>  // character offsets
    public let kind: CodeTokenKind
}

public struct CodeLanguage {
    public let keywords: Set<String>
    public let literals: Set<String>
    public let lineComments: [String]
    public let blockComment: (start: String, end: String)?
    public let stringDelimiters: Set<Character>
    public let highlightsCapitalizedTypes: Bool

    public init(
        keywords: Set<String>,
        literals: Set<String> = ["true", "false", "null"],
        lineComments: [String] = ["//"],
        blockComment: (start: String, end: String)? = ("/*", "*/"),
        stringDelimiters: Set<Character> = ["\"", "'"],
        highlightsCapitalizedTypes: Bool = true
    ) {
        self.keywords = keywords
        self.literals = literals
        self.lineComments = lineComments
        self.blockComment = blockComment
        self.stringDelimiters = stringDelimiters
        self.highlightsCapitalizedTypes = highlightsCapitalizedTypes
    }
}

public enum CodeHighlighter {
    public static func language(named name: String?) -> CodeLanguage? {
        guard let name = name?.lowercased(), !name.isEmpty else {
            return nil
        }
        return languages[name]
    }

    /// Code blocks beyond this size render unhighlighted (matches the
    /// spirit of editors capping highlight work on giant files).
    public static let maxTokenizedCharacters = 200_000

    /// Tokenizes `code`; ranges are non-overlapping and in order.
    public static func tokenize(_ code: String, language: CodeLanguage) -> [CodeToken] {
        let chars = Array(code)
        guard chars.count <= maxTokenizedCharacters else {
            return []
        }

        // Precompute needles once — allocating them per character made
        // tokenizing large blocks pathologically slow.
        let lineCommentNeedles = language.lineComments.map(Array.init)
        let blockCommentNeedles = language.blockComment.map {
            (start: Array($0.start), end: Array($0.end))
        }

        var tokens: [CodeToken] = []
        var i = 0

        func matches(_ needle: [Character], at index: Int) -> Bool {
            guard !needle.isEmpty, index + needle.count <= chars.count else { return false }
            var offset = 0
            while offset < needle.count {
                if chars[index + offset] != needle[offset] {
                    return false
                }
                offset += 1
            }
            return true
        }

        while i < chars.count {
            let char = chars[i]

            // Line comments.
            if let comment = lineCommentNeedles.first(where: { matches($0, at: i) }) {
                let start = i
                i += comment.count
                while i < chars.count, chars[i] != "\n" {
                    i += 1
                }
                tokens.append(CodeToken(range: start..<i, kind: .comment))
                continue
            }

            // Block comments.
            if let block = blockCommentNeedles, matches(block.start, at: i) {
                let start = i
                i += block.start.count
                while i < chars.count, !matches(block.end, at: i) {
                    i += 1
                }
                i = min(i + block.end.count, chars.count)
                tokens.append(CodeToken(range: start..<i, kind: .comment))
                continue
            }

            // Strings (single line for quotes, multi-line for backticks).
            if language.stringDelimiters.contains(char) {
                let delimiter = char
                let start = i
                i += 1
                while i < chars.count {
                    if chars[i] == "\\" {
                        i += 2
                        continue
                    }
                    if chars[i] == delimiter {
                        i += 1
                        break
                    }
                    if chars[i] == "\n", delimiter != "`" {
                        break
                    }
                    i += 1
                }
                tokens.append(CodeToken(range: start..<min(i, chars.count), kind: .string))
                continue
            }

            // Numbers. ASCII digits only: Unicode "numbers" like ①, ², ３
            // satisfy isNumber but not isHexDigit, and consuming zero
            // characters here used to spin the tokenizer forever.
            if char.isASCII, char.isNumber {
                let start = i
                i += 1  // always make progress
                while i < chars.count, chars[i].isHexDigit || "xXoObB_.".contains(chars[i]) {
                    i += 1
                }
                tokens.append(CodeToken(range: start..<i, kind: .number))
                continue
            }

            // Identifiers / keywords.
            if char.isLetter || char == "_" {
                let start = i
                while i < chars.count, chars[i].isLetter || chars[i].isNumber || chars[i] == "_" {
                    i += 1
                }
                let word = String(chars[start..<i])

                if language.keywords.contains(word) {
                    tokens.append(CodeToken(range: start..<i, kind: .keyword))
                } else if language.literals.contains(word) {
                    tokens.append(CodeToken(range: start..<i, kind: .literal))
                } else if language.highlightsCapitalizedTypes, word.first?.isUppercase == true {
                    tokens.append(CodeToken(range: start..<i, kind: .type))
                }
                continue
            }

            i += 1
        }

        return tokens
    }

    // MARK: - Token colors (github-dark, as used by the Tauri version)

    public static func color(for kind: CodeTokenKind) -> Color {
        switch kind {
        case .keyword: Color(hex: 0xFF7B72)
        case .string: Color(hex: 0xA5D6FF)
        case .comment: Color(hex: 0x8B949E)
        case .number, .literal: Color(hex: 0x79C0FF)
        case .type: Color(hex: 0xFFA657)
        }
    }

    // MARK: - Language registry

    private static let cFamilyKeywords: Set<String> = [
        "auto", "break", "case", "char", "const", "continue", "default", "do",
        "double", "else", "enum", "extern", "float", "for", "goto", "if",
        "inline", "int", "long", "register", "return", "short", "signed",
        "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned",
        "void", "volatile", "while", "class", "namespace", "template",
        "public", "private", "protected", "virtual", "override", "new",
        "delete", "this", "using", "try", "catch", "throw",
    ]

    private static let jsKeywords: Set<String> = [
        "async", "await", "break", "case", "catch", "class", "const",
        "continue", "debugger", "default", "delete", "do", "else", "export",
        "extends", "finally", "for", "from", "function", "if", "import",
        "in", "instanceof", "let", "new", "of", "return", "static", "super",
        "switch", "this", "throw", "try", "typeof", "var", "void", "while",
        "with", "yield", "get", "set",
        // TypeScript extras (harmless for plain JS).
        "abstract", "any", "as", "declare", "enum", "implements", "interface",
        "is", "keyof", "module", "namespace", "never", "readonly", "type",
        "satisfies", "string", "number", "boolean", "unknown", "object",
    ]

    private static let languages: [String: CodeLanguage] = {
        let swift = CodeLanguage(
            keywords: [
                "actor", "as", "associatedtype", "async", "await", "break",
                "case", "catch", "class", "continue", "convenience", "default",
                "defer", "deinit", "didSet", "do", "dynamic", "else", "enum",
                "extension", "fallthrough", "fileprivate", "final", "for",
                "func", "get", "guard", "if", "import", "in", "indirect",
                "infix", "init", "inout", "internal", "is", "lazy", "let",
                "mutating", "nonisolated", "nonmutating", "open", "operator",
                "optional", "override", "postfix", "precedencegroup", "prefix",
                "private", "protocol", "public", "repeat", "required",
                "rethrows", "return", "self", "set", "some", "static",
                "struct", "subscript", "super", "switch", "throw", "throws",
                "try", "typealias", "unowned", "var", "weak", "where",
                "while", "willSet",
            ],
            literals: ["true", "false", "nil"]
        )

        let python = CodeLanguage(
            keywords: [
                "and", "as", "assert", "async", "await", "break", "class",
                "continue", "def", "del", "elif", "else", "except", "finally",
                "for", "from", "global", "if", "import", "in", "is", "lambda",
                "nonlocal", "not", "or", "pass", "raise", "return", "try",
                "while", "with", "yield", "match", "case", "self",
            ],
            literals: ["True", "False", "None"],
            lineComments: ["#"],
            blockComment: nil
        )

        let rust = CodeLanguage(
            keywords: [
                "as", "async", "await", "break", "const", "continue", "crate",
                "dyn", "else", "enum", "extern", "fn", "for", "if", "impl",
                "in", "let", "loop", "match", "mod", "move", "mut", "pub",
                "ref", "return", "self", "static", "struct", "super", "trait",
                "type", "unsafe", "use", "where", "while",
            ],
            literals: ["true", "false", "None", "Some", "Ok", "Err"]
        )

        let go = CodeLanguage(
            keywords: [
                "break", "case", "chan", "const", "continue", "default",
                "defer", "else", "fallthrough", "for", "func", "go", "goto",
                "if", "import", "interface", "map", "package", "range",
                "return", "select", "struct", "switch", "type", "var",
            ],
            literals: ["true", "false", "nil", "iota"],
            stringDelimiters: ["\"", "'", "`"]
        )

        let bash = CodeLanguage(
            keywords: [
                "case", "do", "done", "elif", "else", "esac", "exit",
                "export", "fi", "for", "function", "if", "in", "local",
                "read", "return", "select", "set", "shift", "source", "then",
                "trap", "until", "while", "echo", "cd",
            ],
            literals: [],
            lineComments: ["#"],
            blockComment: nil,
            highlightsCapitalizedTypes: false
        )

        let json = CodeLanguage(
            keywords: [],
            literals: ["true", "false", "null"],
            lineComments: [],
            blockComment: nil,
            highlightsCapitalizedTypes: false
        )

        let yaml = CodeLanguage(
            keywords: [],
            literals: ["true", "false", "null", "yes", "no", "on", "off"],
            lineComments: ["#"],
            blockComment: nil,
            highlightsCapitalizedTypes: false
        )

        let ruby = CodeLanguage(
            keywords: [
                "alias", "and", "begin", "break", "case", "class", "def",
                "defined", "do", "else", "elsif", "end", "ensure", "for",
                "if", "in", "module", "next", "not", "or", "raise", "redo",
                "require", "rescue", "retry", "return", "self", "super",
                "then", "undef", "unless", "until", "when", "while", "yield",
                "attr_accessor", "attr_reader", "attr_writer", "puts",
            ],
            literals: ["true", "false", "nil"],
            lineComments: ["#"],
            blockComment: ("=begin", "=end")
        )

        let java = CodeLanguage(
            keywords: cFamilyKeywords.union([
                "abstract", "boolean", "byte", "extends", "final", "finally",
                "implements", "import", "instanceof", "interface", "native",
                "package", "strictfp", "super", "synchronized", "throws",
                "transient", "fun", "val", "when", "object", "companion",
                "data", "sealed", "suspend",
            ]),
            literals: ["true", "false", "null", "this"]
        )

        let css = CodeLanguage(
            keywords: ["important", "media", "keyframes", "import", "supports"],
            literals: [],
            lineComments: [],
            highlightsCapitalizedTypes: false
        )

        let sql = CodeLanguage(
            keywords: [
                "select", "from", "where", "insert", "into", "values",
                "update", "set", "delete", "create", "table", "drop", "alter",
                "index", "join", "inner", "left", "right", "outer", "on",
                "group", "by", "order", "having", "limit", "offset", "as",
                "and", "or", "not", "in", "like", "between", "distinct",
                "union", "all", "exists", "primary", "key", "foreign",
                "references", "default", "unique", "constraint",
                "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES",
                "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "DROP", "ALTER",
                "INDEX", "JOIN", "INNER", "LEFT", "RIGHT", "OUTER", "ON",
                "GROUP", "BY", "ORDER", "HAVING", "LIMIT", "OFFSET", "AS",
                "AND", "OR", "NOT", "IN", "LIKE", "BETWEEN", "DISTINCT",
                "UNION", "ALL", "EXISTS", "PRIMARY", "KEY", "FOREIGN",
                "REFERENCES", "DEFAULT", "UNIQUE", "CONSTRAINT",
            ],
            literals: ["NULL", "TRUE", "FALSE"],
            lineComments: ["--"],
            highlightsCapitalizedTypes: false
        )

        let html = CodeLanguage(
            keywords: [],
            literals: [],
            lineComments: [],
            blockComment: ("<!--", "-->"),
            highlightsCapitalizedTypes: false
        )

        var registry: [String: CodeLanguage] = [:]
        let entries: [(CodeLanguage, [String])] = [
            (swift, ["swift"]),
            (CodeLanguage(keywords: jsKeywords, literals: ["true", "false", "null", "undefined", "NaN", "Infinity"], stringDelimiters: ["\"", "'", "`"]),
             ["javascript", "js", "jsx", "typescript", "ts", "tsx"]),
            (python, ["python", "py", "python3"]),
            (rust, ["rust", "rs"]),
            (go, ["go", "golang"]),
            (bash, ["bash", "sh", "shell", "zsh", "console"]),
            (json, ["json", "jsonc"]),
            (yaml, ["yaml", "yml"]),
            (ruby, ["ruby", "rb"]),
            (java, ["java", "kotlin", "kt", "scala"]),
            (CodeLanguage(keywords: cFamilyKeywords, literals: ["true", "false", "NULL", "nullptr"]),
             ["c", "cpp", "c++", "objc", "objective-c", "h", "hpp", "cs", "csharp"]),
            (css, ["css", "scss", "less"]),
            (sql, ["sql"]),
            (html, ["html", "xml", "svg"]),
            (CodeLanguage(keywords: [], literals: ["true", "false"], lineComments: ["#"], blockComment: nil, highlightsCapitalizedTypes: false),
             ["toml", "ini", "conf", "properties", "dockerfile", "makefile"]),
        ]
        for (config, names) in entries {
            for name in names {
                registry[name] = config
            }
        }
        return registry
    }()
}
