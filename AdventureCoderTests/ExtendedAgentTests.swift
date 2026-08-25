import XCTest
@testable import AdventureCoder

final class ExtendedAgentTests: XCTestCase {
    func testHasAtLeastOneHundredThirtyAgents() {
        let count = AgentRegistry.shared.count
        XCTAssertGreaterThanOrEqual(count, 130, "Expected at least 130 agents, got \(count)")
    }

    func testMLAgentsExist() {
        XCTAssertNotNil(AgentRegistry.shared.find("ml.pipeline"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.preprocessing"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.feature_engineering"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.training"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.evaluation"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.hyperparameter"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.deployment"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.monitoring"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.dataset"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.labeling"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.validation"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.augmentation"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.prompt_engineering"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.fine_tuning"))
        XCTAssertNotNil(AgentRegistry.shared.find("ml.rag"))
    }

    func testWeb3AgentsExist() {
        XCTAssertNotNil(AgentRegistry.shared.find("web3.smart_contract"))
        XCTAssertNotNil(AgentRegistry.shared.find("web3.solidity"))
        XCTAssertNotNil(AgentRegistry.shared.find("web3.solana"))
        XCTAssertNotNil(AgentRegistry.shared.find("web3.frontend"))
        XCTAssertNotNil(AgentRegistry.shared.find("web3.ipfs"))
        XCTAssertNotNil(AgentRegistry.shared.find("web3.nft"))
        XCTAssertNotNil(AgentRegistry.shared.find("web3.defi"))
        XCTAssertNotNil(AgentRegistry.shared.find("web3.dao"))
        XCTAssertNotNil(AgentRegistry.shared.find("web3.security"))
        XCTAssertNotNil(AgentRegistry.shared.find("web3.gas_optimizer"))
    }

    func testGameDevAgentsExist() {
        XCTAssertNotNil(AgentRegistry.shared.find("gamedev.unity"))
        XCTAssertNotNil(AgentRegistry.shared.find("gamedev.unreal"))
        XCTAssertNotNil(AgentRegistry.shared.find("gamedev.godot"))
        XCTAssertNotNil(AgentRegistry.shared.find("gamedev.spritekit"))
        XCTAssertNotNil(AgentRegistry.shared.find("gamedev.scenekit"))
        XCTAssertNotNil(AgentRegistry.shared.find("gamedev.metal_shader"))
        XCTAssertNotNil(AgentRegistry.shared.find("gamedev.physics"))
        XCTAssertNotNil(AgentRegistry.shared.find("gamedev.ai"))
        XCTAssertNotNil(AgentRegistry.shared.find("gamedev.audio"))
        XCTAssertNotNil(AgentRegistry.shared.find("gamedev.level"))
    }

    func testDevOpsAgentsExist() {
        XCTAssertNotNil(AgentRegistry.shared.find("devops.cloud_architect"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.aws"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.azure"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.gcp"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.cloudflare"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.vercel"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.netlify"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.railway"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.fly"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.envoy"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.nginx"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.monitoring"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.observability"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.alerting"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.oncall"))
        XCTAssertNotNil(AgentRegistry.shared.find("devops.incident_response"))
    }

    func testDataAgentsExist() {
        XCTAssertNotNil(AgentRegistry.shared.find("data.db_architect"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.sql_optimizer"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.migration"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.orm"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.redis"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.mongodb"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.postgres"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.mysql"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.sqlite"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.elasticsearch"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.supabase"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.firebase"))
        XCTAssertNotNil(AgentRegistry.shared.find("data.appwrite"))
    }

    func testAllExtendedAgentsHaveNonEmptyInstructions() {
        let extendedAgents = AgentRegistry.shared.all.filter { agent in
            agent.agentId.hasPrefix("ml.") || agent.agentId.hasPrefix("web3.") || agent.agentId.hasPrefix("gamedev.") || agent.agentId.hasPrefix("devops.") || agent.agentId.hasPrefix("data.")
        }
        XCTAssertGreaterThan(extendedAgents.count, 40)
        for agent in extendedAgents {
            XCTAssertFalse(agent.systemInstructions.isEmpty, "Agent \(agent.name) has empty instructions")
            XCTAssertFalse(agent.role.isEmpty, "Agent \(agent.name) has empty role")
            XCTAssertFalse(agent.toolPermissions.isEmpty, "Agent \(agent.name) has no tools")
        }
    }
}

final class APIReferenceTests: XCTestCase {
    func testAllEntriesExist() {
        XCTAssertGreaterThanOrEqual(APIReference.allEntries.count, 9)
    }

    func testProjectEntry() {
        XCTAssertEqual(APIReference.project.name, "Project")
        XCTAssertFalse(APIReference.project.summary.isEmpty)
        XCTAssertGreaterThan(APIReference.project.parameters.count, 0)
    }

    func testSSHServiceEntry() {
        XCTAssertEqual(APIReference.sshService.name, "SSHService")
        XCTAssertFalse(APIReference.sshService.summary.isEmpty)
    }

    func testSearch() {
        let results = APIReference.search("SSH")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.name == "SSHService" })
    }

    func testSearchEmpty() {
        let results = APIReference.search("")
        XCTAssertEqual(results.count, APIReference.allEntries.count)
    }
}

final class ToolReferenceTests: XCTestCase {
    func testAllDocsExist() {
        XCTAssertGreaterThanOrEqual(ToolReference.allDocs.count, 10)
    }

    func testReadFileDoc() {
        let doc = ToolReference.allDocs.first { $0.name == "read_file" }
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc?.category, "File")
    }

    func testSearch() {
        let results = ToolReference.search("git")
        XCTAssertFalse(results.isEmpty)
    }
}

final class AgentReferenceTests: XCTestCase {
    func testCategoryDocsExist() {
        XCTAssertGreaterThanOrEqual(AgentReference.categoryDocs.count, 8)
    }

    func testPlanningCategoryDoc() {
        let doc = AgentReference.doc(for: .planning)
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc?.category, .planning)
        XCTAssertGreaterThan(doc?.capabilities.count ?? 0, 0)
    }

    func testCodingCategoryDoc() {
        let doc = AgentReference.doc(for: .coding)
        XCTAssertNotNil(doc)
        XCTAssertGreaterThan(doc?.capabilities.count ?? 0, 10)
    }
}
