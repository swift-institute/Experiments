// Status: SUPERSEDED -- Input.Stream.Protocol with ~Copyable Element shipped in swift-input-primitives. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ============================================================================
// EXPERIMENT: noncopyable-streaming
// ============================================================================
// DATE: 2026-01-23
// CLAIM: Using `_read` accessor enables Input.Stream.Protocol to work with
//        ~Copyable elements
// STATUS: CONFIRMED (PARTIALLY) - See conclusions
// ============================================================================
//
// HYPOTHESIS:
// H1: `associatedtype Element` implicitly requires Copyable (per SE-0427)
// H2: `_read` accessor provides borrowing semantics but doesn't change
//     the associated type constraint
// H3: To support ~Copyable elements, we need to either:
//     (a) Wait for `associatedtype Element: ~Copyable` support
//     (b) Remove `associatedtype Element` from protocol
//     (c) Use closure-based API
//
// METHODOLOGY: [EXP-004a] Incremental Construction
// ============================================================================

// MARK: - Test Infrastructure

struct FileHandle: ~Copyable {
    let fd: Int
    init(fd: Int) { self.fd = fd }
    deinit { print("Closing fd \(fd)") }
}

enum StreamError: Error {
    case empty
}

// ============================================================================
// VARIANT 1: Protocol with associatedtype Element (implicit Copyable)
// RESULT: ✅ COMPILES - works with Copyable elements
// ============================================================================

protocol StreamingV1: ~Copyable {
    associatedtype Element  // Implicitly requires Copyable per SE-0427
    var isEmpty: Bool { get }
    var first: Element? { get }
    mutating func advance() throws(StreamError) -> Element
}

// Test: Can a ~Copyable container conform with Copyable elements?
struct BufferV1<T>: ~Copyable, StreamingV1 {
    var storage: [T]
    var position: Int = 0

    var isEmpty: Bool { position >= storage.count }
    var first: T? {
        _read {
            if position < storage.count {
                yield storage[position]
            } else {
                yield nil
            }
        }
    }
    mutating func advance() throws(StreamError) -> T {
        guard position < storage.count else { throw .empty }
        defer { position += 1 }
        return storage[position]
    }
}

func testV1() {
    print("=== VARIANT 1: Protocol with implicit Copyable Element ===")
    var buffer = BufferV1(storage: [1, 2, 3])
    print("isEmpty: \(buffer.isEmpty)")
    print("first: \(buffer.first ?? -1)")
    if let element = try? buffer.advance() {
        print("advanced: \(element)")
    }
    print("RESULT: ✅ Works with Copyable elements (Int)")
    print("        The `_read` accessor avoids copies but Element still Copyable")
    print()
}

// ============================================================================
// VARIANT 2: Try ~Copyable associated type
// RESULT: ❌ DOES NOT COMPILE - SE-0427 limitation
// ============================================================================
//
// protocol StreamingV2: ~Copyable {
//     associatedtype Element: ~Copyable  // ❌ Error: cannot suppress Copyable
//     ...
// }
//
// Error: "Associated type 'Element' can only be suppressed with '~Copyable'
//         in its inheritance clause"
// Actually the real issue is: associated types cannot be marked ~Copyable

func testV2() {
    print("=== VARIANT 2: associatedtype Element: ~Copyable ===")
    print("RESULT: ❌ Not supported - SE-0427 deferred this feature")
    print("        Error: associated types cannot suppress Copyable requirement")
    print()
}

// ============================================================================
// VARIANT 3: Protocol without `first`, using ~Copyable element
// RESULT: ❌ DOES NOT COMPILE - multiple issues
// ============================================================================
//
// struct BufferV3: ~Copyable, StreamingV3 {
//     var handles: [FileHandle]  // ❌ Array requires Copyable elements
//     ...
// }
//
// Errors:
// 1. `[FileHandle]` fails - Array requires Element: Copyable
// 2. `associatedtype Element` infers FileHandle which is not Copyable
// 3. Would need custom storage (InlineArray, UnsafeBufferPointer, etc.)

func testV3() {
    print("=== VARIANT 3: Protocol without `first`, ~Copyable element ===")
    print("RESULT: ❌ Multiple blockers:")
    print("        1. [FileHandle] fails - Array requires Copyable")
    print("        2. associatedtype Element still requires Copyable")
    print("        3. Would need custom ~Copyable-aware storage")
    print()
}

// ============================================================================
// VARIANT 4: Protocol without associatedtype Element
// RESULT: ✅ Pattern works conceptually - but ~Copyable storage is also hard
// ============================================================================

protocol StreamingCoreV4: ~Copyable {
    var isEmpty: Bool { get }
    // No Element associated type - conformers provide their own typed API
}

// Note: Actually implementing ~Copyable storage is challenging:
// - InlineArray(repeating:) requires Copyable
// - Array requires Copyable elements
// - Would need unsafe manual initialization
//
// This demonstrates that ~Copyable elements have multiple blockers,
// not just the protocol's associated type constraint.

func testV4() {
    print("=== VARIANT 4: Protocol without associatedtype Element ===")
    print("RESULT: ⚠️ Pattern works conceptually, but:")
    print("        1. Protocol loses Element type abstraction")
    print("        2. Storage initialization also requires Copyable")
    print("        3. InlineArray(repeating:) requires Copyable")
    print()
}

// ============================================================================
// VARIANT 5: Closure-based protocol with generic parameter
// RESULT: ✅ COMPILES - preserves type safety via generic
// ============================================================================

protocol StreamingV5<Element>: ~Copyable {
    associatedtype Element  // Still implicitly Copyable
    var isEmpty: Bool { get }
    func withFirst<R>(_ body: (borrowing Element) -> R) -> R?
    mutating func advance() throws(StreamError) -> Element
}

struct BufferV5<T>: ~Copyable, StreamingV5 {
    var storage: [T]
    var position: Int = 0

    var isEmpty: Bool { position >= storage.count }

    func withFirst<R>(_ body: (borrowing T) -> R) -> R? {
        guard position < storage.count else { return nil }
        return body(storage[position])
    }

    mutating func advance() throws(StreamError) -> T {
        guard position < storage.count else { throw .empty }
        defer { position += 1 }
        return storage[position]
    }
}

func testV5() {
    print("=== VARIANT 5: Closure-based with primary associated type ===")
    let buffer = BufferV5(storage: ["a", "b", "c"])
    print("isEmpty: \(buffer.isEmpty)")
    buffer.withFirst { print("first (borrowed): \($0)") }
    print("RESULT: ✅ Works - closure-based peek avoids return ownership issue")
    print("        But Element still implicitly Copyable")
    print()
}

// ============================================================================
// MAIN
// ============================================================================

func repeatString(_ s: String, _ n: Int) -> String {
    String(repeating: s, count: n)
}

print(repeatString("=", 70))
print("EXPERIMENT: Can Input.Stream.Protocol support ~Copyable elements?")
print(repeatString("=", 70))
print()

testV1()
testV2()
testV3()
testV4()
testV5()

print(repeatString("=", 70))
print("CONCLUSIONS:")
print(repeatString("=", 70))
print("""

1. `_read` ACCESSOR VALUE:
   ✅ Provides borrowing semantics for IMPLEMENTATIONS
   ✅ Avoids unnecessary copies for Copyable elements
   ❌ Does NOT change protocol's associated type constraints

2. PROTOCOL-LEVEL ~COPYABLE ELEMENTS:
   ❌ `associatedtype Element` implicitly requires `Copyable` (SE-0427)
   ❌ Cannot write `associatedtype Element: ~Copyable` today
   ❌ Standard library collections (Array, etc.) require Copyable elements

3. WORKAROUNDS FOR ~COPYABLE ELEMENTS:
   Option A: Remove `associatedtype Element` from protocol
             → Loses type abstraction at protocol level
             → Conformers provide typed API as direct members
             → This is the Collection.Indexed pattern

   Option B: Use closure-based API (`withFirst` instead of `first`)
             → Element still implicitly Copyable in protocol
             → But avoids return ownership issues

   Option C: Wait for language evolution
             → SE-0427 deferred `associatedtype Element: ~Copyable`
             → Future Swift may support this

4. RECOMMENDATION FOR INPUT-PRIMITIVES:
   - KEEP `_read` accessor: Avoids copies, no downside
   - ACCEPT current limitation: Element implicitly Copyable
   - DOCUMENT clearly: ~Copyable elements await language support
   - CONSIDER: Closure-based `withFirst` as alternative to `first`
     for future-proofing (can coexist with `first` property)

""")
