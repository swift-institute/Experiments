// constraint-poisoning-module-split
//
// Purpose: Test whether ~Escapable constraint poisoning occurs with result
// builders and whether suppressing ~Escapable on builder generic params fixes it.
//
// Context: Parser.Protocol declares `associatedtype Input: ~Escapable`.
// Parser.Take.Builder<Input> has `Input` as an unconstrained generic parameter
// (implicitly Escapable). When used as `@Parser.Take.Builder<Wrapped.Input>`,
// the compiler rejects it: "type 'Wrapped.Input' does not conform to 'Escapable'".
//
// Hypothesis: Adding `~Escapable` suppression to the builder's generic parameter
// (`Builder<Input: ~Escapable>`) resolves the constraint mismatch.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — Adding `~Escapable` to the builder's generic parameter
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         resolves the constraint mismatch. No module split needed for ~Escapable;
//         the fix is simply `Builder<Input: ~Escapable>`.
//         V1: REFUTED (implicit Escapable on builder param rejects ~Escapable Input)
//         V2: CONFIRMED (~Escapable suppression on builder param compiles)
//         V3: CONFIRMED (full ~Escapable & ~Copyable suppression compiles)
//         V4: CONFIRMED (builder overloads work with ~Escapable)
// Date: 2026-02-13

// MARK: - V1: Baseline — result builder with implicit Escapable, protocol with ~Escapable
// Hypothesis: This reproduces the Parser.Optionally error.

protocol StreamV1: ~Copyable {
    associatedtype Input: ~Escapable
    func parse(_ input: inout Input)
}

@resultBuilder
struct BuilderV1<Input> {
    static func buildBlock<P: StreamV1>(_ p: P) -> P where P.Input == Input {
        p
    }
}

// REFUTED — uncommented to verify, produces exact error:
//   error: type 'Wrapped.Input' does not conform to protocol 'Escapable'
// struct WrapperV1<Wrapped: StreamV1>: Sendable where Wrapped: Sendable {
//     let wrapped: Wrapped
//     init(@BuilderV1<Wrapped.Input> _ build: () -> Wrapped) {
//         self.wrapped = build()
//     }
// }

// MARK: - V2: Suppress ~Escapable on builder generic parameter
// Hypothesis: `Builder<Input: ~Escapable>` compiles and resolves the mismatch.

@resultBuilder
struct BuilderV2<Input: ~Escapable> {
    static func buildBlock<P: StreamV1>(_ p: P) -> P where P.Input == Input {
        p
    }
}

struct WrapperV2<Wrapped: StreamV1>: Sendable where Wrapped: Sendable {
    let wrapped: Wrapped

    init(@BuilderV2<Wrapped.Input> _ build: () -> Wrapped) {
        self.wrapped = build()
    }
}

// MARK: - V3: Suppress ~Escapable + ~Copyable on builder (full suppression)
// Hypothesis: Both suppressions together work, matching the full Parser scenario.

protocol StreamV3: ~Copyable {
    associatedtype Input: ~Escapable & ~Copyable
    func parse(_ input: inout Input)
}

@resultBuilder
struct BuilderV3<Input: ~Escapable & ~Copyable> {
    static func buildBlock<P: StreamV3>(_ p: P) -> P where P.Input == Input {
        p
    }
}

struct WrapperV3<Wrapped: StreamV3>: Sendable where Wrapped: Sendable {
    let wrapped: Wrapped

    init(@BuilderV3<Wrapped.Input> _ build: () -> Wrapped) {
        self.wrapped = build()
    }
}

// MARK: - V4: Multiple builder methods (buildBlock overloads)
// Hypothesis: Builder with ~Escapable supports multiple buildBlock methods.

@resultBuilder
struct BuilderV4<Input: ~Escapable> {
    static func buildBlock() -> Int { 0 }

    static func buildBlock<P: StreamV1>(_ p: P) -> P where P.Input == Input {
        p
    }

    static func buildBlock<P0: StreamV1, P1: StreamV1>(
        _ p0: P0, _ p1: P1
    ) -> (P0, P1) where P0.Input == Input, P1.Input == Input {
        (p0, p1)
    }
}

struct WrapperV4<Wrapped: StreamV1>: Sendable where Wrapped: Sendable {
    let wrapped: Wrapped

    init(@BuilderV4<Wrapped.Input> _ build: () -> Wrapped) {
        self.wrapped = build()
    }
}

// MARK: - Execution

print("=== ~Escapable Constraint Poisoning Experiment ===")
print()
print("V1: (commented out — expected to fail)")
print("V2: Compiles if ~Escapable suppression on builder works")
print("V3: Compiles if full suppression (~Escapable & ~Copyable) works")
print("V4: Compiles if builder overloads work with ~Escapable")
print()
print("If this binary runs, V2–V4 are CONFIRMED.")
