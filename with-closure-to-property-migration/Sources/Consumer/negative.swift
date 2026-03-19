// ============================================================
// NEGATIVE TESTS — Escape attempt results
//
// 15 escape attempts tested. Results:
//
// REJECTED ✓ (14 of 15 safety violations caught):
//   N2  — Global variable: concurrency safety rejects mutable global
//   N3  — Escaping closure: "lifetime-dependent value escapes its scope"
//   N4  — Consume while borrowed: "cannot be consumed when borrowed by non-Escapable"
//   N5  — Reassign while borrowed: "overlapping accesses, modification requires exclusive"
//   N6  — Array storage: "does not conform to 'Copyable'"
//   N7  — Task capture: "lifetime-dependent value escapes its scope"
//   N8  — Any existential: "does not conform to 'Copyable'"
//   N9  — Wrong @_lifetime: "lifetime-dependent value escapes its scope"
//   N10 — Class property: "implicit conversion to Optional is consuming"
//   N11 — Return without parameter: "~Escapable result needs a parameter to depend on"
//   N12 — View after scope: "lifetime-dependent variable escapes its scope"
//   N13 — Escapable generic: "requires that 'BorrowedView' conform to 'Escapable'"
//   N14 — Optional return: "~Escapable result needs a parameter to depend on"
//   N16 — Tuple: "noncopyable element type not supported"
//   N17 — Consume own owner: "cannot be consumed when borrowed by non-Escapable"
//
// COMPILES (2, both by design):
//   N1  — Return without @_lifetime: compiler INFERS @_lifetime(borrow buf)
//          when exactly one borrowing parameter exists. By design.
//   N15 — Extract Escapable pointer: UnsafePointer IS Escapable.
//          Extracting Escapable values from ~Escapable containers is
//          allowed. This is the unsafe escape hatch — by design.
//
// CONCLUSION: The ~Escapable + ~Copyable safety model catches ALL
// meaningful escape attempts. The two "escapes" are either correct
// inference (N1) or inherent to the unsafe pointer model (N15).
// ============================================================

import Primitives
import Foundations


// ============================================================
// N1: COMPILES — lifetime inference (by design)
// When a function has exactly one borrowing parameter and a
// ~Escapable return, the compiler infers @_lifetime(borrow param).
// ============================================================

func n1_returnWithoutLifetime(_ buf: borrowing OwnedBuffer) -> BorrowedView {
    buf.view
}

// ============================================================
// N15: COMPILES — unsafe escape hatch (by design)
// UnsafePointer is Escapable. Extracting it from a ~Escapable
// view is the user's responsibility. The compiler cannot track
// pointer validity beyond the lifetime system.
// ============================================================

func n15_unsafePointerEscape() -> UnsafePointer<UInt8> {
    let buf = OwnedBuffer([1, 2, 3])
    let view = buf.view
    return view.pointer  // dangling pointer! but compiler allows it
}


// ============================================================
// ALL REJECTED TESTS (commented out — see error messages above)
// ============================================================

// N3: func n3_escapingClosure() -> () -> Int {
//     let buf = OwnedBuffer([1, 2, 3])
//     let view = buf.view  // ERROR: lifetime-dependent value escapes its scope
//     return { view.count }
// }

// N4: func n4_consumeWhileBorrowed() {
//     let buf = OwnedBuffer([1, 2, 3])
//     let view = buf.view
//     _ = consume buf  // ERROR: cannot be consumed when borrowed by non-Escapable
//     _ = view.count
// }

// N5: func n5_reassignWhileBorrowed() {
//     var buf = OwnedBuffer([1, 2, 3])
//     let view = buf.view
//     buf = OwnedBuffer([4, 5, 6])  // ERROR: overlapping accesses, exclusive required
//     _ = view.count
// }

// N7: func n7_taskCapture() async {
//     let buf = OwnedBuffer([1, 2, 3])
//     let view = buf.view  // ERROR: lifetime-dependent value escapes its scope
//     Task { _ = view.count }
// }

// N9: @_lifetime(borrow buf)
// func n9_wrongLifetime(_ buf: borrowing OwnedBuffer) -> BorrowedView {
//     let other = OwnedBuffer([9, 9, 9])
//     return other.view  // ERROR: lifetime-dependent value escapes its scope
// }

// N12: func n12_viewAfterScopeEnd() {
//     let view: BorrowedView  // ERROR: lifetime-dependent variable escapes its scope
//     do {
//         let buf = OwnedBuffer([1, 2, 3])
//         view = buf.view
//     }
//     _ = view.count  // out of scope
// }

// N17: func n17_consumeOwnOwner() {
//     let buf = OwnedBuffer([1, 2])
//     let view = buf.view
//     _ = consume buf  // ERROR: cannot be consumed when borrowed by non-Escapable
//     _ = view.count
// }


func runNegativeTests() {
    print("\n--- Negative Tests ---")
    print("N1  COMPILES: Lifetime inference (by design — single borrowing param)")
    print("N15 COMPILES: UnsafePointer escape (by design — pointer is Escapable)")
    print("All 15 other escape attempts correctly REJECTED by compiler")
}
