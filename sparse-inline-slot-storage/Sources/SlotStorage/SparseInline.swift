/// A sparse-inline buffer with **no custom `deinit`** — storage self-cleans via
/// `InlineArray`'s automatic recursive teardown.
///
/// The `@_rawLayout` value-witness-triviality surface behind `swift#86652`
/// (**Wall 2**, the cross-module deinit skip) is absent here — `InlineArray` is a
/// normal stdlib type with a compiler-generated value witness — so this type is
/// also the cross-module teardown verification bed (see `Demo`).
public struct SparseInline<Element: ~Copyable, let N: Int>: ~Copyable {
    public var storage: InlineArray<N, Slot<Element>>

    public init() {
        storage = InlineArray<N, Slot<Element>> { _ in .empty }
    }

    /// Occupies slot `i` with `e` (consumes it). The prior `.empty` drops trivially.
    public mutating func put(_ e: consuming Element, at i: Int) {
        storage[i] = .occupied(e)
    }
}

extension SparseInline: Copyable where Element: Copyable {}
