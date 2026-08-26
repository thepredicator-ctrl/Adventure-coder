import Foundation

/// OpenRouter AI provider (https://openrouter.ai).
///
/// Implements the OpenRouter Chat Completions API with streaming via Server-Sent Events.
public final class OpenRouterProvider: AIProvider {
    public let id = "openrouter"
    public let displayName = "OpenRouter"
    public let requiresAPIKey = true
    public let keychainKey: KeychainService.Key = .openRouterAPIKey

    private let baseURL = URL(string: "https://openrouter.ai/api/v1")!
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func isConfigured() -> Bool {
        KeychainService.has(.openRouterAPIKey)
    }

    public func apiKey() -> String? {
        KeychainService.load(.openRouterAPIKey)
    }

    public func testConnection() async -> ProviderTestResult {
        guard let key = apiKey(), !key.isEmpty else {
            return ProviderTestResult(success: false, message: "Add an OpenRouter API key first.")
        }
        do {
            let models = await discoverModels()
            if models.isEmpty {
                return ProviderTestResult(success: false, message: "Connected but no models were returned. Check the key permissions.")
            }
            return ProviderTestResult(success: true, message: "Connected to OpenRouter. \(models.count) models discovered.", modelsDiscovered: models.count)
        } catch {
            return ProviderTestResult(success: false, message: "Connection failed: \(error.localizedDescription)")
        }
    }

    public func discoverModels() async -> [AIModel] {
        guard let key = apiKey() else { return [] }
        let url = baseURL.appendingPathComponent("models")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("AdventureCoder/1.0", forHTTPHeaderField: "X-Title")

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let body = String(data: data, encoding: .utf8) ?? ""
                Logger.shared.log("OpenRouter discoverModels failed: status \(statusCode), body: \(body.prefix(200))", level: .error, category: "provider")
                return []
            }
            let decoded = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
            return decoded.data.map { m in
                let pricing = m.pricing
                let prompt = Double(pricing.prompt) ?? 0
                let completion = Double(pricing.completion) ?? 0
                let isFree = prompt == 0 && completion == 0
                let ctx = Int(m.contextLength ?? "8192") ?? 8192
                let maxOut = Int(m.topProvider?.maxCompletionTokens ?? "2048") ?? 2048
                return AIModel(
                    providerId: id,
                    modelId: m.id,
                    displayName: m.name ?? m.id,
                    contextLength: ctx,
                    maxOutputTokens: maxOut,
                    isFree: isFree,
                    promptPricePer1K: prompt * 1000,
                    completionPricePer1K: completion * 1000,
                    supportsToolCalls: m.supportedParameters?.contains("tools") ?? false,
                    supportsVision: m.architecture?.modality?.contains("image") ?? false,
                    supportsStreaming: true,
                    description: m.description ?? "",
                    tags: m.architecture?.inputModalities ?? [],
                    codingScore: ScoreEstimator.codingScore(for: m.id),
                    toolUseScore: ScoreEstimator.toolUseScore(for: m.id, supportsTools: m.supportedParameters?.contains("tools") ?? false),
                    reliabilityScore: ScoreEstimator.reliabilityScore(for: m.id)
                )
            }
        } catch {
            Logger.shared.log("OpenRouter discoverModels decode error: \(error)", level: .error, category: "provider")
            return []
        }
    }

    public func streamChat(
        messages: [ProviderMessage],
        model: String,
        temperature: Double,
        maxTokens: Int,
        onDelta: @escaping (String) -> Void
    ) async throws -> ProviderCompletion {
        guard let key = apiKey() else { throw ProviderError.missingKey }
        let url = baseURL.appendingPathComponent("chat/completions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("AdventureCoder/1.0", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.requestFailed(-1, "No HTTP response") }
        if http.statusCode == 429 { throw ProviderError.rateLimited }
        if http.statusCode != 200 {
            let body = try await bytes.lines.reduce(into: "") { $0 += $1 }
            throw ProviderError.requestFailed(http.statusCode, body)
        }

        var content = ""
        var finish = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(OpenRouterStreamChunk.self, from: data) else { continue }
            if let delta = chunk.choices.first?.delta.content {
                content += delta
                onDelta(delta)
            }
            if let f = chunk.choices.first?.finishReason, !f.isEmpty { finish = f }
        }
        return ProviderCompletion(content: content, finishReason: finish.isEmpty ? "stop" : finish, model: model)
    }

    public func chat(
        messages: [ProviderMessage],
        model: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> ProviderCompletion {
        guard let key = apiKey() else { throw ProviderError.missingKey }
        let url = baseURL.appendingPathComponent("chat/completions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("AdventureCoder/1.0", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": false
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.requestFailed(-1, "No HTTP response") }
        if http.statusCode == 429 { throw ProviderError.rateLimited }
        if http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderError.requestFailed(http.statusCode, body)
        }
        let decoded = try JSONDecoder().decode(OpenRouterChatResponse.self, from: data)
        let choice = decoded.choices.first
        let content = choice?.message.content ?? ""
        let usage = decoded.usage
        return ProviderCompletion(
            content: content,
            finishReason: choice?.finishReason ?? "stop",
            usageTokensIn: usage?.promptTokens ?? 0,
            usageTokensOut: usage?.completionTokens ?? 0,
            model: decoded.model ?? model
        )
    }
}

// MARK: - Decoding models

private struct OpenRouterModelsResponse: Decodable {
    let data: [Model]
    struct Model: Decodable {
        let id: String
        let name: String?
        let description: String?
        let contextLength: String?
        let pricing: Pricing
        let architecture: Architecture?
        let topProvider: TopProvider?
        let supportedParameters: [String]?

        enum CodingKeys: String, CodingKey {
            case id, name, description, pricing, architecture
            case contextLength = "context_length"
            case topProvider = "top_provider"
            case supportedParameters = "supported_parameters"
        }

        struct Pricing: Decodable {
            let prompt: String
            let completion: String
        }
        struct Architecture: Decodable {
            let modality: String?
            let inputModalities: [String]?
            enum CodingKeys: String, CodingKey {
                case modality
                case inputModalities = "input_modalities"
            }
        }
        struct TopProvider: Decodable {
            let maxCompletionTokens: String?
            enum CodingKeys: String, CodingKey {
                case maxCompletionTokens = "max_completion_tokens"
            }
        }
    }
}

private struct OpenRouterStreamChunk: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let delta: Delta
        let finishReason: String?
        struct Delta: Decodable {
            let content: String?
        }
        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }
}

private struct OpenRouterChatResponse: Decodable {
    let choices: [Choice]
    let usage: Usage?
    let model: String?
    struct Choice: Decodable {
        let message: Message
        let finishReason: String?
        struct Message: Decodable {
            let role: String
            let content: String?
        }
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
        }
    }
}

/// Heuristic scoring used to rank free models by coding/tool/reliability suitability.
public enum ScoreEstimator {
    public static func codingScore(for modelId: String) -> Double {
        let id = modelId.lowercased()
        var score = 0.4
        if id.contains("deepseek") { score = 0.85 }
        if id.contains("deepseek-coder") || id.contains("deepseek-v3") || id.contains("deepseek-r1") { score = 0.9 }
        if id.contains("qwen") { score = 0.75 }
        if id.contains("qwen2.5-coder") { score = 0.88 }
        if id.contains("llama-3.1") || id.contains("llama-3.3") { score = 0.78 }
        if id.contains("llama-3.2") { score = 0.7 }
        if id.contains("mistral") || id.contains("codestral") { score = 0.8 }
        if id.contains("codestral") { score = 0.86 }
        if id.contains("gemma") { score = 0.65 }
        if id.contains("phi") { score = 0.6 }
        if id.contains("gpt-4") { score = 0.92 }
        if id.contains("gpt-3.5") { score = 0.7 }
        if id.contains("claude-3") { score = 0.9 }
        if id.contains("claude-3.5") || id.contains("claude-3-7") { score = 0.93 }
        return min(score, 1.0)
    }

    public static func toolUseScore(for modelId: String, supportsTools: Bool) -> Double {
        if !supportsTools { return 0.2 }
        let id = modelId.lowercased()
        var score = 0.6
        if id.contains("claude") { score = 0.9 }
        if id.contains("gpt-4") { score = 0.9 }
        if id.contains("llama-3.1") || id.contains("llama-3.3") { score = 0.8 }
        if id.contains("mistral") || id.contains("qwen") { score = 0.75 }
        if id.contains("deepseek") { score = 0.7 }
        return min(score, 1.0)
    }

    public static func reliabilityScore(for modelId: String) -> Double {
        let id = modelId.lowercased()
        if id.contains("gpt-4") || id.contains("claude") { return 0.95 }
        if id.contains("llama-3") || id.contains("qwen") || id.contains("mistral") { return 0.85 }
        if id.contains("deepseek") { return 0.82 }
        if id.contains("gemma") { return 0.78 }
        return 0.7
    }
}
