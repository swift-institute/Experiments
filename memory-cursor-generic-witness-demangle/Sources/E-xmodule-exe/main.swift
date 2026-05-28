// MARK: - E-xmodule-exe: drive .collect() across the FULL 3-module topology.
//
// This is the highest-fidelity reconstruction of the crashing Buffer.Linear.Inline<8>:
// Sequenceable shape that can be built WITHOUT buffer-linear:
//
//   • Type module (E-type-module)        ≈ "Buffer Linear Inline Primitive" (singular)
//   • Ops/conformance module (E-ops-module) ≈ "Buffer Linear Inline Primitives" (plural)
//   • Bridge-default witness module       = swift-memory-sequence-primitives (3rd)
//   • This executable                      = the consumer driving .collect()
//
// PLUS the per-type factors target D lacked combined with the split:
//   • DOUBLY-NESTED value-generic ~Copyable type (EBuffer<Element>.Linear.Inline<capacity>)
//   • @_rawLayout storage (owned Storage.Inline)
//   • DUAL Iterable + Sequenceable @_implements
//   • cross-module bridge-DEFAULT Sequenceable witness (no explicit makeIterator)
//
// Hypothesis: this 3-module split (the one un-reconstructed structural factor per
// EXPERIMENT.md lines 80-87) triggers the Signal-6 swift_getAssociatedTypeWitness demangle
// where target D's flat 2-module lib/exe split did not.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108). Platform: macOS 26 (arm64).

import E_type_module
import E_ops_module
import Sequence_Protocol_Primitives
import Sequence_Hint_Primitives

// (1) capacity fixed at the call site = 8 (matching the crash's Inline<8>), driven in the
//     consuming module so the generic Iterator associated-type witness resolves here.
func driveFixed() -> [Int] {
    let buffer = EBuffer<Int>.Linear.Inline<8>(fill: 7)
    return buffer.collect()
}
let fixed = driveFixed()
print("E fixed: EBuffer<Int>.Linear.Inline<8>.collect().count = \(fixed.count) (expect 8)")

// (2) capacity flowing through a generic function (value-generic capacity reached generically).
func driveValueGeneric<let capacity: Int>(_: EBuffer<Int>.Linear.Inline<capacity>.Type, fill: Int) -> [Int] {
    let buffer = EBuffer<Int>.Linear.Inline<capacity>(fill: fill)
    return buffer.collect()
}
let vg = driveValueGeneric(EBuffer<Int>.Linear.Inline<8>.self, fill: 9)
print("E value-generic: EBuffer<Int>.Linear.Inline<8>.collect().count = \(vg.count) (expect 8)")

// (3) element type ALSO generic (fully generic over Element + capacity), the maximal-generic
//     drive — the closest to the crashing generic conformer.
func driveFullyGeneric<Element: Copyable & Escapable, let capacity: Int>(
    _: EBuffer<Element>.Linear.Inline<capacity>.Type, fill: Element
) -> [Element] {
    let buffer = EBuffer<Element>.Linear.Inline<capacity>(fill: fill)
    return buffer.collect()
}
let fg = driveFullyGeneric(EBuffer<Int>.Linear.Inline<8>.self, fill: 5)
print("E fully-generic: EBuffer<Int>.Linear.Inline<8>.collect().count = \(fg.count) (expect 8)")
