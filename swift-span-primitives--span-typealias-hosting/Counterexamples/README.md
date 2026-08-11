# Counterexamples

These files are **expected NOT to compile**. They are deliberately outside `Sources/`,
so SwiftPM never builds them — each documents one hard limit that shapes the design.
Their verbatim diagnostics are captured in `../Outputs/counterexamples.txt`.

| File | Demonstrates | Expected diagnostic |
|---|---|---|
| `01-baseline-collision.swift` | the current problem: `enum Span {}` shadows `Swift.Span` | `cannot specialize non-generic type 'Span'` |
| `02-host-alias-redeclaration.swift` | you can't keep a `Span` host AND a `Span` alias | `invalid redeclaration of 'Span'` |
| `03-bound-alias-bare-protocol.swift` | a **bound** `Span<E>` alias breaks bare `Span.Protocol` (the unbound alias fixes it) | `'Protocol' is not a member type of type 'Span'` |

The fix for 03 lives in `../Sources/UnboundAlias` — `typealias Span = Swift.Span`
(unbound) makes bare `Span.Protocol` resolve. See `../EXPERIMENT.md`.

Reproduce:

```bash
for f in 0*.swift; do
  swiftc -swift-version 6 -parse-as-library -typecheck \
    -enable-experimental-feature Lifetimes -enable-experimental-feature SuppressedAssociatedTypes "$f"
done
```
