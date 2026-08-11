// MARK: - Witness .mock ~Copyable Borrowing Parameter Experiment
//
// Purpose: Determine whether the recent @Witness macro refresh (removed
//          underscore-stripping, removed deprecation attrs, aligned closure
//          storage with method generation) also fixed `.mock` synthesis for
//          `borrowing <~Copyable>` parameters.
//
// Background: `swift-foundations/swift-io/Sources/IO Core/IO.swift:92–98`
//             documents that @Witness(.mock) was intentionally disabled on
//             the IO witness because the macro's mock closure synthesis
//             cannot emit `borrowing Kernel.Descriptor` for the `read`/`write`
//             descriptor parameters — it drops the ownership annotation and
//             fails to compile with "parameter of noncopyable type
//             'Kernel.Descriptor' must specify ownership".
//
// Hypothesis: The macro still drops ownership annotations in `.mock`
//             synthesis — status REFUTED-as-expected (limitation persists).
//             If CONFIRMED unexpectedly (limitation gone), `IO.fake()`
//             becomes generator-driven instead of hand-rolled — a
//             significant ergonomic win for Shape F's testing story.
//
// Methodology: Mirror the IO witness shape with a ~Copyable token
//              (`Resource`) used as a `borrowing` parameter in a closure
//              property, decorate with @Witness(.mock), and build.
//
// Toolchain: Apple Swift 6.3
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform:  macOS 26 (arm64)
// Date:      2026-04-16

public import Witnesses

// ============================================================================
// MARK: - Shared Types
// ============================================================================

/// A non-copyable token mirroring the shape of `Kernel.Descriptor` in IO.
public struct Resource: ~Copyable, Sendable {
    public let raw: Int32
    public init(raw: Int32) { self.raw = raw }
}

public enum SomeError: Error {
    case failed
}

// ============================================================================
// MARK: - V1: @Witness(.mock) with `borrowing Resource` — core hypothesis
// Hypothesis: Mock synthesis drops ownership annotation on `borrowing`
//             parameters whose base type is ~Copyable, failing to compile.
// Expected diagnostic (if hypothesis holds):
//   "parameter of noncopyable type 'Resource' must specify ownership"
// ============================================================================

/// Witness that exactly mirrors the IO.read / IO.write / IO.close shape:
/// @Sendable async throws(E) closures with `borrowing` of a ~Copyable
/// parameter, and a `consuming` of a ~Copyable parameter for close.
@Witness(.mock)
public struct API: Sendable {
    public var read: @Sendable (
        _ from: borrowing Resource,
        _ count: Int
    ) async throws(SomeError) -> Int

    public var write: @Sendable (
        _ to: borrowing Resource,
        _ count: Int
    ) async throws(SomeError) -> Int

    // Mirrors IO.close: `(consuming Kernel.Descriptor) async -> Void`.
    // Void returns get a default `= ()` in the synthesized `mock()` signature.
    public var close: @Sendable (consuming Resource) async -> Void
}

// If the macro synthesizes `API.mock` correctly, this instantiation compiles.
// If the original hypothesis were correct, the synthesized mock closure body
// would be `{ (_, _) throws(SomeError) -> Int in read }` — no `borrowing`
// annotation — and the compiler would reject it because `_` for a ~Copyable
// parameter position requires an ownership annotation.
@main
struct Main {
    static func main() async {
        let api = API.mock(read: 42, write: 99)
        let r = Resource(raw: 3)
        do {
            let n = try await api.read(from: r, count: 10)
            print("read returned: \(n)")
            let m = try await api.write(to: r, count: 20)
            print("write returned: \(m)")
            await api.close(consume r)
            print("close returned")
        } catch {
            print("error: \(error)")
        }
    }
}
