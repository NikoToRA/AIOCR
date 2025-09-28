import Foundation

enum AuditEvent: String, Codable {
    case appLaunch
    case cameraGranted
    case cameraDenied
    case capture
    case analyzeStart
    case analyzeSuccess
    case analyzeError
    case sessionSaved
}

struct AuditRecord: Codable {
    let timestamp: Date
    let event: AuditEvent
    let detail: String?
}

final class AuditLogger {
    static let shared = AuditLogger()
    private init() {}

    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "audit.logger.queue", qos: .utility)
    private var logURL: URL {
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("KoEReqOCR")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("audit_log.jsonl")
    }

    func log(_ event: AuditEvent, detail: String? = nil) {
        queue.async {
            let rec = AuditRecord(timestamp: Date(), event: event, detail: detail)
            let enc = JSONEncoder()
            enc.outputFormatting = [.sortedKeys]
            if let data = try? enc.encode(rec), let line = String(data: data, encoding: .utf8) {
                let withNL = (line + "\n").data(using: .utf8)!
                if let handle = try? FileHandle(forWritingTo: self.logURL) {
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: withNL)
                    try? handle.close()
                } else {
                    try? withNL.write(to: self.logURL)
                }
                #if DEBUG
                print("[Audit]", line)
                #endif
            }
        }
    }
}

