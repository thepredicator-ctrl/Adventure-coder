import Foundation

/// Hugging Face Inference provider.
///
/// Uses the Hugging Face router API (https://router.huggingface.co) which exposes an
/// OpenAI-compatible chat completions endpoint, plus the models API for discovery.
public final class HuggingFaceProvider: AIProvider {
    public let id = "huggingface"
    public let displayName = "Hugging Face"
    public let requiresAPIKey = true
    public let keychainKey: KeychainService.Key = .huggingFaceToken

    private let inferenceBase = URL(string: "https://router.huggingface.co/v1")!
    private let modelsAPI = URL(string: "https://huggingface.co/api/models")!
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func isConfigured() -> Bool {
        KeychainService.has(.huggingFaceToken)
    }

    public func token() -> String? {
        KeychainService.load(.huggingFaceToken)
    }

    public func testConnection() async -> ProviderTestResult {
        guard let token = token(), !token.isEmpty else {
            return ProviderTestResult(success: false, message: "Add a Hugging Face token first.")
        }
        // Verify the token by listing whoami
        var req = URLRequest(url: URL(string: "https://huggingface.co/api/whoami-v2")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                return ProviderTestResult(success: false, message: "Unexpected response from Hugging Face.")
            }
            if http.statusCode == 200 {
                return ProviderTestResult(success: true, message: "Connected to Hugging Face.")
            }
            return ProviderTestResult(success: false, message: "Hugging Face rejected the token (status \(http.statusCode)).")
        } catch {
            return ProviderTestResult(success: false, message: "Connection failed: \(error.localizedDescription)")
        }
    }

    public func discoverModels() async -> [AIModel] {
        guard let token = token() else { return [] }
        // Use the curated inference-enabled text-generation models list.
        let url = modelsAPI.appending(queryItems: [
            URLQueryItem(name: "filter", value: "text-generation-inference"),
            URLQueryItem(name: "full", value: "true"),
            URLQueryItem(name: "limit", value: "100")
        ])
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            let decoded = try JSONDecoder().decode([HFModel].self, from: data)
            return decoded.map { m in
                let id = m.id
                let tag = m.tags?.first(where: { $0 == "conversational" }) ?? ""
                let ctx = extractContext(from: m.configs)
                return AIModel(
                    providerId: self.id,
                    modelId: id,
                    displayName: id,
                    contextLength: ctx,
                    maxOutputTokens: 2048,
                    isFree: true,           // Hugging Face free tier is the default
                    promptPricePer1K: 0,
                    completionPricePer1K: 0,
                    supportsToolCalls: false, // HF free inference generally doesn't support OpenAI-style tools
                    supportsVision: m.tags?.contains("image-text-to-text") ?? false,
                    supportsStreaming: true,
                    description: m.pipeline_tag ?? "text-generation",
                    tags: m.tags ?? [],
                    codingScore: ScoreEstimator.codingScore(for: id),
                    toolUseScore: ScoreEstimator.toolUseScore(for: id, supportsTools: false),
                    reliabilityScore: ScoreEstimator.reliabilityScore(for: id)
                )
            }
        } catch {
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
        guard let token = token() else { throw ProviderError.missingKey }
        let url = inferenceBase.appendingPathComponent("chat/completions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
                  let chunk = try? JSONDecoder().decode(HFStreamChunk.self, from: data) else { continue }
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
        guard let token = token() else { throw ProviderError.missingKey }
        let url = inferenceBase.appendingPathComponent("chat/completions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        let decoded = try JSONDecoder().decode(HFChatResponse.self, from: data)
        let choice = decoded.choices.first
        return ProviderCompletion(
            content: choice?.message.content ?? "",
            finishReason: choice?.finishReason ?? "stop",
            usageTokensIn: decoded.usage?.promptTokens ?? 0,
            usageTokensOut: decoded.usage?.completionTokens ?? 0,
            model: decoded.model ?? model
        )
    }

    private func extractContext(from configs: [String: HFModelConfig?]?) -> Int {
        guard let configs = configs, let firstKey = configs.keys.first, let cfg = configs[firstKey] ?? nil else { return 4096 }
        return cfg.max_position_embeddings ?? cfg.seq_length ?? 4096
    }
}

private struct HFModel: Decodable {
    let id: String
    let tags: [String]?
    let pipeline_tag: String?
    let configs: [String: HFModelConfig?]?
}

private struct HFModelConfig: Decodable {
    let max_position_embeddings: Int?
    let seq_length: Int?
}

private struct HFStreamChunk: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let delta: Delta
        let finishReason: String?
        struct Delta: Decodable {
            let content: String?
        }
    }
}

private struct HFChatResponse: Decodable {
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
    }
    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.queryItems = queryItems
        return components.url ?? self
    }
}
