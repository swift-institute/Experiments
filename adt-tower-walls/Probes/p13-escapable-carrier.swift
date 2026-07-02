// p13: can the thin carrier suppress ~Escapable on 6.3.3 — `X<S: ~Copyable & ~Escapable>`
// Result (Apple Swift 6.3.3, 2026-07-02): MIXED — bare: FAILS (implicit accessors/init cannot return ~Escapable result); with -enable-experimental-feature Lifetimes + @_lifetime(copy column): compiles AND runs, ordinary Escapable columns unaffected. Carrier ~Escapable suppression is Lifetimes-gated on 6.3.3.
// storing S, with conditional Escapable/Copyable restored — and still work for ordinary
// Escapable columns? (The full-fidelity carrier posture the user requires "where appropriate".)
public struct Carrier<S: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    public var column: S
    @_lifetime(copy column)
    public init(column: consuming S) { self.column = column }
}
extension Carrier: Copyable where S: Copyable & ~Escapable {}
extension Carrier: Escapable where S: Escapable & ~Copyable {}

// ordinary (Escapable, Copyable) column still composes:
public struct Plain { public var x: Int }
func esc() -> Carrier<Plain> { Carrier(column: Plain(x: 7)) }
print("p13 ok:", esc().column.x)
