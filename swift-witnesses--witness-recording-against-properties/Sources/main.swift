// MARK: - Witness Recording Against Non-Underscored Properties
//
// Purpose: Verify that the composition operators in swift-witnesses
//   (Witness.Recording, Witness.Scope, Witness.Values, Witness.Sequence,
//   Witness.Cycle) wrap a `@Witness` value whose closure storage is
//   NOT underscore-prefixed. After the recent macro change, a labeled
//   closure with non-underscored name receives a sibling labeled method
//   (no deprecation attribute on the property). Composition operators
//   must still compose transparently.
//
// Hypothesis: All five operators accept non-underscored witness storage
//   and compile. The V4 "property-wins" phenomenon from
//   witness-property-method-collision only bites on same-signature
//   method+property collisions, which none of these operators synthesize.
//
// Toolchain: Swift 6.3 release (package declares `// swift-tools-version: 6.3`).
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform: macOS 26 (arm64).
// Date: 2026-04-16.
//
// See EXPERIMENT.md for the tabulated outcome per operator.

public import Witnesses
internal import Synchronization

// ============================================================================
// MARK: - Subject: a tiny @Witness with a single non-underscored labeled closure
// ============================================================================
//
// Labeled single-closure form — for this form the (post-change) @Witness
// macro synthesizes a sibling `log(message:)` labeled method next to the
// stored `log` closure. Both call sites are supported:
//
//   logger.log("hi")              — stored closure (unlabeled)
//   logger.log(message: "hi")     — macro-synthesized labeled method

@Witness
public struct Logger: Sendable {
    public let log: @Sendable (_ message: String) -> Void
}

// ============================================================================
// MARK: - Witness.Key conformance (needed for Witness.Values / Witness.Scope)
// ============================================================================
//
// Witness.Values is a typed DI container keyed by a `Witness.Key` conformance.
// Witness.Scope executes an operation with a captured `Witness.Values`. Both
// therefore require Logger to conform to `Witness.Key` with at least a live
// default — we use a no-op for the liveValue.

extension Logger: Witness.Key {
    public static var liveValue: Logger {
        Logger(log: { _ in })
    }
}

// ============================================================================
// MARK: - V1: Witness.Recording wraps Logger
// ============================================================================
//
// Witness.Recording<Args> is a Sendable recorder. The wrapping pattern is:
// construct the Logger with a closure that calls `recording.record(args)`.
// This compiles iff the Logger's stored closure is assignable from the
// recording-capturing closure literal — a pure type-level check, independent
// of whether storage has the underscore.

func v1_recording() {
    let recording = Witness.Recording<String>()
    let logger = Logger(log: { message in
        recording.record(message)
    })

    // Drive it through both call syntaxes:
    logger.log("hello")                  // stored closure (unlabeled)
    logger.log(message: "world")         // macro-synthesized labeled method

    precondition(recording.count == 2, "V1: expected 2 recorded calls")
    precondition(recording.calls == ["hello", "world"], "V1: args mismatch")
    print("V1 Witness.Recording — OK (\(recording.count) calls)")
}

// ============================================================================
// MARK: - V2: Witness.Scope wraps a Witness.Values containing the Logger
// ============================================================================
//
// Witness.Scope is a consuming scope token. We place a custom Logger into
// a Witness.Values, construct a scope, and invoke `run { … }` on it. Inside
// the scope body we pull the Logger back from `Witness.Context.current`
// (the live context within the scope) and exercise it.

func v2_scope() {
    let tape = Mutex<[String]>([])
    let custom = Logger(log: { msg in
        tape.withLock { $0.append(msg) }
    })

    var values = Witness.Values()
    values[Logger.self] = custom

    let scope = Witness.Scope(values: values)
    scope.run {
        let l = Witness.Context.current[Logger.self]
        l.log("inside-scope")
        l.log(message: "inside-scope-labeled")
    }

    let recorded = tape.withLock { $0 }
    precondition(recorded == ["inside-scope", "inside-scope-labeled"],
                 "V2: scope did not route calls through the custom Logger")
    print("V2 Witness.Scope — OK (\(recorded.count) calls)")
}

// ============================================================================
// MARK: - V3: Witness.Values stores and retrieves Logger by key
// ============================================================================
//
// Witness.Values exposes a typed subscript keyed by the Witness.Key metatype.
// Compile-only goal: assigning a Logger into `values[Logger.self]` and reading
// it back must both type-check against the Witness.Key conformance above.

func v3_values() {
    let probe = Mutex<[String]>([])
    let custom = Logger(log: { msg in
        probe.withLock { $0.append(msg) }
    })

    var values = Witness.Values()
    values[Logger.self] = custom

    // Round-trip read from the container:
    let retrieved: Logger = values[Logger.self]
    retrieved.log("via-values")
    retrieved.log(message: "via-values-labeled")

    let recorded = probe.withLock { $0 }
    precondition(recorded == ["via-values", "via-values-labeled"],
                 "V3: values round-trip did not preserve the Logger closure")
    print("V3 Witness.Values — OK (\(recorded.count) calls)")
}

// ============================================================================
// MARK: - V4: Witness.Sequence drives the Logger's side-channel
// ============================================================================
//
// Witness.Sequence<T> returns values in order, staying on the last element
// when exhausted. Logger.log returns Void, so we demonstrate Sequence by
// having the log closure *consume* a sequenced value per call (e.g., a
// prefix the mock prepends before recording). Compile goal: Sequence's
// callAsFunction must compose inside a closure literal assigned to the
// non-underscored `log` property.

func v4_sequence() {
    let prefixes = Witness.Sequence<String>(["alpha-", "beta-", "gamma-"])
    let tape = Mutex<[String]>([])
    let logger = Logger(log: { msg in
        let p = prefixes()
        tape.withLock { $0.append(p + msg) }
    })

    logger.log("one")                  // alpha-one
    logger.log(message: "two")         // beta-two
    logger.log("three")                // gamma-three
    logger.log(message: "four")        // gamma-four (stays on last)

    let recorded = tape.withLock { $0 }
    precondition(recorded == ["alpha-one", "beta-two", "gamma-three", "gamma-four"],
                 "V4: sequence did not advance / saturate as expected")
    print("V4 Witness.Sequence — OK (\(recorded.count) calls)")
}

// ============================================================================
// MARK: - V5: Witness.Cycle drives the Logger's side-channel
// ============================================================================
//
// Witness.Cycle<T> cycles forever. Same compositional shape as V4 but with
// wrap-around semantics. Compile-only goal identical to V4.

func v5_cycle() {
    let marks = Witness.Cycle<String>(["red", "green", "blue"])
    let tape = Mutex<[String]>([])
    let logger = Logger(log: { msg in
        let m = marks()
        tape.withLock { $0.append("\(m):\(msg)") }
    })

    logger.log("0")                    // red:0
    logger.log(message: "1")           // green:1
    logger.log("2")                    // blue:2
    logger.log(message: "3")           // red:3 (wrap)

    let recorded = tape.withLock { $0 }
    precondition(recorded == ["red:0", "green:1", "blue:2", "red:3"],
                 "V5: cycle did not wrap as expected")
    print("V5 Witness.Cycle — OK (\(recorded.count) calls)")
}

// ============================================================================
// MARK: - Runner
// ============================================================================

print("== Witness Recording Against Non-Underscored Properties ==")
v1_recording()
v2_scope()
v3_values()
v4_sequence()
v5_cycle()
print("All five operators composed with non-underscored storage.")
