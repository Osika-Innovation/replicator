import Foundation

/// A zero-dependency test harness.
///
/// XCTest ships with Xcode, and this machine has Command Line Tools only, so
/// `swift test` cannot build (`no such module 'XCTest'`). Rather than take a
/// dependency or require a 10 GB Xcode install to run the suite, the harness is
/// ~60 lines and lives in the product. Consequence: `fieldc test` works
/// anywhere Swift does, including CI containers with no developer tools.
public final class TestHarness {
    public struct Failure: Sendable { public let test: String; public let message: String }

    public private(set) var passed = 0
    public private(set) var failures: [Failure] = []
    private var current = ""

    public init() {}

    public func test(_ name: String, _ body: (TestHarness) throws -> Void) {
        current = name
        let before = failures.count
        do { try body(self) } catch { fail("threw \(error)") }
        if failures.count == before { passed += 1 }
    }

    public func fail(_ message: String) {
        failures.append(Failure(test: current, message: message))
    }

    public func check(_ cond: Bool, _ message: @autoclosure () -> String) {
        if !cond { fail(message()) }
    }

    public func near(_ a: Double, _ b: Double, _ tol: Double,
                     _ what: @autoclosure () -> String = "") {
        if !(abs(a - b) <= tol) || a.isNaN || b.isNaN {
            fail("\(what()) expected \(b) +/- \(tol), got \(a)")
        }
    }

    public var summary: String {
        var out = ["\(passed) passed, \(failures.count) failed"]
        for f in failures { out.append("  FAIL  \(f.test): \(f.message)") }
        return out.joined(separator: "\n")
    }

    public var allPassed: Bool { failures.isEmpty }
}
