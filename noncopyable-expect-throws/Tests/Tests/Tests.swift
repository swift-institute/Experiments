// MARK: - Noncopyable #expect(throws:) Interaction
// Purpose: Isolate which combination of factors causes #expect(throws:)
//          to hang when used with ~Copyable types.
// Hypothesis: The hang requires a specific combination of factors present in
//             Dictionary.Ordered.Static but absent from a minimal ~Copyable struct.
//
// Toolchain: TBD
// Platform: macOS (arm64)
//
// Phase 1 Result: REFUTED — minimal ~Copyable + #expect(throws:) works fine.
// Phase 2: Incrementally add complexity factors.
// Date: 2026-02-10

import Testing

// MARK: - Phase 1: Minimal (CONFIRMED: all pass)

struct Box: ~Copyable {
    var value: Int = 0
    enum Err: Error, Equatable { case full }

    mutating func fill() throws(Err) {
        guard value < 2 else { throw .full }
        value += 1
    }

    func check() throws(Err) {
        guard value < 2 else { throw .full }
    }
}

@Suite("Phase 1: Minimal")
struct Phase1 {
    @Test func `Copyable control`() {
        struct CopyBox {
            var value: Int = 0
            enum Err: Error { case full }
            mutating func fill() throws(Err) {
                guard value < 2 else { throw .full }
                value += 1
            }
        }
        var box = CopyBox()
        try! box.fill()
        try! box.fill()
        #expect(throws: CopyBox.Err.self) { try box.fill() }
    }

    @Test func `Noncopyable do-catch`() {
        var box = Box()
        try! box.fill()
        try! box.fill()
        do {
            try box.fill()
            Issue.record("Expected Err.full")
        } catch {}
    }

    @Test func `Noncopyable expect-throws mutating`() {
        var box = Box()
        try! box.fill()
        try! box.fill()
        #expect(throws: Box.Err.self) { try box.fill() }
    }

    @Test func `Noncopyable expect-throws non-mutating`() {
        var box = Box()
        try! box.fill()
        try! box.fill()
        #expect(throws: Box.Err.self) { try box.check() }
    }
}

// MARK: - Phase 2: Add deinit

struct BoxWithDeinit: ~Copyable {
    var value: Int = 0
    enum Err: Error, Equatable { case full }

    mutating func fill() throws(Err) {
        guard value < 2 else { throw .full }
        value += 1
    }

    deinit {}
}

@Suite("Phase 2: With deinit")
struct Phase2 {
    @Test func `Noncopyable with deinit`() {
        var box = BoxWithDeinit()
        try! box.fill()
        try! box.fill()
        #expect(throws: BoxWithDeinit.Err.self) { try box.fill() }
    }
}

// MARK: - Phase 3: Add AnyObject? field (deinit workaround pattern)

struct BoxWithAnyObject: ~Copyable {
    var value: Int = 0
    var _workaround: AnyObject? = nil
    enum Err: Error, Equatable { case full }

    mutating func fill() throws(Err) {
        guard value < 2 else { throw .full }
        value += 1
    }

    deinit {}
}

@Suite("Phase 3: With AnyObject?")
struct Phase3 {
    @Test func `Noncopyable with AnyObject workaround`() {
        var box = BoxWithAnyObject()
        try! box.fill()
        try! box.fill()
        #expect(throws: BoxWithAnyObject.Err.self) { try box.fill() }
    }
}

// MARK: - Phase 4: Value generic parameter

struct BoxGeneric<let capacity: Int>: ~Copyable {
    var value: Int = 0
    enum Err: Error, Equatable { case full }

    mutating func fill() throws(Err) {
        guard value < capacity else { throw .full }
        value += 1
    }

    deinit {}
}

@Suite("Phase 4: Value generic")
struct Phase4 {
    @Test func `Value generic with deinit`() {
        var box = BoxGeneric<2>()
        try! box.fill()
        try! box.fill()
        #expect(throws: BoxGeneric<2>.Err.self) { try box.fill() }
    }
}

// MARK: - Phase 5: Nested ~Copyable field with deinit

struct InnerResource: ~Copyable {
    var data: Int = 0
    deinit {}
}

struct BoxWithNestedNoncopyable: ~Copyable {
    var inner: InnerResource
    var count: Int = 0
    enum Err: Error, Equatable { case full }

    init() {
        self.inner = InnerResource()
    }

    mutating func fill() throws(Err) {
        guard count < 2 else { throw .full }
        count += 1
        inner.data += 1
    }

    deinit {}
}

@Suite("Phase 5: Nested ~Copyable field")
struct Phase5 {
    @Test func `Nested noncopyable with deinit`() {
        var box = BoxWithNestedNoncopyable()
        try! box.fill()
        try! box.fill()
        #expect(throws: BoxWithNestedNoncopyable.Err.self) { try box.fill() }
    }
}

// MARK: - Phase 6: Multiple ~Copyable fields + value generic + AnyObject?
// This mirrors Dictionary.Ordered.Static's composition:
// - Value generic for capacity
// - Multiple ~Copyable fields (each with deinit)
// - AnyObject? workaround

struct InnerStorage<let cap: Int>: ~Copyable {
    var slots: (Int, Int, Int, Int) = (0, 0, 0, 0)
    var used: Int = 0
    deinit {}
}

struct CompositeBox<let capacity: Int>: ~Copyable {
    var _values: InnerStorage<capacity>
    var _keys: InnerStorage<capacity>
    var _workaround: AnyObject? = nil
    enum Err: Error, Equatable { case full }

    init() {
        _values = InnerStorage<capacity>()
        _keys = InnerStorage<capacity>()
    }

    mutating func set(_ key: Int, _ value: Int) throws(Err) {
        guard _values.used < capacity else { throw .full }
        _values.used += 1
        _keys.used += 1
    }

    deinit {}
}

@Suite("Phase 6: Full composition")
struct Phase6 {
    @Test func `Composite noncopyable mirrors Static`() {
        var box = CompositeBox<2>()
        try! box.set(1, 10)
        try! box.set(2, 20)
        #expect(throws: CompositeBox<2>.Err.self) { try box.set(3, 30) }
    }
}

// MARK: - Phase 7: Deep type nesting (Dictionary<K,V>.Ordered.Static<N> pattern)

enum Outer<Key: Hashable, Value> {
    struct Inner: ~Copyable {
        struct Static<let capacity: Int>: ~Copyable {
            var count: Int = 0
            var _storage: InnerStorage<capacity>
            enum Err: Error, Equatable { case full }

            init() {
                _storage = InnerStorage<capacity>()
            }

            mutating func set(_ value: Int) throws(Err) {
                guard count < capacity else { throw .full }
                count += 1
            }

            deinit {}
        }
    }
}

@Suite("Phase 7: Deep nesting")
struct Phase7 {
    @Test func `Deeply nested type mirrors Dictionary pattern`() {
        var dict = Outer<String, Int>.Inner.Static<2>()
        try! dict.set(1)
        try! dict.set(2)
        #expect(throws: Outer<String, Int>.Inner.Static<2>.Err.self) { try dict.set(3) }
    }
}
