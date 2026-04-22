# Namespaced Accessors Walkthrough

Companion experiments for the blog post **Designing namespaced accessors in Swift**.

Each variant is a self-contained executable demonstrating one step in the post's walkthrough. No variant imports `swift-property-primitives` — the shape is rederived from scratch, so the reader can clone this package and step through each build's reasoning independently.

## Variants

| Variant | Blog section | Demonstrates |
|---------|-------------|--------------|
| `V1_BespokeProxy` | One accessor, one proxy | A single `Stack.Push` proxy struct with the five-step `_modify` dance for CoW-safe mutation on Copyable bases. |
| `V2_FiveProxies` | Five verbs, five nearly-identical proxies | Five proxies (`Push`, `Pop`, `Peek`, `ForEach`, `Remove`) on the same Copyable `Stack`, with the structural duplication visible across all five. |
| `V3_Wrapper` | A discriminated wrapper | One `Wrapper<Tag, Base>` type with empty-enum tags. Five namespaces become five tags + two accessor properties + two extension blocks. Demonstrates method-case extensions; property-case extensions require a `.Typed` sibling, which the walkthrough omits and the real library (`swift-property-primitives`) provides. |
| `V4_NoncopyableFails` | `~Copyable` doesn't cooperate | An attempted `Wrapper<Push, Ring>` on a `~Copyable` `Ring`, showing why the five-step `_modify` dance can't apply. The failing accessor is commented out with expected errors inline. |
| `V5_View` | A pointer-backed variant | `Wrapper<Tag, Base>.View` — an `UnsafeMutablePointer`-backed sibling of `Wrapper`, declared `~Copyable, ~Escapable` with `@_lifetime(borrow base)`. Yielded from a `mutating _read` coroutine; the call-site shape `ring.push.back(_:)` is identical to V1–V3's Stack version. |

## Running

```bash
cd namespaced-accessors-walkthrough
swift build
swift run V1_BespokeProxy
swift run V2_FiveProxies
swift run V3_Wrapper
swift run V4_NoncopyableFails
swift run V5_View
```

`V4_NoncopyableFails` builds and runs — it does NOT exercise the failing accessor. The failure is documented as a commented-out block inside `Sources/V4_NoncopyableFails/main.swift`; uncomment it to reproduce the compiler errors.

## Toolchain

Swift 6.3.1 (or later). Some variants use experimental features (`LifetimeDependence`, `Lifetimes`) that are gated behind `.enableExperimentalFeature(...)` in `Package.swift`.
