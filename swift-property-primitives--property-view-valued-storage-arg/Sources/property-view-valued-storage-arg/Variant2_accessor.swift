// MARK: - Variant 2: Q-ACCESSOR — can Buffer.Linear vend the `remove` accessor for a
// storage-arg value generic? Three candidate shapes; toggle the active one to capture each signal.
//
// The consumer (Stack.Small<n>) calls `_buffer.remove.all()`. `_buffer` is
// `Buffer<Small<Element, n>>.Linear`; `n` is the CALLER's generic, but the accessor lives on
// `Buffer.Linear` whose only generic is `S` (opaque) — `n` is buried inside `S == Small<Element, n>`.

import Property_Primitives
import Property_Inout_Primitives

// MARK: - Shape A: property accessor, value generic via where S == Small<Element, n>
// HYPOTHESIS: fails — `n` is free in the extension (no `<let n: Int>` to introduce it).

#if SHAPE_A
extension Buffer.Linear where S == Small<S.Element, n> {
    var remove: Property_Primitives.Property<Buffer<Small<S.Element, n>>.Linear.Remove, Buffer<Small<S.Element, n>>.Linear>
        .Inout.Typed<S.Element>.Valued<n> {
        mutating _read { yield .init(&self) }
        mutating _modify {
            var view = Property_Primitives.Property<Buffer<Small<S.Element, n>>.Linear.Remove, Buffer<Small<S.Element, n>>.Linear>
                .Inout.Typed<S.Element>.Valued<n>(&self)
            yield &view
        }
    }
}
#endif

// MARK: - Shape M: METHOD accessor with an explicit value-generic param `m` (methods CAN
// introduce generics; properties cannot). Surface becomes `_buffer.remove().all()`.
// HYPOTHESIS: `m` is the method's own value generic; `where S == Small<Element, m>` infers it
// from the concrete S at the call site. If this compiles + runs, the accessor IS expressible
// (at the cost of `()` — `remove()` vs `remove`).

#if SHAPE_M
extension Buffer.Linear where S: ~Copyable {
    func removeView<E: ~Copyable, let m: Int>() -> Property_Primitives.Property<Buffer<Small<E, m>>.Linear.Remove, Buffer<Small<E, m>>.Linear>
        .Inout.Typed<E>.Valued<m>
    where S == Small<E, m> {
        // NOTE: a returning method cannot hand back an inout-borrowing ~Escapable view safely
        // without lifetime plumbing; this shape only probes whether `m` (+ E) BIND, not runtime use.
        fatalError("compile-only probe")
    }
}
#endif

// MARK: - Shape C: tag-enum View typealias ([PRP-012] shape) on the storage-arg composition
// HYPOTHESIS: fails — the typealias RHS references `n` with no binder (same wall as Shape A).

#if SHAPE_C
extension Buffer.Linear where S == Small<S.Element, n> {
    enum RemoveTagView {
        typealias View = Property_Primitives.Property<Buffer<Small<S.Element, n>>.Linear.Remove, Buffer<Small<S.Element, n>>.Linear>
            .Inout.Typed<S.Element>.Valued<n>
    }
}
#endif

// MARK: - Shape D: PROPERTY accessor on a CONSUMER whose OWN generic IS the value generic
// (the Stack.Small<cap> analog). `cap` is the consumer's generic — in scope — so the property
// accessor over the buffer field can bind it. HYPOTHESIS: compiles (the clean `.remove.all()`
// property surface IS expressible at the consumer layer, where the value generic lives).

#if SHAPE_D
struct StackSmall<Element: ~Copyable, let cap: Int>: ~Copyable {
    var _buffer: Buffer<Small<Element, cap>>.Linear
    init(_ buffer: consuming Buffer<Small<Element, cap>>.Linear) { self._buffer = buffer }

    var remove: Property_Primitives.Property<Buffer<Small<Element, cap>>.Linear.Remove, Buffer<Small<Element, cap>>.Linear>
        .Inout.Typed<Element>.Valued<cap> {
        mutating _read { yield .init(&_buffer) }
        mutating _modify {
            var view = Property_Primitives.Property<Buffer<Small<Element, cap>>.Linear.Remove, Buffer<Small<Element, cap>>.Linear>
                .Inout.Typed<Element>.Valued<cap>(&_buffer)
            yield &view
        }
    }
}

// compile-only probe: the function body type-checks `stack.remove.all()`, which is the
// binding test. (Top-level expressions are illegal outside main.swift, so no bare call here.)
func exerciseD() {
    var stack = StackSmall<Int, 4>(Buffer<Small<Int, 4>>.Linear(storage: Small<Int, 4>()))
    stack._buffer.storage.count = 3
    stack.remove.all()
    _ = stack
}
#endif
