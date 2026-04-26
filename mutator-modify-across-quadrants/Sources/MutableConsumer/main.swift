// Cross-module consumer of `Mutable`. This target imports the sibling
// `MutableLib` and exercises all four quadrants of the trivial-self
// default, plus a distinct-Value conformance, to verify that the four-
// quadrant pattern survives a module boundary (per [EXP-017]).

import MutableLib

// MARK: - Q1 — Copyable & Escapable.

struct Counter: Mutable {
    typealias Value = Counter
    var raw: Int
}

// MARK: - Q2 — ~Copyable, Escapable.

struct UniqueCounter: ~Copyable, Mutable {
    typealias Value = UniqueCounter
    var raw: Int
}

// MARK: - Q3 — Copyable, ~Escapable.
// Cross-module conformance to `Mutable` for `MutableSpan`.

extension MutableSpan: Mutable {
    public typealias Value = MutableSpan<Element>
}

// MARK: - Q4 — ~Copyable & ~Escapable.

struct ScopedHandle: ~Copyable, ~Escapable, Mutable {
    typealias Value = ScopedHandle
    var raw: Int
}

// MARK: - Distinct-Value: ~Copyable Value differs from Self.

struct RawDescriptor: ~Copyable {
    var raw: Int32
}

struct DescriptorBox: ~Copyable {
    var _storage: RawDescriptor
    init(_ storage: consuming RawDescriptor) { self._storage = storage }
}

extension DescriptorBox: Mutable {
    typealias Value = RawDescriptor
    var value: RawDescriptor {
        _read { yield _storage }
        _modify { yield &_storage }
    }
}

// MARK: - Generic dispatch through `inout some Mutable` (probes that the
// protocol surface is callable across the module boundary, including
// for ~Copyable types).

func bumpRaw(_ counter: inout some Mutable<Counter>) {
    counter.value.raw += 1
}

func bumpRawUnique<C: Mutable<UniqueCounter> & ~Copyable>(_ counter: inout C) {
    counter.value.raw += 2
}

func bumpRawScoped<H: Mutable<ScopedHandle> & ~Copyable & ~Escapable>(_ handle: inout H) {
    handle.value.raw += 3
}

// MARK: - Main

var c = Counter(raw: 7)
bumpRaw(&c)
print("Q1 cross-module: c.value.raw = \(c.value.raw)")

var u = UniqueCounter(raw: 13)
bumpRawUnique(&u)
print("Q2 cross-module: u.value.raw = \(u.value.raw)")

// Q3 cross-module read-only check (mutation through MutableSpan typically
// uses the type's own subscript; the `value` accessor exists for protocol
// conformance and is exercised on the read path here):
do {
    var bytes: [UInt8] = [10, 20, 30]
    bytes.withUnsafeMutableBufferPointer { buffer in
        let span = MutableSpan<UInt8>(_unsafeElements: buffer)
        print("Q3 cross-module: span.value.count = \(span.value.count)")
    }
}

func runQ4() {
    var s = ScopedHandle(raw: 21)
    bumpRawScoped(&s)
    print("Q4 cross-module: s.value.raw = \(s.value.raw)")
}
runQ4()

var box = DescriptorBox(RawDescriptor(raw: 100))
box.value.raw += 5
print("Distinct-Value cross-module: box.value.raw = \(box.value.raw)")
