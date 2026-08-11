// MARK: - Tagged Mutable Ambiguity Test
// Purpose: Verify that Pointer<T>.Mutable can be a typealias to
//          Tagged<T, Memory.Address.Mutable> without colliding with
//          Memory.Address.Mutable (typealias to Tagged<Memory.Mutable, Ordinal>)
//
// Design:
//   Pointer<T>         = Tagged<T, Memory.Address>          (immutable)
//   Pointer<T>.Mutable = Tagged<T, Memory.Address.Mutable>  (mutable)
//   Memory.Address         = Tagged<Memory, Ordinal>
//   Memory.Address.Mutable = Tagged<Memory.Mutable, Ordinal>
//
// Hypothesis: Two typealias Mutable in non-overlapping Tagged extensions compile
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED - compiles and runs correctly
//   Memory.Address.Mutable: 42
//   Pointer<Int>.Mutable: 99
//   Immutable === Pointer: true
//
// Key finding: Two typealias Mutable in non-overlapping Tagged extensions
//   compile and resolve correctly. The `invalid redeclaration` error only
//   occurs when at least one is a struct/enum, not when both are typealiases.
// Date: 2026-01-28

// --- Simulate Tagged infrastructure ---

struct Ordinal: Copyable, Sendable {
    let rawValue: Int
    init(_ rawValue: Int) { self.rawValue = rawValue }
}

struct Tagged<Tag: ~Copyable, RawValue: Copyable & Sendable>: Copyable, Sendable {
    let rawValue: RawValue
    init(_ rawValue: RawValue) { self.rawValue = rawValue }
}

// --- Memory namespace ---

enum Memory {
    enum Mutable {}
}

// --- Memory.Address = Tagged<Memory, Ordinal> ---

typealias MemoryAddress = Tagged<Memory, Ordinal>

extension Tagged where Tag == Memory, RawValue == Ordinal {
    /// Memory.Address.Mutable = Tagged<Memory.Mutable, Ordinal>
    typealias Mutable = Tagged<Memory.Mutable, Ordinal>
}

// --- Pointer<T> = Tagged<T, Memory.Address> ---

typealias Pointer<Pointee: ~Copyable> = Tagged<Pointee, MemoryAddress>

extension Tagged where RawValue == MemoryAddress, Tag: ~Copyable {
    /// Pointer<T>.Mutable = Tagged<T, Memory.Address.Mutable>
    typealias Mutable = Tagged<Tag, MemoryAddress.Mutable>
}

// MARK: - Variant 1: Use both Mutable types

func testBothMutables() {
    // Memory.Address.Mutable
    let addrMut = MemoryAddress.Mutable(Ordinal(42))
    print("Memory.Address.Mutable: \(addrMut.rawValue.rawValue)")

    // Pointer<Int>.Mutable
    let ptrMut = Pointer<Int>.Mutable(MemoryAddress.Mutable(Ordinal(99)))
    print("Pointer<Int>.Mutable: \(ptrMut.rawValue.rawValue.rawValue)")
}

// MARK: - Variant 2: Pointer<T>.Immutable === Pointer<T>

extension Tagged where RawValue == MemoryAddress, Tag: ~Copyable {
    typealias Immutable = Tagged<Tag, MemoryAddress>
}

func testImmutableAlias() {
    let ptr: Pointer<Int> = Pointer<Int>(MemoryAddress(Ordinal(10)))
    let ptrImm: Pointer<Int>.Immutable = ptr
    print("Immutable === Pointer: \(type(of: ptr) == type(of: ptrImm))")
}

// MARK: - Run

testBothMutables()
testImmutableAlias()
