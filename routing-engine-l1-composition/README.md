# routing-engine-l1-composition

**Spike A — de-risks routing-arc W2 (the `swift-url-routing` rebase off pointfree
`Parsing` onto the institute L1 engine `swift-parser-primitives`).**

| | |
|---|---|
| **Status** | **CONFIRMED** |
| **Toolchain** | Apple Swift 6.3.3 (`swiftlang-6.3.3.1.3`), plain env (no `TOOLCHAINS`) |
| **Platform** | macOS 26 (arm64) |
| **Build / Test** | `swift build` exit 0 · `swift test` exit 0 (7 tests, 4 suites, all pass) |
| **Date** | 2026-07-11 |

---

## Hypothesis

An end-to-end **Route body** — Path + Query + Body composition — composes on the
institute L1 parsing engine and round-trips in **both** directions:

1. **parse**  : URI-request carrier → route value
2. **print**  : route value → URI-request carrier

using only `swift-parser-primitives` combinators (no pointfree `Parsing`
vocabulary, no `pointfreeco` dependency).

## Method

A minimal, faithful-in-miniature model:

- **Route value** — a 3-case enum (`Model.swift`), one case per composition axis:
  - `.user(id: Int)`   → path parameter        `/users/:id`
  - `.search(term:)`   → query parameter       `/search?q=:term`
  - `.create(body:)`   → body payload          `/posts` + request body
- **Carrier** (`Route.Request`, the parser `Input`) — a `URLRequestData`-shaped
  `Copyable` struct: `path: [Substring]`, `query: [String: Substring]`,
  `body: Substring?`. Faithful in miniature to `RFC_3986.URI.Request.Data`.
- **Leaves** (`Leaves.swift`) — four `Parser.Bidirectional` leaves over the
  carrier: `Route.Path.Literal`, `Route.Path.Integer`, `Route.Query.Field`,
  `Route.Body`.
- **Composition** (`Router.swift`) — each case body is built with the engine's
  own machinery:

  ```swift
  Parser.Take.Sequence {          // @Parser.Take.Builder<Route.Request>
      Route.Path.Literal("users")
      Route.Path.Integer()
  }
  .map(Route.userConversion)      // Parser.Converted (bidirectional seam)
  ```

  The `Skip.First` Void-skip drops the literal, leaving the captured value; the
  `.map(conversion)` seam (a closure-backed `Parser.Conversion.Witness`) embeds
  it into the enum case while preserving printability.
- **Alternative** — the 3-way choice is hand-rolled (value-copy backtracking);
  see friction **F1**.

Case embed/extract is closure-based; the `@Cases` macro is a *separate* spike
and is deliberately not built here.

## Evidence

`Tests/…/RoundTripTests.swift`, all green:

- **Contract 1 — `print ∘ parse == identity` on the route value** (3 cases).
- **Contract 2 — `parse ∘ print == identity` on the carrier** (3 canonical carriers).
- **Discrimination** — the router picks the right case for each carrier and
  rejects an unknown path with `Route.Router.Fault.noRouteMatched`.
- **Multi-value printing** — `Parser.Take.Two(Integer, Integer)` prints a
  `(Int, Int)` tuple round-trip (the explicit escape hatch for friction **F2**).

## Verdict — CONFIRMED

A Path + Query + Body Route body composes on the L1 engine and round-trips in
both directions. The printability-preserving `.map(conversion)` → `Parser.Converted`
seam, the `@Parser.Builder` Void-skip sequencing, and leaf `Parser.Bidirectional`
propagation through `Skip.First`/`Take.Sequence`/`Converted` all work as the
parity audit predicted. Type inference on `Take.Sequence { … }.map(conversion)`
held as stored properties with no explicit generic annotation.

The composition is **not** frictionless — the spike's real payload for W2 is the
friction list below. None of these refute the hypothesis (each has a local
workaround, applied here), but each is a per-combinator delta W2 will hit at scale.

---

## Frictions found (the W2 payload)

### F1 — `Parser.OneOf` requires an `Input.Protocol` cursor; a routing carrier is not one  *(biggest delta)*
The engine's alternative combinators (`Parser.OneOf.Two`/`.Three`, and likewise
`Parser.Not`/`Peek`/`Many`) constrain `Input: Input_Primitives.Input.Protocol`
— a **linear element-stream cursor** with `checkpoint`/`restore`/`seek`/`advance`/
`count`/`Element`. A structured request carrier (path + query + body) cannot
satisfy that without a semantically-wrong element-stream conformance. pointfree's
`OneOf` requires *nothing* of the `Input` — it backtracks by value-copy on a
`Copyable` input. **Workaround (applied):** the router hand-rolls value-copy
backtracking (try each case parser, first success wins; the conversion's partial
`unapply` selects the print case). **W2 must** either add a value-copy `OneOf`
variant for `Copyable` inputs, or accept a hand-rolled router seam. This is the
single largest router-level delta.

### F2 — `@Parser.Builder` tuple-flatten (`Take.Two.Map`) is parse-only
`Parser.Take.Sequence` / `@Parser.Builder` **do** forward printing now (a fix
landed: `Parser.Take.Sequence+Printer.swift`). BUT any builder block that
captures **≥ 2 non-Void values** flattens through `Parser.Take.Two.Map`, which
has **no `Parser.Printer` conformance** (its tuple transform is a one-way
closure). So a route capturing 2+ params *via the builder* is parse-only.
**Workaround (applied + tested):** build the pair explicitly with
`Parser.Take.Two` (which *is* a printer) — see the `MultiValuePrinting` test.
Single-value routes (all-but-one Void, via `Skip`) print fine through the
builder — the common path. **W2 must** provide a bidirectional variadic-flatten
combinator (the engine's own source comment flags this exact gap) or drop
multi-value routes to explicit `Take.Two` + a `Memberwise`/tuple conversion.

### F3 — `Parser.Conversion.Witness` is not `Sendable`
It stores `apply`/`unapply` closures with no `Sendable` conformance, so case
conversions **cannot be `static let` module constants** under strict concurrency
(v6 language mode) — the build fails with a non-Sendable-global-state error.
**Workaround (applied):** computed `static var` properties (fresh value per
access, no shared mutable state). At router scale (many case conversions) this
is ergonomic friction. **W2 could** add conditional `Sendable` to `Witness`
(gated on `@Sendable` closures), or accept the computed-property form.

### F4 — `Parser.OneOf.Sequence` loses printability (mirrors the just-fixed `Take.Sequence` bug)
`Parser.OneOf.Sequence` (the `@Parser.OneOf.Builder` entry wrapper) delegates
only `parse` to its body, not `print`, so `OneOf.Sequence { … }` is parse-only
even though the `OneOf.Two`/`.Three` it wraps **are** printers. Identical shape
to the `Take.Sequence` gap that was closed with a one-line `+Printer` extension;
`OneOf.Sequence` needs the same fix. This spike does not use `OneOf` (see F1), so
it does not bite here — but it is a latent W2 gap the moment `OneOf` is used over
a printable sub-parser (e.g. `HTTP.Method` over `Substring`, parity-audit row 9).

### F5 — Typed-throws `Either`-nesting is faithful but unnameable
Composed failure types nest fast:
`Converted<Take.Sequence<Skip.First<…>>, Witness<…, Mismatch>>.Failure`
`== Either<Either<Match.Error, Match.Error>, Route.Mismatch>`. Correct, but
unwieldy — the router can only consume these through the L1 protocols (or `try?`),
never by naming the concrete `Failure`. **W2's** Route seam that wants a *single*
unified error must insert `.error.map` / `.error.replace` at each case boundary
(extra plumbing) or accept `try?`-style erasure (applied here). This is the
parity audit's "typed-throws unification" signature-delta made concrete.

---

## What worked cleanly (no friction)
- `.map(conversion)` → `Parser.Converted` is bidirectional exactly when the
  upstream is; the printability-preserving output-map seam behaves as documented.
- Leaf `Parser.Bidirectional` conformances propagate through `Skip.First` →
  `Take.Sequence` → `Converted` with no manual `Printer` plumbing.
- `@Parser.Builder` Void-skip sequencing (`Skip.First`/`Skip.Second`) and the
  `Take.Sequence` printer-forwarding fix cover the single-value route path — the
  common case — end to end.
- Whole-graph build from a path dependency (≈1064 modules) is clean on 6.3.3.

## Scope / ground rules honoured
- No edits outside this package; `swift-parser-primitives` was **read, not
  edited** — every gap above is recorded here, not patched upstream (that is W2's
  ratified work).
- No `pointfreeco` dependency; no pointfree `Parsing` vocabulary.
- Built/tested with the plain default toolchain (6.3.3).
