import Foundation

// MARK: - Web tools

public struct WebSearchTool: Tool {
    public let definition = ToolDefinition.find("web_search") ?? ToolDefinition(
        name: "web_search", category: .web, summary: "Search the web", description: "")

    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let query = parameters["query"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'query'.")
        }
        let limit = (parameters["limit"] as? Int) ?? 8
        do {
            let hits = try await WebSearchService.shared.search(query: query, limit: limit)
            let arr: [[String: Any]] = hits.map {
                ["title": $0.title, "url": $0.url, "snippet": $0.snippet]
            }
            let data = try JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted])
            return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct FetchURLTool: Tool {
    public let definition = ToolDefinition.find("fetch_url") ?? ToolDefinition(
        name: "fetch_url", category: .web, summary: "Fetch a URL", description: "")

    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let urlString = parameters["url"] as? String,
              let url = URL(string: urlString) else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing or invalid 'url'.")
        }
        do {
            let text = try await WebSearchService.shared.fetchText(at: url)
            return ToolResult(toolName: definition.name, success: true, output: text)
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct SearchDocumentationTool: Tool {
    public let definition = ToolDefinition.find("search_documentation") ?? ToolDefinition(
        name: "search_documentation", category: .web, summary: "Search docs", description: "")

    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let query = parameters["query"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'query'.")
        }
        let source = (parameters["source"] as? String) ?? "apple"
        let mappedQuery: String
        switch source.lowercased() {
        case "swift": mappedQuery = "site:swift.org \(query)"
        case "mdn": mappedQuery = "site:developer.mozilla.org \(query)"
        case "github": mappedQuery = "site:github.com \(query)"
        default: mappedQuery = "site:developer.apple.com \(query)"
        }
        do {
            let hits = try await WebSearchService.shared.search(query: mappedQuery, limit: 8)
            let arr: [[String: Any]] = hits.map {
                ["title": $0.title, "url": $0.url, "snippet": $0.snippet]
            }
            let data = try JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted])
            return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return ToolResult(toolName: definition.name, success: false, output: "", error: error.localizedDescription)
        }
    }
}

public struct SearchImagesTool: Tool {
    public let definition = ToolDefinition.find("search_images") ?? ToolDefinition(
        name: "search_images", category: .web, summary: "Search images", description: "")

    public func invoke(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        guard let query = parameters["query"] as? String else {
            return ToolResult(toolName: definition.name, success: false, output: "", error: "Missing 'query'.")
        }
        let hits = try await WebSearchService.shared.searchImages(query: query)
        let arr: [[String: Any]] = hits.map {
            ["title": $0.title, "url": $0.url, "thumbnail": $0.thumbnail ?? ""]
        }
        let data = try JSONSerialization.data(withJSONObject: arr, options: [.prettyPrinted])
        return ToolResult(toolName: definition.name, success: true, output: String(data: data, encoding: .utf8) ?? "[]")
    }
}

/// Backing service for web tools. Uses the public DuckDuckGo HTML endpoint and
/// a lightweight HTML-to-text extractor. No third-party API key required.
public final class WebSearchService {
    public static let shared = WebSearchService()
    private let session: URLSession

    public struct Hit: Codable, Hashable {
        public let title: String
        public let url: String
        public let snippet: String
        public let thumbnail: String?
    }

    private init(session: URLSession = .shared) {
        self.session = session
    }

    public func search(query: String, limit: Int = 8) async throws -> [Hit] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else { return [] }
        let req = URLRequest(url: url)
        let (data, _) = try await session.data(for: req)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        return parseDuckDuckGoHTML(html).prefix(limit).map { $0 }
    }

    public func fetchText(at url: URL) async throws -> String {
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: req)
        let raw = String(data: data, encoding: .utf8) ?? ""
        let stripped = WebSearchService.stripHTML(raw)
        return String(stripped.prefix(10_000))
    }

    public func searchImages(query: String) async throws -> [Hit] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)&iar=images&iax=images&ia=images") else { return [] }
        let req = URLRequest(url: url)
        let (data, _) = try await session.data(for: req)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        return parseImageResults(html)
    }

    // MARK: - Parsing

    private func parseDuckDuckGoHTML(_ html: String) -> [Hit] {
        // DuckDuckGo's HTML endpoint lists results in <a class="result__a" href="...">title</a>
        // and snippets in <a class="result__snippet" ...>snippet</a>
        var hits: [Hit] = []
        let resultPattern = try? NSRegularExpression(pattern: #"class="result__a"\s+href="([^"]+)"[^>]*>(.*?)</a>"#, options: [.caseInsensitive, .dotall])
        let snippetPattern = try? NSRegularExpression(pattern: #"class="result__snippet"[^>]*>(.*?)</a>"#, options: [.caseInsensitive, .dotall])
        let ns = html as NSString
        let snippetMatches = snippetPattern?.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length)) ?? []
        if let resultPattern {
            resultPattern.enumerateMatches(in: html, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                guard let match = match, match.numberOfRanges >= 3 else { return }
                let rawURL = ns.substring(with: match.range(at: 1))
                let rawTitle = ns.substring(with: match.range(at: 2))
                let idx = hits.count
                let snippet = idx < snippetMatches.count ? WebSearchService.stripHTML(ns.substring(with: snippetMatches[idx].range(at: 1))) : ""
                let resolvedURL = WebSearchService.resolveDuckDuckGoRedirect(rawURL)
                let title = WebSearchService.stripHTML(rawTitle)
                if !title.isEmpty {
                    hits.append(Hit(title: title, url: resolvedURL, snippet: snippet, thumbnail: nil))
                }
            }
        }
        return hits
    }

    private func parseImageResults(_ html: String) -> [Hit] {
        var hits: [Hit] = []
        let pattern = try? NSRegularExpression(pattern: #"<img[^>]+src="([^"]+)"[^>]+alt="([^"]*)""#, options: [.caseInsensitive])
        let ns = html as NSString
        pattern?.enumerateMatches(in: html, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match = match, match.numberOfRanges >= 3 else { return }
            let src = ns.substring(with: match.range(at: 1))
            let alt = ns.substring(with: match.range(at: 2))
            hits.append(Hit(title: alt, url: src, snippet: "", thumbnail: src))
        }
        return hits
    }

    public static func stripHTML(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&#39;", with: "'")
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolveDuckDuckGoRedirect(_ raw: String) -> String {
        // DuckDuckGo HTML results use /l/?uddg=<encoded URL>
        if raw.contains("//duckduckgo.com/l/?uddg=") || raw.contains("uddg=") {
            if let comp = URLComponents(string: raw),
               let item = comp.queryItems?.first(where: { $0.name == "uddg" }),
               let value = item.value,
               let decoded = value.removingPercentEncoding,
               let url = URL(string: decoded) {
                return url.absoluteString
            }
        }
        return raw
    }
}
