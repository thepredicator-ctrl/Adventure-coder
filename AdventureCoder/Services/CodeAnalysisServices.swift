import Foundation

/// Calculates code complexity metrics: cyclomatic complexity, cognitive complexity,
/// nesting depth, and maintainability index.
public final class CodeComplexityAnalyzer {
    public static let shared = CodeComplexityAnalyzer()
    private init() {}

    public struct FunctionMetrics {
        public var name: String
        public var file: String
        public var line: Int
        public var cyclomaticComplexity: Int
        public var cognitiveComplexity: Int
        public var nestingDepth: Int
        public var parameterCount: Int
        public var linesOfCode: Int
        public var isHotspot: Bool { cyclomaticComplexity > 10 }
    }

    public struct FileMetrics {
        public var file: String
        public var functions: [FunctionMetrics]
        public var totalLines: Int
        public var codeLines: Int
        public var commentLines: Int
        public var blankLines: Int
        public var maintainabilityIndex: Double
        public var grade: Grade
    }

    public enum Grade: String {
        case a, b, c, d, f
        public var color: String {
            switch self {
            case .a: return "green"
            case .b: return "blue"
            case .c: return "yellow"
            case .d: return "orange"
            case .f: return "red"
            }
        }
    }

    /// Analyze a Swift file and return its metrics.
    public func analyzeSwift(content: String, fileName: String) -> FileMetrics {
        let lines = content.components(separatedBy: .newlines)
        var functions: [FunctionMetrics] = []
        var codeLines = 0
        var commentLines = 0
        var blankLines = 0

        var currentFunction: String?
        var functionStartLine = 0
        var functionBraceDepth = 0
        var functionCyclomatic = 1
        var functionCognitive = 0
        var functionNesting = 0
        var functionMaxNesting = 0
        var functionParamCount = 0
        var functionLines: [String] = []

        var globalBraceDepth = 0

        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { blankLines += 1; continue }
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                commentLines += 1
                continue
            }
            codeLines += 1

            // Detect function start
            if let funcRange = trimmed.range(of: #"func\s+(\w+)"#, options: .regularExpression) {
                let name = String(trimmed[funcRange]).replacingOccurrences(of: "func ", with: "").split(separator: "(").first.map { String($0) } ?? "unknown"
                // Count parameters
                if let parenStart = trimmed.firstIndex(of: "("), let parenEnd = trimmed.firstIndex(of: ")") {
                    let params = String(trimmed[trimmed.index(after: parenStart)..<parenEnd])
                    functionParamCount = params.split(separator: ",").count
                }
                currentFunction = name
                functionStartLine = idx + 1
                functionBraceDepth = 0
                functionCyclomatic = 1
                functionCognitive = 0
                functionNesting = 0
                functionMaxNesting = 0
                functionLines = [line]
            } else if currentFunction != nil {
                functionLines.append(line)
            }

            // Count complexity tokens
            let complexityTokens = ["if ", "else if", "for ", "while ", "case ", "catch", "&&", "||", "?"]
            for token in complexityTokens {
                let count = trimmed.components(separatedBy: token).count - 1
                functionCyclomatic += count
                functionCognitive += count * (functionNesting + 1)
            }

            // Track nesting
            let openBraces = line.filter { $0 == "{" }.count
            let closeBraces = line.filter { $0 == "}" }.count
            if currentFunction != nil {
                functionBraceDepth += openBraces
                functionBraceDepth -= closeBraces
                functionNesting = max(0, functionBraceDepth)
                functionMaxNesting = max(functionMaxNesting, functionNesting)

                // Function ends when braces balance
                if functionBraceDepth <= 0 && (openBraces > 0 || closeBraces > 0) {
                    let metrics = FunctionMetrics(
                        name: currentFunction!,
                        file: fileName,
                        line: functionStartLine,
                        cyclomaticComplexity: max(1, functionCyclomatic),
                        cognitiveComplexity: max(0, functionCognitive),
                        nestingDepth: functionMaxNesting,
                        parameterCount: functionParamCount,
                        linesOfCode: functionLines.count
                    )
                    functions.append(metrics)
                    currentFunction = nil
                }
            }
            globalBraceDepth += openBraces - closeBraces
        }

        let totalLines = lines.count
        let avgComplexity = functions.isEmpty ? 1.0 : Double(functions.reduce(0) { $0 + $1.cyclomaticComplexity }) / Double(functions.count)
        let mi = calculateMaintainabilityIndex(totalLines: totalLines, codeLines: codeLines, avgComplexity: avgComplexity)
        let grade = gradeForMI(mi)

        return FileMetrics(
            file: fileName,
            functions: functions,
            totalLines: totalLines,
            codeLines: codeLines,
            commentLines: commentLines,
            blankLines: blankLines,
            maintainabilityIndex: mi,
            grade: grade
        )
    }

    /// Calculate the Maintainability Index using the classic formula.
    public func calculateMaintainabilityIndex(totalLines: Int, codeLines: Int, avgComplexity: Double) -> Double {
        let loc = max(1, Double(codeLines))
        let cc = max(1, avgComplexity)
        let hv = loc * log2(max(2, loc))  // simplified Halstead volume
        var mi = (171 - 5.2 * log(hv) - 0.23 * cc - 16.2 * log(loc)) * 100 / 171
        mi = max(0, mi)
        return min(100, mi)
    }

    public func gradeForMI(_ mi: Double) -> Grade {
        switch mi {
        case 65...: return .a
        case 50..<65: return .b
        case 35..<50: return .c
        case 20..<35: return .d
        default: return .f
        }
    }

    /// Analyze all Swift files in a directory.
    public func analyzeProject(at path: String) -> [FileMetrics] {
        var results: [FileMetrics] = []
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        for entry in entries {
            if entry.hasPrefix(".") { continue }
            let full = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            if isDir.boolValue {
                results.append(contentsOf: analyzeProject(at: full))
            } else if entry.hasSuffix(".swift") {
                if let content = try? String(contentsOfFile: full, encoding: .utf8) {
                    results.append(analyzeSwift(content: content, fileName: entry))
                }
            }
        }
        return results
    }

    /// Find all hotspot functions (complexity > 10).
    public func findHotspots(in metrics: [FileMetrics]) -> [FunctionMetrics] {
        metrics.flatMap { $0.functions }.filter { $0.isHotspot }
    }
}

// MARK: - Duplicate Code Detector

/// Detects duplicate code blocks using token-based similarity.
public final class DuplicateDetector {
    public static let shared = DuplicateDetector()
    private init() {}

    public struct Duplicate {
        public let originalFile: String
        public let originalLine: Int
        public let duplicateFile: String
        public let duplicateLine: Int
        public let tokenCount: Int
        public let similarity: Double
    }

    public struct TokenBlock {
        public let file: String
        public let startLine: Int
        public let tokens: [String]
    }

    /// Tokenize source code into normalized tokens.
    public func tokenize(_ content: String, file: String) -> [TokenBlock] {
        let lines = content.components(separatedBy: .newlines)
        let blockSize = 6  // 6-line blocks
        var blocks: [TokenBlock] = []

        for i in stride(from: 0, to: lines.count - blockSize, by: blockSize / 2) {
            let blockLines = Array(lines[i..<min(i + blockSize, lines.count)])
            let tokens = blockLines.flatMap { line -> [String] in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("//") { return [] }
                // Split on word boundaries and operators
                return trimmed.split { $0.isWhitespace || $0 == "{" || $0 == "}" || $0 == "(" || $0 == ")" || $0 == ";" }
                    .map { String($0) }
                    .filter { !$0.isEmpty }
            }
            if tokens.count >= 10 {
                blocks.append(TokenBlock(file: file, startLine: i + 1, tokens: tokens))
            }
        }
        return blocks
    }

    /// Find duplicates across files.
    public func findDuplicates(in files: [(name: String, content: String)]) -> [Duplicate] {
        var allBlocks: [TokenBlock] = []
        for file in files {
            allBlocks.append(contentsOf: tokenize(file.content, file: file.name))
        }

        var duplicates: [Duplicate] = []
        for i in 0..<allBlocks.count {
            for j in (i+1)..<allBlocks.count {
                let block1 = allBlocks[i]
                let block2 = allBlocks[j]
                if block1.file == block2.file && abs(block1.startLine - block2.startLine) < 6 { continue }

                let sim = similarity(block1.tokens, block2.tokens)
                if sim > 0.8 {
                    duplicates.append(Duplicate(
                        originalFile: block1.file,
                        originalLine: block1.startLine,
                        duplicateFile: block2.file,
                        duplicateLine: block2.startLine,
                        tokenCount: block1.tokens.count,
                        similarity: sim
                    ))
                }
            }
        }
        return duplicates
    }

    /// Calculate Jaccard similarity between two token sets.
    public func similarity(_ tokens1: [String], _ tokens2: [String]) -> Double {
        let set1 = Set(tokens1)
        let set2 = Set(tokens2)
        let intersection = set1.intersection(set2).count
        let union = set1.union(set2).count
        return union == 0 ? 0 : Double(intersection) / Double(union)
    }
}

// MARK: - Dead Code Detector

/// Detects dead code: unused functions, variables, imports.
public final class DeadCodeDetector {
    public static let shared = DeadCodeDetector()
    private init() {}

    public struct DeadCodeItem {
        public let file: String
        public let line: Int
        public let type: DeadCodeType
        public let name: String
        public let suggestion: String
    }

    public enum DeadCodeType: String {
        case unusedFunction = "Unused Function"
        case unusedVariable = "Unused Variable"
        case unusedImport = "Unused Import"
        case unreachableCode = "Unreachable Code"
        case commentedOut = "Commented Out Code"
    }

    /// Detect dead code in a Swift file.
    public func detect(in content: String, fileName: String, allFiles: [(name: String, content: String)]) -> [DeadCodeItem] {
        var items: [DeadCodeItem] = []
        let lines = content.components(separatedBy: .newlines)

        // Detect unused functions
        let functionPattern = #"func\s+(\w+)"#
        if let regex = try? NSRegularExpression(pattern: functionPattern) {
            let ns = content as NSString
            regex.enumerateMatches(in: content, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                guard let match = match, match.numberOfRanges >= 2 else { return }
                let funcName = ns.substring(with: match.range(at: 1))
                let line = ns.substring(with: NSRange(location: 0, length: match.range.location)).components(separatedBy: "\n").count

                // Check if this function name appears in any other file
                var usedElsewhere = false
                for (otherName, otherContent) in allFiles {
                    if otherName == fileName { continue }
                    if otherContent.contains(funcName) {
                        usedElsewhere = true
                        break
                    }
                }
                // Also check if it's called within the same file (not just defined)
                let ownUsageCount = content.components(separatedBy: funcName).count - 1
                if !usedElsewhere && ownUsageCount <= 1 {
                    // Check if it's a protocol requirement or override
                    let lineContent = lines.indices.contains(line - 1) ? lines[line - 1] : ""
                    if !lineContent.contains("override") && !lineContent.contains("protocol") {
                        items.append(DeadCodeItem(
                            file: fileName, line: line, type: .unusedFunction,
                            name: funcName,
                            suggestion: "Function '\(funcName)' is not called anywhere. Consider removing it."
                        ))
                    }
                }
            }
        }

        // Detect unused imports
        let importPattern = #"^\s*import\s+(\w+)"#
        if let regex = try? NSRegularExpression(pattern: importPattern) {
            let ns = content as NSString
            regex.enumerateMatches(in: content, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                guard let match = match, match.numberOfRanges >= 2 else { return }
                let moduleName = ns.substring(with: match.range(at: 1))
                let line = ns.substring(with: NSRange(location: 0, length: match.range.location)).components(separatedBy: "\n").count
                // Check if any symbol from that module is used (simplified: check if module name appears elsewhere)
                let withoutImport = content.replacingOccurrences(of: "import \(moduleName)", with: "")
                if !withoutImport.contains(moduleName) {
                    items.append(DeadCodeItem(
                        file: fileName, line: line, type: .unusedImport,
                        name: moduleName,
                        suggestion: "Module '\(moduleName)' is imported but not used."
                    ))
                }
            }
        }

        // Detect unreachable code (after return/throw)
        var afterReturn = false
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("return ") || trimmed == "return" || trimmed.hasPrefix("throw ") || trimmed == "throw" {
                afterReturn = true
                continue
            }
            if afterReturn && !trimmed.isEmpty && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("}") && !trimmed.hasPrefix("case") {
                items.append(DeadCodeItem(
                    file: fileName, line: idx + 1, type: .unreachableCode,
                    name: trimmed,
                    suggestion: "Code after return/throw is unreachable."
                ))
            }
            if trimmed.hasPrefix("}") || trimmed.hasPrefix("case") {
                afterReturn = false
            }
        }

        // Detect commented-out code
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") && !trimmed.hasPrefix("// MARK:") && !trimmed.hasPrefix("// TODO:") {
                // Check if it looks like code
                let uncommented = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if uncommented.contains("=") || uncommented.contains("(") || uncommented.contains("{") {
                    if !uncommented.contains("://") {  // Not a URL
                        items.append(DeadCodeItem(
                            file: fileName, line: idx + 1, type: .commentedOut,
                            name: uncommented,
                            suggestion: "Commented-out code should be removed (use version control)."
                        ))
                    }
                }
            }
        }

        return items
    }
}

// MARK: - Code Metrics Calculator

/// Calculates comprehensive code metrics.
public final class CodeMetricsCalculator {
    public static let shared = CodeMetricsCalculator()
    private init() {}

    public struct ProjectMetrics {
        public var totalFiles: Int
        public var totalLines: Int
        public var sourceLines: Int
        public var commentLines: Int
        public var blankLines: Int
        public var commentDensity: Double
        public var totalFunctions: Int
        public var totalClasses: Int
        public var totalStructs: Int
        public var totalEnums: Int
        public var totalProtocols: Int
        public var totalExtensions: Int
        public var averageFunctionLength: Double
        public var maxInheritanceDepth: Int
        public var couplingBetweenObjects: Int
        public var languages: [String: Int]
        public var byFileType: [String: Int]
    }

    /// Calculate metrics for a project directory.
    public func calculate(for directory: String) -> ProjectMetrics {
        var totalFiles = 0
        var totalLines = 0
        var sourceLines = 0
        var commentLines = 0
        var blankLines = 0
        var totalFunctions = 0
        var totalClasses = 0
        var totalStructs = 0
        var totalEnums = 0
        var totalProtocols = 0
        var totalExtensions = 0
        var languages: [String: Int] = [:]
        var byFileType: [String: Int] = [:]
        var functionLengths: [Int] = []
        var maxDepth = 0

        let walker = MetricsFileWalker()
        walker.walk(directory) { path, content in
            totalFiles += 1
            let ext = (path as NSString).pathExtension.lowercased()
            byFileType[ext, default: 0] += 1

            let lang = Language.forExtension(ext)
            languages[lang.displayName, default: 0] += 1

            let lines = content.components(separatedBy: .newlines)
            totalLines += lines.count

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { blankLines += 1 }
                else if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                    commentLines += 1
                } else {
                    sourceLines += 1
                }
            }

            // Count Swift declarations
            if ext == "swift" {
                totalFunctions += countPattern(in: content, pattern: #"func\s+\w+"#)
                totalClasses += countPattern(in: content, pattern: #"class\s+\w+"#)
                totalStructs += countPattern(in: content, pattern: #"struct\s+\w+"#)
                totalEnums += countPattern(in: content, pattern: #"enum\s+\w+"#)
                totalProtocols += countPattern(in: content, pattern: #"protocol\s+\w+"#)
                totalExtensions += countPattern(in: content, pattern: #"extension\s+\w+"#)
            }
        }

        let commentDensity = totalLines > 0 ? Double(commentLines) / Double(totalLines) : 0
        let avgFuncLength = functionLengths.isEmpty ? 0 : Double(functionLengths.reduce(0, +)) / Double(functionLengths.count)

        return ProjectMetrics(
            totalFiles: totalFiles,
            totalLines: totalLines,
            sourceLines: sourceLines,
            commentLines: commentLines,
            blankLines: blankLines,
            commentDensity: commentDensity,
            totalFunctions: totalFunctions,
            totalClasses: totalClasses,
            totalStructs: totalStructs,
            totalEnums: totalEnums,
            totalProtocols: totalProtocols,
            totalExtensions: totalExtensions,
            averageFunctionLength: avgFuncLength,
            maxInheritanceDepth: maxDepth,
            couplingBetweenObjects: 0,
            languages: languages,
            byFileType: byFileType
        )
    }

    private func countPattern(in content: String, pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let ns = content as NSString
        return regex.numberOfMatches(in: content, options: [], range: NSRange(location: 0, length: ns.length))
    }
}

private final class MetricsFileWalker {
    private let fm = FileManager.default

    func walk(_ dir: String, callback: (String, String) -> Void) {
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }
        for entry in entries {
            if entry.hasPrefix(".") || entry == "node_modules" || entry == "DerivedData" || entry == "build" || entry == ".build" || entry == "Pods" { continue }
            let full = (dir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            if isDir.boolValue {
                walk(full, callback: callback)
            } else {
                if let content = try? String(contentsOfFile: full, encoding: .utf8) {
                    callback(full, content)
                }
            }
        }
    }
}

// MARK: - Code Formatter

/// Formats code according to language-specific style guides.
public final class CodeFormatter {
    public static let shared = CodeFormatter()
    private init() {}

    /// Format a Swift file.
    public func formatSwift(_ content: String) -> String {
        var lines = content.components(separatedBy: .newlines)
        var indentLevel = 0
        let indentString = "    "  // 4 spaces

        for i in lines.indices {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Decrease indent for closing braces
            if trimmed.hasPrefix("}") || trimmed.hasPrefix(")") || trimmed.hasPrefix("]") {
                indentLevel = max(0, indentLevel - 1)
            }

            // Apply indentation
            lines[i] = String(repeating: indentString, count: indentLevel) + trimmed

            // Increase indent after opening braces
            let openCount = trimmed.filter { $0 == "{" || $0 == "(" || $0 == "[" }.count
            let closeCount = trimmed.filter { $0 == "}" || $0 == ")" || $0 == "]" }.count
            indentLevel += openCount - closeCount
            indentLevel = max(0, indentLevel)
        }

        // Remove trailing whitespace
        lines = lines.map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }

        // Ensure file ends with newline
        var result = lines.joined(separator: "\n")
        if !result.hasSuffix("\n") {
            result += "\n"
        }

        return result
    }

    /// Format a Python file.
    public func formatPython(_ content: String) -> String {
        var lines = content.components(separatedBy: .newlines)
        // Remove trailing whitespace
        lines = lines.map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
        // Ensure file ends with newline
        var result = lines.joined(separator: "\n")
        if !result.hasSuffix("\n") {
            result += "\n"
        }
        return result
    }

    /// Format a JavaScript/TypeScript file.
    public func formatJavaScript(_ content: String) -> String {
        return formatSwift(content)  // Similar brace-based formatting
    }

    /// Format content based on language.
    public func format(_ content: String, language: Language) -> String {
        switch language {
        case .swift: return formatSwift(content)
        case .python: return formatPython(content)
        case .javascript, .typescript, .jsx, .tsx: return formatJavaScript(content)
        default: return content
        }
    }
}

// MARK: - Code Linter

/// Lints code for common issues.
public final class CodeLinter {
    public static let shared = CodeLinter()
    private init() {}

    public struct LintFinding {
        public let file: String
        public let line: Int
        public let rule: String
        public let severity: Severity
        public let message: String
        public let suggestion: String?
    }

    public enum Severity: String {
        case error, warning, info, style
    }

    /// Lint a Swift file.
    public func lintSwift(_ content: String, fileName: String) -> [LintFinding] {
        var findings: [LintFinding] = []
        let lines = content.components(separatedBy: .newlines)

        for (idx, line) in lines.enumerated() {
            let lineNumber = idx + 1

            // Check line length (120 chars)
            if line.count > 120 {
                findings.append(LintFinding(
                    file: fileName, line: lineNumber, rule: "line_length",
                    severity: .warning,
                    message: "Line exceeds 120 characters (\(line.count))",
                    suggestion: "Break into multiple lines"
                ))
            }

            // Check trailing whitespace
            if line != line.trimmingTrailingWhitespace() {
                findings.append(LintFinding(
                    file: fileName, line: lineNumber, rule: "trailing_whitespace",
                    severity: .style,
                    message: "Trailing whitespace",
                    suggestion: "Remove trailing whitespace"
                ))
            }

            // Check for force unwrap
            if line.contains("!") && !line.contains("!=") && !line.contains("//") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.hasPrefix("//") && trimmed.contains("!.") {
                    findings.append(LintFinding(
                        file: fileName, line: lineNumber, rule: "force_unwrapping",
                        severity: .warning,
                        message: "Force unwrapping can cause crashes",
                        suggestion: "Use optional binding or nil coalescing"
                    ))
                }
            }

            // Check for TODO/FIXME
            if line.contains("TODO") || line.contains("FIXME") {
                findings.append(LintFinding(
                    file: fileName, line: lineNumber, rule: "todo",
                    severity: .info,
                    message: "TODO/FIXME comment found",
                    suggestion: "Consider creating an issue"
                ))
            }

            // Check for print statements
            if line.contains("print(") && !fileName.contains("Test") && !fileName.contains("Logger") {
                findings.append(LintFinding(
                    file: fileName, line: lineNumber, rule: "print",
                    severity: .style,
                    message: "Use a logger instead of print()",
                    suggestion: "Use Logger.shared.log()"
                ))
            }

            // Check for empty function bodies
            if line.contains("{}") && !line.contains("dict") {
                findings.append(LintFinding(
                    file: fileName, line: lineNumber, rule: "empty_body",
                    severity: .style,
                    message: "Empty function/struct body",
                    suggestion: "Add implementation or document why empty"
                ))
            }

            // Check for large nesting
            let nesting = line.prefix(while: { $0 == " " || $0 == "\t" }).count / 4
            if nesting > 5 {
                findings.append(LintFinding(
                    file: fileName, line: lineNumber, rule: "nesting",
                    severity: .warning,
                    message: "Deep nesting (\(nesting) levels)",
                    suggestion: "Extract into a function"
                ))
            }
        }

        // Check for missing newline at end of file
        if !content.hasSuffix("\n") {
            findings.append(LintFinding(
                file: fileName, line: lines.count, rule: "eof_newline",
                severity: .style,
                message: "File should end with a newline",
                suggestion: "Add a newline at the end"
            ))
        }

        return findings
    }

    /// Lint based on language.
    public func lint(_ content: String, fileName: String, language: Language) -> [LintFinding] {
        switch language {
        case .swift: return lintSwift(content, fileName: fileName)
        default: return []
        }
    }
}

private extension String {
    func trimmingTrailingWhitespace() -> String {
        var s = self
        while let last = s.last, last.isWhitespace && last != "\n" {
            s.removeLast()
        }
        return s
    }
}
