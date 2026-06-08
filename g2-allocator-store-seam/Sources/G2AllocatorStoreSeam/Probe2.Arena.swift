// ===----------------------------------------------------------------------===//
//
// Probe 2 — Arena as a typed Store.
//
// A bump arena hands out VARIABLE-SIZE allocations SEQUENTIALLY from a moving
// cursor. `Store.`Protocol`` wants FIXED-SIZE typed slots with RANDOM
// `subscript(slot: Index<Element>)`. Do `capacity` / `subscript(slot:)` /
// `initialize(at:)` even have a meaningful definition for a bump arena?
//
// ===----------------------------------------------------------------------===//

public import Index_Primitives
import Memory_Contiguous_Primitives
public import Store_Protocol_Primitives
import Affine_Primitives_Standard_Library_Integration
import Byte_Primitive
import Cardinal_Primitive
public import Memory_Address_Primitives
import Memory_Primitive
import Ordinal_Primitive

extension G2 {
    /// A bump arena over a `Memory.Contiguous<Byte>`: a monotonic byte cursor.
    ///
    /// This is the HONEST bump arena. Its native surface is `bump(count:) ->
    /// Memory.Address?` (variable-size, sequential, no reuse). It does NOT and
    /// cannot expose typed random-access slots.
    public struct Arena: ~Copyable {
        /// Raw byte backing.
        var _bytes: Memory.Contiguous<Byte>

        /// Total capacity in bytes.
        let _capacityBytes: Int

        /// The bump cursor: bytes handed out so far.
        var _cursor: Int

        public init(capacityBytes: Int) {
            let n = Swift.max(capacityBytes, 1)
            let raw = unsafe UnsafeMutableRawPointer.allocate(byteCount: n, alignment: 16)
            let bound = unsafe raw.bindMemory(to: Byte.self, capacity: n)
            self._bytes = unsafe Memory.Contiguous<Byte>(adopting: bound, count: n)
            self._capacityBytes = capacityBytes
            self._cursor = 0
        }

        deinit {
            // A bump arena CANNOT run per-element deinit: it does not know the TYPES
            // (let alone the count or boundaries) of what was bumped into it. It only
            // ever reclaims storage en masse (here, freeing the byte region). This is
            // the first sign the typed-store model does not fit: Store's `move(at:)`
            // is per-typed-slot, but an arena has no typed-slot inventory to walk.
        }
    }
}

// MARK: - The honest bump surface (NOT Store.Protocol)

extension G2.Arena {
    /// Bumps `count` bytes off the cursor, aligned to `alignment`. Returns the base
    /// address, or `nil` if exhausted. VARIABLE-SIZE, SEQUENTIAL, NO REUSE.
    ///
    /// This is the arena's true contract — and it is precisely `Memory.Allocator`'s
    /// `allocate(count:alignment:)` shape (see Probe 3 / FINDINGS §(c)), NOT the
    /// typed-slot shape of `Store.`Protocol``.
    public mutating func bump(count: Int, alignment: Int) -> Memory.Address? {
        let aligned = (_cursor + (alignment - 1)) & ~(alignment - 1)
        guard aligned + count <= _capacityBytes else { return nil }
        _cursor = aligned + count
        let base = unsafe UnsafeMutableRawPointer(mutating: _bytes.unsafeBaseAddress)
            .advanced(by: aligned)
        return unsafe Memory.Address(base)
    }

    /// En-masse reclamation — the arena's ONLY deallocation discipline.
    public mutating func reset() { _cursor = 0 }
}

// FINDING: Arena vs the Store.Protocol seam — where every requirement breaks
// ==========================================================================
//
// The bump arena's native surface (`bump(count:alignment:)` + `reset()`) is clean
// and conforms to `Memory.Allocator.`Protocol`` naturally (Probe 3). Trying to make
// it a `Store.`Protocol`` breaks at EVERY requirement:
//
//   • `capacity: Index<Element>.Count`
//       MEANINGLESS. An arena's capacity is BYTES. How many `Element`s fit is
//       undefined because a bump arena holds VARIABLE-SIZE, possibly
//       HETEROGENEOUSLY-TYPED allocations. There is no single `Element` and no
//       fixed slot count. `capacityBytes / stride` is a fiction the moment you bump
//       anything of a different size/alignment.
//
//   • `subscript(slot: Index<Element>) -> Element`
//       MEANINGLESS. `Index<Element>` is an ORDINAL slot coordinate implying fixed
//       stride: slot k lives at base + k*stride. A bump arena has no fixed stride
//       and no notion of "the k-th Element" — allocation k might be 3 bytes, k+1
//       might be 4 KB. Random access by ordinal slot is undefined.
//
//   • `initialize(at: Index<Element>, to:)`
//       MEANINGLESS for the same reason: there is no slot `at` which to initialize.
//       The arena only knows "the next `count` bytes", not "the slot numbered k".
//
//   • `move(at: Index<Element>)`
//       DOUBLY MEANINGLESS: no addressable slot, AND a bump arena has no
//       per-allocation reclamation (it reclaims only en masse). `move(at:)` (init →
//       uninit, ownership out) has no counterpart in the bump discipline.
//
// To force ANY conformance you must DESTROY the arena's defining properties and
// turn it into a fixed-stride slot pool (one `Element`, fixed stride, ordinal
// addressing, an occupancy oracle). At that point it is NOT a bump arena anymore —
// it is Probe 1's Pool minus reuse. This is EXACTLY what the real ecosystem did:
// `Storage.Arena` is documented as a fixed-slot SoA (meta array + element array,
// `_elementRegionOffset + slot*stride`, generation tokens) — the raw `Memory.Arena`
// bump cursor is demoted to a mere byte-region provider underneath, and the typed
// `subscript(slot:)` addresses fixed slots, not bump output. The bump SEMANTICS do
// NOT survive the lift; only the byte-backing role does.
//
// CONCLUSION: a genuine bump arena CANNOT conform to `Store.`Protocol`` without
// ceasing to be a bump arena. Its correct seam is raw `Memory.Allocator.`Protocol``.
// The genuine non-compiler is preserved below.

// GENUINE NON-COMPILER: a bump arena trying to witness `subscript(slot:)`.
// =======================================================================
#if false
// The most faithful attempt: define the typed slot subscript from the bump cursor.
// There is no honest body — a bump arena cannot turn an ordinal `Index<Element>`
// into an address, because it never laid out fixed `Element`-stride slots. Writing
// the conformance forces an arbitrary `slot * stride` fiction that contradicts the
// bump layout. Below, we instead expose the COMPILER error from the most direct
// contradiction: an arena has no `Element` associated type to pin (it is
// type-heterogeneous), so it cannot even *name* the requirement.

extension G2.Arena: Store.`Protocol` {
    // ERROR (conceptual → compiler): `Store.`Protocol`` requires
    //   associatedtype Element: ~Copyable
    // A bump arena is element-AGNOSTIC: it bumps raw bytes for allocations of MANY
    // types. There is no single `Element` to bind. Picking one (say `Byte`) is a
    // lie — you cannot read back a 4 KB struct through `subscript(slot:) -> Byte`.
    //
    // With NO witnesses (none has an honest body — there is no `Element`, no fixed
    // slot, no per-slot move), the REAL compiler error captured from this exact
    // declaration under TOOLCHAINS=org.swift.64202605271a (verbatim) is:
    //
    //   error: type 'G2.Arena' does not conform to protocol '__StoreProtocol'
    //   note: add stubs for conformance
    //   Store_Protocol_Primitives.__StoreProtocol.Element:2:16:
    //     note: protocol requires nested type 'Element'
    //   1 | protocol __StoreProtocol {
    //   2 | associatedtype Element : ~Copyable}
    //     |                `- note: protocol requires nested type 'Element'
    //
    // The FIRST unsatisfiable requirement is the associated `Element` itself: the
    // arena has no single element type to bind. Even granting `Element = Byte`, the
    // remaining requirements (`capacity: Index<Byte>.Count`, the fixed-stride
    // `subscript(slot: Index<Byte>)`, per-slot `initialize`/`move`) have no honest
    // body over a variable-size bump cursor. There is no set of witnesses; the
    // conformance cannot be written.
}
#endif
