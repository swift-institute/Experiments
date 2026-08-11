# span-typealias-hosting

**Status:** CONFIRMED · **Toolchain:** Apple Swift 6.3.2 (swiftlang-6.3.2.1.108) · **Platform:** macOS 26 (arm64) · **Date:** 2026-06-23

## Question

`swift-span-primitives` currently declares its top-level `Span` as a **namespace enum** (`public enum Span {}`) that hosts the span-vending capability protocols (`Span.Protocol`, `Span.Mutable.Protocol`) and types (`Span.Raw`). Because the enum claims the bare name `Span`, it **shadows the stdlib `Swift.Span`** — the package, and every consumer, must write `Swift.Span<Element>` fully-qualified.

Can we make `Span` a typealias to `Swift.Span` (so `Span<Byte>` *is* the stdlib span), **and** `Span.Mutable` a typealias to `Swift.MutableSpan` (so `Span.Mutable<Byte>` *is* the stdlib mutable span), **while keeping the bare `Span.Protocol` / `Span.Mutable.Protocol` spellings** the ecosystem already uses?

**Answer: yes — with an UNBOUND alias (`typealias Span = Swift.Span`) plus Element-free member typealiases.** A *bound* generic typealias does not work (it forces a phantom element); that distinction is the finding.

## Result table

| Variant | What it tests | Result | Evidence |
|---|---|---|---|
| **01 baseline collision** | `enum Span {}` lets a consumer spell stdlib as `Span<Int>` | **REFUTED** | `error: cannot specialize non-generic type 'Span'` |
| **02 redeclaration** | keep `enum Span` host AND a `Span` alias together | **REFUTED** | `error: invalid redeclaration of 'Span'` |
| **03 bound alias → bare** | bound `Span<E> = Swift.Span<E>`, then bare `Span.Protocol` | **REFUTED** | `error: 'Protocol' is not a member type of type 'Span'` |
| **unbound alias → bare read** | `typealias Span = Swift.Span`; bare `Span.Protocol`; `Span<E>` stdlib span | **CONFIRMED** | builds + runs cross-module (debug + release) |
| **Span.Mutable<E> = MutableSpan<E>** | member `typealias Mutable = Swift.MutableSpan`; `Span.Mutable<Int>` mutates | **CONFIRMED** | `run.txt`: `mutated first = 101` |
| **Span.Mutable.Protocol bare** | mutable capability via member typealias on `Swift.MutableSpan` | **CONFIRMED** | cross-module constraint resolves |

Receipts in `Outputs/`: `build.txt` (debug + cross-module), `build-release.txt` (release), `run.txt` (runtime), `counterexamples.txt` (verbatim REFUTED diagnostics).

Stdlib signatures (from the interface): `struct Span<Element>: ~Escapable, Copyable, BitwiseCopyable where Element: ~Copyable`; `struct MutableSpan<Element>: ~Copyable, ~Escapable where Element: ~Copyable`.

## Why bound fails but unbound works

Member lookup differs between a generic typealias and a type name:

- `Span.Protocol` where `Span` is a **bound** generic typealias (`Span<Element> = Swift.Span<Element>`) **fails** — the name demands its generic argument before member lookup.
- `Span.Protocol` where `Span` is an **unbound** alias (`typealias Span = Swift.Span`) **resolves** — the unbound alias *is* the type name, behaving exactly like `Swift.Span` (whose `Swift.Span.Protocol` resolves unspecialized).

Hoisting the protocol (top-level vs nested in a host enum) makes **no** difference; the unbound alias is the load-bearing ingredient.

## The technique (validated — `Sources/UnboundAlias`)

```swift
// 1. Hidden backing namespace = today's `enum Span`, renamed (non-generic, so it nests protocols):
public enum __Span {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        var span: Swift.Span<Element> { @_lifetime(borrow self) get }
    }
    public enum Mutable {
        public protocol `Protocol`: __Span.`Protocol`, ~Copyable { /* mutableSpan */ }
    }
    public struct Raw { /* … */ }
}

// 2. The aliases — Span/Span.Mutable ARE the stdlib read/write span types:
public typealias Span = Swift.Span
extension Swift.Span {
    public typealias `Protocol` = __Span.`Protocol`       // bare Span.Protocol
    public typealias Mutable    = Swift.MutableSpan        // Span.Mutable<E> == MutableSpan<E>
    public typealias Raw        = __Span.Raw              // bare Span.Raw (type)
}
extension Swift.MutableSpan {
    public typealias `Protocol` = __Span.Mutable.`Protocol`   // bare Span.Mutable.Protocol
}
extension Swift.Span: __Span.`Protocol` { /* linchpin: vends itself */ }
```

Resulting consumer surface — all **bare**, no phantom element (`Sources/span-typealias-hosting/main.swift`, runtime-verified cross-module):

| Spelling | Is |
|---|---|
| `Span<E>` | `Swift.Span<E>` (read span) |
| `Span.Mutable<E>` | `Swift.MutableSpan<E>` (mutable span) |
| `Span.Protocol` | vend-a-read-span capability |
| `Span.Mutable.Protocol` | vend-a-mutable-span capability (refines `Span.Protocol`) |
| `Span.Raw` | the package's Copyable byte-span descriptor (type) |

### Caveats

- **Surface members must be Element-free typealiases, not nested nominal types.** A nested `struct`/`enum` declared directly in `extension Swift.Span { … }` is parameterized by `Element`, so its bare form needs specialization. Surface via `typealias X = …`.
- **Constructing a `Raw` *value*** via bare `Span.Raw(...)` fails (`Element` unbound in expression position). Use `.init(...)` in a typed context, or `Span<Byte>.Raw(...)`. `Span.Raw` as a *type* is bare. Protocols and the span *types* are unaffected.
- **`__Span` backing decls are public** (so cross-module conformance/typealiases work) but soft-hidden by convention; the supported spelling is `Span.Protocol` etc.

## Conclusion

1. **Make `Span` an UNBOUND typealias to `Swift.Span` and `Span.Mutable` a member typealias to `Swift.MutableSpan`.** Both stdlib span types are reachable under one namespace, and the bare `Span.Protocol` / `Span.Mutable.Protocol` capability spellings survive.
2. **No ecosystem-wide rename.** The bare spellings keep compiling, so existing conformers (`extension X: Span.Protocol`, 110 sites) are untouched. The change is internal to this package.
3. **Do NOT use a bound generic typealias** — it forces specialized `Span<Int>.Protocol` with a vacuous phantom element (Counterexample 03).
4. **Scope of the real change (principal decision):** rename `enum Span` → `enum __Span`; add `typealias Span = Swift.Span`; add the surfacing member typealiases on `Swift.Span` (`Protocol`, `Mutable = Swift.MutableSpan`, `Raw`) and on `Swift.MutableSpan` (`Protocol`); re-point the linchpin; migrate `Span.Raw(...)` value-constructions to `.init`/`Span<Byte>.Raw(...)`. This experiment validates the mechanics (cross-module + release) and does **not** touch `Sources/`.

## Reproduce

```bash
swift build && swift build -c release && swift run     # UnboundAlias, bare spellings, cross-module
cd Counterexamples && for f in 0*.swift; do \
  swiftc -swift-version 6 -parse-as-library -typecheck \
    -enable-experimental-feature Lifetimes -enable-experimental-feature SuppressedAssociatedTypes "$f"; done
# each counterexample MUST fail with the documented diagnostic
```
