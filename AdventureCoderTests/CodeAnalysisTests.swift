import XCTest
@testable import AdventureCoder

final class CodeComplexityAnalyzerTests: XCTestCase {
    func testSimpleFunction() {
        let code = """
        func simple() {
            print("hello")
        }
        """
        let metrics = CodeComplexityAnalyzer.shared.analyzeSwift(content: code, fileName: "test.swift")
        XCTAssertEqual(metrics.functions.count, 1)
        XCTAssertGreaterThanOrEqual(metrics.functions[0].cyclomaticComplexity, 1)
    }

    func testComplexFunction() {
        let code = """
        func complex(x: Int) -> Int {
            if x > 0 {
                for i in 0..<x {
                    if i % 2 == 0 {
                        print(i)
                    }
                }
            }
            return x
        }
        """
        let metrics = CodeComplexityAnalyzer.shared.analyzeSwift(content: code, fileName: "test.swift")
        XCTAssertEqual(metrics.functions.count, 1)
        XCTAssertGreaterThan(metrics.functions[0].cyclomaticComplexity, 1)
    }

    func testMaintainabilityIndex() {
        let mi = CodeComplexityAnalyzer.shared.calculateMaintainabilityIndex(totalLines: 100, codeLines: 80, avgComplexity: 5)
        XCTAssertGreaterThan(mi, 0)
        XCTAssertLessThanOrEqual(mi, 100)
    }

    func testGradeForMI() {
        XCTAssertEqual(CodeComplexityAnalyzer.shared.gradeForMI(70), .a)
        XCTAssertEqual(CodeComplexityAnalyzer.shared.gradeForMI(55), .b)
        XCTAssertEqual(CodeComplexityAnalyzer.shared.gradeForMI(40), .c)
        XCTAssertEqual(CodeComplexityAnalyzer.shared.gradeForMI(25), .d)
        XCTAssertEqual(CodeComplexityAnalyzer.shared.gradeForMI(10), .f)
    }

    func testFindHotspots() {
        let code = """
        func simple() { return 1 }
        func complex(a: Int, b: Int) -> Int {
            if a > 0 {
                if b > 0 {
                    if a > b {
                        for i in 0..<a {
                            if i % 2 == 0 {
                                if i % 3 == 0 {
                                    print(i)
                                }
                            }
                        }
                    }
                }
            }
            return a + b
        }
        """
        let metrics = CodeComplexityAnalyzer.shared.analyzeSwift(content: code, fileName: "test.swift")
        let hotspots = CodeComplexityAnalyzer.shared.findHotspots(in: [metrics])
        XCTAssertFalse(hotspots.isEmpty)
    }
}

final class DuplicateDetectorTests: XCTestCase {
    func testTokenize() {
        let code = """
        func foo() {
            print("hello")
        }
        func bar() {
            print("hello")
        }
        """
        let blocks = DuplicateDetector.shared.tokenize(code, file: "test.swift")
        XCTAssertFalse(blocks.isEmpty)
    }

    func testSimilarity() {
        let tokens1 = ["func", "foo", "print", "hello"]
        let tokens2 = ["func", "foo", "print", "hello"]
        XCTAssertEqual(DuplicateDetector.shared.similarity(tokens1, tokens2), 1.0)
    }

    func testNoSimilarity() {
        let tokens1 = ["func", "foo"]
        let tokens2 = ["class", "bar"]
        XCTAssertEqual(DuplicateDetector.shared.similarity(tokens1, tokens2), 0.0)
    }

    func testFindDuplicates() {
        let code1 = """
        func duplicate() {
            let x = 1
            let y = 2
            let z = x + y
            print(z)
            return z
        }
        """
        let code2 = """
        func alsoDuplicate() {
            let x = 1
            let y = 2
            let z = x + y
            print(z)
            return z
        }
        """
        let dups = DuplicateDetector.shared.findDuplicates(in: [("a.swift", code1), ("b.swift", code2)])
        XCTAssertFalse(dups.isEmpty)
    }
}

final class DeadCodeDetectorTests: XCTestCase {
    func testDetectUnusedFunction() {
        let code = """
        func used() { print("used") }
        func unused() { print("unused") }
        used()
        """
        let deadCode = DeadCodeDetector.shared.detect(in: code, fileName: "test.swift", allFiles: [("test.swift", code)])
        XCTAssertTrue(deadCode.contains { $0.type == .unusedFunction })
    }

    func testDetectCommentedOutCode() {
        let code = """
        // let x = 42
        // print(x)
        func real() {}
        """
        let deadCode = DeadCodeDetector.shared.detect(in: code, fileName: "test.swift", allFiles: [("test.swift", code)])
        XCTAssertTrue(deadCode.contains { $0.type == .commentedOut })
    }

    func testDetectUnreachableCode() {
        let code = """
        func test() {
            return
            print("unreachable")
        }
        """
        let deadCode = DeadCodeDetector.shared.detect(in: code, fileName: "test.swift", allFiles: [("test.swift", code)])
        XCTAssertTrue(deadCode.contains { $0.type == .unreachableCode })
    }
}

final class CodeMetricsCalculatorTests: XCTestCase {
    func testCalculateMetrics() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("metrics-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try? "func foo() {}".write(to: tmp.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)
        try? "class Bar {}".write(to: tmp.appendingPathComponent("b.swift"), atomically: true, encoding: .utf8)

        let metrics = CodeMetricsCalculator.shared.calculate(for: tmp.path)
        XCTAssertEqual(metrics.totalFiles, 2)
        XCTAssertGreaterThan(metrics.totalLines, 0)
        XCTAssertEqual(metrics.totalFunctions, 1)
        XCTAssertEqual(metrics.totalClasses, 1)
    }
}

final class CodeFormatterTests: XCTestCase {
    func testFormatSwift() {
        let code = """
        func foo(){
        if true{
        print("hi")
        }
        }
        """
        let formatted = CodeFormatter.shared.formatSwift(code)
        XCTAssertTrue(formatted.contains("    "))
    }

    func testFormatAddsNewline() {
        let code = "let x = 1"
        let formatted = CodeFormatter.shared.formatSwift(code)
        XCTAssertTrue(formatted.hasSuffix("\n"))
    }

    func testFormatByLanguage() {
        let code = "let x = 1"
        let formatted = CodeFormatter.shared.format(code, language: .swift)
        XCTAssertTrue(formatted.hasSuffix("\n"))
    }
}

final class CodeLinterTests: XCTestCase {
    func testDetectLongLine() {
        let longLine = String(repeating: "x", count: 130)
        let findings = CodeLinter.shared.lintSwift(longLine, fileName: "test.swift")
        XCTAssertTrue(findings.contains { $0.rule == "line_length" })
    }

    func testDetectTrailingWhitespace() {
        let findings = CodeLinter.shared.lintSwift("let x = 1   \n", fileName: "test.swift")
        XCTAssertTrue(findings.contains { $0.rule == "trailing_whitespace" })
    }

    func testDetectForceUnwrap() {
        let findings = CodeLinter.shared.lintSwift("let x = optional!.\n", fileName: "test.swift")
        XCTAssertTrue(findings.contains { $0.rule == "force_unwrapping" })
    }

    func testDetectPrint() {
        let findings = CodeLinter.shared.lintSwift("print(\"hello\")\n", fileName: "test.swift")
        XCTAssertTrue(findings.contains { $0.rule == "print" })
    }

    func testDetectMissingEOFNewline() {
        let findings = CodeLinter.shared.lintSwift("let x = 1", fileName: "test.swift")
        XCTAssertTrue(findings.contains { $0.rule == "eof_newline" })
    }
}
