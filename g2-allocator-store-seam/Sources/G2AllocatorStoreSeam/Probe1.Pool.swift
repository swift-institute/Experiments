// ===----------------------------------------------------------------------===//
//
// Probe 1 — Pool as a typed Store.
//
// `G2.Pool<Element>` carves a `Memory.Contiguous<Byte>` into `capacity`
// Element-sized slots plus a free-list, and conforms to `Store.`Protocol``.
//
// ===----------------------------------------------------------------------===//

public import Index_Primitives
import Memory_Contiguous_Primitives
public import Store_Protocol_Primitives
import Affine_Primitives_Standard_Library_Integration
import Byte_Primitive
import Cardinal_Primitive
import Memory_Primitive
import Ordinal_Primitive

extension G2 {
    /// A fixed-slot pool allocator presented as a typed `Store.`Protocol``.
    ///
    /// Backing is a single `Memory.Contiguous<Byte>` carved into `capacity`
    /// element-sized, element-aligned slots. A LIFO free-list (a sidecar stack of
    /// free slot indices) supplies `allocate()` / `free(_:)`. Occupancy — *which*
    /// slots currently hold an initialized element — is tracked by an out-of-band
    /// `_occupied` bitset, because the Store seam itself has no slot-occupancy
    /// vocabulary (see the FINDING block at the bottom of this file).
    ///
    /// `Element: ~Copyable` flows through to the slot surface; the backing is raw
    /// bytes, so the element type is never required to be `BitwiseCopyable`.
    public struct Pool<Element: ~Copyable>: ~Copyable {

        /// Raw byte backing — one contiguous region holding all slots.
        var _bytes: Memory.Contiguous<Byte>

        /// Byte stride between consecutive slots (element stride, alignment-rounded).
        let _slotStride: Int

        /// Number of physical slots.
        let _capacity: Index<Element>.Count

        /// LIFO free-list of slot ordinals available for allocation.
        ///
        /// SIDE-CHANNEL #1. The Store seam carries no free/used distinction, so the
        /// allocation discipline lives entirely here, beside the seam.
        var _freeList: [Int]

        /// Occupancy oracle: `_occupied[i]` is true iff slot `i` currently holds an
        /// initialized element.
        ///
        /// SIDE-CHANNEL #2. The Store `subscript(slot:)` precondition is "the slot
        /// must be initialized" — but the seam offers no way to *ask* whether a slot
        /// is initialized. A sparse pool MUST keep this oracle out-of-band.
        var _occupied: [Bool]

        /// Creates a pool of `capacity` element-sized slots.
        public init(capacity: Index<Element>.Count) {
            let n = Int(bitPattern: capacity)
            let stride = Swift.max(MemoryLayout<Element>.stride, 1)
            let alignment = Swift.max(MemoryLayout<Element>.alignment, 1)

            let raw = unsafe UnsafeMutableRawPointer.allocate(
                byteCount: Swift.max(stride * n, 1),
                alignment: alignment
            )
            let bound = unsafe raw.bindMemory(to: Byte.self, capacity: Swift.max(stride * n, 1))
            self._bytes = unsafe Memory.Contiguous<Byte>(adopting: bound, count: Swift.max(stride * n, 1))
            self._slotStride = stride
            self._capacity = capacity
            // Virgin slots pushed high→low so allocate() hands out 0,1,2,… first.
            self._freeList = (0..<n).reversed().map { $0 }
            self._occupied = Array(repeating: false, count: n)
        }

        deinit {
            // Honor the occupancy oracle: deinitialize exactly the live slots before
            // the byte region is freed. THIS is the teardown the Store seam cannot
            // express on its own — it has `move(at:)` per slot but no "which slots".
            for i in 0..<_occupied.count where _occupied[i] {
                let p = unsafe _slotPointer(ordinal: i)
                unsafe p.deinitialize(count: 1)
            }
            // `_bytes`'s own deinit frees the raw allocation.
        }
    }
}

// MARK: - Slot addressing

extension G2.Pool where Element: ~Copyable {
    /// Typed pointer to the slot at the given 0-based ordinal.
    @unsafe
    func _slotPointer(ordinal: Int) -> UnsafeMutablePointer<Element> {
        // `Memory.Contiguous<Byte>` is a read-only owner; `unsafeBaseAddress` is the
        // documented escape hatch. We re-derive a mutable raw pointer from it.
        let base = unsafe UnsafeMutableRawPointer(mutating: _bytes.unsafeBaseAddress)
        return unsafe base.advanced(by: ordinal * _slotStride)
            .assumingMemoryBound(to: Element.self)
    }

    /// Typed pointer to the slot named by a typed `Index<Element>`.
    @unsafe
    func _slotPointer(at slot: Index<Element>) -> UnsafeMutablePointer<Element> {
        unsafe _slotPointer(ordinal: Int(bitPattern: Index<Element>.Offset(fromZero: slot)))
    }
}

// MARK: - Store.Protocol witnesses

extension G2.Pool where Element: ~Copyable {
    /// Witnesses `capacity`.
    public var capacity: Index<Element>.Count { _capacity }

    /// Witnesses `subscript(slot:)` — read/write the INITIALIZED element at `slot`.
    ///
    /// The seam's precondition "slot must be initialized" is on the *caller*; this
    /// witness cannot enforce it without consulting the out-of-band `_occupied`
    /// oracle, which the seam never threads in. A debug assertion is the best the
    /// conformer can do.
    public subscript(slot: Index<Element>) -> Element {
        _read {
            let p = unsafe _slotPointer(at: slot)
            yield unsafe p.pointee
        }
        _modify {
            let p = unsafe _slotPointer(at: slot)
            yield &(unsafe p.pointee)
        }
    }

    /// Witnesses `initialize(at:to:)` — uninit → init at `slot`.
    public mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        let p = unsafe _slotPointer(at: slot)
        unsafe p.initialize(to: consume element)
        _occupied[Int(bitPattern: Index<Element>.Offset(fromZero: slot))] = true
    }

    /// Witnesses `move(at:)` — init → uninit at `slot`.
    public mutating func move(at slot: Index<Element>) -> Element {
        let p = unsafe _slotPointer(at: slot)
        _occupied[Int(bitPattern: Index<Element>.Offset(fromZero: slot))] = false
        return unsafe p.move()
    }
}

extension G2.Pool: Store.`Protocol` where Element: ~Copyable {}

// MARK: - Allocation surface (NOT part of Store.Protocol)

extension G2.Pool where Element: ~Copyable {
    /// Pops a free slot, or `nil` if the pool is exhausted.
    ///
    /// Returns an UNINITIALIZED slot. The caller must `initialize(at:to:)` it before
    /// reading. Note: allocation and initialization are TWO separate steps living on
    /// TWO separate surfaces (this method vs. the Store witness).
    public mutating func allocate() -> Index<Element>? {
        guard let ordinal = _freeList.popLast() else { return nil }
        // Build a typed Index<Element> from a runtime ordinal: a Cardinal-backed
        // Count, mapped to an Ordinal-backed Index. (The canonical ecosystem idiom —
        // cf. Memory.Pool `slotCount.map(Ordinal.init)`.)
        return Index<Element>.Count(Cardinal(UInt(ordinal))).map(Ordinal.init)
    }

    /// Returns a slot to the free-list.
    ///
    /// Precondition (caller-enforced, invisible to the seam): the slot's element has
    /// already been moved/deinitialized via `move(at:)`.
    public mutating func free(_ slot: Index<Element>) {
        let ordinal = Int(bitPattern: Index<Element>.Offset(fromZero: slot))
        _freeList.append(ordinal)
    }
}

// FINDING: Pool vs the Store.Protocol seam
// ========================================
//
// COMPILES: YES. `G2.Pool<Element: ~Copyable>` conforms to `Store.`Protocol``
// cleanly — all four requirements (`capacity`, `subscript(slot:)`,
// `initialize(at:)`, `move(at:)`) have natural, direct witnesses over the carved
// byte region. The `_read`/`_modify` idiom is copied verbatim from the heap
// conformer and needed no contortion.
//
// WHERE IT IS NATURAL:
//   - `subscript(slot:)`/`initialize`/`move` are PER-SLOT, RANDOM-ACCESS, typed.
//     A pool is exactly per-slot random access. The four verbs map 1:1 onto "write
//     the slot I allocated", "read it", "take it back". No impedance at all.
//   - `capacity` is the slot count — trivially the pool's fixed capacity.
//   - `Element: ~Copyable` flows straight through; the raw-byte backing never
//     demands BitwiseCopyable, so move-only payloads work.
//
// WHERE IT IS FORCED (the sparse-occupancy crux):
//   - The seam's MODEL is a DENSE store: every slot in [0, capacity) is assumed
//     initialized (the subscript precondition). A pool's defining feature is SPARSE
//     occupancy: free (uninitialized) slots are interspersed with live ones.
//   - The seam gives the conformer NO place to record or answer "is slot i
//     initialized?". So the init oracle (`_occupied`) and the free-list itself live
//     ENTIRELY OUT OF BAND (SIDE-CHANNEL #1 and #2 above). The free-list IS the
//     allocation truth; `_occupied` IS the init truth; NEITHER is visible through
//     `Store.`Protocol``.
//   - `Store.Initialization` (the ledger the seam DOES ship) is a ≤2-range view
//     (`.empty` / `.one(range)` / `.two(first,second)`). A pool's live set is an
//     ARBITRARY subset of slots — it cannot be expressed as ≤2 contiguous ranges
//     once any interior slot is freed. So a pool can only ever honestly vend
//     `.empty` (which is what the REAL `Storage.Pool` does — confirmed:
//     swift-storage-pool-primitives/.../Storage.Pool+Store.Protocol.swift vends
//     `.empty` with an explicit "the ≤2-range view cannot express it" comment).
//   - Consequence: the SEAM works for the slot verbs, but the SEAM IS NOT
//     SELF-SUFFICIENT for a pool — correct teardown (deinit) and safe subscripting
//     both require the out-of-band occupancy oracle. The Store conformance is a
//     PARTIAL view of a Pool: it exposes the typed slot mechanics but hides the
//     allocation/occupancy discipline that makes a pool a pool.
//   - Also note the allocation surface (`allocate`/`free`) is necessarily SEPARATE
//     from the Store surface. `allocate()` returns an UNINITIALIZED slot; the seam
//     then initializes it. Two surfaces, two steps — Store cannot model allocation.
