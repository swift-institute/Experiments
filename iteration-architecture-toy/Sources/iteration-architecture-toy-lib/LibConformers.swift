// MARK: - Phase 7 (Gap c) — CROSS-MODULE: a conformer that lives in the LIB target.
// Proves same-module conformance to the lib families still holds; the executable adds DOWNSTREAM
// conformers (the real cross-module test: a consumer module conforming an upstream family protocol
// and inheriting the upstream default body). See the executable's XM* conformers + run block.

// A D1 conformer in the lib module — makeIteratorD1() inherited from the lib's FamD default.
public struct LibFamDImpl: ~Copyable {
    @usableFromInline var storage: [Int]
    @inlinable public init(_ storage: [Int]) { self.storage = storage }
}

extension LibFamDImpl: FamD.`Protocol` {
    public typealias Element = Int
    public typealias View = Memory.CopyView<Int>
    public var view: Memory.CopyView<Int> {
        @_lifetime(borrow self) get { Memory.CopyView(storage.span) }
    }
}
