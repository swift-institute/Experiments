// ===----------------------------------------------------------------------===//
// Experiment: ManagedBuffer Init Syntax
// ===----------------------------------------------------------------------===//
//
// Question: Can we use nice `init` syntax for ManagedBuffer subclasses
//           instead of the ugly `.create` factory method?
//
// Background:
// - ManagedBuffer uses a static `create` factory that returns `ManagedBuffer<H,E>`
// - Subclasses need to downcast this result to their concrete type
// - Swift doesn't allow `self = ...` in class convenience initializers
// - We want `Storage(minimumCapacity: 10)` instead of `Storage.create(...)`
//
// Result: [TO BE FILLED]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ===----------------------------------------------------------------------===//

// MARK: - V1: Test unsafeDowncast with subclass

final class StorageV1<Element>: ManagedBuffer<Int, Element> {}

func testV1() {
    print("=== V1: Testing unsafeDowncast with subclass ===")

    // Call create on the subclass
    let buffer = StorageV1<Int>.create(minimumCapacity: 10) { _ in 0 }

    print("Static type: ManagedBuffer<Int, Int>")
    print("Dynamic type: \(type(of: buffer))")
    print("Is StorageV1? \(buffer is StorageV1<Int>)")

    // Test unsafeDowncast
    print("Attempting unsafeDowncast...")
    let typed = unsafeDowncast(buffer, to: StorageV1<Int>.self)
    print("unsafeDowncast succeeded!")
    print("Capacity: \(typed.capacity)")
}

// MARK: - V2: Static factory with unsafeDowncast

final class StorageV2<Element>: ManagedBuffer<Int, Element> {
    static func make(minimumCapacity: Int) -> StorageV2<Element> {
        let buffer = StorageV2<Element>.create(minimumCapacity: minimumCapacity) { _ in 0 }
        return unsafeDowncast(buffer, to: StorageV2<Element>.self)
    }
}

func testV2() {
    print("\n=== V2: Static factory with unsafeDowncast ===")
    let storage = StorageV2<Int>.make(minimumCapacity: 10)
    print("Capacity: \(storage.capacity)")
}

// MARK: - V3: What if we DON'T use the subclass to call create?

func testV3() {
    print("\n=== V3: Calling create on base ManagedBuffer, then downcasting ===")

    // Call create on ManagedBuffer directly (not on subclass)
    let buffer = ManagedBuffer<Int, Int>.create(minimumCapacity: 10) { _ in 0 }

    print("Static type: ManagedBuffer<Int, Int>")
    print("Dynamic type: \(type(of: buffer))")
    print("Is StorageV1? \(buffer is StorageV1<Int>)")

    // This SHOULD fail - we didn't call create on the subclass
    if buffer is StorageV1<Int> {
        print("Cast would succeed (unexpected!)")
    } else {
        print("Cast would fail (expected)")
    }
}

// MARK: - V4: Wrapper struct pattern (nice init syntax)

struct StorageWrapper<Element> {
    // Use a nested class to get the subclass type
    private final class _Buffer: ManagedBuffer<Int, Element> {}

    private var _buffer: _Buffer

    init(minimumCapacity: Int) {
        let buffer = _Buffer.create(minimumCapacity: minimumCapacity) { _ in 0 }
        self._buffer = unsafeDowncast(buffer, to: _Buffer.self)
    }

    var capacity: Int { _buffer.capacity }
    var header: Int {
        get { _buffer.header }
        nonmutating set { _buffer.header = newValue }
    }

    func withUnsafeMutablePointerToElements<R>(_ body: (UnsafeMutablePointer<Element>) throws -> R) rethrows -> R {
        try _buffer.withUnsafeMutablePointerToElements(body)
    }
}

func testV4() {
    print("\n=== V4: Wrapper struct with init syntax ===")
    let storage = StorageWrapper<Int>(minimumCapacity: 10)
    print("Capacity: \(storage.capacity)")
    print("This gives init() syntax!")
}

// MARK: - V5: Test with ~Copyable element

struct MoveOnly: ~Copyable {
    var value: Int
}

final class StorageV5<Element: ~Copyable>: ManagedBuffer<Int, Element> {
    static func make(minimumCapacity: Int) -> StorageV5<Element> {
        let buffer = StorageV5<Element>.create(minimumCapacity: minimumCapacity) { _ in 0 }
        return unsafeDowncast(buffer, to: StorageV5<Element>.self)
    }
}

func testV5() {
    print("\n=== V5: Testing with ~Copyable element ===")
    let storage = StorageV5<MoveOnly>.make(minimumCapacity: 10)
    print("Capacity: \(storage.capacity)")
}

// MARK: - Main

testV1()
testV2()
testV3()
testV4()
testV5()

print("\n=== CONCLUSION ===")
print("""
FINDINGS:
1. ManagedBuffer.create() called on Subclass.create() DOES return the subclass dynamically
2. unsafeDowncast works correctly when the subclass was used to call create()
3. unsafeDowncast would FAIL if you call ManagedBuffer.create() directly (not on subclass)
4. The static factory pattern (V2) works correctly

For Array.Storage, the issue is NOT unsafeDowncast - it's the attempt to use
convenience init with `self = ...` which Swift doesn't allow.

RECOMMENDATION:
Convert convenience init to static factory method:

    // BEFORE (doesn't compile):
    convenience init(minimumCapacity: Int) {
        let storage = Self.create(minimumCapacity: minimumCapacity) { _ in 0 }
        self = unsafeDowncast(storage, to: Self.self)  // ERROR
    }

    // AFTER (works):
    static func make(minimumCapacity: Int) -> Array<Element>.Storage {
        let storage = Array<Element>.Storage.create(minimumCapacity: minimumCapacity) { _ in 0 }
        return unsafeDowncast(storage, to: Array<Element>.Storage.self)
    }

OR use a wrapper struct to get init() syntax.
""")
