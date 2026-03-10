// MARK: - ~Copyable Nested Deinit Chain (Cross-Package, Generic Element, Value Generic)
//
// Purpose: Reproduce the Queue.Static deinit bug — element destructors are not
//          called when a ~Copyable container wraps a ~Copyable buffer wraps an element,
//          all across PACKAGE boundaries with generic Element: ~Copyable and value generics.
//
// Status: NOT REPRODUCED (2026-03-10, Swift 6.2.4)
//   All 11 variants pass. The simplified reproduction does NOT use @_rawLayout
//   storage or the Property.View deinitialize pattern, so the bug doesn't manifest.
//   The production bug requires the exact Buffer.Ring.Inline → Storage.Inline chain
//   with @_rawLayout and per-slot bitvector tracking.
//   Workaround in production: remove.all() through mutable pointer in deinit body.
//
// Production chain (3 separate packages):
//   Queue.Static<capacity>              (queue-primitives)  — outer container
//     → Buffer<Element>.Ring.Inline<capacity>  (buffer-primitives)  — middle buffer
//       → Storage<Element>.Inline<capacity>    (storage-primitives) — raw storage
//
// The existing noncopyable-inline-deinit experiment (V1-V4) tests ONE level of
// wrapping with concrete element types and passes in 6.2.4. This experiment adds:
//   - Cross-PACKAGE boundaries (3 separate SwiftPM packages)
//   - Generic Element: ~Copyable (not concrete types)
//   - Value generic capacity threading through the chain
//
// Tracking: swiftlang/swift #86652 (InlineArray + value generic deinit)
//
// Variants:
//   V1: One level, direct                           — control
//   V2: Two levels, type generic only               — isolates type generic
//   V3: Two levels, type generic + value generic    — mirrors production
//   V4: V3 + _deinitWorkaround on outer             — tests the fix
//   V5: V3 but outer wraps enum                     — mirrors Queue.Small
//   V6: V3 but outer is nested in generic extension — mirrors Queue<Element>.Static

import Element
import Buffer

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

// MARK: - Test Runner

nonisolated(unsafe) var failures = 0

func test(_ name: String, expected: Int, body: () -> Void) {
    deinitCount = 0
    body()
    let passed = deinitCount == expected
    if !passed { failures += 1 }
    print("\(passed ? "PASS" : "FAIL"): \(name) — expected \(expected), got \(deinitCount)")
    if !passed { print("  *** BUG: element deinit not called through nested chain ***") }
    print()
}

print("=== Nested Deinit Chain Verification ===")
print("Toolchain: Swift 6.2.4")
print("Setup: 3 packages (Element → Buffer → Container)")
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

print("=== Summary: \(failures) failure(s) ===")
if failures > 0 {
    print("Bug #86652 variant: nested ~Copyable deinit chain")
    print("still present in this toolchain.")
}
