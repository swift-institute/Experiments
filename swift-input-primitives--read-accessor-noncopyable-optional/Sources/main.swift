// read-accessor-noncopyable-optional
//
// Hypothesis: `_read` accessor can yield through Optional<~Copyable>,
// enabling `var first: Element? { _read { yield storage[position] } }`
// when Element is ~Copyable.
//
// This determines whether Input.Stream.Protocol can keep `first: Element?`
// as a protocol requirement after adding `associatedtype Element: ~Copyable`,
// or whether `first` must be removed/restructured.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.2 (arm64)
//
// Result: REFUTED — `_read` cannot yield ~Copyable element into Optional.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         Two distinct failures: (1) yield into Optional? consumes the element,
//         (2) `if let` at call site consumes the ~Copyable Optional.
//         `first: Element?` CANNOT be a protocol requirement for ~Copyable Element.
// Date: 2026-02-13
//
// Variants:
//   V1: _read yielding ~Copyable element into Optional property — REFUTED
//   V2: _read yielding nil for ~Copyable Optional — CONFIRMED
//   V3: _read with if/else (Input.Buffer pattern) — REFUTED
//   V4: Protocol requirement with _read conformance — REFUTED
//   V5: Generic function using first (parser pattern) — REFUTED
//   V6: _read yielding ~Copyable directly (not Optional) — CONFIRMED
//   V7: Protocol without first + next() consuming wrapper — CONFIRMED
//   V8: Protocol without first + Copyable-constrained first extension — CONFIRMED
//   V9: Copyable element control (current Input.Buffer pattern) — CONFIRMED

// MARK: - Non-Copyable Type

struct NC: ~Copyable {
    var value: Int
}

// MARK: - V1: _read yielding ~Copyable element into Optional property
// REFUTED: 'self' is borrowed and cannot be consumed
//   error: 'self' is borrowed and cannot be consumed (yield wraps in .some, consuming)
//   error: 'c.first' is borrowed and cannot be consumed (if let unwraps, consuming)

// struct ContainerV1: ~Copyable {
//     var element: NC
//     var first: NC? {
//         _read {
//             yield element  // ❌ wrapping in .some() consumes element
//         }
//     }
// }

// MARK: - V2: _read yielding nil for ~Copyable Optional — CONFIRMED

struct ContainerV2: ~Copyable {
    var first: NC? {
        _read {
            yield nil
        }
    }
}

func testV2() {
    let c = ContainerV2()
    if c.first == nil {
        print("V2: first is nil — CONFIRMED")
    }
}

// V2: CONFIRMED — nil yields fine (no ~Copyable value involved)

// MARK: - V3: _read with if/else (Input.Buffer pattern)
// REFUTED: same errors as V1 — yield into Optional consumes, if let consumes

// @unsafe
// struct ContainerV3: ~Copyable {
//     let storage: UnsafeMutablePointer<NC>
//     let count: Int
//     var position: Int = 0
//     var isEmpty: Bool { position >= count }
//     var first: NC? {
//         _read {
//             if !isEmpty {
//                 yield unsafe storage.advanced(by: position).pointee  // ❌ consumes
//             } else {
//                 yield nil
//             }
//         }
//     }
// }

// MARK: - V4: Protocol requirement with _read conformance
// REFUTED: same yield-into-Optional consumption error

// protocol StreamV4: ~Copyable {
//     associatedtype Element: ~Copyable
//     var isEmpty: Bool { get }
//     var first: Element? { get }
//     mutating func advance() -> Element
// }
// (conformer would hit same error as V3)

// MARK: - V5: Generic function using first (parser pattern)
// REFUTED: noncopyable 'stream.first' cannot be consumed

// func parseFirstV5<S: StreamV4 & ~Copyable>(_ stream: inout S) -> Bool
// where S.Element == NC {
//     guard let element = stream.first else { return false }  // ❌ consumes
//     ...
// }

// MARK: - V6: _read yielding ~Copyable directly (not Optional)

@unsafe
struct ContainerV6: ~Copyable {
    let storage: UnsafeMutablePointer<NC>

    var first: NC {
        _read {
            yield unsafe storage.pointee
        }
    }
}

func testV6() {
    let ptr = UnsafeMutablePointer<NC>.allocate(capacity: 1)
    unsafe ptr.initialize(to: NC(value: 42))

    let c = unsafe ContainerV6(storage: ptr)
    // Borrow the element without consuming
    let val = unsafe c.first.value
    print("V6: first.value = \(val) — CONFIRMED")

    unsafe ptr.deinitialize(count: 1)
    unsafe ptr.deallocate()
}

// V6: CONFIRMED — _read CAN yield ~Copyable directly, borrowing works.
// The issue is specifically Optional wrapping, not _read itself.

// MARK: - V7: Protocol without first + next() consuming wrapper

protocol StreamV7: ~Copyable {
    associatedtype Element: ~Copyable
    var isEmpty: Bool { get }
    @discardableResult
    mutating func advance() -> Element
}

extension StreamV7 where Self: ~Copyable {
    mutating func next() -> Element? {
        guard !isEmpty else { return nil }
        return advance()  // advance() consumes, wraps consumed value in Optional
    }
}

@unsafe
struct NCStreamV7: StreamV7, ~Copyable {
    typealias Element = NC

    let storage: UnsafeMutablePointer<NC>
    let count: Int
    var position: Int = 0

    var isEmpty: Bool { unsafe position >= count }

    @discardableResult
    mutating func advance() -> NC {
        let element = unsafe storage.advanced(by: position).move()
        unsafe position += 1
        return element
    }
}

func testV7() {
    let ptr = UnsafeMutablePointer<NC>.allocate(capacity: 2)
    unsafe ptr.initialize(to: NC(value: 10))
    unsafe ptr.advanced(by: 1).initialize(to: NC(value: 20))

    var stream = unsafe NCStreamV7(storage: ptr, count: 2)

    if let first = stream.next() {
        print("V7: next() = \(first.value) — CONFIRMED")
    }
    if let second = stream.next() {
        print("V7: next() = \(second.value) — CONFIRMED")
    }
    if stream.next() == nil {
        print("V7: next() = nil when empty — CONFIRMED")
    }

    unsafe ptr.deallocate()
}

// V7: CONFIRMED — Protocol without first + consuming next() works for ~Copyable.

// MARK: - V8: Protocol without first + Copyable-constrained first extension

protocol StreamV8: ~Copyable {
    associatedtype Element: ~Copyable
    var isEmpty: Bool { get }
    @discardableResult
    mutating func advance() -> Element
}

// first available only when Element is Copyable — matches current parser usage
extension StreamV8 where Self: ~Copyable, Element: Copyable {
    // NOTE: Cannot provide default implementation — no access to storage.
    // This extension would need to be a protocol requirement or conformer member.
}

// Concrete conformer with Copyable element provides first as member
struct IntStreamV8: StreamV8, ~Copyable {
    typealias Element = Int

    var storage: [Int]
    var position: Int = 0

    var isEmpty: Bool { position >= storage.count }

    var first: Int? {
        _read {
            if !isEmpty {
                yield storage[position]
            } else {
                yield nil
            }
        }
    }

    @discardableResult
    mutating func advance() -> Int {
        defer { position += 1 }
        return storage[position]
    }
}

// Generic function constrained to Copyable Element — can it see conformer's first?
// NO — `first` is a member, not on the protocol. Must use isEmpty + advance().
// For parsers: they'd use `where Input.Element: Copyable` and access first on concrete types.

func testV8() {
    var stream = IntStreamV8(storage: [100, 200, 300])

    // Direct member access works (not through protocol)
    if let v = stream.first {
        print("V8: first = \(v) — CONFIRMED (member access)")
    }

    let consumed = stream.advance()
    print("V8: advanced = \(consumed) — CONFIRMED")

    if let v = stream.first {
        print("V8: next first = \(v) — CONFIRMED")
    }
}

// V8: CONFIRMED — Copyable conformers keep first as member.
// Generic code cannot access first through the protocol (it's not a requirement).

// MARK: - V9: Copyable element control (current Input.Buffer pattern)

protocol StreamV9: ~Copyable {
    associatedtype Element  // Implicitly Copyable (no suppression)
    var isEmpty: Bool { get }
    var first: Element? { get }
    @discardableResult
    mutating func advance() -> Element
}

struct IntStreamV9: StreamV9, ~Copyable {
    typealias Element = Int

    var storage: [Int]
    var position: Int = 0

    var isEmpty: Bool { position >= storage.count }

    var first: Int? {
        _read {
            if !isEmpty {
                yield storage[position]
            } else {
                yield nil
            }
        }
    }

    @discardableResult
    mutating func advance() -> Int {
        defer { position += 1 }
        return storage[position]
    }
}

func parseV9<S: StreamV9 & ~Copyable>(_ stream: inout S) -> S.Element?
where S.Element == Int {
    guard let element = stream.first else { return nil }
    _ = stream.advance()
    return element
}

func testV9() {
    var stream = IntStreamV9(storage: [42, 84])
    if let v = parseV9(&stream) {
        print("V9: parsed = \(v) — CONFIRMED (Copyable control)")
    }
}

// V9: CONFIRMED — Current pattern with implicit Copyable Element works fine.

// MARK: - Results Summary
//
// V1: REFUTED  — _read yield into Optional<NC> consumes element
// V2: CONFIRMED — _read yield nil into Optional<NC> works (no NC value)
// V3: REFUTED  — Same as V1 (full if/else pattern)
// V4: REFUTED  — Protocol requirement hits same error
// V5: REFUTED  — Generic code if-let consumes ~Copyable Optional
// V6: CONFIRMED — _read yield NC directly (not Optional) works fine
// V7: CONFIRMED — Protocol without first + consuming next() works
// V8: CONFIRMED — Copyable conformers keep first as member
// V9: CONFIRMED — Copyable Element control (current design) works
//
// CONCLUSION:
// The blocker is Optional wrapping, not _read itself.
// _read CAN borrow ~Copyable values (V6), but wrapping in Optional
// requires consuming the value (.some() construction).
//
// DESIGN IMPLICATION:
// Input.Stream.Protocol with `associatedtype Element: ~Copyable` MUST
// remove `first: Element?` from protocol requirements. The correct design:
//   - Core protocol: isEmpty + advance() (works for all Element types)
//   - Concrete conformers: provide first as member when Element: Copyable
//   - Future: SE-0474 (yielding borrow) may enable first on protocol

// MARK: - Execution

print("=== _read Accessor with Optional<~Copyable> Experiment ===")
print()
testV2()
testV6()
testV7()
testV8()
testV9()
print()
print("V1: REFUTED  — yield into Optional<NC> consumes")
print("V2: CONFIRMED — yield nil works")
print("V3: REFUTED  — same as V1")
print("V4: REFUTED  — protocol requirement hits same error")
print("V5: REFUTED  — generic if-let consumes ~Copyable Optional")
print("V6: CONFIRMED — yield NC directly (not Optional) works")
print("V7: CONFIRMED — protocol without first + next() works")
print("V8: CONFIRMED — Copyable member first works")
print("V9: CONFIRMED — Copyable control works")
