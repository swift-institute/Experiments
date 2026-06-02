// MARK: - SubscriptProducerProbe — can a SUBSCRIPT produce the ~Escapable view? (EXPECT: NO)
//
// The handoff names "a borrowing-bounds subscript". This isolates whether the view
// PRODUCER can be a subscript (vs the `func slice(from:upTo:)` that ScopedSliceKit uses).
// Two distinct obstructions, both reproduced here:
//
//   (A) The `borrowing` ownership keyword is rejected on subscript parameters:
//         error: 'borrowing' may only be used on function or initializer parameters
//       (so the literal "borrowing-bounds subscript" is not spellable). See the commented
//       declaration below.
//
//   (B) A by-value subscript whose getter RETURNS a ~Escapable value cannot thread the
//       bounds' lifetimes through its compiler-generated `get`:
//         error: lifetime-dependent value escapes its scope
//         note: it depends on the lifetime of argument 'lower' / 'upper'
//         note: error in compiler-generated 'get'
//
// Contrast: ScopedSlice's cursor-keyed ELEMENT subscript (returns Int — Escapable) DOES
// compile; only the ~Escapable-RETURNING producer subscript is obstructed. The producer
// must therefore be a `func`.
//
// Build with: swift build --target SubscriptProducerProbe   (EXPECT non-zero exit)
// Toolchain: probed on BOTH Apple Swift 6.3.2 and 6.5-dev.
// Status: REFUTED — the producer cannot be a subscript (identical on both toolchains).
// Result: REFUTED. Obstruction (B) reproduced verbatim on 6.3.2 AND 6.5-dev:
//   error: lifetime-dependent value escapes its scope
//   note: error in compiler-generated 'get'  /  it depends on the lifetime of argument 'lower'
//   Cmd: swift build --target SubscriptProducerProbe
//   (Obstruction (A), the `borrowing` keyword on a subscript param —
//    `error: 'borrowing' may only be used on function or initializer parameters` — is the
//    commented declaration below.) The ScopedSliceKit producer is therefore a `func`.

import ScopedSliceKit

public extension Base {
    // (A) Rejected at parse time — uncomment to reproduce obstruction (A):
    // @_lifetime(copy lower, copy upper)
    // subscript(borrowingFrom lower: borrowing Cursor, upTo upper: borrowing Cursor) -> ScopedSlice {
    //     ScopedSlice(buffer: self.buffer, lower: lower, upper: upper)
    // }

    // (B) By-value subscript returning the ~Escapable view — EXPECT: lifetime escape in
    // the compiler-generated getter.
    @_lifetime(copy lower, copy upper)
    subscript(from lower: Cursor, upTo upper: Cursor) -> ScopedSlice {
        ScopedSlice(buffer: self.buffer, lower: lower, upper: upper)
    }
}
