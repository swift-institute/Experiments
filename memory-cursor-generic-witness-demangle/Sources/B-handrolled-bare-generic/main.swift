// MARK: - B: HAND-ROLLED bare-generic protocol/associated-type/witness — VERDICT DISCRIMINATOR
//
// Purpose: decide compiler/runtime bug vs Memory.Cursor design issue. This target
//   reconstructs the institute bridge's STRUCTURE with the absolute minimum and
//   ZERO institute dependencies:
//     - a minimal ~Copyable iteration protocol `Seq` with associated `Iterator`
//       (constrained to a minimal `Iter` protocol) + `consuming func makeIterator()`,
//       supplied by a constrained protocol-extension default (the WITNESS);
//     - a GENERIC owned cursor `Cursor<Base>` parameterized by the conformer Base,
//       re-deriving Base.span inside next() (mirrors Memory.Cursor exactly);
//     - a GENERIC conformer `Region<Element>` whose Iterator associated-type witness
//       resolves to the generic `Cursor<Region<Element>>`;
//     - a `collect()`-equivalent terminal driven from a generic call site.
//
//   This is the SAME associated-type-witness pattern (generic conformer; Iterator
//   witness = generic struct over Self; resolved through a protocol-extension default)
//   minus everything specific to Memory.Cursor / Tagged / @frozen / the institute
//   protocol hierarchy.
//
// Discriminating logic:
//   - If B ALSO crashes Signal-6 at collect() (generic associated-type-witness
//     demangle) → COMPILER/RUNTIME BUG. The bridge is just the messenger.
//   - If B PASSES while A crashes → DESIGN ISSUE specific to Memory.Cursor's shape
//     (e.g. @frozen, Tagged<Base,Ordinal> position, Self-owning binding).
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108) AND 6.4-dev (LLVM a3655ee8d8c4d74)
// Platform: macOS 26 (arm64)
// Result: PASSES (debug + release, both toolchains). Output: "B: collect() = [10, 20, 30]".
//   The bare hand-rolled generic associated-type-witness case does NOT crash. Combined with
//   targets A/C/D (the institute bridge on synthetic generic, value-generic, dual-@_implements,
//   and @_rawLayout conformers) ALSO passing, NO synthetic reconstruction reproduces the
//   Signal-6 demangle. The crash needs a factor present only in the literal Buffer.Linear.Inline
//   that cannot be isolated synthetically (see EXPERIMENT.md verdict). So this is NOT a generic
//   associated-type-witness compiler/runtime bug in the general case.
// Date: 2026-05-27

// --- Minimal iterator protocol (mirror of Iterator.`Protocol`: ~Copyable, ~Escapable,
//     Element ~Copyable & ~Escapable). ---
protocol Iter<Element>: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable & ~Escapable
    // @_lifetime(&self): mirror of Iterator.`Protocol`.next(); the ~Escapable Element
    // result ties its lifetime to self.
    @_lifetime(&self)
    mutating func next() -> Element?
}

// --- Minimal single-pass sequence protocol (mirror of Sequenceable): ~Copyable,
//     associated Iterator constrained to Iter, consuming makeIterator().
//     Iterator suppresses Copyable (Sequenceable.Iterator is `~Copyable, ~Escapable`)
//     so a ~Copyable cursor witness (Cursor) satisfies it. ---
protocol Seq<Element>: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable & ~Escapable
    associatedtype Iterator: Iter, ~Copyable, ~Escapable where Iterator.Element == Element
    @_lifetime(copy self)
    consuming func makeIterator() -> Iterator
}

// --- A minimal "contiguous-like" capability the cursor reads through.
//     Stands in for Memory.ContiguousProtocol.span; kept as a plain array accessor
//     so the cursor re-derives a fresh view per next() (mirrors base.span re-derive). ---
protocol Contig<Element>: ~Copyable {
    associatedtype Element
    var items: [Element] { get }
}

// --- GENERIC owned cursor parameterized by the conformer Base (mirror of
//     Memory.Cursor<Base: ... & ~Copyable>). Owns Base by value, re-derives the
//     view in next(). Conforms the minimal Iter. ---
struct Cursor<Base: Contig & ~Copyable>: Iter, ~Copyable {
    typealias Element = Base.Element
    var base: Base
    var position: Int
    init(_ base: consuming Base) { self.base = base; self.position = 0 }
    mutating func next() -> Base.Element? {
        let view = base.items   // re-derive per call (mirrors base.span)
        guard position < view.count else { return nil }
        defer { position += 1 }
        return view[position]
    }
}

// --- The WITNESS: a constrained protocol-extension default supplying makeIterator()
//     -> Cursor<Self> for any Seq conformer that is also Contig. EXACTLY mirrors
//     `extension Memory.ContiguousProtocol where Self: Sequenceable { makeIterator()
//      -> Memory.Cursor<Self> }`. The Iterator associated-type witness for any
//     conformer is therefore the GENERIC Cursor<Self>. ---
extension Seq where Self: Contig & ~Copyable {
    // Cursor<Self> is Escapable, so @_lifetime is OMITTED on the witness (the Escapable
    // witness satisfies the @_lifetime(copy self)-annotated requirement — the Wave-1 OQ-2
    // finding, replicated here independently of the institute bridge).
    consuming func makeIterator() -> Cursor<Self> {
        Cursor(self)
    }
}

// --- collect()-equivalent terminal on Seq (mirror of Sequenceable.collect()).
//     Calls makeIterator() then drives next() — needs the Iterator associated-type
//     witness at runtime (the demangle site). ---
extension Seq where Element: Copyable & Escapable {
    consuming func collect() -> [Element] {
        var iterator = self.makeIterator()
        var result: [Element] = []
        while let element = iterator.next() { result.append(element) }
        return result
    }
}

// --- A GENERIC conformer. Its Iterator associated-type witness resolves to the
//     generic Cursor<Region<Element>>. Mirrors Buffer.Linear.Inline<8>: Sequenceable. ---
struct Region<Element: Copyable>: Contig, Seq {
    var storage: [Element]
    init(_ storage: [Element]) { self.storage = storage }
    var items: [Element] { storage }
}

// Drive from a GENERIC call site (mirrors A's run<Element>).
func run<Element: Copyable>(_ values: [Element]) -> [Element] {
    let region = Region(values)
    return region.collect()
}

let out = run([10, 20, 30])
print("B: collect() = \(out) (expect [10, 20, 30])")
