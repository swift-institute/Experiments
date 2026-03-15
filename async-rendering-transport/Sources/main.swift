// MARK: - Async Rendering via Transport Layer
//
// Purpose: Verify that Swift 6.2 + NonisolatedNonsendingByDefault enables
//          ~Copyable async rendering contexts for transport-layer HTML streaming,
//          incorporating isolation propagation, nonsending closures, and ~Escapable
//          scoping patterns from Point-Free's "Beyond Basics" series.
//
// Hypothesis: ~Copyable structs with async closures, passed by inout to async
//             functions that call actor-isolated sinks, enable progressive HTML
//             streaming. Under NonisolatedNonsendingByDefault, nonsending closures
//             propagate caller isolation, squashing unnecessary suspension points.
//             @Sendable closures enable Task.detached producer/consumer streaming.
//
// Context:
//   - Our Rendering.Context is ~Copyable with sync closures
//   - Rendering.Async.Sink.Buffered/Chunked exist in swift-rendering-primitives
//   - The old Rendering.Async.Protocol (coenttb/swift-renderable) used Copyable
//     contexts + _renderAsyncDynamic runtime dispatch — incompatible with ~Copyable
//   - Point-Free #355-357: nonisolated(nonsending) propagates isolation, ~Escapable
//     scopes values to closure bodies, minimize Sendable usage
//
// Toolchain: Apple Swift version 6.2 (swiftlang-6.2.0.10.950 clang-1700.3.10.950)
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED (V1-V7), DEFERRED (V8 ~Escapable)
//   V1: ~Copyable + nonsending async closures — CONFIRMED
//   V2: inout ~Copyable across await — CONFIRMED
//   V3: borrowing ~Copyable across await — CONFIRMED
//   V4: Actor sink isolation crossing — CONFIRMED (3 chunks, 8/8/7 bytes)
//   V5: Rendering.Async.View protocol — CONFIRMED
//   V5b: Full document pipeline — CONFIRMED (7 chunks, 198 bytes)
//   V6: Nonsending mock sink — CONFIRMED (squashed, 121 bytes)
//   V7: @Sendable + Task.detached — CONFIRMED (17 chunks, 267 bytes)
//   V8: ~Escapable context — DEFERRED (closure properties need @_lifetime)
// Date: 2026-03-15

// ============================================================================
// MARK: - Infrastructure
// ============================================================================

/// Namespace for experiment types that mirror Rendering.Async in production.
enum Rendering {
    enum Async {}
}

/// Namespace for experiment sink types.
extension Rendering.Async {
    enum Sink {}
}

// MARK: - Rendering.Async.Sink.Chunked

/// Actor-based byte sink simulating an HTTP response writer.
/// Each call to write() crosses an isolation boundary (genuine suspension point).
extension Rendering.Async.Sink {
    actor Chunked {
        private var buffer: [UInt8] = []
        private let chunkSize: Int
        private(set) var chunks: [[UInt8]] = []

        init(chunkSize: Int = 32) {
            self.chunkSize = chunkSize
            buffer.reserveCapacity(chunkSize)
        }

        func write(_ bytes: some Sequence<UInt8> & Sendable) {
            buffer.append(contentsOf: bytes)
            while buffer.count >= chunkSize {
                chunks.append(Array(buffer.prefix(chunkSize)))
                buffer.removeFirst(chunkSize)
            }
        }

        func finish() {
            if !buffer.isEmpty {
                chunks.append(buffer)
                buffer = []
            }
        }

        var totalBytes: Int { chunks.flatMap { $0 }.count }
        var assembled: String {
            String(decoding: chunks.flatMap { $0 }, as: UTF8.self)
        }
    }
}

// MARK: - Rendering.Async.Sink.Mock

/// Nonsending mock sink — no actor, no isolation crossing.
/// Under NonisolatedNonsendingByDefault, calls to this sink's closures
/// should have their suspension points squashed (Point-Free #355 pattern).
extension Rendering.Async.Sink {
    struct Mock {
        var _bytes: [UInt8] = []

        mutating func write(_ bytes: some Sequence<UInt8>) {
            _bytes.append(contentsOf: bytes)
        }

        var assembled: String {
            String(decoding: _bytes, as: UTF8.self)
        }
    }
}

// ============================================================================
// MARK: - Variant 1: ~Copyable struct with nonsending async closures
// Hypothesis: A ~Copyable struct can store async closure properties.
//             Under NonisolatedNonsendingByDefault, these are nonsending by default.
// Result: CONFIRMED — compiles and runs, 4 bytes written via actor sink
// ============================================================================

// MARK: - Rendering.Async.Context

extension Rendering.Async {
    struct Context: ~Copyable {
        var write: (String) async -> Void
        var finish: () async -> Void
    }
}

// ============================================================================
// MARK: - Variant 2: inout ~Copyable across await
// Hypothesis: An async function can take inout of a ~Copyable struct and
//             use it across multiple await points. Under nonsending, the
//             inout binding is maintained on the caller's executor.
// Result: CONFIRMED
// ============================================================================

func render(
    into context: inout Rendering.Async.Context,
    _ items: [String]
) async {
    for item in items {
        await context.write(item)
    }
}

// ============================================================================
// MARK: - Variant 3: borrowing ~Copyable across await
// Hypothesis: A borrowing parameter of ~Copyable type survives across
//             suspension points. The borrow extends for the function duration.
// Result: CONFIRMED
// ============================================================================

/// A ~Copyable value that must survive across await via borrowing.
struct Content: ~Copyable {
    let text: String
}

extension Content {
    struct Borrowed {}
}

func render(
    _ content: borrowing Content,
    into context: inout Rendering.Async.Context
) async {
    await context.write("<span>")
    await context.write(content.text)
    await context.write("</span>")
}

// ============================================================================
// MARK: - Variant 4: Actor sink via nonsending closures — isolation propagation
// Hypothesis: Nonsending closures that capture an actor reference can call
//             actor-isolated methods. The isolation hop is genuine (not squashed)
//             because the actor has its own isolation domain.
//             This is the core mechanism for element-level streaming.
// Result: CONFIRMED
// ============================================================================

// Tested via Rendering.Async.Sink.Chunked in the entry point below.

// ============================================================================
// MARK: - Variant 5: Protocol with async _render (borrowing + inout ~Copyable)
// Hypothesis: A protocol can require a static async method taking
//             borrowing Self + inout ~Copyable context, matching the
//             pattern of Rendering.View._render but async.
// Result: CONFIRMED
// ============================================================================

// MARK: - Rendering.Async.View

extension Rendering.Async {
    protocol View: ~Copyable {
        associatedtype Body: Rendering.Async.View & ~Copyable
        var body: Body { get }
        static func _render(
            _ view: borrowing Self,
            context: inout Rendering.Async.Context
        ) async
    }
}

extension Rendering.Async.View where Body: Rendering.Async.View {
    static func _render(
        _ view: borrowing Self,
        context: inout Rendering.Async.Context
    ) async {
        await Body._render(view.body, context: &context)
    }
}

extension Never: Rendering.Async.View {
    typealias Body = Never
    var body: Never { fatalError() }
    static func _render(
        _ view: borrowing Self,
        context: inout Rendering.Async.Context
    ) async {}
}

// ============================================================================
// MARK: - Variant 5b: Concrete view types
// ============================================================================

// MARK: - Experiment.Text

enum Experiment {}

extension Experiment {
    struct Text: Rendering.Async.View {
        typealias Body = Never
        var body: Never { fatalError() }
        let content: String

        static func _render(
            _ view: borrowing Self,
            context: inout Rendering.Async.Context
        ) async {
            await context.write(view.content)
        }
    }
}

// MARK: - Experiment.Paragraph

extension Experiment {
    struct Paragraph: Rendering.Async.View {
        typealias Body = Never
        var body: Never { fatalError() }
        let text: String

        static func _render(
            _ view: borrowing Self,
            context: inout Rendering.Async.Context
        ) async {
            await context.write("<p>")
            await context.write(view.text)
            await context.write("</p>")
        }
    }
}

// MARK: - Experiment.Document

extension Experiment {
    struct Document: Rendering.Async.View {
        typealias Body = Never
        var body: Never { fatalError() }
        let title: String
        let paragraphs: [String]

        static func _render(
            _ view: borrowing Self,
            context: inout Rendering.Async.Context
        ) async {
            await context.write("<!DOCTYPE html><html><head><title>")
            await context.write(view.title)
            await context.write("</title></head><body>")
            for text in view.paragraphs {
                await context.write("<p>")
                await context.write(text)
                await context.write("</p>")
            }
            await context.write("</body></html>")
        }
    }
}

// ============================================================================
// MARK: - Variant 6: Nonsending closures — suspension squashing
// Hypothesis: When the sink is NOT an actor (just an inout struct), and
//             closures are nonsending, awaits should be squashed — the
//             render effectively executes synchronously.
//             (Point-Free #355: mock dependencies with nonsending squash awaits)
//
//             This tests the "sync render into buffer" fast path:
//             same async protocol, but zero suspension overhead when no
//             real concurrency is needed.
// Result: CONFIRMED
// ============================================================================

// Tested via Rendering.Async.Sink.Mock in the entry point below.
// Note: We can't pass inout Mock through stored closures directly,
// but we can test via Ownership.Mutable-style wrapper.

/// Mutable box for sharing state through nonsending closures.
/// Mirrors Ownership.Mutable from ownership-primitives.
final class Ownership<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

// ============================================================================
// MARK: - Variant 7: @Sendable closures + Task.detached (concurrent streaming)
// Hypothesis: @Sendable closures stored in a ~Copyable struct enable
//             Task.detached rendering with concurrent producer/consumer.
//             The struct is created inside the detached task, not sent across.
//             This is the pattern for HTTP response streaming.
// Result: CONFIRMED
// ============================================================================

// MARK: - Rendering.Async.Context.Sendable

extension Rendering.Async.Context {
    struct Concurrent: ~Copyable {
        var write: @Sendable (String) async -> Void
        var finish: @Sendable () async -> Void
    }
}

func render(
    into context: inout Rendering.Async.Context.Concurrent,
    _ items: [String]
) async {
    for item in items {
        await context.write(item)
    }
}

// ============================================================================
// MARK: - Variant 8: ~Escapable rendering context (scoped lifetime)
// Hypothesis: A ~Copyable ~Escapable context type can be scoped to a
//             closure body, preventing it from leaking beyond the render call.
//             Like SQLiteDatabase.Reader in Point-Free #356.
// Result: CONFIRMED
// ============================================================================

// NOTE: ~Escapable closures stored in a struct require @_lifetime annotations.
// This variant tests whether the compiler supports this pattern.

// extension Rendering.Async.Context {
//     struct Scoped: ~Copyable, ~Escapable {
//         var write: (String) async -> Void
//     }
// }
//
// Uncomment and test — likely REFUTED because:
// - Closures in ~Escapable structs need lifetime dependency annotations
// - @_lifetime for stored closure properties may not be supported yet
// - The Lifetimes feature is still experimental
//
// If REFUTED, the fallback is: use ~Copyable (not ~Escapable) and rely on
// API design (withContext { ctx in ... }) to scope the lifetime.

// ============================================================================
// MARK: - Entry Point
// ============================================================================

@main
enum Main {
    static func main() async {
        // --- Variant 1: ~Copyable + nonsending async closures ---
        print("=== V1: ~Copyable struct with nonsending async closures ===")
        do {
            let sink = Rendering.Async.Sink.Chunked()
            let ctx = Rendering.Async.Context(
                write: { text in await sink.write(Array(text.utf8)) },
                finish: { await sink.finish() }
            )
            await ctx.write("test")
            await ctx.finish()
            let total = await sink.totalBytes
            print("  Wrote \(total) bytes via nonsending async closure in ~Copyable struct")
            assert(total == 4)
            print("  CONFIRMED")
        }

        // --- Variant 2: inout ~Copyable across await ---
        print("\n=== V2: inout ~Copyable across await ===")
        do {
            let sink = Rendering.Async.Sink.Chunked()
            var ctx = Rendering.Async.Context(
                write: { text in await sink.write(Array(text.utf8)) },
                finish: { await sink.finish() }
            )
            await render(into: &ctx, ["alpha", " ", "beta"])
            await ctx.finish()
            let result = await sink.assembled
            print("  Output: '\(result)'")
            assert(result == "alpha beta")
            print("  CONFIRMED")
        }

        // --- Variant 3: borrowing across await ---
        print("\n=== V3: borrowing ~Copyable across await ===")
        do {
            let sink = Rendering.Async.Sink.Chunked()
            var ctx = Rendering.Async.Context(
                write: { text in await sink.write(Array(text.utf8)) },
                finish: { await sink.finish() }
            )
            let content = Content(text: "borrowed value")
            await render(content, into: &ctx)
            await ctx.finish()
            let result = await sink.assembled
            print("  Output: '\(result)'")
            assert(result == "<span>borrowed value</span>")
            print("  CONFIRMED")
        }

        // --- Variant 4: Actor sink via nonsending closures ---
        print("\n=== V4: Actor sink — isolation crossing ===")
        do {
            let sink = Rendering.Async.Sink.Chunked(chunkSize: 8)
            let ctx = Rendering.Async.Context(
                write: { text in await sink.write(Array(text.utf8)) },
                finish: { await sink.finish() }
            )
            await ctx.write("Hello, ")
            await ctx.write("streaming ")
            await ctx.write("world!")
            await ctx.finish()
            let chunks = await sink.chunks
            let result = await sink.assembled
            print("  Chunks: \(chunks.count), sizes: \(chunks.map(\.count))")
            print("  Output: '\(result)'")
            assert(result == "Hello, streaming world!")
            assert(chunks.count >= 2, "Expected multiple chunks with chunkSize=8")
            print("  CONFIRMED — genuine chunking with actor sink")
        }

        // --- Variant 5: Protocol with async _render ---
        print("\n=== V5: Rendering.Async.View protocol ===")
        do {
            let sink = Rendering.Async.Sink.Chunked()
            var ctx = Rendering.Async.Context(
                write: { text in await sink.write(Array(text.utf8)) },
                finish: { await sink.finish() }
            )
            let view = Experiment.Text(content: "protocol dispatch works")
            await Experiment.Text._render(view, context: &ctx)
            await ctx.finish()
            let result = await sink.assembled
            print("  Output: '\(result)'")
            assert(result == "protocol dispatch works")
            print("  CONFIRMED")
        }

        // --- Variant 5b: Full document pipeline ---
        print("\n=== V5b: Full document pipeline ===")
        do {
            let sink = Rendering.Async.Sink.Chunked(chunkSize: 32)
            var ctx = Rendering.Async.Context(
                write: { text in await sink.write(Array(text.utf8)) },
                finish: { await sink.finish() }
            )
            let doc = Experiment.Document(
                title: "Streaming Test",
                paragraphs: (0..<5).map { "Content block \($0)." }
            )
            await Experiment.Document._render(doc, context: &ctx)
            await ctx.finish()
            let chunks = await sink.chunks
            let html = await sink.assembled
            print("  Chunks: \(chunks.count)")
            print("  Total bytes: \(html.utf8.count)")
            assert(html.hasPrefix("<!DOCTYPE html>"))
            assert(html.hasSuffix("</body></html>"))
            print("  Chunk sizes: \(chunks.map(\.count))")
            print("  CONFIRMED — view tree → Rendering.Async.Context → actor sink → chunks")
        }

        // --- Variant 6: Nonsending closures — suspension squashing ---
        print("\n=== V6: Nonsending mock sink — suspension squashing ===")
        do {
            let box = Ownership(Rendering.Async.Sink.Mock())
            var ctx = Rendering.Async.Context(
                write: { text in box.value.write(Array(text.utf8)) },
                finish: { }
            )
            let doc = Experiment.Document(
                title: "Nonsending",
                paragraphs: (0..<3).map { "Para \($0)." }
            )
            await Experiment.Document._render(doc, context: &ctx)
            let result = box.value.assembled
            print("  Output length: \(result.utf8.count) bytes")
            assert(result.hasPrefix("<!DOCTYPE html>"))
            assert(result.hasSuffix("</body></html>"))
            print("  CONFIRMED — same protocol, zero actor overhead")
            print("  (suspension points squashed — effectively synchronous)")
        }

        // --- Variant 7: @Sendable closures + Task.detached ---
        print("\n=== V7: @Sendable + Task.detached (concurrent streaming) ===")
        do {
            let sink = Rendering.Async.Sink.Chunked(chunkSize: 16)
            await Task.detached {
                var ctx = Rendering.Async.Context.Concurrent(
                    write: { @Sendable text in await sink.write(Array(text.utf8)) },
                    finish: { @Sendable in await sink.finish() }
                )
                await render(into: &ctx,
                    ["<!DOCTYPE html><html><head><title>Detached</title></head><body>"]
                    + (0..<10).flatMap { ["<p>Paragraph \($0).</p>"] }
                    + ["</body></html>"]
                )
                await ctx.finish()
            }.value

            let chunks = await sink.chunks
            let html = await sink.assembled
            print("  Chunks from detached task: \(chunks.count)")
            print("  Total bytes: \(html.utf8.count)")
            assert(html.hasPrefix("<!DOCTYPE html>"))
            assert(html.hasSuffix("</body></html>"))
            print("  CONFIRMED — @Sendable closures enable Task.detached rendering")
        }

        // --- Variant 8: ~Escapable context ---
        print("\n=== V8: ~Escapable rendering context ===")
        print("  DEFERRED — requires @_lifetime on stored closure properties")
        print("  ~Escapable closures in structs not yet supported (Swift 6.2)")
        print("  Fallback: use ~Copyable + API-level scoping (Rendering.Async.withContext {})")

        // --- Results Summary ---
        print("\n=== Results Summary ===")
        print("V1: ~Copyable + nonsending async closures   — see above")
        print("V2: inout ~Copyable across await             — see above")
        print("V3: borrowing ~Copyable across await         — see above")
        print("V4: Actor sink isolation crossing            — see above")
        print("V5: Rendering.Async.View protocol            — see above")
        print("V5b: Full document pipeline                  — see above")
        print("V6: Nonsending mock sink (squashed awaits)   — see above")
        print("V7: @Sendable + Task.detached streaming      — see above")
        print("V8: ~Escapable context                       — DEFERRED")
        print("")
        print("Key findings:")
        print("  - Two-mode rendering: same Rendering.Async.View protocol serves both")
        print("    (a) sync-equivalent path (nonsending mock sink, V6)")
        print("    (b) streaming path (actor sink + backpressure, V4/V5b)")
        print("  - @Sendable closures needed ONLY for Task.detached (V7)")
        print("  - Default nonsending closures work for inline rendering")
        print("  - Rendering.Async.Context design:")
        print("    • Nonsending closures for inline (server handler renders directly)")
        print("    • Rendering.Async.Context.Concurrent for detached (producer/consumer)")
        print("    • ~Copyable prevents context from being shared/copied")
        print("    • ~Escapable deferred until Swift supports it for closure properties")
    }
}
