//
// A mutable-value buffer that can be consumed and returned in a tuple.
//
// Sendable conformance rationale: Memory.Buffer keeps `: Sendable` even though
// this sketch's witness takes `consuming Memory.Buffer`. The two are
// complementary, not redundant:
//
//   * `consuming` enforces single-owner flow at the type level — the parameter
//     name is invalidated after the call and the buffer must be re-bound from
//     the tuple return. This is the rental-shape contract monoio uses.
//   * `Sendable` lets the buffer flow across actor/isolation boundaries
//     without region-transfer analysis. A prior iteration tried pure-`sending`
//     (dropping Sendable) and it fails at the `buf = returnedBuf` re-bind
//     inside `readLoop`: the re-bound value is not in a sending region, so
//     the next iteration's `consume buf` is rejected.
//
// With Memory.Buffer: Sendable, both constraints live peacefully — the
// language checks ownership via `consuming`, and isolation via Sendable.
//

extension Memory {
    public struct Buffer: Sendable {
        public var bytes: [UInt8]

        public init(capacity: Int) {
            self.bytes = Array(repeating: 0, count: capacity)
        }
    }
}
