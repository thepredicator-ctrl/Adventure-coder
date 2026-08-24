import XCTest
@testable import AdventureCoder

final class AgentTests: XCTestCase {
    func testHasAtLeastSeventyAgents() {
        let count = AgentRegistry.shared.count
        XCTAssertGreaterThanOrEqual(count, 70, "Expected at least 70 agents, got \(count)")
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

    func testSpecificAgentsExist() {
        XCTAssertNotNil(AgentRegistry.shared.find("planning.project_planner"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.swift"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.swiftui"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.typescript"))
        XCTAssertNotNil(AgentRegistry.shared.find("coding.react"))
        XCTAssertNotNil(AgentRegistry.shared.find("understanding.code_reviewer"))
        XCTAssertNotNil(AgentRegistry.shared.find("understanding.security_analyzer"))
        XCTAssertNotNil(AgentRegistry.shared.find("debugging.build_error"))
        XCTAssertNotNil(AgentRegistry.shared.find("research.web_search"))
        XCTAssertNotNil(AgentRegistry.shared.find("research.documentation"))
        XCTAssertNotNil(AgentRegistry.shared.find("tools.git"))
        XCTAssertNotNil(AgentRegistry.shared.find("tools.github"))
        XCTAssertNotNil(AgentRegistry.shared.find("deployment.ios_build"))
        XCTAssertNotNil(AgentRegistry.shared.find("deployment.ipa_packaging"))
    }

    func testCodingAgentCount() {
        let coding = AgentRegistry.shared.agents(in: .coding)
        XCTAssertGreaterThanOrEqual(coding.count, 12, "Expected at least 12 coding agents, got \(coding.count)")
    }
}
