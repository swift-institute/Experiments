// MARK: - Hash Table Context-Passing Lookup Validation
// Purpose: Validate that a context-passing overload on hash-table lookup avoids
//          the closure capture problem for ~Copyable elements, restoring O(1) contains.
//
// Key question: Can `position(forHash:context:equals:)` where context is
//               `borrowing Context: ~Copyable` enable hash-table lookup without
//               capturing the element in a closure?
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Context-passing enables O(1) for all container types:
//
//   F4: Context-passing API compiles and runs for ~Copyable context.
//       `position(forHash:context:equals:)` where `context: borrowing Context: ~Copyable`
//       passes the element through to the closure as a parameter — NOT captured.
//       The closure captures only Copyable values (Array buffer ref). This enables
//       O(1) hash-table lookup for Set.Ordered and Set.Ordered.Fixed (class-backed buffers).
//
//   F5: Probe iterator (ProbeSequence) is a Copyable value type that yields
//       candidate positions. The caller checks equality directly via
//       `buffer[pos] == element` — no closure needed at all. This is the
//       closure-free path for any context.
//
//   F6: ~Copyable containers (inline buffers) cannot capture `self` in closures.
//       Extensions that access ~Copyable stored properties (even via subscript
//       or `if let`) get implicit `where Element: Copyable` constraints.
//       For Set.Ordered.Static and Small, the O(1) path requires either:
//       (a) Probe iterator + borrowing subscript access, or
//       (b) Copyable-constrained O(1) overload alongside the unconstrained O(n) witness.
//
//   F7: Implicit `where Element: Copyable` on ALL extensions of ~Copyable generic
//       types — even empty functions. `extension NCBuffer { func empty() {} }` gets
//       implicit Copyable. Fix: explicit `where Element: ~Copyable` opt-out on extension.
//       Root cause: `extension Foo<T>` implicitly constrains `T: Copyable` unless
//       the extension explicitly writes `where T: ~Copyable`.
//
//   F8 (H5 CONFIRMED): ~Copyable container with context-passing lookup works when:
//       (a) The extension has explicit `where Element: ~Copyable` (or `& ~Copyable`),
//       (b) A Copyable storage handle (e.g., UnsafeMutablePointer) is extracted to a
//           local and captured in the closure instead of self,
//       (c) The element is passed as `borrowing Context` parameter — not captured.
//       Tested with NCBuffer<MoveOnlyKey> where MoveOnlyKey: ~Copyable.
//       lookup(20) = true, lookup(99) = false. Build Succeeded.
//
//   All V1-V6 variants compile and run with correct results. Build Succeeded.
//
// Date: 2026-03-02

// ============================================================================
// MARK: - Infrastructure
// ============================================================================

protocol EqProto: ~Copyable {
    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

protocol HashProto: EqProto & ~Copyable {
    borrowing func hash(into hasher: inout Hasher)
}

extension Int: EqProto {}
extension Int: HashProto {}

struct MoveOnlyKey: ~Copyable, HashProto {
    let value: Int
    init(_ value: Int) { self.value = value }
    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.value == rhs.value
    }
    borrowing func hash(into hasher: inout Hasher) { hasher.combine(value) }
}

func computeHash<T: HashProto & ~Copyable>(_ value: borrowing T) -> Int {
    var hasher = Hasher()
    value.hash(into: &hasher)
    return hasher.finalize()
}

// ============================================================================
// MARK: - Simulated Hash Table (Copyable — mirrors real Hash.Table)
// ============================================================================

struct SimHashTable {
    var hashes: [Int]
    var positions: [Int]
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.hashes = [Int](repeating: 0, count: capacity)
        self.positions = [Int](repeating: -1, count: capacity)
    }

    static func normalize(_ hashValue: Int) -> Int {
        hashValue == 0 ? 1 : (hashValue == Int.min ? 1 : hashValue)
    }

    mutating func insert(position: Int, hashValue: Int) {
        let hash = Self.normalize(hashValue)
        var bucket = Int(UInt(bitPattern: hash) % UInt(capacity))
        while hashes[bucket] != 0 { bucket = (bucket + 1) % capacity }
        hashes[bucket] = hash
        positions[bucket] = position
    }

    // Existing closure-based lookup
    borrowing func position(
        forHash hashValue: Int,
        equals: (Int) -> Bool
    ) -> Int? {
        let hash = Self.normalize(hashValue)
        var bucket = Int(UInt(bitPattern: hash) % UInt(capacity))
        var probes = 0
        while probes < capacity {
            let storedHash = hashes[bucket]
            if storedHash == 0 { return nil }
            if storedHash == hash {
                if equals(positions[bucket]) { return positions[bucket] }
            }
            bucket = (bucket + 1) % capacity
            probes += 1
        }
        return nil
    }
}

// ============================================================================
// MARK: - V1: Context-passing lookup API
// Hypothesis: A `borrowing Context: ~Copyable` parameter passed through to
//             the closure as a parameter (not captured) compiles.
// ============================================================================

extension SimHashTable {
    borrowing func position<Context: ~Copyable>(
        forHash hashValue: Int,
        context: borrowing Context,
        equals: (Int, borrowing Context) -> Bool
    ) -> Int? {
        let hash = Self.normalize(hashValue)
        var bucket = Int(UInt(bitPattern: hash) % UInt(capacity))
        var probes = 0
        while probes < capacity {
            let storedHash = hashes[bucket]
            if storedHash == 0 { return nil }
            if storedHash == hash {
                if equals(positions[bucket], context) { return positions[bucket] }
            }
            bucket = (bucket + 1) % capacity
            probes += 1
        }
        return nil
    }
}

// ============================================================================
// MARK: - V2: Probe iterator API (closure-free)
// Hypothesis: A Copyable iterator over probe positions enables external
//             equality checking without any closure capture.
// ============================================================================

extension SimHashTable {
    struct ProbeSequence {
        let hash: Int
        let hashes: [Int]
        let positions: [Int]
        let capacity: Int
        var bucket: Int
        var probes: Int

        mutating func next() -> Int? {
            while probes < capacity {
                let storedHash = hashes[bucket]
                if storedHash == 0 { return nil }
                if storedHash == hash {
                    let pos = positions[bucket]
                    bucket = (bucket + 1) % capacity
                    probes += 1
                    return pos
                }
                bucket = (bucket + 1) % capacity
                probes += 1
            }
            return nil
        }
    }

    borrowing func candidates(forHash hashValue: Int) -> ProbeSequence {
        let hash = Self.normalize(hashValue)
        return ProbeSequence(
            hash: hash, hashes: hashes, positions: positions,
            capacity: capacity,
            bucket: Int(UInt(bitPattern: hash) % UInt(capacity)),
            probes: 0
        )
    }
}

// ============================================================================
// MARK: - Protocol
// ============================================================================

protocol SetProto: ~Copyable {
    associatedtype Element: HashProto & ~Copyable
    func contains(_ element: borrowing Element) -> Bool
    func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)
}

extension SetProto where Self: ~Copyable {
    func isDisjoint<Other: SetProto & ~Copyable>(
        with other: borrowing Other
    ) -> Bool where Other.Element == Element {
        var disjoint = true
        forEach { element in
            if disjoint, other.contains(element) { disjoint = false }
        }
        return disjoint
    }
}

// ============================================================================
// MARK: - V3: Context-passing with Copyable buffer (Set.Ordered/Fixed pattern)
//
// This mirrors the real production architecture:
// - Array<Element> is Copyable (reference-counted)
// - Closure captures `elements` (Copyable Array ref) — no problem
// - Element is passed as `context` parameter — not captured
// ============================================================================

struct CopyableBufferSet<Element: HashProto>: ~Copyable {
    var _elements: [Element]
    var _hashTable: SimHashTable

    init(capacity: Int) {
        _elements = []
        _hashTable = SimHashTable(capacity: capacity)
    }

    mutating func insert(_ element: Element) {
        let hashValue = computeHash(element)
        let elements = _elements
        if _hashTable.position(forHash: hashValue, equals: { idx in
            elements[idx] == element
        }) != nil { return }
        let position = _elements.count
        _elements.append(element)
        _hashTable.insert(position: position, hashValue: hashValue)
    }

    func contains(_ element: borrowing Element) -> Bool {
        let hashValue = computeHash(element)
        let elements = _elements  // Copyable Array — captured in closure
        return _hashTable.position(
            forHash: hashValue,
            context: element,
            equals: { idx, elem in elements[idx] == elem }
        ) != nil
    }

    func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        for element in _elements { try body(element) }
    }
}

extension CopyableBufferSet: SetProto {}

// ============================================================================
// MARK: - V4: Standalone context-passing test with ~Copyable element
// Test the API directly without a container.
// ============================================================================

func testContextPassingDirect() {
    var ht = SimHashTable(capacity: 8)

    // Insert 3 elements at positions 0, 1, 2
    let keys = [10, 20, 30]
    for (i, key) in keys.enumerated() {
        ht.insert(position: i, hashValue: computeHash(key))
    }

    // Lookup with Copyable Int — closure-based (baseline)
    let found1 = ht.position(forHash: computeHash(20), equals: { idx in
        keys[idx] == 20
    })
    print("Closure-based (Int):   position(20) = \(found1 as Any)")

    // Lookup with Copyable Int — context-passing
    let found2 = ht.position(forHash: computeHash(20), context: 20, equals: { idx, elem in
        keys[idx] == elem
    })
    print("Context-passing (Int): position(20) = \(found2 as Any)")

    // Lookup with ~Copyable MoveOnlyKey — context-passing
    let mk = MoveOnlyKey(20)
    let found3 = ht.position(forHash: computeHash(mk), context: mk, equals: { idx, elem in
        keys[idx] == elem.value  // compare Int from key to Int stored in array
    })
    print("Context-passing (~Copyable): position(MoveOnlyKey(20)) = \(found3 as Any)")

    // Lookup miss
    let mk2 = MoveOnlyKey(99)
    let found4 = ht.position(forHash: computeHash(mk2), context: mk2, equals: { idx, elem in
        keys[idx] == elem.value
    })
    print("Context-passing (~Copyable): position(MoveOnlyKey(99)) = \(found4 as Any)")
}

// ============================================================================
// MARK: - V5: Probe iterator test with ~Copyable element
// ============================================================================

func testProbeIteratorDirect() {
    var ht = SimHashTable(capacity: 8)

    let keys = [10, 20, 30]
    for (i, key) in keys.enumerated() {
        ht.insert(position: i, hashValue: computeHash(key))
    }

    // Probe iterator — no closure at all
    let mk = MoveOnlyKey(20)
    let hashValue = computeHash(mk)
    var probe = ht.candidates(forHash: hashValue)
    var found: Int? = nil
    while let pos = probe.next() {
        if keys[pos] == mk.value {
            found = pos
            break
        }
    }
    print("Probe iterator (~Copyable): position(MoveOnlyKey(20)) = \(found as Any)")
}

// ============================================================================
// MARK: - V6: ~Copyable container with context-passing (H5 validation)
//
// Hypothesis H5: A nonescaping closure that (a) borrows ~Copyable self for
//   stored property access AND (b) receives `borrowing Context: ~Copyable`
//   as a parameter compiles in an unconstrained extension.
//
// This combines:
//   C3 (proven by Static's `index`): nonescaping closure borrows ~Copyable self
//   F4 (proven by V1): context-passing with `borrowing Context: ~Copyable`
//
// The test: Can both work SIMULTANEOUSLY in the same closure?
// ============================================================================

struct NCBuffer<Element: EqProto & ~Copyable>: ~Copyable {
    // Simulated inline storage using raw memory
    let _storage: UnsafeMutablePointer<Element>
    var _count: Int
    let _capacity: Int

    init(capacity: Int) {
        _storage = .allocate(capacity: capacity)
        _count = 0
        _capacity = capacity
    }

    deinit {
        _storage.deinitialize(count: _count)
        _storage.deallocate()
    }

    subscript(index: Int) -> Element {
        _read {
            precondition(index >= 0 && index < _count)
            yield _storage[index]
        }
    }

    mutating func append(_ element: consuming Element) {
        precondition(_count < _capacity)
        _storage.advanced(by: _count).initialize(to: element)
        _count += 1
    }
}

// ---- V6a: Direct self capture in closure (expected: implicit Copyable) ----
// This tests whether `self[idx]` in a closure on ~Copyable self compiles.
// Expected: FAILS with implicit `where Element: Copyable` (F6 reconfirmed).
//
// extension NCBuffer where Element: HashProto {
//     func lookupViaSelf(_ element: borrowing Element) -> Bool {
//         var ht = SimHashTable(capacity: _capacity * 2)
//         ...
//         return ht.position(
//             forHash: hashValue,
//             context: element,
//             equals: { idx, elem in self[idx] == elem }
//             //                     ↑ captures self → implicit Copyable
//         ) != nil
//     }
// }
//
// Result: REFUTED — `'where Element: Copyable' is implicit here`
// This is F6. Closures capturing ~Copyable self add implicit Copyable constraint.

// ---- V6b: Reduction — find which operation triggers implicit Copyable ----

// V6b-1: Empty function — does the extension itself require Copyable?
// Test WITHOUT ~Copyable opt-out:
extension NCBuffer {
    func v6b1_empty_copyable() -> Bool { return false }
}

// Test WITH ~Copyable opt-out:
extension NCBuffer where Element: ~Copyable {
    func v6b1_empty_nc() -> Bool { return false }
}

// V6b-2: Access stored properties with ~Copyable opt-out
extension NCBuffer where Element: ~Copyable {
    func v6b2_accessProps() -> Int {
        let s = _storage   // UnsafeMutablePointer<Element> — should be Copyable
        let c = _count     // Int
        let _ = s
        return c
    }
}

// V6b-3: Access element through pointer subscript
extension NCBuffer where Element: EqProto & ~Copyable {
    func v6b3_accessElement() -> Bool {
        return _count > 0
    }
}

// V6b-4: Use context-passing closure with Copyable closure body only
extension NCBuffer where Element: HashProto & ~Copyable {
    func v6b4_contextPassingTrivial(_ element: borrowing Element) -> Bool {
        let capacity = _capacity
        var ht = SimHashTable(capacity: capacity * 2)
        var hasher = Hasher()
        element.hash(into: &hasher)
        let hashValue = hasher.finalize()
        return ht.position(
            forHash: hashValue,
            context: element,
            equals: { idx, elem in true }  // trivial closure
        ) != nil
    }
}

// V6b-5: Full context-passing lookup through extracted pointer
// This is the complete H5 test: ~Copyable container, ~Copyable element,
// context-passing closure that captures a Copyable storage handle.
extension NCBuffer where Element: HashProto & ~Copyable {
    func lookup(_ element: borrowing Element) -> Bool {
        let storage = _storage
        let count = _count
        let capacity = _capacity

        // Build hash table over all stored elements
        var ht = SimHashTable(capacity: capacity * 2)
        var i = 0
        while i < count {
            var hasher = Hasher()
            storage[i].hash(into: &hasher)
            ht.insert(position: i, hashValue: hasher.finalize())
            i += 1
        }

        // Lookup element via context-passing
        var hasher = Hasher()
        element.hash(into: &hasher)
        let hashValue = hasher.finalize()

        return ht.position(
            forHash: hashValue,
            context: element,
            equals: { idx, elem in storage[idx] == elem }
            //                     ↑ Copyable ptr  ↑ borrowing parameter
        ) != nil
    }
}

func testH5() {
    // Test with Copyable Int
    var buf1 = NCBuffer<Int>(capacity: 8)
    buf1.append(10)
    buf1.append(20)
    buf1.append(30)

    // V6b-1: empty (both variants should work for Copyable Int)
    print("v6b1_empty_copyable = \(buf1.v6b1_empty_copyable())")
    print("v6b1_empty_nc = \(buf1.v6b1_empty_nc())")
    // V6b-2: access props
    print("v6b2_accessProps = \(buf1.v6b2_accessProps())")
    // V6b-3: access element
    print("v6b3_accessElement = \(buf1.v6b3_accessElement())")
    // V6b-4: trivial context-passing (no data in HT — always false)
    print("v6b4_contextPassingTrivial = \(buf1.v6b4_contextPassingTrivial(20))")
    // V6b-5: full lookup with populated hash table
    print("lookup(20) = \(buf1.lookup(20))")       // true
    print("lookup(99) = \(buf1.lookup(99))")       // false

    // Test with ~Copyable MoveOnlyKey — call each variant
    var buf2 = NCBuffer<MoveOnlyKey>(capacity: 8)
    buf2.append(MoveOnlyKey(10))
    buf2.append(MoveOnlyKey(20))
    buf2.append(MoveOnlyKey(30))

    print("MoveOnly v6b1_empty_nc = \(buf2.v6b1_empty_nc())")
    print("MoveOnly v6b2_accessProps = \(buf2.v6b2_accessProps())")
    print("MoveOnly v6b3_accessElement = \(buf2.v6b3_accessElement())")
    let mk1 = MoveOnlyKey(20)
    print("MoveOnly v6b4_contextPassingTrivial = \(buf2.v6b4_contextPassingTrivial(mk1))")
    let mk2 = MoveOnlyKey(20)
    print("MoveOnly lookup(20) = \(buf2.lookup(mk2))")    // true
    let mk3 = MoveOnlyKey(99)
    print("MoveOnly lookup(99) = \(buf2.lookup(mk3))")    // false
}

// ============================================================================
// MARK: - Execution
// ============================================================================

print("=== V1+V4: Context-passing API (direct) ===")
testContextPassingDirect()

print("\n=== V2+V5: Probe iterator API (direct) ===")
testProbeIteratorDirect()

print("\n=== V3: Context-passing with Copyable buffer (Set.Ordered pattern) ===")

var cbs1 = CopyableBufferSet<Int>(capacity: 16)
cbs1.insert(10); cbs1.insert(20); cbs1.insert(30)
print("contains(20)=\(cbs1.contains(20)), contains(99)=\(cbs1.contains(99))")

var cbs2 = CopyableBufferSet<Int>(capacity: 16)
cbs2.insert(30); cbs2.insert(40)

var cbs3 = CopyableBufferSet<Int>(capacity: 16)
cbs3.insert(20); cbs3.insert(50)

print("isDisjoint(cbs1,cbs2)=\(cbs1.isDisjoint(with: cbs2))")  // false (share 30)
print("isDisjoint(cbs1,cbs3)=\(cbs1.isDisjoint(with: cbs3))")  // false (share 20)

print("\n=== V6: ~Copyable container + context-passing (H5) ===")
testH5()

print("\nDone.")
