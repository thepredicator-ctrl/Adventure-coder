import UIKit
import Foundation
import SwiftUI

/// Lightweight syntax highlighter that operates on NSMutableAttributedString.
/// It applies monochrome-leaning colors (keyword, type, string, comment, number)
/// using regular expressions.
public enum SyntaxHighlighter {
    public static func highlight(_ attr: NSMutableAttributedString, language: Language, font: UIFont) {
        let text = attr.string as NSString
        let range = NSRange(location: 0, length: text.length)

        // Comments first (so other rules don't override them)
        let commentPattern: String
        switch language {
        case .swift, .c, .cpp, .csharp, .java, .kotlin, .rust, .go, .javascript, .typescript, .jsx, .tsx, .php:
            commentPattern = #"//.*$|/\*[\s\S]*?\*/"#
        case .python, .ruby, .shell:
            commentPattern = "#.*$"
        case .sql:
            commentPattern = #"--.*$|/\*[\s\S]*?\*/"#
        default:
            commentPattern = ""
        }
        if !commentPattern.isEmpty, let regex = try? NSRegularExpression(pattern: commentPattern, options: [.anchorsMatchLines]) {
            regex.enumerateMatches(in: attr.string, options: [], range: range) { match, _, _ in
                if let m = match {
                    attr.addAttribute(.foregroundColor, value: MonoColor.Code.comment.uiColor, range: m.range)
                    attr.addAttribute(.font, value: font.italic(), range: m.range)
                }
            }
        }

        // Strings
        if let regex = try? NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, options: []) {
            regex.enumerateMatches(in: attr.string, options: [], range: range) { match, _, _ in
                if let m = match {
                    attr.addAttribute(.foregroundColor, value: MonoColor.Code.string.uiColor, range: m.range)
                }
            }
        }

        // Keywords
        let keywords = keywordSet(for: language)
        if !keywords.isEmpty {
            let pattern = "\\b(?:" + keywords.joined(separator: "|") + ")\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                regex.enumerateMatches(in: attr.string, options: [], range: range) { match, _, _ in
                    if let m = match {
                        attr.addAttribute(.foregroundColor, value: MonoColor.Code.keyword.uiColor, range: m.range)
                        attr.addAttribute(.font, value: font.bold(), range: m.range)
                    }
                }
            }
        }

        // Types (PascalCase identifiers)
        if let regex = try? NSRegularExpression(pattern: "\\b[A-Z][A-Za-z0-9_]*\\b", options: []) {
            regex.enumerateMatches(in: attr.string, options: [], range: range) { match, _, _ in
                if let m = match {
                    attr.addAttribute(.foregroundColor, value: MonoColor.Code.type.uiColor, range: m.range)
                }
            }
        }

        // Numbers
        if let regex = try? NSRegularExpression(pattern: "\\b(?:0x[0-9A-Fa-f]+|\\d+\\.?\\d*[fL]?)\\b", options: []) {
            regex.enumerateMatches(in: attr.string, options: [], range: range) { match, _, _ in
                if let m = match {
                    attr.addAttribute(.foregroundColor, value: MonoColor.Code.number.uiColor, range: m.range)
                }
            }
        }

        // Attributes (@Something for Swift)
        if language == .swift {
            if let regex = try? NSRegularExpression(pattern: "@[A-Za-z0-9_]+", options: []) {
                regex.enumerateMatches(in: attr.string, options: [], range: range) { match, _, _ in
                    if let m = match {
                        attr.addAttribute(.foregroundColor, value: MonoColor.Code.attribute.uiColor, range: m.range)
                    }
                }
            }
        }
    }

    private static func keywordSet(for language: Language) -> [String] {
        switch language {
        case .swift:
            return ["import", "struct", "class", "enum", "protocol", "extension", "func", "let", "var", "if", "else", "guard", "for", "while", "switch", "case", "default", "return", "throw", "throws", "try", "catch", "do", "defer", "in", "where", "as", "is", "self", "Self", "init", "deinit", "private", "fileprivate", "internal", "public", "open", "static", "final", "lazy", "weak", "unowned", "inout", "mutating", "nonmutating", "override", "convenience", "required", "optional", "indirect", "associatedtype", "typealias", "subscript", "operator", "precedencegroup", "async", "await", "actor", "distributed", "some", "any", "each"]
        case .javascript, .jsx, .tsx, .typescript:
            return ["import", "export", "from", "default", "const", "let", "var", "function", "return", "if", "else", "for", "while", "do", "switch", "case", "break", "continue", "new", "delete", "typeof", "instanceof", "in", "of", "this", "super", "class", "extends", "implements", "interface", "type", "enum", "namespace", "async", "await", "yield", "try", "catch", "finally", "throw", "void", "as", "is", "satisfies", "abstract", "private", "public", "protected", "readonly", "static", "get", "set"]
        case .python:
            return ["def", "class", "import", "from", "as", "return", "if", "elif", "else", "for", "while", "in", "is", "not", "and", "or", "with", "try", "except", "finally", "raise", "yield", "lambda", "pass", "break", "continue", "global", "nonlocal", "assert", "del", "async", "await"]
        case .rust:
            return ["fn", "let", "mut", "const", "static", "if", "else", "match", "for", "while", "loop", "return", "break", "continue", "struct", "enum", "trait", "impl", "pub", "use", "mod", "self", "Self", "super", "crate", "as", "in", "where", "async", "await", "move", "ref", "dyn", "unsafe", "extern"]
        case .go:
            return ["package", "import", "func", "var", "const", "type", "struct", "interface", "if", "else", "for", "range", "switch", "case", "default", "return", "go", "defer", "select", "chan", "map", "make", "new", "nil", "true", "false"]
        case .java, .kotlin:
            return ["public", "private", "protected", "class", "interface", "enum", "extends", "implements", "package", "import", "static", "final", "void", "int", "long", "short", "byte", "float", "double", "boolean", "char", "if", "else", "for", "while", "switch", "case", "break", "continue", "return", "new", "try", "catch", "finally", "throw", "throws", "this", "super", "fun", "val", "var", "when", "object", "companion", "data", "sealed", "suspend", "override"]
        case .c, .cpp, .csharp:
            return ["#include", "#define", "#ifndef", "#ifdef", "#endif", "int", "long", "short", "float", "double", "char", "void", "if", "else", "for", "while", "switch", "case", "break", "continue", "return", "struct", "class", "public", "private", "protected", "static", "const", "void", "new", "delete", "this", "namespace", "using", "template", "typename", "auto", "constexpr", "nullptr"]
        case .sql:
            return ["SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "ADD", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "NOT", "NULL", "DEFAULT", "UNIQUE", "INDEX", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "GROUP", "BY", "ORDER", "HAVING", "LIMIT", "OFFSET", "AS", "AND", "OR", "IN", "LIKE", "BETWEEN"]
        case .shell:
            return ["if", "then", "fi", "for", "in", "do", "done", "while", "case", "esac", "function", "return", "exit", "echo", "export", "local", "readonly", "set", "unset", "source", "alias"]
        case .ruby, .php:
            return ["def", "end", "if", "elsif", "else", "unless", "while", "until", "for", "do", "break", "next", "redo", "retry", "return", "yield", "class", "module", "require", "require_relative", "include", "extend", "attr_accessor", "attr_reader", "attr_writer", "public", "private", "protected"]
        default:
            return []
        }
    }
}

extension UIColor {
    var mono: Color { Color(self) }
}

extension UIFont {
    func italic() -> UIFont { UIFont(descriptor: fontDescriptor.withSymbolicTraits([.traitItalic]) ?? fontDescriptor, size: pointSize) }
    func bold() -> UIFont { UIFont(descriptor: fontDescriptor.withSymbolicTraits([.traitBold]) ?? fontDescriptor, size: pointSize) }
}

extension Color {
    var uiColor: UIColor {
        UIColor(self)
    }
}
