// MARK: - C: institute bridge, CONCRETE contiguous conformer -> Memory.Cursor<Self> -> .collect()
//
// Purpose: control for the concrete->generic gap. Same institute bridge + same
//   Memory.Cursor<Self> iterator as target A, but the conformer is CONCRETE
//   (Element fixed to Int). Wave-1's oq2 spike passed on a concrete [Int] base with
//   a HAND-ROLLED cursor; this re-confirms the concrete case passes through the
//   ACTUAL institute Memory.Cursor bridge, isolating "generic-ness of the conformer"
//   as the load-bearing factor.
//
// Hypothesis: this CONCRETE conformer's .collect() succeeds (no Signal-6).
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108) AND 6.4-dev (LLVM a3655ee8d8c4d74)
// Platform: macOS 26 (arm64)
// Result: PASSES (debug + release). Output: "C: collect() = [10, 20, 30]". Concrete control
//   confirms the concrete path works through the real institute Memory.Cursor bridge — but so
//   does the generic path (target A), so "generic-ness of the conformer" is NOT the trigger.
// Date: 2026-05-27

import Memory_Contiguous_Primitives
import Memory_Cursor_Primitives
import Sequence_Protocol_Primitives
import Sequence_Hint_Primitives

// A CONCRETE contiguous conformer (Element == Int). Otherwise identical to A's Region.
struct ConcreteRegion: ~Copyable {
    var storage: [Int]
    init(_ storage: [Int]) { self.storage = storage }
}

extension ConcreteRegion: Memory.Contiguous.`Protocol` {
    var span: Span<Int> { storage.span }

    func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Int>) throws(E) -> R
    ) throws(E) -> R {
        let s = span
        return try unsafe s.withUnsafeBufferPointer { (bp: UnsafeBufferPointer<Int>) throws(E) -> R in
            try body(bp)
        }
    }
}

// CONCRETE conformer: Iterator witness = the (still concretely-specialized) Memory.Cursor.
extension ConcreteRegion: Sequenceable {
    typealias Iterator = Memory.Cursor<ConcreteRegion>
    consuming func makeIterator() -> Memory.Cursor<ConcreteRegion> {
        Memory.Cursor(self)
    }
}

// Drive .collect() from a CONCRETE (non-generic) call site.
func driveConcrete() -> [Int] {
    let region = ConcreteRegion([10, 20, 30])
    return region.collect()
}
let out = driveConcrete()
print("C: collect() = \(out) (expect [10, 20, 30])")
