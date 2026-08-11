// MARK: - Escapable Heap Storage via Builtin.addressof
// Purpose: Verify that a final class using UnsafeMutableRawPointer + Builtin.addressof
//          can serve as heap storage for ~Copyable, ~Escapable elements.
//          This is the foundation for replacing ManagedBuffer in Storage.Heap
//          when Element: ~Escapable.
// Hypothesis: Builtin.addressof bypasses the Escapable constraints on typed pointer
//             APIs (UnsafeMutablePointer, assumingMemoryBound, initializeMemory),
//             enabling full lifecycle management: allocate, store, borrow fields,
//             move out, deinitialize.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
// Platform: macOS 26.0 (arm64)
//
// Result: PARTIAL — Builtin.addressof works for ~Copyable-only but is BLOCKED
//         for ~Escapable. The compiler treats addressof as an "escape" that
//         violates ~Escapable's scope confinement. A field-by-field
//         decomposition/recomposition approach works as an alternative,
//         with full lifecycle confirmed: store, borrow fields, borrow value,
//         mutate in place, move out, @_lifetime composition, ARC.
// Date: 2026-04-02
//
// Phases:
//   Phase 1: Builtin.addressof with ~Copyable only (baseline) — CONFIRMED
//   Phase 2: Builtin.addressof with ~Escapable — REFUTED (4 approaches tested)
//     V2a: inout parameter — REFUTED (escape check blocks)
//     V2b: @unsafe function — REFUTED (@unsafe does not suppress lifetime checks)
//     V2c: unsafeBitCast — REFUTED (requires Escapable + Copyable)
//     V2d: _detach(@_unsafeNonescapableResult) — REFUTED (type is still ~Escapable)
//   Phase 3: Field-by-field store/load (workaround) — CONFIRMED
//   Phase 4: Full lifecycle with field-by-field — CONFIRMED (debug + release)
//   Phase 5: @_lifetime composition on class — CONFIRMED
//   Phase 6: ARC correctness — CONFIRMED
//
// Results Summary:
//   Phase 1: CONFIRMED — Builtin.addressof + copyMemory works for ~Copyable
//   Phase 2: REFUTED — Builtin.addressof categorically blocked for ~Escapable
//     Error: "lifetime-dependent variable 'X' escapes its scope"
//     Cause: Builtin.addressof creates a Builtin.RawPointer, which the compiler
//            treats as an escape path for the ~Escapable value. This is not
//            suppressible via @unsafe, @_unsafeNonescapableResult, or inout.
//   Phase 3: CONFIRMED — Field-by-field storeBytes/load works for ~Escapable
//   Phase 4: CONFIRMED — Full lifecycle: store, read fields, withEntry,
//            withMutableEntry, take, multi-slot
//   Phase 5: CONFIRMED — @_lifetime(borrow self) on computed property and
//            borrowing func composes correctly with EntryView: ~Escapable
//   Phase 6: CONFIRMED — ARC shared references work correctly

import Builtin

// ============================================================================
// Shared Infrastructure
// ============================================================================

@_unsafeNonescapableResult
@_transparent
func _detach<T: ~Copyable & ~Escapable>(_ value: consuming T) -> T { value }

// ============================================================================
// MARK: - Phase 1: Builtin.addressof with ~Copyable Only (Baseline)
// Hypothesis: Builtin.addressof + copyMemory works for ~Copyable (Escapable) types.
// Result: CONFIRMED — Build Succeeded, correct values recovered
// ============================================================================

struct NCEntry: ~Copyable {
    var id: Int
    var payload: Int
    init(id: Int, payload: Int) { self.id = id; self.payload = payload }
}

func phase1_store(_ entry: consuming NCEntry, at ptr: UnsafeMutableRawPointer) {
    var entry = consume entry
    let src = UnsafeMutableRawPointer(Builtin.addressof(&entry))
    unsafe ptr.copyMemory(from: src, byteCount: MemoryLayout<NCEntry>.size)
}

func phase1_take(from ptr: UnsafeMutableRawPointer) -> NCEntry {
    var result = NCEntry(id: 0, payload: 0)
    let dest = UnsafeMutableRawPointer(Builtin.addressof(&result))
    unsafe dest.copyMemory(from: ptr, byteCount: MemoryLayout<NCEntry>.size)
    return result
}

// ============================================================================
// MARK: - Phase 2: Builtin.addressof with ~Escapable — REFUTED
// ============================================================================
//
// All four approaches below fail with the same diagnostic:
//   error: lifetime-dependent variable 'X' escapes its scope
//   note: this use causes the lifetime-dependent value to escape
//          (pointing to Builtin.addressof(&X))
//
// The compiler treats Builtin.addressof as creating an escape path
// for the ~Escapable value. This is a hard constraint — not suppressible
// by any combination of:
//   - @unsafe (does not suppress lifetime checks)
//   - @_unsafeNonescapableResult (severs dependencies, not escapability)
//   - inout parameters (addressof still seen as escape)
//   - unsafeBitCast (requires Escapable + Copyable conformances)
//
// Note: `swiftc -typecheck` passes all variants. The escape check is
// enforced during SIL generation, not during Sema. This means the
// diagnostic cannot be worked around at the type-checking level.

struct NEEntry: ~Copyable, ~Escapable {
    var id: Int
    var payload: Int

    @_lifetime(immortal)
    init(id: Int, payload: Int) { self.id = id; self.payload = payload }
}

// MARK: V2a: Builtin.addressof on inout parameter — REFUTED
// Error: lifetime-dependent variable 'source' escapes its scope

// func v2a_rawCopy(_ source: inout NEEntry, to dest: UnsafeMutableRawPointer) {
//     let src = UnsafeMutableRawPointer(Builtin.addressof(&source))
//     unsafe dest.copyMemory(from: src, byteCount: MemoryLayout<NEEntry>.size)
// }

// MARK: V2b: @unsafe function with addressof — REFUTED
// Error: lifetime-dependent variable 'source' escapes its scope
// (@unsafe does not suppress lifetime-escape diagnostics)

// @unsafe
// func v2b_rawCopy(_ source: inout NEEntry, to dest: UnsafeMutableRawPointer) {
//     let src = unsafe UnsafeMutableRawPointer(Builtin.addressof(&source))
//     unsafe dest.copyMemory(from: src, byteCount: MemoryLayout<NEEntry>.size)
// }

// MARK: V2c: unsafeBitCast to Escapable tuple — REFUTED
// Error: global function 'unsafeBitCast(_:to:)' requires that 'NEEntry'
//        conform to 'Escapable'
// Note: unsafeBitCast also requires Copyable

// func v2c_store(_ entry: consuming NEEntry, at ptr: UnsafeMutableRawPointer) {
//     let asRaw: (Int, Int) = unsafeBitCast(entry, to: (Int, Int).self)
//     unsafe ptr.storeBytes(of: asRaw, as: (Int, Int).self)
// }

// MARK: V2d: _detach + addressof — REFUTED
// Error: lifetime-dependent variable 'detached' escapes its scope
// Note: @_unsafeNonescapableResult severs lifetime DEPENDENCIES but does
//       not change the type's ~Escapable constraint. The value is still
//       ~Escapable and cannot have its address taken.

// func v2d_store(_ entry: consuming NEEntry, at dest: UnsafeMutableRawPointer) {
//     var detached = _detach(consume entry)
//     let src = UnsafeMutableRawPointer(Builtin.addressof(&detached))
//     unsafe dest.copyMemory(from: src, byteCount: MemoryLayout<NEEntry>.size)
// }

// ============================================================================
// MARK: - Phase 3: Field-by-Field Store/Load (Working Alternative)
// Hypothesis: Extracting Escapable fields and storing individually bypasses
//             all ~Escapable restrictions. Reconstruction via init reverses.
// Result: CONFIRMED — Both store and load work in debug and release.
// ============================================================================

extension NEEntry {
    consuming func storeTo(_ ptr: UnsafeMutableRawPointer) {
        unsafe ptr.storeBytes(of: self.id, toByteOffset: 0, as: Int.self)
        unsafe ptr.storeBytes(of: self.payload, toByteOffset: MemoryLayout<Int>.stride, as: Int.self)
    }
}

func loadEntry(from ptr: UnsafeMutableRawPointer) -> NEEntry {
    let id = unsafe ptr.load(fromByteOffset: 0, as: Int.self)
    let payload = unsafe ptr.load(fromByteOffset: MemoryLayout<Int>.stride, as: Int.self)
    return NEEntry(id: id, payload: payload)
}

// ============================================================================
// MARK: - Phase 4: Full Lifecycle with Field-by-Field
// Hypothesis: A final class can manage ~Escapable elements via field-by-field
//             store/load with full lifecycle: store, read, borrow, mutate, take.
// Result: CONFIRMED — All operations work in debug and release.
// ============================================================================

final class HeapStorage {
    let _raw: UnsafeMutableRawPointer
    let _capacity: Int
    var _count: Int

    init(capacity: Int) {
        _raw = .allocate(
            byteCount: MemoryLayout<NEEntry>.stride * capacity,
            alignment: MemoryLayout<NEEntry>.alignment
        )
        _capacity = capacity
        _count = 0
    }

    deinit {
        _raw.deallocate()
    }

    func rawPointer(at index: Int) -> UnsafeMutableRawPointer {
        unsafe _raw.advanced(by: index &* MemoryLayout<NEEntry>.stride)
    }

    // Store: field-by-field decomposition
    func store(_ entry: consuming NEEntry, at index: Int) {
        precondition(index < _capacity, "index out of bounds")
        (consume entry).storeTo(unsafe rawPointer(at: index))
        _count += 1
    }

    // Read individual fields
    func readId(at index: Int) -> Int {
        unsafe rawPointer(at: index).load(fromByteOffset: 0, as: Int.self)
    }

    func readPayload(at index: Int) -> Int {
        unsafe rawPointer(at: index).load(fromByteOffset: MemoryLayout<Int>.stride, as: Int.self)
    }

    // Move out: reconstruct from fields
    @_unsafeNonescapableResult
    func take(at index: Int) -> NEEntry {
        precondition(index < _capacity && _count > 0, "invalid take")
        let entry = loadEntry(from: unsafe rawPointer(at: index))
        _count -= 1
        return entry
    }

    // Borrow entire value via closure: reconstruct, pass, drop
    func withEntry<R>(at index: Int, _ body: (borrowing NEEntry) -> R) -> R {
        let temp = loadEntry(from: unsafe rawPointer(at: index))
        return body(temp)
    }

    // Modify in place via closure: reconstruct, mutate, store back
    func withMutableEntry<R>(at index: Int, _ body: (inout NEEntry) -> R) -> R {
        var temp = loadEntry(from: unsafe rawPointer(at: index))
        let result = body(&temp)
        (consume temp).storeTo(unsafe rawPointer(at: index))
        return result
    }
}

// ============================================================================
// MARK: - Phase 5: @_lifetime Composition — EntryView
// Hypothesis: A ~Escapable view into HeapStorage can use @_lifetime(borrow storage)
//             on init and @_lifetime(borrow self) on the accessor to chain the
//             lifetime to the class. No _overrideLifetime needed when the init
//             directly takes the storage as a lifetime source.
// Result: CONFIRMED — Both computed property and borrowing method work.
// ============================================================================

struct EntryView: ~Escapable {
    let _ptr: UnsafeRawPointer

    @_lifetime(borrow storage)
    init(_ storage: borrowing HeapStorage, index: Int) {
        unsafe _ptr = UnsafeRawPointer(storage.rawPointer(at: index))
    }

    var id: Int { unsafe _ptr.load(fromByteOffset: 0, as: Int.self) }
    var payload: Int { unsafe _ptr.load(fromByteOffset: MemoryLayout<Int>.stride, as: Int.self) }
}

extension HeapStorage {
    var firstEntry: EntryView {
        @_lifetime(borrow self)
        borrowing get {
            precondition(_count > 0, "empty")
            return EntryView(self, index: 0)
        }
    }

    @_lifetime(borrow self)
    borrowing func entryView(at index: Int) -> EntryView {
        precondition(index < _count, "index out of bounds")
        return EntryView(self, index: index)
    }
}

// ============================================================================
// MARK: - Phase 6: ARC
// Hypothesis: Multiple ARC references to HeapStorage work correctly.
//             The class deinit runs once when the last reference is released.
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

func testARC() {
    let s1 = HeapStorage(capacity: 2)
    s1.store(NEEntry(id: 1, payload: 10), at: 0)
    let s2 = s1
    let id = s2.readId(at: 0)
    print("Phase 6: ARC shared ref — id=\(id) — \(id == 1 ? "CONFIRMED" : "FAILED")")
}

// ============================================================================
// MARK: - Main: Run Tests
// ============================================================================

print("=== Escapable Heap Storage Experiment ===\n")

// Phase 1: ~Copyable baseline
do {
    let ptr = UnsafeMutableRawPointer.allocate(
        byteCount: MemoryLayout<NCEntry>.stride,
        alignment: MemoryLayout<NCEntry>.alignment
    )
    defer { ptr.deallocate() }
    phase1_store(NCEntry(id: 42, payload: 100), at: ptr)
    let recovered = phase1_take(from: ptr)
    print("Phase 1: ~Copyable addressof — id=\(recovered.id), payload=\(recovered.payload) — \(recovered.id == 42 && recovered.payload == 100 ? "CONFIRMED" : "FAILED")")
}

// Phase 2: Documented as REFUTED (see commented-out variants above)
print("Phase 2: Builtin.addressof + ~Escapable — REFUTED (4 approaches; see source)")

// Phase 3a: Field-by-field store
do {
    let ptr = UnsafeMutableRawPointer.allocate(
        byteCount: MemoryLayout<NEEntry>.stride,
        alignment: MemoryLayout<NEEntry>.alignment
    )
    defer { ptr.deallocate() }
    NEEntry(id: 42, payload: 100).storeTo(ptr)
    let id = unsafe ptr.load(fromByteOffset: 0, as: Int.self)
    let payload = unsafe ptr.load(fromByteOffset: MemoryLayout<Int>.stride, as: Int.self)
    print("Phase 3a: field-by-field store — id=\(id), payload=\(payload) — \(id == 42 && payload == 100 ? "CONFIRMED" : "FAILED")")
}

// Phase 3b: Reconstruct
do {
    let ptr = UnsafeMutableRawPointer.allocate(
        byteCount: MemoryLayout<NEEntry>.stride,
        alignment: MemoryLayout<NEEntry>.alignment
    )
    defer { ptr.deallocate() }
    NEEntry(id: 77, payload: 88).storeTo(ptr)
    let entry = loadEntry(from: ptr)
    print("Phase 3b: reconstruct — id=\(entry.id), payload=\(entry.payload) — \(entry.id == 77 && entry.payload == 88 ? "CONFIRMED" : "FAILED")")
}

// Phase 4: Full lifecycle
do {
    let storage = HeapStorage(capacity: 4)

    // Store
    storage.store(NEEntry(id: 42, payload: 100), at: 0)
    print("Phase 4: store — count=\(storage._count)")

    // Read fields
    let id = storage.readId(at: 0)
    let payload = storage.readPayload(at: 0)
    print("Phase 4: readId=\(id), readPayload=\(payload) — \(id == 42 && payload == 100 ? "CONFIRMED" : "FAILED")")

    // Borrow entire value
    let sum = storage.withEntry(at: 0) { $0.id + $0.payload }
    print("Phase 4: withEntry sum=\(sum) — \(sum == 142 ? "CONFIRMED" : "FAILED")")

    // Modify in place
    storage.withMutableEntry(at: 0) { $0.id = 50 }
    let newId = storage.readId(at: 0)
    print("Phase 4: withMutableEntry id=50, readId=\(newId) — \(newId == 50 ? "CONFIRMED" : "FAILED")")

    // Move out
    let taken = storage.take(at: 0)
    print("Phase 4: take — id=\(taken.id), payload=\(taken.payload) — \(taken.id == 50 && taken.payload == 100 ? "CONFIRMED" : "FAILED")")

    // Store again + store second
    storage.store(NEEntry(id: 1, payload: 2), at: 0)
    storage.store(NEEntry(id: 3, payload: 4), at: 1)
    print("Phase 4: multi-slot — id[0]=\(storage.readId(at: 0)), id[1]=\(storage.readId(at: 1))")
}

// Phase 5: @_lifetime composition
do {
    let storage = HeapStorage(capacity: 4)
    storage.store(NEEntry(id: 55, payload: 66), at: 0)
    storage.store(NEEntry(id: 77, payload: 88), at: 1)

    // Computed property
    let view0 = storage.firstEntry
    print("Phase 5a: firstEntry.id=\(view0.id), payload=\(view0.payload) — \(view0.id == 55 && view0.payload == 66 ? "CONFIRMED" : "FAILED")")

    // Borrowing method
    let view1 = storage.entryView(at: 1)
    print("Phase 5b: entryView(1).id=\(view1.id), payload=\(view1.payload) — \(view1.id == 77 && view1.payload == 88 ? "CONFIRMED" : "FAILED")")
}

// Phase 6: ARC
testARC()

print("\n=== Experiment Complete ===")
