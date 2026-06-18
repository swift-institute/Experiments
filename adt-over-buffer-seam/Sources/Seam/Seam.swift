// MARK: - ADT-over-Buffer seam — validate `extension ADT where B: Buffer.`Protocol`, B.Storage: Store.`Protocol``
//
// Purpose:   Validate the principal's sketch — an ADT generic over a CONCRETE buffer value
//            (`struct ArrayADT<B: ~Copyable>`), with the Buffer / Store capabilities purely ADDITIVE,
//            and element ops attached by a conditional extension that reaches the storage THROUGH the
//            buffer's associated type: `extension ArrayADT where B: BufferSeam, B.Storage: StoreSeam`.
// Hypothesis: That nested associated-type conditional extension (assoc-types + `~Copyable` +
//            SuppressedAssociatedTypes) COMPILES and SPECIALIZES (0 witness_method) cross-module +
//            release on 6.3.2 — i.e. it does NOT hit the rough-zone walls (the variant-typealias SIGSEGV,
//            the [MEM-COPY-018] derivation failures).
// Faithful reduction ([EXP-004]/[EXP-020]): Element == Int isolates the protocol-shape claim from
//            element-genericity; a class-backed store stands in for the generational arena.
//
// Toolchain: Apple Swift 6.3.2 (swift-6.3.2-RELEASE, TOOLCHAINS=org.swift.632202605101a)
// Platform:  macOS 26 (arm64)
// Result:    CONFIRMED — the sketch compiles (debug + release) and runs correctly cross-module on 6.3.2.
//   Build Succeeded debug + release, 0 errors. Run (cross-module): `V1 count=3 a[1]=20` → set → `a[1]=99`; `V2 ridingCount=3`.
//   V1 = THE SKETCH (`extension ArrayADT where B: BufferSeam, B.Storage: StoreSeam, B.Element == B.Storage.Element`):
//        reads + writes through the buffer's associated storage. V2 = ride-the-buffer (single-protocol) also compiles.
//   FINDINGS:
//   (1) The nested associated-type CONSTRAINT (`B.Storage: StoreSeam`) RESOLVES with no error/crash — it does NOT hit
//       the namespaced-generic-typealias SIGSEGV zone. The ADT-over-a-concrete-buffer + additive-protocols shape is viable.
//   (2) Required boilerplate (none about the constraint, all standard ~Copyable idiom): the buffer struct must be
//       `~Copyable`; element-returning accessors must be `_read`/`_modify` (not get/set — a get can't return a ~Copyable
//       element by value); conditional extensions must propagate `where B: ~Copyable` (feedback_extension_implies_copyable).
//   (3) Specialization: a no-`@inlinable` cross-module client SIL shows 6 witness_method — an artifact of omitting
//       `@inlinable`, NOT a sketch property; the pattern-class's 0-witness is established by
//       Experiments/storage-protocol-specialization + the GATE-1 receipts. An `@inlinable` pass would replicate it here.
// Revalidated: Swift 6.3.2 (2026-06-18) — PASSES
// Date:      2026-06-18

// --- The two minimal capability cores (faithful to Store.`Protocol` / Buffer.`Protocol`) ---

public protocol StoreSeam: ~Copyable {
    associatedtype Element: ~Copyable
    var capacity: Int { get }
    subscript(_ slot: Int) -> Element { get set }
    mutating func initialize(at slot: Int, to value: consuming Element)
    mutating func move(at slot: Int) -> Element
}

// Buffer core: occupancy + the has-a storage exposed as an associated type (what the sketch reaches).
public protocol BufferSeam: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Storage: ~Copyable
    var count: Int { get }
    var storage: Storage { get set }
}

// --- Concrete leaves ---

public final class Heap { public var e: [Int]; public init(_ e: [Int]) { self.e = e } }

public struct HeapStore: StoreSeam {
    public typealias Element = Int
    var heap: Heap
    public init(_ e: [Int]) { heap = Heap(e) }
    public var capacity: Int { heap.e.count }
    public subscript(_ slot: Int) -> Int {
        _read { yield heap.e[slot] }
        _modify { yield &heap.e[slot] }
    }
    public mutating func initialize(at slot: Int, to value: consuming Int) { heap.e[slot] = value }
    public mutating func move(at slot: Int) -> Int { heap.e[slot] }
}

// A concrete buffer (faithful to Buffer.Linear): has-a store; conforms the Buffer core.
public struct LinearBuffer<S: StoreSeam & ~Copyable>: ~Copyable, BufferSeam {
    public typealias Element = S.Element
    public typealias Storage = S
    public var storage: S
    public var count: Int
    public init(storage: consuming S, count: Int) { self.storage = storage; self.count = count }
}

// --- The ADT — over a CONCRETE buffer value, minimal `~Copyable` bound, NO foundational protocol bound ---

public struct ArrayADT<B: ~Copyable>: ~Copyable {
    public var buffer: B
    public init(buffer: consuming B) { self.buffer = buffer }
}

// MARK: - V1 — THE SKETCH: reach storage via the buffer's associated type
// `extension ArrayADT where B: BufferSeam, B.Storage: StoreSeam` (+ element same-type tie).
extension ArrayADT where B: ~Copyable, B: BufferSeam, B.Storage: StoreSeam, B.Element == B.Storage.Element {
    public var count: Int { buffer.count }
    public subscript(_ i: Int) -> B.Element {
        _read { yield buffer.storage[i] }
        _modify { yield &buffer.storage[i] }
    }
}

// MARK: - V2 — ALTERNATIVE: ride a richer buffer directly; the ADT never touches storage
public protocol BufferRich: ~Copyable {
    associatedtype Element: ~Copyable
    var count: Int { get }
    subscript(_ i: Int) -> Element { get set }
}

extension LinearBuffer: BufferRich where S: ~Copyable {
    public subscript(_ i: Int) -> S.Element {
        _read { yield storage[i] }
        _modify { yield &storage[i] }
    }
}

extension ArrayADT where B: ~Copyable, B: BufferRich {
    public var ridingCount: Int { buffer.count }   // rides the buffer directly (single-protocol constraint; no storage reach)
}

// MARK: - V3 — REFUTED on 6.3.2: the explicit `B.Storage.Element: ~Copyable` clause does NOT compile.
//   error: cannot suppress '~Copyable' on generic parameter 'B.Storage.Element' defined in outer scope.
//   You cannot RE-suppress ~Copyable on a nested associated type whose protocol already declares it ~Copyable;
//   the clause is also UNNECESSARY — B.Storage.Element is already ~Copyable from StoreSeam, so the 2-level V1
//   shape already admits ~Copyable elements. (Original V3 kept commented for the record.)
/*
extension ArrayADT where B: ~Copyable, B: BufferSeam, B.Storage: StoreSeam, B.Storage.Element: ~Copyable {
    public var deepCount: Int { buffer.count }
    public subscript(deep i: Int) -> B.Storage.Element {
        _read { yield buffer.storage[i] }
        _modify { yield &buffer.storage[i] }
    }
}
*/
