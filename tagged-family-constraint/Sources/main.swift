// MARK: - Tagged Family Constraint
// Purpose: Swift cannot constrain to generic tag families
// Status: REFUTED
// Result: REFUTED — protocol-based tag families DO work as constraints; production uses concrete Tag == constraints instead for API isolation
// Date: 2026-01-21
// Toolchain: Swift 6.2

// Hypothesis: Swift cannot constrain to "any tag in a family."
// Test: Can we use protocols to group tag types into families?
//
// Note: While protocol-based tag families compile (hence REFUTED),
// production swift-primitives uses concrete `Tag ==` constraints exclusively.
//
// Reason: Each tag selects a specific API surface. Grouping tags into families
// via protocols would expose operations across domains — a .set view should
// not accidentally inherit .clear methods. One tag = one API surface.
//
// Production DOES use protocol constraints on Base (not Tag):
//   extension Property.View.Typed where Tag == Bit.Vector.Pop,
//                                       Base: Bit.Vector.Protocol & ~Copyable
// This shares implementations across types conforming to a protocol.

struct View<Tag, Base> {
    let base: UnsafeMutablePointer<Base>
    init(_ base: UnsafeMutablePointer<Base>) {
        self.base = base
    }
}

// Define a "family" protocol
protocol BufferOperation {}

struct Container {
    enum ReadOps: BufferOperation {}
    enum WriteOps: BufferOperation {}
    enum UnrelatedOps {}  // Not in family

    var value: Int = 0
}

// Constrain to the family — this WORKS
extension View where Tag: BufferOperation, Base == Container {
    func containerValue() -> Int {
        base.pointee.value
    }
}

// Test: both family members get the method
var c = Container(value: 99)

let rv = withUnsafeMutablePointer(to: &c) { ptr in
    View<Container.ReadOps, Container>(unsafe ptr).containerValue()
}

let wv = withUnsafeMutablePointer(to: &c) { ptr in
    View<Container.WriteOps, Container>(unsafe ptr).containerValue()
}

print("Read: \(rv)")
print("Write: \(wv)")
assert(rv == 99)
assert(wv == 99)

// UnrelatedOps does NOT get containerValue() — not in family
// let uv = withUnsafeMutablePointer(to: &c) { ptr in
//     View<Container.UnrelatedOps, Container>(unsafe ptr).containerValue()
// }
// ^ Error: referencing instance method 'containerValue()' requires that
//   'Container.UnrelatedOps' conform to 'BufferOperation'

print("tagged-family-constraint: REFUTED")
print("(Protocol-based tag families DO work as constraints)")
