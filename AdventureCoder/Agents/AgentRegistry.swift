import Foundation

/// Registry of all specialized agents.
public final class AgentRegistry {
    public static let shared = AgentRegistry()
    public let all: [AgentDefinition]
    private init() {
        self.all = PlanningAgents.all
            + CodingAgents.all
            + UnderstandingAgents.all
            + DebuggingAgents.all
            + ResearchAgents.all
            + DevToolAgents.all
            + ProductAgents.all
            + DeploymentAgents.all
            + AdvancedCodingAgents.all
            + AdvancedAnalysisAgents.all
            + DevOpsDataAgents.all
            + MLSpecialistAgents.all
            + Web3Agents.all
            + GameDevAgents.all
            + SecurityComplianceAgents.all
            + TestingQAAgents.all
    }
    public func find(_ id: String) -> AgentDefinition? {
        all.first { $0.agentId == id }
    }
    public func agents(in category: AgentCategory) -> [AgentDefinition] {
        all.filter { $0.category == category }
    }
    public var count: Int { all.count }
    public var categories: [AgentCategory] { AgentCategory.allCases }
}
