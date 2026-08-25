import Foundation
import os

/// Lightweight central logger that writes to OSLog and keeps an in-memory ring buffer
/// for display in the Terminal pane.
public final class Logger {
    public static let shared = Logger()

    private let osLog = OSLog(subsystem: "com.adventurecoder.app", category: "workspace")
    private let queue = DispatchQueue(label: "com.adventurecoder.logger")
    private var buffer: [LogEntry] = []
    private let maxBuffer = 5000

    public struct LogEntry: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let level: Level
        public let category: String
        public let message: String
    }

    public enum Level: String {
        case debug, info, warning, error
        public var symbol: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO "
            case .warning: return "WARN "
            case .error: return "ERROR"
            }
        }
    }

    public init() {}

    public func log(_ message: String, level: Level = .info, category: String = "app") {
        let entry = LogEntry(timestamp: Date(), level: level, category: category, message: message)
        queue.sync {
            buffer.append(entry)
            if buffer.count > maxBuffer { buffer.removeFirst(buffer.count - maxBuffer) }
        }
        let type: OSLogType
        switch level {
        case .debug: type = .debug
        case .info: type = .info
        case .warning: type = .default
        case .error: type = .error
        }
        os_log("%{public}@", log: osLog, type: type, "[\(category)] \(message)")
    }

    public func snapshot() -> [LogEntry] {
        queue.sync { buffer }
    }

    public func clear() {
        queue.sync { buffer.removeAll() }
    }
}
