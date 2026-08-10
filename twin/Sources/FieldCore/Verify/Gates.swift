import Foundation

/// A numeric acceptance gate result (§22). Every gate reports its measured
/// value, its threshold, and a verdict — never a bare pass/fail, because the
/// number is what a receipt quotes.
public struct GateResult: Sendable, Codable {
    public var id: String
    public var name: String
    public var measured: Double
    public var threshold: Double
    public var comparison: Comparison
    public var passed: Bool
    public var detail: String

    public enum Comparison: String, Sendable, Codable {
        case lessThan = "<"
        case greaterThan = ">"
        case informational = "info"   // G14-style: reports numbers, no bar
    }

    public init(id: String, name: String, measured: Double, threshold: Double,
                comparison: Comparison = .lessThan, detail: String = "") {
        self.id = id; self.name = name
        self.measured = measured; self.threshold = threshold
        self.comparison = comparison
        switch comparison {
        case .lessThan:       self.passed = measured < threshold
        case .greaterThan:    self.passed = measured > threshold
        case .informational:  self.passed = true
        }
        self.detail = detail
    }

    public var line: String {
        let mark = comparison == .informational ? "[info]" : (passed ? "[PASS]" : "[FAIL]")
        let bar = comparison == .informational
            ? "" : "  (bar \(comparison.rawValue) \(fmt(threshold)))"
        return "\(mark) \(id)  \(name): \(fmt(measured))\(bar)\(detail.isEmpty ? "" : "  — \(detail)")"
    }

    private func fmt(_ v: Double) -> String {
        if v == 0 { return "0" }
        let a = abs(v)
        if a < 1e-3 || a >= 1e5 { return String(format: "%.4g", v) }
        return String(format: "%.5f", v)
    }
}

/// A run's receipt (§20 law L4): every run writes one, and claims quote it.
public struct Receipt: Sendable, Codable {
    public var name: String
    public var date: String
    public var device: String
    public var gitSHA: String
    public var configHash: String
    public var durationSeconds: Double
    public var gates: [GateResult]

    public var allPassed: Bool { gates.allSatisfy(\.passed) }

    public init(name: String, gates: [GateResult], durationSeconds: Double,
                device: String = "unknown", gitSHA: String = "unknown",
                configHash: String = "") {
        self.name = name
        self.date = ISO8601DateFormatter().string(from: Date())
        self.device = device
        self.gitSHA = gitSHA
        self.configHash = configHash
        self.durationSeconds = durationSeconds
        self.gates = gates
    }

    public func json() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(self)
    }

    public var summary: String {
        var out = ["receipt: \(name)  (\(date))", "device: \(device)  git: \(gitSHA)"]
        out.append(contentsOf: gates.map { "  " + $0.line })
        let failed = gates.filter { !$0.passed }
        out.append(failed.isEmpty
            ? "  => all \(gates.count) gates passed"
            : "  => \(failed.count)/\(gates.count) FAILED: \(failed.map(\.id).joined(separator: ", "))")
        return out.joined(separator: "\n")
    }
}
