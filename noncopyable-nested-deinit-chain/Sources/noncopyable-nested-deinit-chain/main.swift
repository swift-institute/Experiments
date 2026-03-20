// MARK: - ~Copyable Nested Deinit Chain (Cross-Package, @_rawLayout, Value Generic)
//
// Purpose: Reproduce compiler bug #86652 — element destructors are not called
//          when a ~Copyable container wraps a ~Copyable buffer that uses
//          @_rawLayout storage, across PACKAGE boundaries.
//
// Status: BUG REPRODUCED (2026-03-20, Swift 6.2.4)
//   Group A (V1-V11): All PASS — regular stored properties, no @_rawLayout.
//   Group B (V12-V17): V12/V14/V16 FAIL — @_rawLayout member destruction broken.
//                      V13/V15/V17 PASS — _deinitWorkaround + manual cleanup works.
//
// Root cause: @_rawLayout. Value generics, nesting depth, enum wrapping, and
//   cross-module generics are all NON-contributing factors (Group A proves this).
//   The compiler fails to synthesize member destruction ONLY when the stored
//   property chain includes a @_rawLayout-backed type across package boundaries.
//
// Tracking: swiftlang/swift #86652
//
// Production chain (4 separate packages):
//   Queue.Static<capacity>                     (queue-primitives)    — outer container
//     → Buffer<Element>.Ring.Inline<capacity>  (buffer-primitives)   — middle buffer
//       → Storage<Element>.Inline<capacity>    (storage-primitives)  — @_rawLayout storage
//         → Storage.Inline._Raw                                     — @_rawLayout(likeArrayOf:)
//
// This experiment mirrors that chain with 4 packages:
//   Container (executable)
//     → MiddleRaw<Element, capacity>        (BufferPackage)   — middle buffer
//       → InlineStorage<Element, capacity>  (StoragePackage)  — @_rawLayout storage
//         → InlineStorage._Raw                                — @_rawLayout(likeArrayOf:)
//           → Tracked                       (ElementPackage)  — ~Copyable element with deinit
//
// Two groups of variants:
//
//   Group A (V1-V11): Regular stored properties — NO @_rawLayout.
//     All pass in Swift 6.2.4. These isolate type generics, value generics,
//     nesting depth, and enum wrapping as NON-contributing factors.
//
//   Group B (V12-V17): @_rawLayout-backed storage — mirrors production.
//     V12/V14/V16 FAIL: element deinit not called (bug reproduced).
//     V13/V15/V17 PASS: _deinitWorkaround + manual cleanup (workaround validated).
//
// When ALL variants pass, bug #86652 is fully fixed and all workarounds can be removed.

import Element
import Buffer
import Storage

// ===----------------------------------------------------------------------===//
// MARK: - Group A: Regular Stored Properties (control group)
// ===----------------------------------------------------------------------===//

// MARK: - V1: One Level (Control)

struct V1_Direct: ~Copyable {
    var element: Tracked

    init(_ id: Int) {
        self.element = Tracked(id)
    }

    deinit {}
}

// MARK: - V2: Two Levels, Type Generic Only
// Container → Middle<Element> → Element (no value generic)

struct V2_TypeGeneric: ~Copyable {
    var _buffer: Middle<Tracked>

    init(_ id: Int) {
        self._buffer = Middle<Tracked>(header: 0, element: Tracked(id))
    }

    deinit {}
}

// MARK: - V3: Two Levels, Type Generic + Value Generic
// Container<N> → MiddleGeneric<Element, N> → Element
// Mirrors: Queue.Static<capacity> → Buffer<Element>.Ring.Inline<capacity>

struct V3_Full<let capacity: Int>: ~Copyable {
    var _buffer: MiddleGeneric<Tracked, capacity>

    init(_ id: Int) {
        self._buffer = MiddleGeneric<Tracked, capacity>(header: 0, element: Tracked(id))
    }

    deinit {}
}

// MARK: - V4: V3 + _deinitWorkaround on Outer

struct V4_WithWorkaround<let capacity: Int>: ~Copyable {
    var _buffer: MiddleGeneric<Tracked, capacity>
    private var _deinitWorkaround: AnyObject? = nil

    init(_ id: Int) {
        self._buffer = MiddleGeneric<Tracked, capacity>(header: 0, element: Tracked(id))
    }

    deinit {}
}

// MARK: - V5: Two Levels, Outer Wraps Enum
// Mirrors: Queue.Small → Buffer.Ring.Small (_Representation enum)

struct V5_EnumWrapped<let capacity: Int>: ~Copyable {
    var _buffer: MiddleEnum<Tracked, capacity>

    init(_ id: Int) {
        self._buffer = .stored(MiddleGeneric<Tracked, capacity>(header: 0, element: Tracked(id)))
    }

    deinit {}
}

// MARK: - V6: Outer Nested in Generic Extension
// Mirrors: extension Queue where Element: ~Copyable { struct Static<let capacity: Int> }

struct Outer<Element: ~Copyable>: ~Copyable {
    var _never: Element? = nil
}

extension Outer where Element: ~Copyable {
    struct Static<let capacity: Int>: ~Copyable {
        var _buffer: MiddleGeneric<Element, capacity>

        init(element: consuming Element) {
            self._buffer = MiddleGeneric<Element, capacity>(header: 0, element: element)
        }

        deinit {}
    }
}

// MARK: - V7: V6 + _deinitWorkaround

extension Outer where Element: ~Copyable {
    struct StaticFixed<let capacity: Int>: ~Copyable {
        var _buffer: MiddleGeneric<Element, capacity>
        private var _deinitWorkaround: AnyObject? = nil

        init(element: consuming Element) {
            self._buffer = MiddleGeneric<Element, capacity>(header: 0, element: element)
        }

        deinit {}
    }
}

// MARK: - V8: InlineArray in Middle Storage
// Middle uses InlineArray<capacity, Int> alongside the element — this mirrors
// Storage<Element>.Inline<capacity> which uses @_rawLayout(like: InlineArray<...>).

struct V8_InlineArray<let capacity: Int>: ~Copyable {
    var _buffer: MiddleInlineArray<Tracked, capacity>

    init(_ id: Int) {
        self._buffer = MiddleInlineArray<Tracked, capacity>(header: 0, element: Tracked(id))
    }

    deinit {}
}

// MARK: - V9: V8 nested in generic extension

extension Outer where Element: ~Copyable {
    struct StaticInlineArray<let capacity: Int>: ~Copyable {
        var _buffer: MiddleInlineArray<Element, capacity>

        init(element: consuming Element) {
            self._buffer = MiddleInlineArray<Element, capacity>(header: 0, element: element)
        }

        deinit {}
    }
}

// MARK: - V10: Deeply Nested Middle (exact production nesting)
// Outer<Element>.Static<N> → BufferNS<Element>.Ring.Inline<N>
// This mirrors Queue<Element>.Static<capacity> → Buffer<Element>.Ring.Inline<capacity>

extension Outer where Element: ~Copyable {
    struct StaticDeepNested<let capacity: Int>: ~Copyable {
        var _buffer: BufferNS<Element>.Ring.Inline<capacity>

        init(element: consuming Element) {
            self._buffer = BufferNS<Element>.Ring.Inline<capacity>(header: 0, element: element)
        }

        deinit {}
    }
}

// MARK: - V11: V10 + _deinitWorkaround

extension Outer where Element: ~Copyable {
    struct StaticDeepNestedFixed<let capacity: Int>: ~Copyable {
        var _buffer: BufferNS<Element>.Ring.Inline<capacity>
        private var _deinitWorkaround: AnyObject? = nil

        init(element: consuming Element) {
            self._buffer = BufferNS<Element>.Ring.Inline<capacity>(header: 0, element: element)
        }

        deinit {}
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Group B: @_rawLayout-Backed Storage (bug reproduction)
// ===----------------------------------------------------------------------===//
//
// These variants use InlineStorage<Element, capacity> from StoragePackage,
// which uses @_rawLayout(likeArrayOf: Element, count: capacity) internally.
// This is the critical ingredient that triggers compiler bug #86652.

// MARK: - V12: @_rawLayout middle, flat container

struct V12_RawLayout<let capacity: Int>: ~Copyable {
    var _buffer: MiddleRaw<Tracked, capacity>

    init(_ id: Int) {
        var storage = InlineStorage<Tracked, capacity>()
        storage.append(Tracked(id))
        self._buffer = MiddleRaw<Tracked, capacity>(header: 0, storage: storage)
    }

    deinit {}
}

// MARK: - V13: V12 + _deinitWorkaround + manual cleanup
// Production pattern: _deinitWorkaround forces deinit to fire,
// then manual cleanup through mutable pointer handles element destruction.

struct V13_RawLayoutFixed<let capacity: Int>: ~Copyable {
    var _buffer: MiddleRaw<Tracked, capacity>
    private var _deinitWorkaround: AnyObject? = nil

    init(_ id: Int) {
        var storage = InlineStorage<Tracked, capacity>()
        storage.append(Tracked(id))
        self._buffer = MiddleRaw<Tracked, capacity>(header: 0, storage: storage)
    }

    deinit {
        // Manual cleanup — mirrors production Queue.Static.deinit
        unsafe withUnsafePointer(to: _buffer) { ptr in
            unsafe UnsafeMutablePointer(mutating: ptr).pointee.deinitializeStorage()
        }
    }
}

// MARK: - V14: @_rawLayout middle, nested in generic extension
// Mirrors: Queue<Element>.Static<capacity> → Buffer.Ring.Inline → Storage.Inline

extension Outer where Element: ~Copyable {
    struct StaticRaw<let capacity: Int>: ~Copyable {
        var _buffer: MiddleRaw<Element, capacity>

        init(storage: consuming InlineStorage<Element, capacity>) {
            self._buffer = MiddleRaw<Element, capacity>(header: 0, storage: storage)
        }

        deinit {}
    }
}

// MARK: - V15: V14 + _deinitWorkaround + manual cleanup

extension Outer where Element: ~Copyable {
    struct StaticRawFixed<let capacity: Int>: ~Copyable {
        var _buffer: MiddleRaw<Element, capacity>
        private var _deinitWorkaround: AnyObject? = nil

        init(storage: consuming InlineStorage<Element, capacity>) {
            self._buffer = MiddleRaw<Element, capacity>(header: 0, storage: storage)
        }

        deinit {
            unsafe withUnsafePointer(to: _buffer) { ptr in
                unsafe UnsafeMutablePointer(mutating: ptr).pointee.deinitializeStorage()
            }
        }
    }
}

// MARK: - V16: @_rawLayout deeply nested middle (exact production nesting)
// Outer<Element>.Static<N> → BufferRawNS<Element>.Ring.Inline<N> → InlineStorage

extension Outer where Element: ~Copyable {
    struct StaticDeepRaw<let capacity: Int>: ~Copyable {
        var _buffer: BufferRawNS<Element>.Ring.Inline<capacity>

        init(storage: consuming InlineStorage<Element, capacity>) {
            self._buffer = BufferRawNS<Element>.Ring.Inline<capacity>(header: 0, storage: storage)
        }

        deinit {}
    }
}

// MARK: - V17: V16 + _deinitWorkaround + manual cleanup

extension Outer where Element: ~Copyable {
    struct StaticDeepRawFixed<let capacity: Int>: ~Copyable {
        var _buffer: BufferRawNS<Element>.Ring.Inline<capacity>
        private var _deinitWorkaround: AnyObject? = nil

        init(storage: consuming InlineStorage<Element, capacity>) {
            self._buffer = BufferRawNS<Element>.Ring.Inline<capacity>(header: 0, storage: storage)
        }

        deinit {
            unsafe withUnsafePointer(to: _buffer) { ptr in
                unsafe UnsafeMutablePointer(mutating: ptr).pointee.deinitializeStorage()
            }
        }
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Test Runner
// ===----------------------------------------------------------------------===//

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var bugReproduced = false

func test(_ name: String, expected: Int, body: () -> Void) {
    deinitCount = 0
    body()
    let passed = deinitCount == expected
    if !passed { failures += 1 }
    print("\(passed ? "PASS" : "FAIL"): \(name) — expected \(expected), got \(deinitCount)")
    if !passed { print("  *** BUG: element deinit not called through nested chain ***") }
    print()
}

func testBug(_ name: String, expected: Int, body: () -> Void) {
    deinitCount = 0
    body()
    let passed = deinitCount == expected
    if !passed {
        failures += 1
        bugReproduced = true
    }
    print("\(passed ? "PASS" : "FAIL"): \(name) — expected \(expected), got \(deinitCount)")
    if !passed { print("  *** BUG #86652: @_rawLayout member destruction not synthesized ***") }
    print()
}

print("=== Nested Deinit Chain Verification ===")
print("Toolchain: Swift 6.2.4")
print("Setup: 4 packages (Element → Storage[@_rawLayout] → Buffer → Container)")
print()

print("--- Group A: Regular stored properties (control) ---")
print()

test("V1: One level, direct (control)", expected: 1) {
    let _ = V1_Direct(1)
}

test("V2: Two levels, type generic only", expected: 1) {
    let _ = V2_TypeGeneric(2)
}

test("V3: Two levels, type generic + value generic <4>", expected: 1) {
    let _ = V3_Full<4>(3)
}

test("V4: V3 + _deinitWorkaround <4>", expected: 1) {
    let _ = V4_WithWorkaround<4>(4)
}

test("V5: Two levels, enum-wrapped <4>", expected: 1) {
    let _ = V5_EnumWrapped<4>(5)
}

test("V6: Nested in generic extension <4>", expected: 1) {
    let _ = Outer<Tracked>.Static<4>(element: Tracked(6))
}

test("V7: V6 + _deinitWorkaround <4>", expected: 1) {
    let _ = Outer<Tracked>.StaticFixed<4>(element: Tracked(7))
}

test("V8: InlineArray in middle storage <4>", expected: 1) {
    let _ = V8_InlineArray<4>(8)
}

test("V9: V8 nested in generic extension <4>", expected: 1) {
    let _ = Outer<Tracked>.StaticInlineArray<4>(element: Tracked(9))
}

test("V10: Deeply nested middle (production nesting) <4>", expected: 1) {
    let _ = Outer<Tracked>.StaticDeepNested<4>(element: Tracked(10))
}

test("V11: V10 + _deinitWorkaround <4>", expected: 1) {
    let _ = Outer<Tracked>.StaticDeepNestedFixed<4>(element: Tracked(11))
}

print("--- Group B: @_rawLayout-backed storage (bug reproduction) ---")
print()

testBug("V12: @_rawLayout middle, flat <4>", expected: 1) {
    let _ = V12_RawLayout<4>(12)
}

testBug("V13: V12 + _deinitWorkaround <4>", expected: 1) {
    let _ = V13_RawLayoutFixed<4>(13)
}

testBug("V14: @_rawLayout nested in generic extension <4>", expected: 1) {
    var storage = InlineStorage<Tracked, 4>()
    storage.append(Tracked(14))
    let _ = Outer<Tracked>.StaticRaw<4>(storage: storage)
}

testBug("V15: V14 + _deinitWorkaround <4>", expected: 1) {
    var storage = InlineStorage<Tracked, 4>()
    storage.append(Tracked(15))
    let _ = Outer<Tracked>.StaticRawFixed<4>(storage: storage)
}

testBug("V16: @_rawLayout deeply nested (production nesting) <4>", expected: 1) {
    var storage = InlineStorage<Tracked, 4>()
    storage.append(Tracked(16))
    let _ = Outer<Tracked>.StaticDeepRaw<4>(storage: storage)
}

testBug("V17: V16 + _deinitWorkaround <4>", expected: 1) {
    var storage = InlineStorage<Tracked, 4>()
    storage.append(Tracked(17))
    let _ = Outer<Tracked>.StaticDeepRawFixed<4>(storage: storage)
}

print("=== Summary: \(failures) failure(s) ===")
if bugReproduced {
    print("Bug #86652: @_rawLayout variant reproduced in this experiment.")
    print("Workaround: _deinitWorkaround: AnyObject? + manual cleanup in deinit.")
} else if failures == 0 {
    print("All variants pass — bug #86652 appears FIXED in this toolchain.")
    print("Action: Remove _deinitWorkaround from all production types.")
}
