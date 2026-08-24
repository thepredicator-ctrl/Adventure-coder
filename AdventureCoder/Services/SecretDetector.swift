import Foundation

/// Detects secrets that should not be committed to source control.
public struct SecretDetector {
    public struct Hit: Identifiable, Hashable {
        public let id = UUID()
        public let lineNumber: Int
        public let column: Int
        public let kind: Kind
        public let snippet: String

        public enum Kind: String {
            case awsAccessKey = "AWS Access Key"
            case awsSecret = "AWS Secret Key"
            case githubToken = "GitHub Token"
            case openAIKey = "OpenAI API Key"
            case openRouterKey = "OpenRouter API Key"
            case huggingFaceToken = "Hugging Face Token"
            case googleAPIKey = "Google API Key"
            case slackToken = "Slack Token"
            case stripeKey = "Stripe Key"
            case privateKey = "Private Key"
            case jwt = "JWT"
            case genericPassword = "Hardcoded Password"
            case connection = "Connection String"
        }
    }

    public static let patterns: [(Kind: Hit.Kind, regex: NSRegularExpression)] = {
        let raw: [(Hit.Kind, String)] = [
            (.awsAccessKey, #"AKIA[0-9A-Z]{16}"#),
            (.awsSecret, #"aws_secret_access_key\s*=\s*["'][A-Za-z0-9/+=]{40}["']"#),
            (.githubToken, #"gh[pousr]_[A-Za-z0-9]{36,}"#),
            (.githubToken, #"github_pat_[A-Za-z0-9_]{82}"#),
            (.openAIKey, #"sk-[A-Za-z0-9]{20,}"#),
            (.openRouterKey, #"sk-or-[A-Za-z0-9\-]{20,}"#),
            (.huggingFaceToken, #"hf_[A-Za-z0-9]{34,}"#),
            (.googleAPIKey, #"AIza[0-9A-Za-z\-_]{35}"#),
            (.slackToken, #"xox[baprs]-[A-Za-z0-9\-]{10,}"#),
            (.stripeKey, #"sk_live_[A-Za-z0-9]{24,}"#),
            (.stripeKey, #"sk_test_[A-Za-z0-9]{24,}"#),
            (.privateKey, #"-----BEGIN (RSA |EC |DSA |OPENSSH |)PRIVATE KEY-----"#),
            (.jwt, #"eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}"#),
            (.connection, #"(mongodb|postgres|postgresql|mysql|redis)://[^:\s]+:[^@\s]+@"#),
            (.genericPassword, #"(?i)(password|passwd|pwd)\s*[:=]\s*["'][^"']{6,}["']"#),
        ]
        return raw.compactMap { kind, pattern in
            try? (kind, NSRegularExpression(pattern: pattern, options: []))
        }.map { ($0.0, $0.1) }
    }()

    public static func scan(_ text: String) -> [Hit] {
        let lines = text.components(separatedBy: .newlines)
        var hits: [Hit] = []
        for (idx, line) in lines.enumerated() {
            let nsLine = line as NSString
            for (kind, regex) in patterns {
                let range = NSRange(location: 0, length: nsLine.length)
                regex.enumerateMatches(in: line, options: [], range: range) { match, _, _ in
                    guard let match = match else { return }
                    let col = match.range.location + 1
                    let snippet = nsLine.substring(with: match.range)
                    hits.append(Hit(lineNumber: idx + 1, column: col, kind: kind, snippet: snippet))
                }
            }
        }
        return hits
    }

    public static func containsSecrets(_ text: String) -> Bool {
        !scan(text).isEmpty
    }
}
