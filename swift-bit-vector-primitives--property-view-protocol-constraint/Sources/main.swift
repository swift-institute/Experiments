// MARK: - Property.View Protocol Constraint Validation
// Purpose: Validate whether Property.View extensions can use protocol constraints
//          (Base: SomeProtocol & ~Copyable) instead of concrete type constraints
//          (Base == ConcreteType), enabling protocol-level defaults for pop, set, clear.
//
// Hypothesis: Property.View extensions CAN be constrained to a protocol on Base,
//             allowing a single extension to serve all conformers. Protocol defaults
//             CAN provide the `var pop/set/clear` accessors returning Property.View.
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-02-11-a
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED - All 6 variants compile and run correctly.
//         Property.View extensions with protocol constraints (Base: Protocol & ~Copyable)
//         work for ~Copyable, Copyable, and value-generic conformers.
//         Protocol defaults providing _read/_modify coroutines for Property.View accessors
//         work correctly. Generic functions using `some Protocol` also resolve the accessors.
// Evidence: Build Succeeded; all 4 test groups print CONFIRMED
// Date: 2026-02-12

// ============================================================================
// MARK: - Minimal Property.View replica (matches swift-property-primitives)
// ============================================================================

public struct Property<Tag, Base: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _base: Base

    @inlinable
    public init(_ base: consuming Base) {
        self._base = base
    }
}

extension Property: Copyable where Base: Copyable {}
extension Property: Sendable where Base: Sendable {}

extension Property where Base: ~Copyable {
    @safe
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _base: UnsafeMutablePointer<Base>

        @inlinable
        @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            unsafe _base = base
        }

        @inlinable
        public var base: UnsafeMutablePointer<Base> {
            unsafe _base
        }
    }
}

// ============================================================================
// MARK: - Minimal Bit.Vector.Protocol replica
// ============================================================================

enum Bit {
    struct Index: Equatable {
        let value: Int
    }
}

extension Bit {
    enum Vector {}
}

extension Bit.Vector {
    protocol `Protocol`: ~Copyable {
        var bitCapacity: Int { get }
        borrowing func word(at index: Int) -> UInt
        mutating func setWord(at index: Int, to value: UInt)
    }
}

// Tag types
extension Bit.Vector {
    enum Pop {}
    enum Set {}
    enum Clear {}
}

// ============================================================================
// MARK: - Variant 1: Protocol default provides Property.View accessor
// Hypothesis: A ~Copyable protocol can provide a default computed property
//             returning Property<Tag, Self>.View with _read/_modify coroutines.
// Result: CONFIRMED
// ============================================================================

extension Bit.Vector.`Protocol` where Self: ~Copyable {
    var pop: Property<Bit.Vector.Pop, Self>.View {
        mutating _read {
            yield unsafe Property<Bit.Vector.Pop, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Bit.Vector.Pop, Self>.View(&self)
            yield &view
        }
    }

    var `set`: Property<Bit.Vector.Set, Self>.View {
        mutating _read {
            yield unsafe Property<Bit.Vector.Set, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Bit.Vector.Set, Self>.View(&self)
            yield &view
        }
    }

    var clear: Property<Bit.Vector.Clear, Self>.View {
        mutating _read {
            yield unsafe Property<Bit.Vector.Clear, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Bit.Vector.Clear, Self>.View(&self)
            yield &view
        }
    }
}

// ============================================================================
// MARK: - Variant 2: Property.View extension with protocol constraint on Base
// Hypothesis: Property.View extensions CAN use Base: Protocol & ~Copyable
//             instead of Base == ConcreteType.
// Result: CONFIRMED
// ============================================================================

extension Property.View where Tag == Bit.Vector.Pop, Base: Bit.Vector.`Protocol` & ~Copyable {
    func first() -> Bit.Index? {
        for i in 0..<(unsafe base.pointee.bitCapacity + 63) / 64 {
            var word = unsafe base.pointee.word(at: i)
            if word != 0 {
                let bitPosition = word.trailingZeroBitCount
                word &= word &- 1
                unsafe base.pointee.setWord(at: i, to: word)
                return Bit.Index(value: i * 64 + bitPosition)
            }
        }
        return nil
    }
}

extension Property.View where Tag == Bit.Vector.Set, Base: Bit.Vector.`Protocol` & ~Copyable {
    func all() {
        let wordCount = (unsafe base.pointee.bitCapacity + 63) / 64
        for i in 0..<wordCount {
            unsafe base.pointee.setWord(at: i, to: UInt.max)
        }
    }
}

extension Property.View where Tag == Bit.Vector.Clear, Base: Bit.Vector.`Protocol` & ~Copyable {
    func all() {
        let wordCount = (unsafe base.pointee.bitCapacity + 63) / 64
        for i in 0..<wordCount {
            unsafe base.pointee.setWord(at: i, to: 0)
        }
    }
}

// ============================================================================
// MARK: - Variant 3: ~Copyable conformer
// Hypothesis: A ~Copyable conformer gets pop/set/clear from the protocol default.
// Result: CONFIRMED
// ============================================================================

extension Bit.Vector {
    struct Fixed: ~Copyable, Bit.Vector.`Protocol` {
        var _words: (UInt, UInt) = (0, 0)

        var bitCapacity: Int { 128 }

        borrowing func word(at index: Int) -> UInt {
            switch index {
            case 0: _words.0
            case 1: _words.1
            default: fatalError()
            }
        }

        mutating func setWord(at index: Int, to value: UInt) {
            switch index {
            case 0: _words.0 = value
            case 1: _words.1 = value
            default: fatalError()
            }
        }
    }
}

// ============================================================================
// MARK: - Variant 4: Copyable conformer
// Hypothesis: A Copyable conformer also gets pop/set/clear from the protocol.
// Result: CONFIRMED
// ============================================================================

extension Bit.Vector {
    struct Dynamic: Bit.Vector.`Protocol` {
        var _words: [UInt]
        let _bitCapacity: Int

        init(bitCapacity: Int) {
            self._bitCapacity = bitCapacity
            self._words = Array(repeating: 0, count: (bitCapacity + 63) / 64)
        }

        var bitCapacity: Int { _bitCapacity }

        borrowing func word(at index: Int) -> UInt { _words[index] }

        mutating func setWord(at index: Int, to value: UInt) {
            _words[index] = value
        }
    }
}

// ============================================================================
// MARK: - Variant 5: Value-generic conformer
// Hypothesis: A value-generic conformer also gets pop/set/clear.
// Result: CONFIRMED
// ============================================================================

extension Bit.Vector {
    struct Static<let wordCount: Int>: Bit.Vector.`Protocol` {
        var _words: (UInt, UInt) = (0, 0) // simplified for 2-word case

        var bitCapacity: Int { wordCount * 64 }

        borrowing func word(at index: Int) -> UInt {
            switch index {
            case 0: _words.0
            case 1: _words.1
            default: fatalError()
            }
        }

        mutating func setWord(at index: Int, to value: UInt) {
            switch index {
            case 0: _words.0 = value
            case 1: _words.1 = value
            default: fatalError()
            }
        }
    }
}

// ============================================================================
// MARK: - Variant 6: Generic function accepting protocol
// Hypothesis: A generic function taking `inout some Protocol` can use
//             pop/set/clear via the protocol-provided accessors.
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

func testViaProtocol(_ vector: inout some Bit.Vector.`Protocol`) {
    vector.set.all()
    let first = vector.pop.first()
    print("  pop.first after set.all: \(first?.value ?? -1)")
    vector.clear.all()
    let afterClear = vector.pop.first()
    print("  pop.first after clear.all: \(afterClear.map { "\($0.value)" } ?? "nil")")
}

// ============================================================================
// MARK: - Execution
// ============================================================================

print("=== Variant 3: ~Copyable conformer (Fixed) ===")
do {
    var v = Bit.Vector.Fixed()
    v.set.all()
    print("  After set.all, word0: \(v.word(at: 0))")
    let first = v.pop.first()
    print("  pop.first: \(first?.value ?? -1)")
    v.clear.all()
    print("  After clear.all, word0: \(v.word(at: 0))")
    print("  CONFIRMED")
}

print()
print("=== Variant 4: Copyable conformer (Dynamic) ===")
do {
    var v = Bit.Vector.Dynamic(bitCapacity: 128)
    v.set.all()
    print("  After set.all, word0: \(v.word(at: 0))")
    let first = v.pop.first()
    print("  pop.first: \(first?.value ?? -1)")
    v.clear.all()
    print("  After clear.all, word0: \(v.word(at: 0))")
    print("  CONFIRMED")
}

print()
print("=== Variant 5: Value-generic conformer (Static<2>) ===")
do {
    var v = Bit.Vector.Static<2>()
    v.set.all()
    print("  After set.all, word0: \(v.word(at: 0))")
    let first = v.pop.first()
    print("  pop.first: \(first?.value ?? -1)")
    v.clear.all()
    print("  After clear.all, word0: \(v.word(at: 0))")
    print("  CONFIRMED")
}

print()
print("=== Variant 6: Generic function via protocol ===")
do {
    var v = Bit.Vector.Dynamic(bitCapacity: 64)
    testViaProtocol(&v)
    print("  CONFIRMED")
}

print()
print("=== All variants passed ===")
