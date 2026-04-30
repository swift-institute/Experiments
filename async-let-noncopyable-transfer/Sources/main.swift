// MARK: - async let ~Copyable Transfer Without Ownership.Transfer.Cell
// Purpose: Can async let pass ~Copyable values via consuming parameters
//   to a function, eliminating the need for Ownership.Transfer.Cell?
// Hypothesis: async let evaluates its expression in a child task. If the
//   expression is a function call with consuming parameters, the ~Copyable
//   value should be consumed into the call without closure capture.
//
// Toolchain: Xcode 26.0 beta / Swift 6.3
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — all variants produce:
//   "noncopyable 'x' cannot be consumed when captured by an escaping
//   closure or borrowed by a non-Escapable type"
//   async let ALWAYS creates an escaping closure internally. All
//   referenced locals are captures, even when passed as function
//   arguments. Transfer.Cell remains the only mechanism for moving
//   ~Copyable values into async let child tasks in Swift 6.3.
//
// Date: 2026-04-06

// MARK: - Setup

struct Resource: ~Copyable, Sendable {
    let id: Int
    consuming func use() -> String { "used-\(id)" }
}

// MARK: - V1: Direct capture (known failure)
// Result: REFUTED — compile error (expected)
#if false
func v1_directCapture() async {
    let r = Resource(id: 1)
    async let result = r.use()
    print(await result)
}
#endif

// MARK: - V2: Function call with consuming parameter
// Hypothesis: Consuming into a function call avoids capture.
// Result: REFUTED — same error. async let captures r before the call.
#if false
func processResource(_ r: consuming Resource) async -> String {
    r.use()
}
func v2_functionCall() async {
    let r = Resource(id: 2)
    async let result = processResource(r)  // error: noncopyable captured
    print("V2:", await result)
}
#endif

// MARK: - V3: consuming sending parameter
// Hypothesis: Adding sending enables cross-isolation transfer.
// Result: REFUTED — same error. sending doesn't help with capture.
#if false
func processResourceSending(_ r: consuming sending Resource) async -> String {
    r.use()
}
func v3_consumingSending() async {
    let r = Resource(id: 3)
    async let result = processResourceSending(r)  // error: noncopyable captured
    print("V3:", await result)
}
#endif

// MARK: - V4: Forwarding wrapper function
// Hypothesis: Wrapper function with consuming takes ownership before async let.
// Result: REFUTED — the wrapper's consuming param is still captured by async let.
#if false
func runOnChildTask<R: Sendable>(
    _ resource: consuming Resource,
    _ body: @Sendable (consuming Resource) async -> R
) async -> R {
    await body(resource)
}
func v4_wrapper() async {
    let r = Resource(id: 4)
    async let result = runOnChildTask(r) { resource in  // error: noncopyable captured
        resource.use()
    }
    print("V4:", await result)
}
#endif

// MARK: - V5: Full callAsFunction pattern
// Hypothesis: Replicate IO.Stream.callAsFunction without Transfer.Cell.
// Result: REFUTED — writer cannot be consumed in async let expression.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
#if false
struct Writer: ~Copyable, Sendable {
    let id: Int
    consuming func write(_ data: String) -> String { "wrote-\(data)-on-\(id)" }
}
func runWriter(
    _ writer: consuming Writer,
    _ body: @Sendable (consuming Writer) async throws -> Void
) async -> Result<Void, any Error> {
    do { try await body(writer); return .success(()) }
    catch { return .failure(error) }
}
func v5_fullPattern() async {
    let writer = Writer(id: 5)
    async let writeResult = runWriter(writer) { w in  // error: noncopyable captured
        _ = w.write("hello")
    }
    _ = await writeResult
}
#endif

// MARK: - Conclusion
//
// async let in Swift 6.3 ALWAYS creates an escaping closure. Every
// local variable referenced in the async let expression becomes a
// closure capture. ~Copyable values cannot be captured by escaping
// closures — period.
//
// Transfer.Cell is the CORRECT solution for this. It wraps the
// ~Copyable value in an ARC-managed box and provides a Sendable
// token that CAN be captured. This is not a workaround — it's the
// designed mechanism for this pattern until Swift gains a
// ~Copyable-aware async let (e.g., consuming async let).
//
// The IO.Run.callAsFunction(resource, body) pattern we built
// works because it uses regular function parameters (consuming D),
// not async let. The concurrent callAsFunction on IO.Stream uses
// async let and MUST use Transfer.Cell.

print("All variants REFUTED — see comments for details")
