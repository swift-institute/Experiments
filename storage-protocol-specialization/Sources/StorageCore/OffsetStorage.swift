// Concrete storage #2 — different physical addressing (base + offset). Its only purpose
// is to make the protocol witness table NON-trivial: with two conformers, witness-table
// dispatch is a real alternative the optimizer must actively defeat per call site. If the
// generic core still specializes with two conformers present, the result is meaningful.
public struct OffsetStorage: StorageProtocol, ~Copyable {
    public typealias Element = Int
    public let capacity: Int
    @usableFromInline let base: UnsafeMutablePointer<Int>
    @usableFromInline let offset: Int

    public init(capacity: Int, offset: Int) {
        self.capacity = capacity
        self.offset = offset
        self.base = UnsafeMutablePointer<Int>.allocate(capacity: capacity + offset)
    }

    public func pointer(at slot: Int) -> UnsafeMutablePointer<Int> {
        base.advanced(by: slot + offset)
    }

    deinit { base.deallocate() }
}
