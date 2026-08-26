import XCTest
@testable import AdventureCoder

final class AgentCountTests: XCTestCase {
    func testHasAtLeastOneHundredAgents() {
        let count = AgentRegistry.shared.count
        XCTAssertGreaterThanOrEqual(count, 100, "Expected at least 100 agents, got \(count)")
    }

    func testAllAgentsHaveUniqueIDs() {
        let ids = AgentRegistry.shared.all.map { $0.agentId }
        XCTAssertEqual(Set(ids).count, ids.count, "Agent IDs are not unique")
    }

    func testAllAgentsHaveNonEmptyInstructions() {
        for agent in AgentRegistry.shared.all {
            XCTAssertFalse(agent.systemInstructions.isEmpty, "Agent \(agent.name) has empty instructions")
            XCTAssertFalse(agent.role.isEmpty, "Agent \(agent.name) has empty role")
            XCTAssertFalse(agent.toolPermissions.isEmpty, "Agent \(agent.name) has no tool permissions")
            XCTAssertFalse(agent.description.isEmpty, "Agent \(agent.name) has empty description")
        }
    }

    func testAllCategoriesPresent() {
        let categories = Set(AgentRegistry.shared.all.map { $0.category })
        XCTAssertTrue(categories.contains(.planning))
        XCTAssertTrue(categories.contains(.coding))
        XCTAssertTrue(categories.contains(.codeUnderstanding))
        XCTAssertTrue(categories.contains(.debugging))
        XCTAssertTrue(categories.contains(.research))
        XCTAssertTrue(categories.contains(.devTools))
        XCTAssertTrue(categories.contains(.product))
        XCTAssertTrue(categories.contains(.deployment))
    }

    func testCodingAgentCount() {
        let coding = AgentRegistry.shared.agents(in: .coding)
        XCTAssertGreaterThanOrEqual(coding.count, 40, "Expected at least 40 coding agents, got \(coding.count)")
    }

    func testAnalysisAgentCount() {
        let analysis = AgentRegistry.shared.agents(in: .codeUnderstanding)
        XCTAssertGreaterThanOrEqual(analysis.count, 30, "Expected at least 30 understanding agents, got \(analysis.count)")
    }

    func testDeploymentAgentCount() {
        let deployment = AgentRegistry.shared.agents(in: .deployment)
        XCTAssertGreaterThanOrEqual(deployment.count, 30, "Expected at least 30 deployment agents, got \(deployment.count)")
    }

    func testSpecificAdvancedAgentsExist() {
        XCTAssertNotNil(AgentRegistry.shared.find("coding.kotlin"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.dart"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.go"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.java"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.csharp"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.flutter"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.react_native"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.nextjs"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.vue"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.svelte"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.graphql"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.dockerfile"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.terraform"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.kubernetes"))
        XCTAssertNotNil(AgentRegistry.shared.find("analysis.complexity"))
        XCTAssertNotNil(AgentRegistry.shared.find("analysis.duplicates"))
        XCTAssertNotNil(AgentRegistry.shared.find("analysis.dead_code"))
        XCTAssertNotNil(AgentRegistry.shared.find("analysis.metrics"))
        XCTAssertNotNil(AgentRegistry.shared.find("analysis.formatter"))
        XCTAssertNotNil(AgentRegistry.shared.find("analysis.linter"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.aws"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.azure"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.gcp"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.vercel"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.netlify"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.db_architect"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.postgres"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.mongodb"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.supabase"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.firebase"))
    }
}

final class SymbolParserTests: XCTestCase {
    func testParseClass() {
        let code = "class MyClass { }"
        let symbols = SymbolParser.parse(content: code, fileName: "test.swift")
        XCTAssertTrue(symbols.contains { $0.name == "MyClass" && $0.kind == .class })
    }

    func testParseStruct() {
        let code = "struct MyStruct { }"
        let symbols = SymbolParser.parse(content: code, fileName: "test.swift")
        XCTAssertTrue(symbols.contains { $0.name == "MyStruct" && $0.kind == .struct_ })
    }

    func testParseEnum() {
        let code = "enum MyEnum { case one }"
        let symbols = SymbolParser.parse(content: code, fileName: "test.swift")
        XCTAssertTrue(symbols.contains { $0.name == "MyEnum" && $0.kind == .enum_ })
    }

    func testParseProtocol() {
        let code = "protocol MyProtocol { }"
        let symbols = SymbolParser.parse(content: code, fileName: "test.swift")
        XCTAssertTrue(symbols.contains { $0.name == "MyProtocol" && $0.kind == .protocol_ })
    }

    func testParseFunc() {
        let code = "func myFunction() { }"
        let symbols = SymbolParser.parse(content: code, fileName: "test.swift")
        XCTAssertTrue(symbols.contains { $0.name == "myFunction" && $0.kind == .func })
    }

    func testParseExtension() {
        let code = "extension String { }"
        let symbols = SymbolParser.parse(content: code, fileName: "test.swift")
        XCTAssertTrue(symbols.contains { $0.name == "String" && $0.kind == .extension_ })
    }

    func testParseLet() {
        let code = "let myVar = 42"
        let symbols = SymbolParser.parse(content: code, fileName: "test.swift")
        XCTAssertTrue(symbols.contains { $0.name == "myVar" && $0.kind == .var_ })
    }

    func testParseVar() {
        let code = "var myVar = 42"
        let symbols = SymbolParser.parse(content: code, fileName: "test.swift")
        XCTAssertTrue(symbols.contains { $0.name == "myVar" && $0.kind == .var_ })
    }

    func testParseMultipleSymbols() {
        let code = """
        class MyClass { }
        struct MyStruct { }
        func myFunc() { }
        let x = 1
        """
        let symbols = SymbolParser.parse(content: code, fileName: "test.swift")
        XCTAssertGreaterThanOrEqual(symbols.count, 4)
    }

    func testIgnoresComments() {
        let code = "// class Commented { }"
        let symbols = SymbolParser.parse(content: code, fileName: "test.swift")
        XCTAssertTrue(symbols.isEmpty)
    }
}

final class KeyboardShortcutsTests: XCTestCase {
    func testAllShortcutsHaveDescriptions() {
        for category in KeyboardShortcuts.all {
            for shortcut in category.shortcuts {
                XCTAssertFalse(shortcut.description.isEmpty, "Shortcut missing description")
            }
        }
    }

    func testShortcutsHaveKeys() {
        for category in KeyboardShortcuts.all {
            for shortcut in category.shortcuts {
                XCTAssertFalse(shortcut.key.character.isEmpty, "Shortcut missing key")
            }
        }
    }

    func testCommandSystemInitialized() {
        XCTAssertFalse(CommandSystem.shared.commands.isEmpty, "Command system should have default commands")
    }

    func testCommandSystemSearch() {
        let results = CommandSystem.shared.search("build")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.title.contains("Build") })
    }

    func testCommandSystemEmptySearch() {
        let results = CommandSystem.shared.search("")
        XCTAssertEqual(results.count, CommandSystem.shared.commands.count)
    }
}

final class ThemeSystemTests: XCTestCase {
    func testAllThemesExist() {
        XCTAssertGreaterThanOrEqual(AppTheme.allThemes.count, 4)
    }

    func testLightTheme() {
        XCTAssertEqual(AppTheme.light.name, "Light")
    }

    func testDarkTheme() {
        XCTAssertEqual(AppTheme.dark.name, "Dark")
    }

    func testMidnightTheme() {
        XCTAssertEqual(AppTheme.midnight.name, "Midnight")
    }

    func testPaperTheme() {
        XCTAssertEqual(AppTheme.paper.name, "Paper")
    }

    func testThemeManagerDefault() {
        let manager = ThemeManager.shared
        XCTAssertNotNil(manager.currentTheme)
    }

    func testThemeManagerSetTheme() {
        let manager = ThemeManager.shared
        let original = manager.currentTheme
        manager.setTheme(.dark)
        XCTAssertEqual(manager.currentTheme.name, "Dark")
        manager.setTheme(original)
    }
}
