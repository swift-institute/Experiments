// MARK: - Phase 3 — ~Copyable variant exercising route 3 (the crux: compile AND run)

// A ~Copyable element. Owns a resource id; cannot be copied.
public struct Resource: ~Copyable {
    public var id: Int
    @inlinable public init(id: Int) { self.id = id }
}

// MARK: A span-based backing VIEW conforming BorrowForEachable (the leaf forEach).
public extension Memory {
    @frozen
    struct SpanView<Element: ~Copyable>: ~Copyable, ~Escapable {
        @usableFromInline let span: Span<Element>
        @_lifetime(copy span)
        @inlinable public init(_ span: consuming Span<Element>) { self.span = span }
    }
}

extension Memory.SpanView: BorrowForEachable where Element: ~Copyable {
    @inlinable
    public borrowing func forEach(_ body: (borrowing Element) -> Void) {
        for i in 0..<span.count { body(span[i]) }
    }
}

// MARK: The ~Copyable concrete variant — owns a heap buffer of ~Copyable Resources.
@safe
public struct ToyOwned: ~Copyable {
    @usableFromInline let buffer: UnsafeMutableBufferPointer<Resource>
    @inlinable
    public init(_ ids: [Int]) {
        unsafe buffer = .allocate(capacity: ids.count)
        for i in ids.indices {
            let resource = Resource(id: ids[i])
            unsafe buffer.initializeElement(at: i, to: resource)
        }
    }
    @inlinable
    deinit {
        unsafe buffer.deinitialize()
        unsafe buffer.deallocate()
    }
    @usableFromInline var span: Span<Resource> {
        @_lifetime(borrow self) get {
            let s = unsafe Span(_unsafeElements: UnsafeBufferPointer(buffer))
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

extension ToyOwned: Collection.`Protocol` {
    public typealias Element = Resource
    public typealias Index = Int
    public var startIndex: Int { 0 }
    public var endIndex: Int { unsafe buffer.count }
    public borrowing func index(after i: Int) -> Int { i &+ 1 }
    public subscript(position: Int) -> Resource { _read { yield unsafe buffer[position] } }
}

extension ToyOwned: MyFamily.`Protocol` {
    public typealias Backing = Memory.SpanView<Resource>
    public var backing: Memory.SpanView<Resource> {
        @_lifetime(borrow self) get { Memory.SpanView(self.span) }
    }
    // forEach((borrowing Resource) -> Void) provided by the MyFamily family default.
}
