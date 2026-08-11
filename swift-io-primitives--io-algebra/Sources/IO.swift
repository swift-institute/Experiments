//
// Purpose: Pure algebra, minimal Swift annotations. Nothing beyond what
//   the type system forces us to annotate to have algebra at all.
//
// Algebra says (category theory):
//   - `IO<R, E, A>` is a type with combinators `pure, map, flatMap, ...`.
//   - Operations are pure functions on values.
//   - No regions, no isolation, no Sendability — those are Swift artifacts.
//
// Swift forces:
//   - `borrowing Environment` — the Reader monad reads env without
//     consuming it. This IS algebraic (reader semantics), so it's
//     legitimately part of the algebra's Swift expression.
//   - `async throws(LeafError)` — typed throws. Algebraic: error
//     channel is statically-typed.
//   - `@escaping` on closure parameters stored in the struct.
//
// Swift does NOT force (we reject):
//   - `@Sendable` on function types. Sendability is a Swift concurrency
//     notion, not an algebraic one. We let it emerge from closure
//     captures rather than imposing.
//   - `sending` everywhere. Let the compiler demand it at transfer
//     points if needed; don't sprinkle it preemptively.
//   - `~Copyable` IO. The algebra doesn't say "IO is single-use". IO
//     is a value; Swift's default Copyable behavior matches "a
//     computation description can be used twice (two separate
//     invocations)".
//   - `Sendable` constraints on generic parameters. The algebra admits
//     any type. Whether a specific IO crosses actor boundaries is a
//     USE-SITE concern, not an algebra concern.
//
// Resulting properties (not designed, emergent):
//   - IO is Copyable (default) — can be stored on actors and used many times.
//   - IO is non-Sendable (its stored closure is non-@Sendable) — moving an
//     IO across actor boundaries requires `sending IO` at the crossing
//     (a use-site annotation, not an algebra axiom).
//   - Each `.run(env)` runs in caller's isolation (NonisolatedNonsendingByDefault).
//
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Result: PENDING
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-17
//
// Academic pedigree:
// - Moggi 1989 "Computational Lambda-Calculus and Monads"
// - Liang, Hudak, Jones 1995 "Monad Transformers" — ReaderT · ExceptT · IO
// - Atkey 2009 "Parameterised notions of computation"
//

public struct IO<Environment, LeafError: Swift.Error, Value> {
    public let run: (borrowing Environment) async throws(LeafError) -> Value

    public init(
        _ run: @escaping (borrowing Environment) async throws(LeafError) -> Value
    ) {
        self.run = run
    }
}
