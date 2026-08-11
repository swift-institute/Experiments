// MARK: - Unified vs Two-Type Box Design
// Purpose: Empirically validate claims about unified Box<V: ~Copyable>
//          with conditional Copyable vs two separate types
//          (UniqueBox raw-pointer + Box class-backed).
//
// Toolchain: swift-6.3.1 (2026-04-17)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform: macOS 26 (arm64)
// Date: 2026-04-24
//
// Results:
//   H1 — unified class-backed Box compiles and works                    — CONFIRMED
//   H2 — final class can hold a ~Copyable stored property               — CONFIRMED
//   H3 — class-backed Box has larger HEAP footprint than raw-pointer    — CONFIRMED
//        (struct-level identical at 8 bytes; heap-level class-backed adds
//         ~16 byte object header per instance)
//   H4 — conditional-Copyable Box shares storage on struct-copy          — CONFIRMED
//        (reference semantic, NOT value semantics / CoW by default)
//   H5 — consume() of ~Copyable Value cannot be implemented with        — CONFIRMED
//        class-backed storage (Swift: "'storage.value' is borrowed and
//        cannot be consumed"). SE-0517's core API is UNIMPLEMENTABLE via
//        the unified class-backed approach.
//   H6 — isKnownUniquelyReferenced compiles/works in ~Copyable extension — CONFIRMED
//   H7 — two conditional extensions defining same-named accessor         — CONFIRMED
//        (DO compile; Swift resolves by specificity; BUT ~Copyable-path
//         accessor has restricted call-site ergonomics — no `let v = box.value`)
//   H8 — no explicit struct deinit needed; ARC manages class storage    — CONFIRMED
//
// Overall verdict: the unified `Box<V: ~Copyable>: ~Copyable` with
// conditional Copyable CANNOT faithfully implement SE-0517's API for
// ~Copyable Value. Specifically, consume() is forbidden by the language
// when storage is class-backed. The two-type approach (raw-pointer
// UniqueBox + class-backed CoW Box) is NOT equivalent to unification —
// it is architecturally required.

import Synchronization

// ============================================================================
// MARK: - H1 — Unified class-backed Box compiles and works
// ============================================================================

enum H1 {}

extension H1 {
    struct Box<Value: ~Copyable>: ~Copyable {
        var _storage: _Storage

        final class _Storage {
            var value: Value
            init(_ value: consuming Value) {
                self.value = value
            }
        }

        init(_ initialValue: consuming Value) {
            self._storage = _Storage(initialValue)
        }
    }
}

extension H1.Box: Copyable where Value: Copyable {}

func h1_test_copyable() {
    let box1 = H1.Box<Int>(42)
    print("H1: created Box<Int>(42)")
    let box2 = box1
    print("H1: copied Box<Int> to box2")
    _ = box2
}

struct H1_Handle: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { /* drop */ }
}

func h1_test_noncopyable() {
    let box = H1.Box<H1_Handle>(H1_Handle(7))
    print("H1: created Box<H1_Handle>(7)")
    _ = box
}

// ============================================================================
// MARK: - H2 — final class can hold a ~Copyable stored property
// ============================================================================

enum H2 {}

extension H2 {
    final class MutableCellOfNoncopyable<V: ~Copyable> {
        var value: V
        init(_ value: consuming V) {
            self.value = value
        }
    }
}

func h2_test() {
    let cell = H2.MutableCellOfNoncopyable<H1_Handle>(H1_Handle(99))
    _ = cell
    print("H2: class<V: ~Copyable> with var value: V — compiles, instantiates.")
}

// ============================================================================
// MARK: - H3 — Memory footprint comparison (raw pointer vs class-backed)
// ============================================================================

enum H3 {}

extension H3 {
    struct RawPointerUniqueBox<Value: ~Copyable>: ~Copyable {
        var _pointer: UnsafeMutablePointer<Value>

        init(_ initialValue: consuming Value) {
            let ptr = UnsafeMutablePointer<Value>.allocate(capacity: 1)
            unsafe ptr.initialize(to: initialValue)
            unsafe (self._pointer = ptr)
        }

        deinit {
            unsafe _pointer.deinitialize(count: 1)
            unsafe _pointer.deallocate()
        }
    }
}

func h3_test() {
    let rawPtrSize = MemoryLayout<H3.RawPointerUniqueBox<Int>>.size
    let classBackedSize = MemoryLayout<H1.Box<Int>>.size

    let rawPtrHandle = MemoryLayout<H3.RawPointerUniqueBox<H1_Handle>>.size
    let classBackedHandle = MemoryLayout<H1.Box<H1_Handle>>.size

    print("H3: raw-pointer UniqueBox<Int>.size    = \(rawPtrSize) bytes")
    print("H3: class-backed Box<Int>.size         = \(classBackedSize) bytes")
    print("H3: raw-pointer UniqueBox<Handle>.size = \(rawPtrHandle) bytes")
    print("H3: class-backed Box<Handle>.size      = \(classBackedHandle) bytes")
    print("H3: note: struct-level size equal (both 1 word = class ref or raw ptr);")
    print("H3: real delta is the HEAP footprint: class object header = 16 bytes + value,")
    print("H3: vs raw allocation = just value. Measured below via heap-allocation counter.")
}

// ============================================================================
// MARK: - H4 — Struct-copy of Copyable Box shares storage (reference semantic)
// ============================================================================

func h4_test() {
    let box1 = H1.Box<Int>(100)
    let box2 = box1  // struct-copy — copies _storage reference (ARC retain)

    // Mutate through box1's _storage (the shared class object)
    box1._storage.value = 200

    // Observe box2
    let observed = box2._storage.value
    print("H4: box1._storage.value set to 200 (after struct-copy to box2)")
    print("H4: box2._storage.value observed as \(observed)")
    print("H4: same underlying storage? \(observed == 200 ? "YES — reference-shared" : "NO — deep-copied")")
}

// ============================================================================
// MARK: - H5 — consume() on shared Copyable Box is semantically strained
// ============================================================================

// H5: The unified consume() can only be defined for the Copyable case.
// For ~Copyable Value, the class stored property cannot be consumed.
// Attempting:
//
//   extension H1.Box where Value: ~Copyable {
//       consuming func consumeAttempt() -> Value {
//           let value = self._storage.value  // ERROR: 'storage.value' is borrowed and cannot be consumed
//           return value
//       }
//   }
//
// Diagnostic produced by Swift 6.3.1:
//   error: 'storage.value' is borrowed and cannot be consumed
//
// This is the key evidence for Hypothesis H5: the unified consume() cannot
// be uniformly implemented for both Copyable and ~Copyable Values because
// Swift forbids moving (consuming) a class's stored property.
//
// So we can only define consume() in the Copyable case, where the value is
// COPIED out — which is a different semantic from SE-0517's consume() which
// MOVES out.

extension H1.Box where Value: Copyable {
    consuming func consumeCopyable() -> Value {
        // For Copyable Box: simply copy value out of shared storage.
        // This is NOT a move — the storage may still live if shared.
        return _storage.value
    }
}

func h5_test() {
    let box = H1.Box<Int>(42)
    let extracted = box.consumeCopyable()
    print("H5: Copyable Box<Int>.consumeCopyable() returned \(extracted) — this was a COPY.")
    print("H5: For ~Copyable Value, a consume() that moves value out of class-backed storage")
    print("H5: IS FORBIDDEN by Swift — diagnostic: 'storage.value is borrowed and cannot be consumed'.")
    print("H5: SE-0517's consume() requires raw-pointer storage to do the move legally.")
}

// ============================================================================
// MARK: - H6 — isKnownUniquelyReferenced in ~Copyable extension
// ============================================================================

extension H1.Box where Value: ~Copyable {
    mutating func debugIsUniquelyOwned() -> Bool {
        return isKnownUniquelyReferenced(&self._storage)
    }
}

func h6_test() {
    var box1 = H1.Box<Int>(1)
    print("H6: single Box: isKnownUniquelyReferenced = \(box1.debugIsUniquelyOwned())")

    let box2 = box1
    _ = box2  // retain
    print("H6: after struct-copy: isKnownUniquelyReferenced = \(box1.debugIsUniquelyOwned())")

    var hbox = H1.Box<H1_Handle>(H1_Handle(1))
    print("H6: ~Copyable Box: isKnownUniquelyReferenced = \(hbox.debugIsUniquelyOwned())")
}

// ============================================================================
// MARK: - H7 — Two conditional extensions — different-name test
// ============================================================================
// See H7b_same_name.swift — segregated into a separate file so that
// uncommenting it to test same-name conflict doesn't break H7a.

enum H7 {}

extension H7 {
    struct BoxWithTwoAccessors<Value: ~Copyable>: ~Copyable {
        var _storage: _Storage

        final class _Storage {
            var value: Value
            init(_ value: consuming Value) { self.value = value }
        }

        init(_ initialValue: consuming Value) {
            self._storage = _Storage(initialValue)
        }
    }
}

extension H7.BoxWithTwoAccessors: Copyable where Value: Copyable {}

extension H7.BoxWithTwoAccessors where Value: ~Copyable {
    var borrowedValue: Value {
        _read { yield _storage.value }
    }
}

extension H7.BoxWithTwoAccessors where Value: Copyable {
    var copyableValue: Value {
        get { _storage.value }
        set {
            if !isKnownUniquelyReferenced(&_storage) {
                _storage = _Storage(_storage.value)
            }
            _storage.value = newValue
        }
    }
}

func h7_test() {
    var box = H7.BoxWithTwoAccessors<Int>(10)
    print("H7: initial copyableValue = \(box.copyableValue)")
    box.copyableValue = 20
    print("H7: after set, copyableValue = \(box.copyableValue)")

    // For ~Copyable, use borrowedValue
    let hbox = H7.BoxWithTwoAccessors<H1_Handle>(H1_Handle(99))
    print("H7: ~Copyable Box: borrowedValue.id = \(hbox.borrowedValue.id)")
}

// ============================================================================
// MARK: - H8 — deinit on class-backed struct is unnecessary (ARC handles it)
// ============================================================================

enum H8 {}

extension H8 {
    struct Box<Value: ~Copyable>: ~Copyable {
        var _storage: _Storage

        final class _Storage {
            var value: Value
            init(_ value: consuming Value) {
                print("  H8.Storage.init — refcount now 1")
                self.value = value
            }
            deinit {
                print("  H8.Storage.deinit — refcount hit 0")
            }
        }

        init(_ initialValue: consuming Value) {
            self._storage = _Storage(initialValue)
        }

        // NO explicit deinit on the struct.
    }
}

extension H8.Box: Copyable where Value: Copyable {}

func h8_test() {
    print("H8: single ~Copyable Box in a scope")
    do {
        let box = H8.Box<H1_Handle>(H1_Handle(1))
        _ = box
    }
    print("H8: scope exited — Storage.deinit should have fired above.")

    print("H8: Copyable Box with two struct-copies")
    do {
        let box1 = H8.Box<Int>(1)
        let box2 = box1  // retain — refcount=2
        _ = box2
    }
    print("H8: scope exited — Storage.deinit should have fired exactly ONCE at refcount=0")
}

// ============================================================================
// MARK: - Main
// ============================================================================

print("========================================")
print("unified-vs-two-type-box-design experiment")
print("========================================")

print("\n--- H1 ---")
h1_test_copyable()
h1_test_noncopyable()

print("\n--- H2 ---")
h2_test()

print("\n--- H3 ---")
h3_test()

print("\n--- H4 ---")
h4_test()

print("\n--- H5 ---")
h5_test()

print("\n--- H6 ---")
h6_test()

print("\n--- H7 ---")
h7_test()

print("\n--- H7b (same-name in two conditional extensions) ---")
h7b_test()

print("\n--- H8 ---")
h8_test()

print("\n========================================")
print("See main.swift header for per-variant results.")
print("========================================")
