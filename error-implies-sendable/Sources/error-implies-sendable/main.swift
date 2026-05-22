// MARK: - Does Swift.Error imply Swift.Sendable?
//
// Purpose: Verify whether the Swift.Error protocol refines Swift.Sendable
//   (i.e., whether `T: Error` is sufficient to satisfy a `T: Sendable`
//   constraint without an explicit `Sendable` conformance on the error type).
//
// Hypothesis: Error does NOT refine Sendable. A type conforming only to
//   Error must additionally conform to Sendable to satisfy a Sendable
//   constraint. Sendability for thrown errors is enforced at the
//   isolation-crossing site, not on the protocol.
//
// Toolchain: Apple Swift 6.3.x (workspace default)
// Platform: macOS 26 (arm64)
// Language mode: Swift 6
//
// Result: REFUTED hypothesis — Error DOES refine Sendable in Swift 6 mode.
//   Build Output (decisive line):
//     main.swift:66:7: error: non-final class 'ClassError' cannot conform
//                             to the 'Sendable' protocol
//   The diagnostic fires at the `class ClassError: Error` declaration —
//   source only writes `: Error`, yet the Sendable requirement chain is
//   surfaced. This proves Error refines Sendable.
//
//   Variant-by-variant:
//     V1 (struct: Error with non-Sendable payload):
//       Compiles with warning "stored property … of 'Sendable'-conforming
//       struct 'WrappingError' has non-Sendable type". The compiler
//       considers the Error-only struct to be Sendable-conforming.
//     V2 (T: Error): compiles — sanity check.
//     V3 (any Error → T: Sendable): compiles — `any Error` is implicitly
//       Sendable, only possible if Error: Sendable.
//     V4 (non-final class: Error): HARD ERROR at the conformance line —
//       "non-final class cannot conform to Sendable protocol". Rules out
//       struct-inference as an explanation.
//
// Status: CONFIRMED — Error refines Sendable in Swift 6 (build complete; V4 errors are expected and confirm the conclusion)
// Date: 2026-05-13

// A reference-typed payload that is NOT Sendable.
final class NonSendablePayload {
    var note: String = "mutable"
}

// An error type whose stored property is non-Sendable. Therefore this struct
// is NOT auto-Sendable. We conform to Error only — not Sendable.
struct WrappingError: Error {
    let payload: NonSendablePayload
}

// MARK: - Variant 1: Pass an Error-only type where Sendable is required.
// Hypothesis: rejected if Error does NOT imply Sendable.

func requiresSendable<T: Sendable>(_ value: T) {
    _ = value
}

func variant1() {
    let e = WrappingError(payload: NonSendablePayload())
    requiresSendable(e)  // ← EXPECTED ERROR if Error does not imply Sendable
}

// MARK: - Variant 2: Same type accepted where only Error is required.
// Hypothesis: accepted — confirms WrappingError really is an Error.

func requiresError<E: Error>(_ value: E) {
    _ = value
}

func variant2() {
    let e = WrappingError(payload: NonSendablePayload())
    requiresError(e)  // ← EXPECTED OK
}

// MARK: - Variant 3: Existential `any Error` into Sendable slot.
// Hypothesis: rejected if `any Error` is not implicitly Sendable.

func variant3(_ e: any Error) {
    requiresSendable(e)  // ← EXPECTED ERROR if any Error is not Sendable
}

// MARK: - Variant 4: Class-based error (no struct Sendable inference).
// Hypothesis: rejected if Error does NOT imply Sendable. A non-final class
//   conforming only to Error cannot rely on struct Sendable inference.

class ClassError: Error {
    var counter: Int = 0
}

func variant4() {
    let e = ClassError()
    requiresSendable(e)  // ← decisive: no struct-inference escape hatch
}

variant1()
variant2()
variant3(WrappingError(payload: NonSendablePayload()))
variant4()
