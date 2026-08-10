// MARK: - Array.Protocol Feasibility Experiment
// Purpose: Validate whether a ~Copyable protocol can unify Array operations
//          across Copyable, ~Copyable, and value-generic array types.
//
// Hypothesis: Swift 6.2 with SuppressedAssociatedTypes supports ~Copyable
//             protocol with associatedtype Element: ~Copyable, enabling
//             subscript and element-typed operations in the protocol.
//
// Prior Art: Bit.Vector.Protocol experiment (CONFIRMED 2026-02-12)
//
// Toolchain: Apple Swift 6.2
// Platform: macOS 26.0 (arm64)
// Feature flag: SuppressedAssociatedTypes
//
// Result: CONFIRMED — all 13 variants pass
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-02-16
//
// Evidence: Build Succeeded, all assertions pass at runtime.
// Key enabler: SuppressedAssociatedTypes allows associatedtype Element: ~Copyable
// Workaround: subscript { get set } in protocol, _read/_modify in ~Copyable conformers
//             (same compiler bug as Bit.Vector.Protocol)
// Property.View: Protocol-constrained Property.View.Typed<Element> delegation
//                works per [IMPL-026], enabling forEach/withElement as protocol defaults.

// =============================================================================
// MARK: - V1: Protocol Definition
// =============================================================================

// Hypothesis: ~Copyable protocol with associatedtype Element: ~Copyable,
//             associatedtype Index, and subscript requirement works.

protocol __ArrayProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Index: Comparable

    /// The number of elements.
    var count: Int { get }

    /// The first valid index.
    var startIndex: Index { get }

    /// The past-the-end index.
    var endIndex: Index { get }

    /// Returns the index after the given index.
    func index(after i: Index) -> Index

    /// Returns the index before the given index.
    func index(before i: Index) -> Index

    /// Element access. Protocol REQUIREMENT (not default) because subscript
    /// get/set as default in ~Copyable extension crashes compiler
    /// (known bug from Bit.Vector.Protocol experiment).
    subscript(index: Index) -> Element { get set }
}

// =============================================================================
// MARK: - V2: Default implementations
// =============================================================================

// Hypothesis: isEmpty, withElement, forEachIndex work as defaults on ~Copyable Self.

extension __ArrayProtocol where Self: ~Copyable {
    var isEmpty: Bool { count == 0 }

    func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        body(self[index])
    }

    func forEachIndex(_ body: (Index) -> Void) {
        var i = startIndex
        while i < endIndex {
            body(i)
            i = index(after: i)
        }
    }
}

// =============================================================================
// MARK: - V3: ~Copyable conformer (stand-in for Array/Dynamic)
// =============================================================================

struct DynamicArray: ~Copyable, __ArrayProtocol {
    private var _storage: UnsafeMutablePointer<Int>
    private var _count: Int
    private var _capacity: Int

    init(capacity: Int = 4) {
        _capacity = max(capacity, 1)
        _storage = .allocate(capacity: _capacity)
        _count = 0
    }

    deinit {
        _storage.deinitialize(count: _count)
        _storage.deallocate()
    }

    typealias Element = Int
    typealias Index = Int

    var count: Int { _count }
    var startIndex: Int { 0 }
    var endIndex: Int { _count }
    func index(after i: Int) -> Int { i + 1 }
    func index(before i: Int) -> Int { i - 1 }

    subscript(index: Int) -> Int {
        get {
            precondition(index >= 0 && index < _count)
            return _storage[index]
        }
        set {
            precondition(index >= 0 && index < _count)
            _storage[index] = newValue
        }
    }

    mutating func append(_ element: Int) {
        if _count == _capacity {
            let newCap = _capacity * 2
            let newStorage = UnsafeMutablePointer<Int>.allocate(capacity: newCap)
            newStorage.moveInitialize(from: _storage, count: _count)
            _storage.deallocate()
            _storage = newStorage
            _capacity = newCap
        }
        (_storage + _count).initialize(to: element)
        _count += 1
    }
}

// =============================================================================
// MARK: - V4: Copyable conformer (stand-in for Array.Fixed)
// =============================================================================

struct FixedArray: __ArrayProtocol, Sendable {
    private var _elements: [Int]

    init(count: Int, initializer: (Int) -> Int) {
        _elements = (0..<count).map(initializer)
    }

    typealias Element = Int
    typealias Index = Int

    var count: Int { _elements.count }
    var startIndex: Int { 0 }
    var endIndex: Int { _elements.count }
    func index(after i: Int) -> Int { i + 1 }
    func index(before i: Int) -> Int { i - 1 }

    subscript(index: Int) -> Int {
        get { _elements[index] }
        set { _elements[index] = newValue }
    }
}

// =============================================================================
// MARK: - V5: Value-generic conformer (stand-in for Array.Static<capacity>)
// =============================================================================

struct StaticArray<let capacity: Int>: ~Copyable, __ArrayProtocol {
    private var _storage: InlineArray<capacity, Int>
    private var _count: Int

    init() {
        _storage = InlineArray(repeating: 0)
        _count = 0
    }

    typealias Element = Int
    typealias Index = Int

    var count: Int { _count }
    var startIndex: Int { 0 }
    var endIndex: Int { _count }
    func index(after i: Int) -> Int { i + 1 }
    func index(before i: Int) -> Int { i - 1 }

    subscript(index: Int) -> Int {
        get {
            precondition(index >= 0 && index < _count)
            return _storage[index]
        }
        set {
            precondition(index >= 0 && index < _count)
            _storage[index] = newValue
        }
    }

    mutating func append(_ element: Int) {
        precondition(_count < capacity)
        _storage[_count] = element
        _count += 1
    }
}

// =============================================================================
// MARK: - V6: Different Index type (stand-in for Array.Bounded<N>)
// =============================================================================

struct BoundedIndex<let N: Int>: Comparable, Sendable {
    let rawValue: Int
    init(_ value: Int) {
        precondition(value >= 0 && value <= N)
        self.rawValue = value
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.rawValue == rhs.rawValue }
}

struct BoundedArray<let N: Int>: ~Copyable, __ArrayProtocol {
    private var _storage: UnsafeMutablePointer<Int>

    init(initializer: (Int) -> Int) {
        _storage = .allocate(capacity: N)
        for i in 0..<N { (_storage + i).initialize(to: initializer(i)) }
    }

    deinit {
        _storage.deinitialize(count: N)
        _storage.deallocate()
    }

    typealias Element = Int
    typealias Index = BoundedIndex<N>

    var count: Int { N }
    var startIndex: Index { Index(0) }
    var endIndex: Index { Index(N) }
    func index(after i: Index) -> Index { Index(i.rawValue + 1) }
    func index(before i: Index) -> Index { Index(i.rawValue - 1) }

    subscript(index: Index) -> Int {
        get { _storage[index.rawValue] }
        set { _storage[index.rawValue] = newValue }
    }
}

// =============================================================================
// MARK: - V3b: ~Copyable ELEMENTS (stand-in for Array<Token>)
// =============================================================================

struct Token: ~Copyable {
    let id: Int
}

struct TokenArray: ~Copyable, __ArrayProtocol {
    private var _storage: UnsafeMutablePointer<Token>
    private var _count: Int
    private var _capacity: Int

    init(capacity: Int = 4) {
        _capacity = max(capacity, 1)
        _storage = .allocate(capacity: _capacity)
        _count = 0
    }

    deinit {
        for i in 0..<_count { (_storage + i).deinitialize(count: 1) }
        _storage.deallocate()
    }

    typealias Element = Token
    typealias Index = Int

    var count: Int { _count }
    var startIndex: Int { 0 }
    var endIndex: Int { _count }
    func index(after i: Int) -> Int { i + 1 }
    func index(before i: Int) -> Int { i - 1 }

    subscript(index: Int) -> Token {
        _read {
            precondition(index >= 0 && index < _count)
            yield _storage[index]
        }
        _modify {
            precondition(index >= 0 && index < _count)
            yield &_storage[index]
        }
    }

    mutating func append(_ element: consuming Token) {
        if _count == _capacity {
            let newCap = _capacity * 2
            let newStorage = UnsafeMutablePointer<Token>.allocate(capacity: newCap)
            newStorage.moveInitialize(from: _storage, count: _count)
            _storage.deallocate()
            _storage = newStorage
            _capacity = newCap
        }
        (_storage + _count).initialize(to: element)
        _count += 1
    }

    mutating func removeLast() -> Token? {
        guard _count > 0 else { return nil }
        _count -= 1
        return (_storage + _count).move()
    }
}

// =============================================================================
// MARK: - V7: Generic function over all conformers
// =============================================================================

func testAll<V: __ArrayProtocol & ~Copyable>(
    _ v: borrowing V, label: String
) where V.Element == Int {
    print("--- \(label) ---")
    print("  count=\(v.count) isEmpty=\(v.isEmpty)")

    // Forward navigation
    var fwdCount = 0
    var i = v.startIndex
    while i < v.endIndex {
        fwdCount += 1
        i = v.index(after: i)
    }
    assert(fwdCount == v.count)
    print("  forward nav: \(fwdCount) indices")

    // Subscript via protocol
    let first = v[v.startIndex]
    print("  subscript[start]: \(first)")

    // withElement default
    v.withElement(at: v.startIndex) { elem in
        print("  withElement[start]: \(elem)")
    }

    // forEachIndex default + subscript
    var sum = 0
    v.forEachIndex { idx in sum += v[idx] }
    print("  forEachIndex sum: \(sum)")

    // Backward navigation
    if v.count >= 2 {
        let last = v.index(before: v.endIndex)
        print("  backward nav last: \(v[last])")
    }

    print("  PASS")
}

// =============================================================================
// MARK: - V8: Borrowing generic read-only
// =============================================================================

func readOnlyCount<V: __ArrayProtocol & ~Copyable>(_ v: borrowing V) -> Int {
    v.count
}

func readOnlyIsEmpty<V: __ArrayProtocol & ~Copyable>(_ v: borrowing V) -> Bool {
    v.isEmpty
}

// =============================================================================
// MARK: - V9: Generic with ~Copyable Element
// =============================================================================

func testNoncopyableElements<V: __ArrayProtocol & ~Copyable>(
    _ v: borrowing V, label: String
) where V.Element == Token {
    print("--- \(label) ---")
    print("  count=\(v.count) isEmpty=\(v.isEmpty)")

    // withElement default — borrowing access to ~Copyable element
    v.withElement(at: v.startIndex) { elem in
        print("  withElement[start]: Token(id: \(elem.id))")
    }

    // forEachIndex + withElement
    print("  forEachIndex + withElement: ", terminator: "")
    v.forEachIndex { idx in
        v.withElement(at: idx) { elem in
            print("Token(\(elem.id)) ", terminator: "")
        }
    }
    print()

    print("  PASS")
}

// =============================================================================
// MARK: - V10: Property.View stand-in (matches swift-property-primitives)
// =============================================================================

// Minimal replica of Property<Tag, Base>.View.Typed<Element>
// to test protocol-constrained Property.View delegation per [IMPL-026].

struct __Property<Tag, Base: ~Copyable>: ~Copyable {
    var _base: Base
    init(_ base: consuming Base) { _base = base }
}

extension __Property: Copyable where Base: Copyable {}

extension __Property where Base: ~Copyable {
    struct View: ~Copyable, ~Escapable {
        let _base: UnsafeMutablePointer<Base>

        @_lifetime(borrow base)
        init(_ base: UnsafeMutablePointer<Base>) {
            unsafe _base = base
        }

        var base: UnsafeMutablePointer<Base> {
            unsafe _base
        }
    }
}

extension __Property.View where Base: ~Copyable {
    struct Typed<Element: ~Copyable>: ~Copyable, ~Escapable {
        let _base: UnsafeMutablePointer<Base>

        @_lifetime(borrow base)
        init(_ base: UnsafeMutablePointer<Base>) {
            unsafe _base = base
        }

        var base: UnsafeMutablePointer<Base> {
            unsafe _base
        }
    }
}

// Tag types for Property.View operations
enum ForEach {}
enum WithElement {}

// =============================================================================
// MARK: - V11: Protocol default provides Property.View.Typed accessor
// =============================================================================

// Hypothesis: __ArrayProtocol where Self: ~Copyable can provide default
//             var forEach: __Property<ForEach, Self>.View.Typed<Element>
//             with _read/_modify coroutines, serving ALL conformers.

extension __ArrayProtocol where Self: ~Copyable {
    var forEach: __Property<ForEach, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe __Property<ForEach, Self>.View.Typed<Element>(&self)
        }
        mutating _modify {
            var view = unsafe __Property<ForEach, Self>.View.Typed<Element>(&self)
            yield &view
        }
    }

    var withElement: __Property<WithElement, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe __Property<WithElement, Self>.View.Typed<Element>(&self)
        }
        mutating _modify {
            var view = unsafe __Property<WithElement, Self>.View.Typed<Element>(&self)
            yield &view
        }
    }
}

// =============================================================================
// MARK: - V12: Property.View.Typed extension with protocol constraint on Base
// =============================================================================

// Hypothesis: Property.View.Typed extensions CAN use
//             Base: __ArrayProtocol & ~Copyable, Element == Base.Element
//             instead of Base == ConcreteType.

extension __Property.View.Typed
where Tag == ForEach, Base: __ArrayProtocol & ~Copyable, Element: ~Copyable, Element == Base.Element
{
    // forEach.index { } — iterate indices via protocol
    func index(_ body: (Base.Index) -> Void) {
        var i = unsafe base.pointee.startIndex
        while unsafe i < base.pointee.endIndex {
            body(i)
            i = unsafe base.pointee.index(after: i)
        }
    }
}

// ForEach with Copyable Element constraint — can pass element values
extension __Property.View.Typed
where Tag == ForEach, Base: __ArrayProtocol & ~Copyable, Element: Copyable, Element == Base.Element
{
    func callAsFunction(_ body: (Element) -> Void) {
        var i = unsafe base.pointee.startIndex
        while unsafe i < base.pointee.endIndex {
            body(unsafe base.pointee[i])
            i = unsafe base.pointee.index(after: i)
        }
    }
}

extension __Property.View.Typed
where Tag == WithElement, Base: __ArrayProtocol & ~Copyable, Element: ~Copyable, Element == Base.Element
{
    // withElement.at(index) { } — borrowing access to element
    func at(_ index: Base.Index, _ body: (borrowing Element) -> Void) {
        body(unsafe base.pointee[index])
    }
}

// =============================================================================
// MARK: - V13: Generic function using protocol Property.View accessor
// =============================================================================

func testForEachViaProtocol<V: __ArrayProtocol & ~Copyable>(
    _ v: inout V, label: String
) where V.Element == Int {
    print("--- \(label) ---")

    // forEach.index via protocol-provided accessor (index-only, no element access)
    var indexCount = 0
    v.forEach.index { _ in indexCount += 1 }
    print("  forEach.index count: \(indexCount)")
    assert(indexCount == v.count)

    // forEach via callAsFunction (Element: Copyable, passes element through pointer)
    var sum = 0
    v.forEach { element in sum += element }
    print("  forEach { } sum: \(sum)")

    // withElement.at via protocol-provided accessor
    v.withElement.at(v.startIndex) { elem in
        print("  withElement.at(start): \(elem)")
    }

    print("  PASS")
}

// =============================================================================
// MARK: - Execution
// =============================================================================

print("=== Array.Protocol Feasibility Experiment ===")
print("Feature flag: SuppressedAssociatedTypes\n")

// V3: ~Copyable conformer
do {
    var dyn = DynamicArray(capacity: 4)
    dyn.append(10); dyn.append(20); dyn.append(30)
    testAll(dyn, label: "V3: DynamicArray (~Copyable, heap)")

    dyn[0] = 99
    assert(dyn[0] == 99)
    print("  subscript _modify: [0]=\(dyn[0])")

    assert(readOnlyCount(dyn) == 3)
    print("  V8: count=\(readOnlyCount(dyn)) isEmpty=\(readOnlyIsEmpty(dyn))")
    print()
}

// V4: Copyable conformer
do {
    let fixed = FixedArray(count: 5) { $0 * 10 }
    testAll(fixed, label: "V4: FixedArray (Copyable)")

    let fixed2 = fixed
    assert(fixed.count == fixed2.count)
    print("  Copyable: fixed.count=\(fixed.count) fixed2.count=\(fixed2.count)")
    print()
}

// V5: Value-generic conformer
do {
    var stat = StaticArray<8>()
    stat.append(100); stat.append(200); stat.append(300)
    testAll(stat, label: "V5: StaticArray<8> (value-generic)")

    stat[1] = 999
    assert(stat[1] == 999)
    print("  subscript _modify: [1]=\(stat[1])")
    print()
}

// V6: Different Index type
do {
    let bounded = BoundedArray<4>(initializer: { $0 * 5 })
    print("--- V6: BoundedArray<4> (BoundedIndex<4>) ---")
    print("  count=\(bounded.count) isEmpty=\(bounded.isEmpty)")
    let idx0 = BoundedIndex<4>(0)
    let idx3 = BoundedIndex<4>(3)
    print("  subscript: [0]=\(bounded[idx0]) [3]=\(bounded[idx3])")

    // withElement default
    bounded.withElement(at: idx0) { print("  withElement[0]: \($0)") }

    // forEachIndex
    var sum = 0
    bounded.forEachIndex { idx in sum += bounded[idx] }
    print("  forEachIndex sum: \(sum)")
    assert(sum == 0 + 5 + 10 + 15)

    assert(readOnlyCount(bounded) == 4)
    print("  V8: count=\(readOnlyCount(bounded))")
    print("  PASS")
    print()
}

// V3b + V9: ~Copyable elements
do {
    var tokens = TokenArray(capacity: 4)
    tokens.append(Token(id: 1))
    tokens.append(Token(id: 2))
    tokens.append(Token(id: 3))
    testNoncopyableElements(tokens, label: "V3b+V9: TokenArray (~Copyable elements)")

    let removed = tokens.removeLast()!
    print("  removeLast: Token(id: \(removed.id)) count=\(tokens.count)")

    assert(readOnlyCount(tokens) == 2)
    print("  V8: count=\(readOnlyCount(tokens))")
    print()
}

// V10+V11+V12: Property.View protocol delegation with Copyable elements
do {
    var dyn = DynamicArray(capacity: 4)
    dyn.append(10); dyn.append(20); dyn.append(30)
    testForEachViaProtocol(&dyn, label: "V10-12: DynamicArray Property.View")
    print()
}

do {
    var fixed = FixedArray(count: 3) { ($0 + 1) * 10 }
    testForEachViaProtocol(&fixed, label: "V10-12: FixedArray Property.View")
    print()
}

do {
    var stat = StaticArray<8>()
    stat.append(100); stat.append(200); stat.append(300)
    testForEachViaProtocol(&stat, label: "V10-12: StaticArray<8> Property.View")
    print()
}

// V10+V11+V12: Property.View with ~Copyable elements (index-only, no callAsFunction)
do {
    var tokens = TokenArray(capacity: 4)
    tokens.append(Token(id: 10))
    tokens.append(Token(id: 20))
    tokens.append(Token(id: 30))
    print("--- V10-12: TokenArray Property.View (~Copyable elements) ---")

    // forEach.index works with ~Copyable elements
    var count = 0
    tokens.forEach.index { _ in count += 1 }
    print("  forEach.index count: \(count)")
    assert(count == 3)

    // withElement.at works with ~Copyable elements
    tokens.withElement.at(tokens.startIndex) { elem in
        print("  withElement.at(start): Token(id: \(elem.id))")
    }

    print("  PASS")
    print()
}

print("=== RESULTS ===")
print()
print("V1:  Protocol with associatedtype Element: ~Copyable  -> CONFIRMED")
print("V2:  Default isEmpty, withElement, forEachIndex        -> CONFIRMED")
print("V3:  ~Copyable conformer (DynamicArray)                -> CONFIRMED")
print("V4:  Copyable conformer (FixedArray)                   -> CONFIRMED")
print("V5:  Value-generic conformer (StaticArray<8>)          -> CONFIRMED")
print("V6:  Different Index type (BoundedArray<4>)            -> CONFIRMED")
print("V7:  Generic function <V: Protocol & ~Copyable>        -> CONFIRMED")
print("V8:  Borrowing generic read-only                       -> CONFIRMED")
print("V9:  Generic with ~Copyable Element (TokenArray)       -> CONFIRMED")
print("V10: Property.View.Typed stand-in types                -> CONFIRMED")
print("V11: Protocol default Property.View.Typed accessor     -> CONFIRMED")
print("V12: Property.View.Typed protocol-constrained methods  -> CONFIRMED")
print("V13: Generic function using protocol Property.View     -> CONFIRMED")
print()
print("=== ALL 13 VARIANTS CONFIRMED ===")
