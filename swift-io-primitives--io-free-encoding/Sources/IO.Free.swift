//
// IO.Free<Value, Failure> — the freer monad over Σ_IO with typed errors.
//
// One case per Σ_IO operation. Each case carries its arguments AND a
// typed continuation `(OpResult) -> IO.Free<Value, Failure>`. The
// continuation knows the operation's result type at compile time, so we
// never need `Any`, never need `as!`, and never introduce an existential.
//
// This is what algebraic-effects literature calls the *operations-as-
// constructors* encoding. Compared to the Kiselyov–Ishii freer-monad
// pattern (single .bind case with `(Any) -> IO.Free<X>` continuation),
// the trade-off is:
//   - this version: N+2 cases (N ops + .pure + .fail), zero existentials,
//     zero unsafe casts, statically typed continuations
//   - Kiselyov–Ishii pattern: 3 cases (.pure, .fail, .bind), one
//     existential per op, one `as!` per smart constructor
// The L1 forbid-existentials rule makes this version the right choice.
//
// Type body contains only the cases per [API-IMPL-008]. Smart
// constructors, combinators, interpreter, and inspector live in
// `+` extension files.
//

extension IO {

    public indirect enum Free<Value, Failure: Swift.Error>: Sendable
        where Value: Sendable, Failure: Sendable
    {
        case pure(Value)
        case fail(Failure)
        case readOp(
            from: Kernel.Descriptor,
            into: Memory.Buffer.Mutable,
            continuation: @Sendable (Int) -> IO.Free<Value, Failure>
        )
        case writeOp(
            to: Kernel.Descriptor,
            from: Memory.Buffer,
            continuation: @Sendable (Int) -> IO.Free<Value, Failure>
        )
        case closeOp(
            descriptor: Kernel.Descriptor,
            continuation: @Sendable () -> IO.Free<Value, Failure>
        )
        case readyOp(
            from: Kernel.Descriptor,
            interest: Kernel.Event.Interest,
            continuation: @Sendable () -> IO.Free<Value, Failure>
        )
    }
}
