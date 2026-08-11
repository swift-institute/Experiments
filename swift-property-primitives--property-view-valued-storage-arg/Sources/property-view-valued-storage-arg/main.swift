// MARK: - Property.Inout.Typed.Valued<n> when the value generic is in the STORAGE arg
//
// Purpose: The [PRP-012] pattern lifts a container's value generic via
//   `Property.Inout.Typed.Valued<n>` so op-extension where-clauses bind it. Skill examples
//   put the value generic on the CONTAINER (Buffer.Linked<N>). The Cleave-3 composition buries
//   it one level deeper: `Buffer<S>.Linear` with `S == Small<Element, n>` (n in the storage arg).
//
// Two distinct questions:
//   Q-OP:       does the OP extension `extension Property.Inout.Typed.Valued
//               where Base == Buffer<Small<Element, n>>.Linear` bind `n`? (n is Valued's OWN
//               generic param, so it is in scope; the same-type reaches into the storage arg.)
//   Q-ACCESSOR: can a `var remove` accessor ON Buffer.Linear return `.Valued<n>`? (n is NOT
//               Buffer.Linear's generic — it's in the storage arg — so the accessor's context
//               has no `n`. Probed in a sibling source file; expected to fail.)
//
// Toolchain: Apple Swift 6.3.2
// Platform: macOS v26 (arm64)
// Date: 2026-06-05
//
// RESULT MATRIX (six distinct hypotheses, six clean signals — [EXP-011a]):
//   Q-OP      (this file)  CONFIRMED — op extension `Property.Inout.Typed.Valued
//                          where Base == Buffer<Small<E,n>>.Linear` binds `n` (Valued's OWN
//                          `<let n: Int>` param) and reaches into the storage arg. RAN: count 3→0.
//   SHAPE_A   (Variant2)   REFUTED  — `var remove` PROPERTY on the buffer `where S == Small<…,n>`:
//                          "cannot find type 'n'". Properties cannot introduce the value generic.
//   SHAPE_C   (Variant2)   REFUTED  — tag-enum `View` typealias on the buffer: same "cannot find 'n'".
//   SHAPE_M   (Variant2)   CONFIRMED — `func removeView<E, let m>() … where S == Small<E,m>` binds `m`
//                          (with `~Copyable` propagated on the extension). Surface = `buffer.removeView()`
//                          (parens) + returning the inout-borrowing ~Escapable view needs `@_lifetime`.
//   SHAPE_D   (Variant2)   CONFIRMED — `var remove` PROPERTY on a CONSUMER whose OWN generic IS the
//                          value generic (`StackSmall<E, cap>`): clean `.remove.all()` type-checks.
//   SHAPE_E   (Variant3)   REFUTED  — the IDEAL single storage-generic op `where Base == Buffer<S>.Linear`
//                          (free S): "cannot find type 'S'". One-extension-covers-all is NOT expressible.
//
// CONCLUSION: the `.Valued<n>` lift is REQUIRED to bind a value generic in a view op, and an accessor
// returning `.Valued<n>` is expressible ONLY where `n` is the ENCLOSING type's own generic — the
// variant `Buffer.Linear.Small<n>` (being retired) or the CONSUMER (SHAPE_D). The storage-generic
// `Buffer.Linear` (generic `S`) can return only plain `.Inout.Typed`, which cannot reach the `.Valued`
// ops. RATIFICATION-CLASS: the clean buffer-direct `.remove.all()` property surface is not expressible
// for the value-generic composition — surfaced to the seat.

import Property_Primitives
import Property_Inout_Primitives

// MARK: - Model: value-generic ~Copyable storage + Buffer<S>.Linear over it

protocol StorageProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    mutating func clear()
}

struct Small<Element: ~Copyable, let n: Int>: ~Copyable, StorageProtocol {
    var count: Int
    init() { self.count = 0 }
    mutating func clear() { count = 0 }
}

enum Buffer<S: ~Copyable & StorageProtocol> {
    struct Linear: ~Copyable {
        var storage: S
        init(storage: consuming S) { self.storage = storage }
        mutating func _removeAll() { storage.clear() }
        enum Remove {}
    }
}

// MARK: - Q-OP — op extension binds `n` (Valued's own param) + same-type into the storage arg

extension Property_Primitives.Property.Inout.Typed.Valued
where
    Tag == Buffer<Small<Element, n>>.Linear.Remove,
    Base == Buffer<Small<Element, n>>.Linear,
    Element: ~Copyable
{
    mutating func all() {
        base.value._removeAll()
    }
}

// MARK: - Q-OP exercise: construct the Valued<4> view manually + call .all()

func exerciseOP() {
    var buffer = Buffer<Small<Int, 4>>.Linear(storage: Small<Int, 4>())
    buffer.storage.count = 3
    do {
        var view = Property_Primitives.Property<Buffer<Small<Int, 4>>.Linear.Remove, Buffer<Small<Int, 4>>.Linear>
            .Inout.Typed<Int>.Valued<4>(&buffer)
        view.all()
    }
    print("Q-OP: manual Valued<4> .all() over Buffer<Small<Int,4>>.Linear — count after =", buffer.storage.count)
}

exerciseOP()
