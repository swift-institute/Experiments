# member-import-visibility-body-conflict

**Status**: CONFIRMED (root cause identified; rename fix verified)
**Date**: 2026-03-13 (initial); 2026-04-15 (V10 added)
**Toolchain**: Swift 6.3 (originally Swift 6.2.4)
**Receipt for**: [Blog/Draft/associated-type-trap-final.md](../../Blog/Draft/associated-type-trap-final.md) — "The associated type trap"

## Investigation

Why does `extension HTML.Document: NSViewRepresentable` fail to compile when `HTML.Document` already conforms to a custom `View` protocol with `associatedtype Body`?

This package contains ten variants exploring the failure mode. V1–V5 rule out import-level explanations. V6 establishes the rename mechanism with a different identifier. V7–V9 explore alternative escape hatches. V10 verifies the specific rename the blog post recommends.

## Variants

| Variant | Hypothesis | Result | Build expectation |
|---------|-----------|--------|-------------------|
| `V1_SameFile` | `public import SwiftUI` in same file as stored `body` causes the conflict | REFUTED — fails identically to V2–V5 | **Fails to compile** (demonstration of the bug) |
| `V2_MIV_Enabled` | `MemberImportVisibility` leaks SwiftUI to other files | REFUTED — same error | **Fails to compile** |
| `V3_MIV_Disabled` | Disabling `MemberImportVisibility` resolves the conflict | REFUTED — fails anyway | **Fails to compile** |
| `V4_Internal_Import` | `internal import SwiftUI` avoids the leak | REFUTED — same error | **Fails to compile** |
| `V5_Package_Import` | `package import SwiftUI` avoids the leak | REFUTED — same error | **Fails to compile** |
| `V6_Content_AssocType` | Renaming the associated type from `Body` to `Content` resolves the collision | CONFIRMED — compiles | Compiles |
| `V7_Retroactive` | `@retroactive` annotation permits the conformance | REFUTED — `@retroactive` only valid for cross-module conformances | **Fails to compile** (different error) |
| `V8_ModuleSelectors` | SE-0491 `Rendering::View` / `SwiftUI::View` selectors disambiguate | REFUTED — diagnostic confirms same-named associated types are *merged*, not shadowed | **Fails to compile** |
| `V9_Wrapper_Escape_Hatch` | A `.swiftUIView` property on a wrapper type sidesteps direct conformance | CONFIRMED — compiles, but ergonomically rejected | Compiles |
| `V10_Rendered_Namespace` | The blog's specific recommendation: `Render` namespace + `associatedtype Rendered` (constraint `Render.Body`) | CONFIRMED — compiles | Compiles |

> **DO NOT COPY V1–V5, V7, V8.** These variants exist to *reproduce* failure modes. Copying their code into a real codebase reintroduces the bug. The working patterns are V6, V9, and V10; the blog recommends V10's shape.

## Building individual variants

```sh
# Variants expected to compile:
swift build --target V6_Content_AssocType
swift build --target V9_Wrapper_Escape_Hatch
swift build --target V10_Rendered_Namespace

# Variants expected to fail (intentionally — they reproduce the bug):
swift build --target V1_SameFile     # Will emit the unification error
swift build --target V8_ModuleSelectors  # Will emit the merged-not-shadowed diagnostic
```

A whole-package `swift build` will surface every variant's diagnostic; expect the failing variants to error out. The failing diagnostics are themselves part of the receipt — they document what was tried and how the compiler responded.

## Root cause (summary)

Swift's associated-type anchor unifier matches simple identifiers at the protocol declaration site. When `HTML.Document` conforms to two protocols that each declare `associatedtype Body`, the requirements are merged into a single binding — and the constraints from the two protocols (`Body: Custom.View` vs `Body == Never`) are irreconcilable. Module selectors, import attributes, and `@retroactive` cannot disambiguate because they target name lookup, not anchor unification.

The fix is structural: pick an associated-type name that no upstream protocol uses. V10 uses `Rendered` inside a `Render` namespace.

See the blog post for the full investigation, the compiler-source citations, and the design rationale for the `Rendered` name.
