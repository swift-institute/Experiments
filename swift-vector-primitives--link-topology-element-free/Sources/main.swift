// MARK: - Link Topology Element-Free Design Validation
// Purpose: Verify key assumptions for Element-free link topology:
//   1. MemoryLayout<T>.offset(of: \.links) on @frozen value-generic struct
//   2. Copyable/Sendable struct generic over Tag: ~Copyable
//   3. linksAt closure pattern via links-first layout (offset 0)
//   4. linksAt closure pattern via withUnsafeMutablePointer
//   5. Alternative: nodeAt pattern with generic Element on methods only
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: V1 REFUTED, V2-V5 CONFIRMED — see individual variant results
// Date: 2026-04-01

import Index_Primitives
import Vector_Primitives

// ============================================================================
// MARK: - Variant 1: MemoryLayout.offset(of:) on @frozen value-generic struct
// Hypothesis: MemoryLayout<Node<Element>>.offset(of: \.links) returns a valid
//             offset for @frozen structs with <let N: Int> value-generic param
// Result: REFUTED — key paths require Copyable; fails for ~Copyable Element
// Evidence: error: referencing static method 'offset(of:)' on 'Link.Node'
//           requires that 'Element' conform to 'Copyable'
// ============================================================================

// Tested in generic context: does NOT compile when Element: ~Copyable.
// Works only when Element: Copyable (concrete types like Int).
// This rules out MemoryLayout.offset(of:) as the general linksPointer mechanism.

// ============================================================================
// MARK: - Shared types for remaining variants
// ============================================================================

// Design A: element-first layout (conventional)
enum LinkA<let N: Int> {
    @frozen
    public struct Node<Element: ~Copyable>: ~Copyable {
        public var element: Element
        public var links: InlineArray<N, Index<Node>>

        public init(element: consuming Element, links: InlineArray<N, Index<Node>>) {
            self.element = element
            self.links = links
        }
    }
}

extension LinkA.Node: Copyable where Element: Copyable {}
extension LinkA.Node: @unchecked Sendable where Element: Sendable {}

// Design B: links-first layout (topology-optimized)
enum LinkB<let N: Int> {
    @frozen
    public struct Node<Element: ~Copyable>: ~Copyable {
        public var links: InlineArray<N, Index<Node>>
        public var element: Element

        public init(element: consuming Element, links: InlineArray<N, Index<Node>>) {
            self.links = links
            self.element = element
        }
    }
}

extension LinkB.Node: Copyable where Element: Copyable {}
extension LinkB.Node: @unchecked Sendable where Element: Sendable {}

// ============================================================================
// MARK: - Variant 2: Copyable Sendable struct generic over Tag: ~Copyable
// Hypothesis: A struct that is unconditionally Copyable & Sendable can have
//             a generic parameter constrained to ~Copyable
// Result: <pending>
// ============================================================================

// Header is shared — same for both designs
enum LinkH<let N: Int> {
    public struct Header<Tag: ~Copyable>: Copyable, Sendable {
        public var head: Index<Tag>
        public var tail: Index<Tag>
        public var count: Index<Tag>.Count
        public let sentinel: Index<Tag>

        public init(sentinel: Index<Tag>) {
            self.head = sentinel
            self.tail = sentinel
            self.count = .zero
            self.sentinel = sentinel
        }
    }
}

do {
    // Header phantom-tagged with a ~Copyable type
    struct NoncopyableTag: ~Copyable {}
    typealias H = LinkH<2>.Header<NoncopyableTag>
    let sentinel = Index<NoncopyableTag>(Ordinal(UInt(99)))
    let header = H(sentinel: sentinel)
    print("V2a: Header<NoncopyableTag> head=\(header.head), tail=\(header.tail), count=\(header.count), sentinel=\(header.sentinel)")

    // Header phantom-tagged with Node<Int> (the common case)
    typealias H2 = LinkH<2>.Header<LinkA<2>.Node<Int>>
    let sentinel2 = Index<LinkA<2>.Node<Int>>(Ordinal(UInt(99)))
    let header2 = H2(sentinel: sentinel2)
    print("V2b: Header<Node<Int>> head=\(header2.head), count=\(header2.count)")

    // Verify Copyable + Sendable
    func acceptCopyable<T: Copyable>(_ v: T) { print("V2c: Copyable OK") }
    func acceptSendable<T: Sendable>(_ v: T) { print("V2d: Sendable OK") }
    acceptCopyable(header)
    acceptSendable(header)
}

// ============================================================================
// MARK: - Variant 3: Links-first layout (offset 0) — linksAt closure pattern
// Hypothesis: If links is the first field in @frozen struct, the node pointer
//             IS the links pointer (offset 0). No MemoryLayout.offset needed.
// Result: <pending>
// ============================================================================

extension LinkB {
    /// Zero-offset linksPointer — works for ALL Element types including ~Copyable
    @inlinable @unsafe
    public static func linksPointer<Element: ~Copyable>(
        in nodePointer: UnsafeMutablePointer<Node<Element>>
    ) -> UnsafeMutablePointer<InlineArray<N, Index<Node<Element>>>> {
        // @frozen guarantees links is at offset 0 (first field)
        return unsafe UnsafeMutableRawPointer(nodePointer)
            .assumingMemoryBound(to: InlineArray<N, Index<Node<Element>>>.self)
    }

    @inlinable @unsafe
    public static func append<Tag: ~Copyable>(
        _ index: Index<Tag>,
        header: inout LinkH<N>.Header<Tag>,
        _ linksAt: (Index<Tag>) -> UnsafeMutablePointer<InlineArray<N, Index<Tag>>>
    ) {
        let sentinel = header.sentinel
        if header.tail != sentinel {
            unsafe linksAt(header.tail).pointee[0] = index
            if N >= 2 { unsafe linksAt(index).pointee[1] = header.tail }
        } else {
            header.head = index
        }
        header.tail = index
        unsafe linksAt(index).pointee[0] = sentinel
        header.count += .one
    }

    @inlinable @unsafe
    public static func forEach<Tag: ~Copyable>(
        header: LinkH<N>.Header<Tag>,
        _ linksAt: (Index<Tag>) -> UnsafeMutablePointer<InlineArray<N, Index<Tag>>>,
        _ body: (Index<Tag>) -> Void
    ) {
        let sentinel = header.sentinel
        var current = header.head
        while current != sentinel {
            let next = unsafe linksAt(current).pointee[0]
            body(current)
            current = next
        }
    }
}

do {
    typealias N = LinkB<2>.Node<Int>
    typealias H = LinkH<2>.Header<N>

    let capacity = 4
    let sentinel = Index<N>(Ordinal(UInt(capacity)))
    let pool = UnsafeMutableBufferPointer<N>.allocate(capacity: capacity)
    defer { pool.deallocate() }

    for i in 0..<capacity {
        let links = InlineArray<2, Index<N>>(repeating: sentinel)
        pool.baseAddress!.advanced(by: i).initialize(to: N(element: (i + 1) * 10, links: links))
    }

    var header = H(sentinel: sentinel)

    let linksAt: (Index<N>) -> UnsafeMutablePointer<InlineArray<2, Index<N>>> = { idx in
        let nodePtr = pool.baseAddress!.advanced(by: Int(idx.rawValue.rawValue))
        return unsafe LinkB<2>.linksPointer(in: nodePtr)
    }

    for i in 0..<capacity {
        let idx = Index<N>(Ordinal(UInt(i)))
        unsafe LinkB<2>.append(idx, header: &header, linksAt)
    }

    print("V3a: [links-first] After appending 4 nodes:")
    print("  head=\(header.head), tail=\(header.tail), count=\(header.count)")

    var elements: [Int] = []
    unsafe LinkB<2>.forEach(header: header, linksAt) { idx in
        let nodePtr = pool.baseAddress!.advanced(by: Int(idx.rawValue.rawValue))
        elements.append(nodePtr.pointee.element)
    }
    print("  traversal order: \(elements)")

    var reverseElements: [Int] = []
    var current = header.tail
    while current != sentinel {
        let nodePtr = pool.baseAddress!.advanced(by: Int(current.rawValue.rawValue))
        reverseElements.append(nodePtr.pointee.element)
        current = unsafe LinkB<2>.linksPointer(in: nodePtr).pointee[1]
    }
    print("  reverse order: \(reverseElements)")

    let correct = elements == [10, 20, 30, 40] && reverseElements == [40, 30, 20, 10]
    print("V3b: [links-first] Round-trip correct: \(correct)")
}

// ============================================================================
// MARK: - Variant 4: withUnsafeMutablePointer approach (element-first layout)
// Hypothesis: withUnsafeMutablePointer(to: &nodePtr.pointee.links) can extract
//             a field pointer that works outside the closure scope in @unsafe
// Result: <pending>
// ============================================================================

extension LinkA {
    /// linksPointer via withUnsafeMutablePointer — works for element-first layout
    @inlinable @unsafe
    public static func linksPointer<Element: ~Copyable>(
        in nodePointer: UnsafeMutablePointer<Node<Element>>
    ) -> UnsafeMutablePointer<InlineArray<N, Index<Node<Element>>>> {
        return unsafe withUnsafeMutablePointer(to: &nodePointer.pointee.links) { $0 }
    }

    @inlinable @unsafe
    public static func append<Tag: ~Copyable>(
        _ index: Index<Tag>,
        header: inout LinkH<N>.Header<Tag>,
        _ linksAt: (Index<Tag>) -> UnsafeMutablePointer<InlineArray<N, Index<Tag>>>
    ) {
        let sentinel = header.sentinel
        if header.tail != sentinel {
            unsafe linksAt(header.tail).pointee[0] = index
            if N >= 2 { unsafe linksAt(index).pointee[1] = header.tail }
        } else {
            header.head = index
        }
        header.tail = index
        unsafe linksAt(index).pointee[0] = sentinel
        header.count += .one
    }

    @inlinable @unsafe
    public static func forEach<Tag: ~Copyable>(
        header: LinkH<N>.Header<Tag>,
        _ linksAt: (Index<Tag>) -> UnsafeMutablePointer<InlineArray<N, Index<Tag>>>,
        _ body: (Index<Tag>) -> Void
    ) {
        let sentinel = header.sentinel
        var current = header.head
        while current != sentinel {
            let next = unsafe linksAt(current).pointee[0]
            body(current)
            current = next
        }
    }
}

do {
    typealias N = LinkA<2>.Node<Int>
    typealias H = LinkH<2>.Header<N>

    let capacity = 4
    let sentinel = Index<N>(Ordinal(UInt(capacity)))
    let pool = UnsafeMutableBufferPointer<N>.allocate(capacity: capacity)
    defer { pool.deallocate() }

    for i in 0..<capacity {
        let links = InlineArray<2, Index<N>>(repeating: sentinel)
        pool.baseAddress!.advanced(by: i).initialize(to: N(element: (i + 1) * 10, links: links))
    }

    var header = H(sentinel: sentinel)

    let linksAt: (Index<N>) -> UnsafeMutablePointer<InlineArray<2, Index<N>>> = { idx in
        let nodePtr = pool.baseAddress!.advanced(by: Int(idx.rawValue.rawValue))
        return unsafe LinkA<2>.linksPointer(in: nodePtr)
    }

    for i in 0..<capacity {
        let idx = Index<N>(Ordinal(UInt(i)))
        unsafe LinkA<2>.append(idx, header: &header, linksAt)
    }

    print("V4a: [element-first + withUnsafeMutablePointer] After appending 4 nodes:")
    print("  head=\(header.head), tail=\(header.tail), count=\(header.count)")

    var elements: [Int] = []
    unsafe LinkA<2>.forEach(header: header, linksAt) { idx in
        let nodePtr = pool.baseAddress!.advanced(by: Int(idx.rawValue.rawValue))
        elements.append(nodePtr.pointee.element)
    }
    print("  traversal order: \(elements)")

    var reverseElements: [Int] = []
    var current = header.tail
    while current != sentinel {
        let nodePtr = pool.baseAddress!.advanced(by: Int(current.rawValue.rawValue))
        reverseElements.append(nodePtr.pointee.element)
        current = unsafe LinkA<2>.linksPointer(in: nodePtr).pointee[1]
    }
    print("  reverse order: \(reverseElements)")

    let correct = elements == [10, 20, 30, 40] && reverseElements == [40, 30, 20, 10]
    print("V4b: [element-first + withUnsafeMutablePointer] Round-trip correct: \(correct)")
}

// ============================================================================
// MARK: - Variant 5: nodeAt pattern — Element on methods, not on Link
// Hypothesis: Operations can be generic over Element via methods (not the type),
//             keeping Link<N> Element-free while using the simpler nodeAt closure
// Result: <pending>
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

enum LinkC<let N: Int> {
    @frozen
    public struct Node<Element: ~Copyable>: ~Copyable {
        public var element: Element
        public var links: InlineArray<N, Index<Node>>

        public init(element: consuming Element, links: InlineArray<N, Index<Node>>) {
            self.element = element
            self.links = links
        }
    }

    @inlinable @unsafe
    public static func append<Element: ~Copyable>(
        _ index: Index<Node<Element>>,
        header: inout LinkH<N>.Header<Node<Element>>,
        _ nodeAt: (Index<Node<Element>>) -> UnsafeMutablePointer<Node<Element>>
    ) {
        let sentinel = header.sentinel
        if header.tail != sentinel {
            unsafe nodeAt(header.tail).pointee.links[0] = index
            if N >= 2 { unsafe nodeAt(index).pointee.links[1] = header.tail }
        } else {
            header.head = index
        }
        header.tail = index
        unsafe nodeAt(index).pointee.links[0] = sentinel
        header.count += .one
    }

    @inlinable @unsafe
    public static func forEach<Element: ~Copyable>(
        header: LinkH<N>.Header<Node<Element>>,
        _ nodeAt: (Index<Node<Element>>) -> UnsafeMutablePointer<Node<Element>>,
        _ body: (Index<Node<Element>>) -> Void
    ) {
        let sentinel = header.sentinel
        var current = header.head
        while current != sentinel {
            let next = unsafe nodeAt(current).pointee.links[0]
            body(current)
            current = next
        }
    }
}

extension LinkC.Node: Copyable where Element: Copyable {}
extension LinkC.Node: @unchecked Sendable where Element: Sendable {}

do {
    typealias N = LinkC<2>.Node<Int>
    typealias H = LinkH<2>.Header<N>

    let capacity = 4
    let sentinel = Index<N>(Ordinal(UInt(capacity)))
    let pool = UnsafeMutableBufferPointer<N>.allocate(capacity: capacity)
    defer { pool.deallocate() }

    for i in 0..<capacity {
        let links = InlineArray<2, Index<N>>(repeating: sentinel)
        pool.baseAddress!.advanced(by: i).initialize(to: N(element: (i + 1) * 10, links: links))
    }

    var header = H(sentinel: sentinel)

    let nodeAt: (Index<N>) -> UnsafeMutablePointer<N> = { idx in
        pool.baseAddress!.advanced(by: Int(idx.rawValue.rawValue))
    }

    for i in 0..<capacity {
        let idx = Index<N>(Ordinal(UInt(i)))
        unsafe LinkC<2>.append(idx, header: &header, nodeAt)
    }

    print("V5a: [nodeAt, Element on methods] After appending 4 nodes:")
    print("  head=\(header.head), tail=\(header.tail), count=\(header.count)")

    var elements: [Int] = []
    unsafe LinkC<2>.forEach(header: header, nodeAt) { idx in
        let nodePtr = pool.baseAddress!.advanced(by: Int(idx.rawValue.rawValue))
        elements.append(nodePtr.pointee.element)
    }
    print("  traversal order: \(elements)")

    var reverseElements: [Int] = []
    var current = header.tail
    while current != sentinel {
        let nodePtr = pool.baseAddress!.advanced(by: Int(current.rawValue.rawValue))
        reverseElements.append(nodePtr.pointee.element)
        current = nodePtr.pointee.links[1]
    }
    print("  reverse order: \(reverseElements)")

    let correct = elements == [10, 20, 30, 40] && reverseElements == [40, 30, 20, 10]
    print("V5b: [nodeAt, Element on methods] Round-trip correct: \(correct)")
}

// ============================================================================
// MARK: - Results Summary
// V1: REFUTED — MemoryLayout.offset(of:) requires Copyable (key path limitation)
// V2: CONFIRMED — Copyable Sendable struct with ~Copyable phantom tag compiles + works
// V3: CONFIRMED — links-first layout, linksAt closure, offset 0, round-trip correct
// V4: CONFIRMED — element-first layout, withUnsafeMutablePointer, round-trip correct
// V5: CONFIRMED — nodeAt pattern, Element on methods not type, round-trip correct
// ============================================================================
