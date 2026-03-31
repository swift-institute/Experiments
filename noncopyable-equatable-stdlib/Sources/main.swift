// MARK: - Noncopyable Equatable via stdlib (SE-0499)
// Purpose: Verify whether Swift.Equatable supports ~Copyable conformers on Swift 6.3
// Hypothesis: SE-0499 (Equatable: ~Copyable) landed on main only, NOT release/6.3,
//             so ~Copyable types cannot conform to Swift.Equatable on 6.3
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Swift.Equatable does NOT support ~Copyable on Swift 6.3
// Date: 2026-03-30

// MARK: - Variant 1: ~Copyable struct conforming to Swift.Equatable (borrowing ==)
// Hypothesis: Will fail — Equatable requires Copyable on 6.3
// Result: REFUTED (fails)
//   error: type 'Token' does not conform to protocol 'Copyable'
//   note: type 'Token' does not conform to inherited protocol 'Copyable'
//   Command: swift build

// struct Token: ~Copyable, Equatable {
//     let id: Int
//     static func == (lhs: borrowing Token, rhs: borrowing Token) -> Bool {
//         lhs.id == rhs.id
//     }
// }

// MARK: - Variant 2: ~Copyable struct with consuming == (pre-SE-0499 signature)
// Hypothesis: Will also fail — Equatable itself requires Copyable
// Result: REFUTED (fails)
//   error: type 'Ticket' does not conform to protocol 'Copyable'
//   error: parameter of noncopyable type 'Ticket' must specify ownership
//   Command: swift build

// struct Ticket: ~Copyable, Equatable {
//     let number: Int
//     static func == (lhs: Ticket, rhs: Ticket) -> Bool {
//         lhs.number == rhs.number
//     }
// }

// MARK: - Variant 3: Generic function with Equatable & ~Copyable
// Hypothesis: Will fail — cannot compose Equatable & ~Copyable when Equatable implies Copyable
// Result: REFUTED (fails)
//   error: composition cannot contain '~Copyable' when another member requires 'Copyable'
//   Command: swift build

// func areEqual<T: Equatable & ~Copyable>(lhs: borrowing T, rhs: borrowing T) -> Bool {
//     lhs == rhs
// }

// MARK: - Variant 4: Copyable struct (control — should always work)
// Hypothesis: Will succeed — standard Equatable conformance
// Result: CONFIRMED
//   Output: Label(hello) == Label(hello): true

struct Label: Equatable {
    let text: String
}

let x = Label(text: "hello")
let y = Label(text: "hello")
print("Label(hello) == Label(hello): \(x == y)")

// MARK: - Results Summary
// V1: REFUTED — ~Copyable + Equatable with borrowing == fails: "does not conform to inherited protocol 'Copyable'"
// V2: REFUTED — ~Copyable + Equatable with consuming == fails: same inherited Copyable error + ownership annotation required
// V3: REFUTED — Equatable & ~Copyable composition rejected: "cannot contain '~Copyable' when another member requires 'Copyable'"
// V4: CONFIRMED — Copyable Equatable works as expected (control)
//
// Conclusion: SE-0499 is NOT available in Swift 6.3. The stdlib Equatable protocol
// still implicitly requires Copyable. equation-primitives and hash-primitives remain
// necessary for ~Copyable equality/hashing until the Swift version that ships SE-0499.
