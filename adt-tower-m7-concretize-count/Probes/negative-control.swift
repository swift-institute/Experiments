// ===----------------------------------------------------------------------===//
// NEGATIVE CONTROL — NOT part of any build target.
//
// Compiled manually via run-negative-control.sh (swiftc against the built
// modules, mimicking Experiments/adt-tower-walls' single-file probes). This file
// MUST FAIL to compile: it declares a slab-like witness that returns its
// Bit-domain occupancy WITHOUT the `.retag(Element.self)` phantom-label change.
//
// The concrete `count: Index<Element>.Count` requirement is load-bearing: a
// Bit-domain `Bit.Index.Count` (= `Tagged<Bit, Cardinal>`) is a DIFFERENT type
// from the element-domain `Index<Int>.Count` (= `Tagged<Int, Cardinal>`), so the
// compiler rejects the un-retagged witness. This is the M7 correctness guarantee:
// a conformer cannot silently mis-report a Bit-domain count as an element count.
// ===----------------------------------------------------------------------===//

import SeamKit
import Index_Primitives
import Bit_Index_Primitives

struct BadSlab: __M7BufferProtocol {
    typealias Element = Int

    let occupancy: Bit.Index.Count

    init(occupied: UInt) {
        self.occupancy = Bit.Index.Count(occupied)
    }

    // ❌ EXPECTED REJECTION: returns the Bit-domain ledger with NO retag.
    //    `Bit.Index.Count` (Tagged<Bit, Cardinal>) ≠ `Index<Int>.Count`
    //    (Tagged<Int, Cardinal>).
    var count: Index<Int>.Count {
        occupancy
    }
}
