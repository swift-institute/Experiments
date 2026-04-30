// MARK: - Typed Throws Protocol Conformance Verification
// Purpose: Verify whether Swift 6.2.4 allows typed throws on protocol
//          conformances when the protocol requirement uses untyped throws.
//          Covers Codable (Encodable/Decodable) and Clock protocols.
//
// Hypothesis: Protocol conformances CANNOT narrow `throws` to `throws(E)`
//             when the protocol requirement uses untyped `throws`. The compiler
//             will reject the conformance because the signature doesn't match.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.0 (arm64)
//
// stdlib source verification (swiftlang/swift):
//   Encodable.encode(to:)         — `throws`       (Codable.swift:28)
//   Decodable.init(from:)         — `throws`       (Codable.swift:39)
//   Clock.sleep(until:tolerance:) — `async throws`  (Clock.swift:42)
//   Encoder container methods     — `throws`       (Codable.swift:257+)
//   Decoder container methods     — `throws`       (Codable.swift:1126+)
//   Task.checkCancellation()      — `throws`       (TaskCancellation.swift:270)
//   Task.sleep(nanoseconds:)      — `async throws` (TaskSleep.swift:240)
//
// Result: HYPOTHESIS REFUTED — narrowing IS supported (throws covariance)
//         but BLOCKED by downstream untyped throws in Encoder/Decoder/Task APIs.
//         do/catch wrapping makes conversion POSSIBLE but with tradeoffs.
// Date: 2026-03-05

// ============================================================================
// MARK: - Variant 1: Encodable with throws(EncodingError) — direct use
// Hypothesis: Conforming to Encodable with throws(EncodingError) is rejected
// Result: REFUTED — conformance signature IS accepted, but body fails because
//         Encoder container methods (encode(_:forKey:), singleValueContainer())
//         use untyped `throws`, so `try container.encode(value)` produces
//         `any Error` which cannot be caught as `EncodingError`.
//
// Diagnostic: "thrown expression type 'any Error' cannot be converted to
//              error type 'EncodingError'"
// Command: swiftc -typecheck /tmp/v1_test.swift
// ============================================================================

#if false // FAILS — downstream untyped throws
struct V1: Encodable {
    let value: Int
    func encode(to encoder: any Encoder) throws(EncodingError) {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
#endif

// ============================================================================
// MARK: - Variant 1a: Encodable with throws(EncodingError) — empty body
// Hypothesis: The conformance signature itself compiles (no downstream calls)
// Result: CONFIRMED — conformance narrowing is accepted by the compiler
//
// Evidence: Build Succeeded (swiftc -typecheck)
// ============================================================================

struct V1a: Encodable {
    let value: Int
    func encode(to encoder: any Encoder) throws(EncodingError) {
        // Empty body — no try calls. Conformance compiles.
    }
}

// ============================================================================
// MARK: - Variant 1b: Encodable with throws(EncodingError) — do/catch wrapping
// Hypothesis: Wrapping Encoder calls in do/catch to narrow error type works
// Result: CONFIRMED — compiles with do/catch + preconditionFailure catch-all
//
// Evidence: Build Succeeded (swiftc -typecheck)
// ============================================================================

struct V1b: Encodable {
    let value: Int
    func encode(to encoder: any Encoder) throws(EncodingError) {
        do {
            var container = encoder.singleValueContainer()
            try container.encode(value)
        } catch let error as EncodingError {
            throw error
        } catch {
            // All stdlib Encoder implementations throw EncodingError exclusively.
            // Custom Encoder implementations SHOULD also throw EncodingError per
            // Apple's documentation. If they don't, this is a contract violation.
            preconditionFailure(
                "Encoder contract violation: non-EncodingError thrown: \(type(of: error))"
            )
        }
    }
}

// ============================================================================
// MARK: - Variant 2: Decodable with throws(DecodingError) — direct use
// Hypothesis: Conforming to Decodable with throws(DecodingError) is rejected
// Result: REFUTED — same as V1: conformance accepted, body fails on downstream
//         untyped throws from Decoder container methods.
//
// Diagnostic: "thrown expression type 'any Error' cannot be converted to
//              error type 'DecodingError'"
// Command: swiftc -typecheck /tmp/v2_test.swift
// ============================================================================

#if false // FAILS — downstream untyped throws
struct V2: Decodable {
    let value: Int
    init(from decoder: any Decoder) throws(DecodingError) {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(Int.self)
    }
}
#endif

// ============================================================================
// MARK: - Variant 2a: Decodable with throws(DecodingError) — empty body
// Hypothesis: The conformance signature itself compiles
// Result: CONFIRMED — conformance narrowing is accepted
//
// Evidence: Build Succeeded (swiftc -typecheck)
// ============================================================================

struct V2a: Decodable {
    let value: Int
    init(from decoder: any Decoder) throws(DecodingError) {
        self.value = 42
    }
}

// ============================================================================
// MARK: - Variant 2b: Decodable with throws(DecodingError) — do/catch wrapping
// Hypothesis: Wrapping Decoder calls in do/catch to narrow error type works
// Result: CONFIRMED — compiles with do/catch + preconditionFailure catch-all
//
// Evidence: Build Succeeded (swiftc -typecheck)
// ============================================================================

struct V2b: Decodable {
    let value: Int
    init(from decoder: any Decoder) throws(DecodingError) {
        do {
            let container = try decoder.singleValueContainer()
            self.value = try container.decode(Int.self)
        } catch let error as DecodingError {
            throw error
        } catch {
            preconditionFailure(
                "Decoder contract violation: non-DecodingError thrown: \(type(of: error))"
            )
        }
    }
}

// ============================================================================
// MARK: - Variant 3: Clock with throws(CancellationError) — direct use
// Hypothesis: Clock conformance with typed throws is rejected
// Result: REFUTED — conformance accepted, body fails because
//         Task.checkCancellation() and Task.sleep() use untyped throws.
//
// Diagnostic: "thrown expression type 'any Error' cannot be converted to
//              error type 'CancellationError'"
// Command: swiftc -typecheck /tmp/v3_test.swift
// ============================================================================

#if false // FAILS — downstream untyped throws
struct V3Clock: Clock {
    struct Instant: InstantProtocol {
        var offset: Duration
        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static var zero: Instant { Instant(offset: .zero) }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
        typealias Duration = Swift.Duration
    }
    var now: Instant { Instant(offset: .zero) }
    var minimumResolution: Instant.Duration { .nanoseconds(1) }

    func sleep(until deadline: Instant, tolerance: Instant.Duration?) async throws(CancellationError) {
        try await Task.sleep(for: deadline.offset)
    }
}
#endif

// ============================================================================
// MARK: - Variant 3a: Clock with throws(CancellationError) — empty body
// Hypothesis: The conformance signature itself compiles
// Result: CONFIRMED — conformance narrowing is accepted
//
// Evidence: Build Succeeded (swiftc -typecheck)
// ============================================================================

struct V3aClock: Clock {
    struct Instant: InstantProtocol {
        var offset: Duration
        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static var zero: Instant { Instant(offset: .zero) }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
        typealias Duration = Swift.Duration
    }
    var now: Instant { Instant(offset: .zero) }
    var minimumResolution: Instant.Duration { .nanoseconds(1) }

    func sleep(until deadline: Instant, tolerance: Instant.Duration?) async throws(CancellationError) {
        // Empty — conformance compiles
    }
}

// ============================================================================
// MARK: - Variant 3b: Clock with throws(CancellationError) — do/catch wrapping
// Hypothesis: Wrapping Task.sleep in do/catch to narrow error type works
// Result: CONFIRMED — compiles with do/catch + preconditionFailure catch-all
//
// Evidence: Build Succeeded (swiftc -typecheck)
// ============================================================================

struct V3bClock: Clock {
    struct Instant: InstantProtocol {
        var offset: Duration
        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static var zero: Instant { Instant(offset: .zero) }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
        typealias Duration = Swift.Duration
    }
    var now: Instant { Instant(offset: .zero) }
    var minimumResolution: Instant.Duration { .nanoseconds(1) }

    func sleep(until deadline: Instant, tolerance: Instant.Duration?) async throws(CancellationError) {
        do {
            try await Task.sleep(for: deadline.offset)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Task.sleep only throws CancellationError per stdlib docs
            preconditionFailure(
                "Task.sleep contract violation: non-CancellationError thrown: \(type(of: error))"
            )
        }
    }
}

// ============================================================================
// MARK: - Variant 4: Encodable with nonthrowing (baseline — covariance)
// Hypothesis: Non-throwing function satisfies `throws` requirement (covariance)
// Result: CONFIRMED — nonthrowing < throws(E) < throws
//
// Evidence: Build Succeeded
// ============================================================================

struct V4: Encodable {
    let value: Int
    func encode(to encoder: any Encoder) {
        // Non-throwing satisfies `throws` — this is covariance
    }
}

// ============================================================================
// MARK: - Variant 5a: Custom protocol with untyped throws — conformer narrows
// Hypothesis: Conformer CANNOT narrow throws to throws(E)
// Result: REFUTED — conformer CAN narrow. Swift supports throws covariance
//         on protocol conformances: nonthrowing < throws(E) < throws
//
// Evidence: Build Succeeded (swiftc -typecheck)
// ============================================================================

protocol MyProtocol {
    func doWork() throws
}

enum WorkError: Error { case failed }

struct V5a: MyProtocol {
    func doWork() throws(WorkError) { }
}

// ============================================================================
// MARK: - Variant 5b: Custom protocol — non-throwing conformance (baseline)
// Hypothesis: Non-throwing conformance is accepted (known covariance)
// Result: CONFIRMED
//
// Evidence: Build Succeeded
// ============================================================================

struct V5b: MyProtocol {
    func doWork() { }
}

// ============================================================================
// MARK: - Variant 6: Protocol WITH typed throws — conformer matches
// Hypothesis: Conformer with matching typed throws compiles
// Result: CONFIRMED
//
// Evidence: Build Succeeded
// ============================================================================

protocol TypedProtocol {
    func doWork() throws(MyError)
}

enum MyError: Error { case failed }

struct V6: TypedProtocol {
    func doWork() throws(MyError) {
        throw .failed
    }
}

// ============================================================================
// MARK: - Variant 7: Protocol with typed throws — conformer uses DIFFERENT error
// Hypothesis: Conformer CANNOT use a different typed error than protocol specifies
// Result: CONFIRMED — rejected with "type does not conform to protocol"
//
// Diagnostic: "type 'V7' does not conform to protocol 'TypedProtocol'"
//             "candidate throws, but protocol does not allow it"
// Command: swiftc -typecheck /tmp/v7_test.swift
// ============================================================================

#if false // FAILS — different error type
enum OtherError: Error { case other }
struct V7: TypedProtocol {
    func doWork() throws(OtherError) {
        throw .other
    }
}
#endif

// ============================================================================
// MARK: - Variant 8: Protocol with typed throws — nonthrowing conformer
// Hypothesis: Nonthrowing conformer satisfies throws(E) (covariance chain)
// Result: CONFIRMED — nonthrowing < throws(E) is accepted
//
// Evidence: Build Succeeded
// ============================================================================

struct V8: TypedProtocol {
    func doWork() {
        // Non-throwing satisfies throws(MyError) via covariance
    }
}

// ============================================================================
// MARK: - Variant 9: Concrete caller benefits from narrowed throws
// Hypothesis: When calling a concrete type (not through protocol), the caller
//             sees the narrowed throws(E) and benefits from typed error handling
// Result: CONFIRMED — concrete caller can use throws(DecodingError) context
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// Evidence: Build Succeeded (swiftc -typecheck)
// ============================================================================

struct V9Type: Decodable {
    let x: Int
    init(from decoder: any Decoder) throws(DecodingError) { self.x = 0 }
}

func decodeConcrete(from decoder: any Decoder) throws(DecodingError) {
    // Compiler sees throws(DecodingError) on V9Type.init(from:) directly
    _ = try V9Type(from: decoder)
}

// Generic caller does NOT benefit — protocol witness uses untyped throws:
func decodeGeneric<T: Decodable>(_ type: T.Type, from decoder: any Decoder) throws {
    _ = try T(from: decoder) // Caller sees untyped `throws` from protocol
}

// ============================================================================
// MARK: - Execution
// ============================================================================

print("V1a (Encodable typed throws, empty body): OK")
print("V1b (Encodable typed throws, do/catch wrapping): OK")
print("V2a (Decodable typed throws, empty body): OK")
print("V2b (Decodable typed throws, do/catch wrapping): OK")
print("V4  (non-throwing Encodable): OK")
print("V5a (custom protocol, narrowed throws): OK")
print("V5b (custom protocol, non-throwing): OK")
print("V6  (typed protocol, matching throws): OK")
print("V8  (typed protocol, non-throwing): OK")
print("V9  (concrete caller benefits): OK")
print("")
print("All baseline and workaround variants compile and run.")

// ============================================================================
// MARK: - Results Summary
// ============================================================================
//
// V1:  REFUTED  — Encodable throws(EncodingError) accepted, body blocked
// V1a: CONFIRMED — Conformance signature alone compiles
// V1b: CONFIRMED — do/catch wrapping makes it compile
// V2:  REFUTED  — Decodable throws(DecodingError) accepted, body blocked
// V2a: CONFIRMED — Conformance signature alone compiles
// V2b: CONFIRMED — do/catch wrapping makes it compile
// V3:  REFUTED  — Clock throws(CancellationError) accepted, body blocked
// V3a: CONFIRMED — Conformance signature alone compiles
// V3b: CONFIRMED — do/catch wrapping makes it compile
// V4:  CONFIRMED — Non-throwing satisfies throws (covariance)
// V5a: CONFIRMED — throws → throws(E) narrowing IS supported
// V5b: CONFIRMED — Non-throwing satisfies throws (covariance)
// V6:  CONFIRMED — throws(E) matches throws(E) protocol requirement
// V7:  CONFIRMED — throws(E1) does NOT satisfy throws(E2)
// V8:  CONFIRMED — Non-throwing satisfies throws(E) (covariance)
// V9:  CONFIRMED — Concrete caller benefits from narrowed error type
//
// ============================================================================
// MARK: - Conclusions
// ============================================================================
//
// 1. THROWS COVARIANCE EXISTS: Swift 6.2.4 supports throws covariance on
//    protocol conformances. The subtyping chain is:
//      nonthrowing < throws(E) < throws
//    A conformer CAN narrow `throws` to `throws(E)` or to nonthrowing.
//
// 2. THE BLOCKER IS DOWNSTREAM: The remaining untyped throws in swift-standards
//    are NOT blocked by the conformance mechanism. They are blocked by the
//    DOWNSTREAM APIs:
//      - Encoder/Decoder container protocol methods use untyped throws
//      - Task.checkCancellation() uses untyped throws
//      - Task.sleep(nanoseconds:) uses untyped async throws
//    These are in the Swift stdlib — we cannot change them.
//
// 3. do/catch WORKAROUND EXISTS: All 124 remaining untyped throws CAN be
//    converted to typed throws by wrapping downstream calls in do/catch:
//      do { try container.decode(...) }
//      catch let error as DecodingError { throw error }
//      catch { preconditionFailure("...") }
//
// 4. TRADEOFFS of the workaround:
//    PRO:  Concrete callers get typed error handling
//    PRO:  Documents the actual error contract (Encoders throw EncodingError)
//    CON:  Adds boilerplate per Codable conformance
//    CON:  preconditionFailure catch-all for "impossible" branch
//    CON:  Generic callers (T: Decodable) still see untyped throws
//    CON:  Custom Encoder/Decoder implementations COULD theoretically throw
//          non-standard errors, hitting the preconditionFailure
//
// 5. RECOMMENDATION: The conversion is POSSIBLE but NOT RECOMMENDED at scale.
//    The benefit (typed errors on concrete calls) is marginal because:
//    (a) Most Codable usage goes through JSONDecoder/PropertyListDecoder which
//        call through the protocol existential (any Decodable), losing the type
//    (b) The preconditionFailure catch-all is technically unsound — third-party
//        Encoder/Decoder implementations may throw custom errors
//    (c) 122 conformances × boilerplate = significant noise for minimal gain
//
//    The Clock case (2 instances) is more defensible since Task.sleep/
//    checkCancellation genuinely only throw CancellationError.
//
// 6. WHAT WOULD ACTUALLY FIX THIS:
//    - Swift Evolution: typed throws on Encoder/Decoder container protocols
//    - Swift Evolution: typed throws on Task.checkCancellation/sleep
//    - These are additive, non-breaking changes (throws(E) < throws)
