# argv-parser-protocol-spike

Spike for the swift-arguments ecosystem design [RES-027].

## Hypothesis (Premise P1)

> The institute's `Parser.Protocol`, instantiated with
> `Parser.Input.Collection<Array<String>.Indexed<String>>` (or similar
> argv-element-stream type), can express argv parsing (positional + option
> + flag) with backtracking and typed errors.

## Experiment

This package builds a minimal CLI parser for the `Repeat`-style command:

- `--count <Int>` — optional integer option, default 2
- `--include-counter` — boolean flag, default false
- `<positional String>` — required positional phrase

Two variants are provided:

1. **`RepeatParser`** (leaf): implements `Parser.Protocol.parse(_:)` directly,
   walking the argv element-by-element and using
   `input.checkpoint` / `input.restore.to(__unchecked:_:)` for backtracking.
   Demonstrates that the `Input.Protocol` machinery works with
   `Element == String`.

2. **`CombinatorRepeatParser`** (combinator-driven): composes three smaller
   leaf parsers (`MatchLiteral`, `AnyString`, `IntString`) using existing
   combinators only:
   - `Parser.Take.Sequence { ... }.map { ... }` for `--count <int>`
   - `Parser.OneOf.Sequence { ... }` for the three-way alternation
   - `Parser.Many.Simple(element: { ... })` for repetition
   - `.map` on `Parser.Protocol` for token construction

   No new core combinators were added.

The input type is

```swift
public typealias ArgvInput = Input.Slice<Array<String>.Indexed<String>>
```

i.e., `Parser.Input.Collection<Array<String>.Indexed<String>>` per the
typealias `Parser.Input.Collection<Base> = Input.Slice<Base>`. The institute's
`Array` (not `Swift.Array`) is required because `Array.Indexed<Tag>` is a
member of `Array_Primitives_Core.Array`, not `Swift.Array`.

## Tests

```
Suite "RepeatParser (leaf variant, P1 verification)"
  - positional only: [hello]                                  PASS
  - option then positional: [--count, 3, hello]               PASS
  - flag then positional: [--include-counter, hi]             PASS

Suite "CombinatorRepeatParser (combinator variant, P1 verification)"
  - positional only: [hello]                                  PASS
  - option then positional: [--count, 3, hello]               PASS
  - flag then positional: [--include-counter, hi]             PASS

Suite "HelpVisitor (P2 verification — help-text emission)"
  - Help visitor produces expected help text for Repeat       PASS

Suite "BashCompletionVisitor (P2 verification — completion-script emission)"
  - Bash completion visitor produces well-formed completion … PASS

Suite "Schema bidirectionality (P2 — single source of truth)"
  - Same Schema drives both parsing and emission              PASS
  - Parsing with default count uses Schema's defaultValue     PASS

10/10 tests passed.
```

## Verdict

**P1: CONFIRMED.**

Both variants compile and pass. The combinator-driven variant exercises:

- `Parser.OneOf.Sequence` with three branches over `Element == String`,
  with each branch producing a common `ArgvToken` and rolling back
  failed branches via `Input.Slice`'s checkpoint/restore.
- `Parser.Take.Sequence` for the `--count <int>` two-element shape.
- `Parser.Many.Simple` for argv-element repetition.
- `Parser.Protocol.map` for token normalization.
- `Parser.Protocol`'s typed `Failure` chain (`ArgvParseError` for leaves,
  composed by `Parser.OneOf` into `Product<…>`, then erased by
  `Parser.Many.Simple` into `Parser.Many.Error`).

Backtracking works correctly: when `MatchLiteral("--count")` fails on a
positional argument like `"hello"`, `Parser.OneOf.Sequence` restores the
cursor and tries the next branch, eventually succeeding with
`AnyString()`. This is the load-bearing claim of P1, and the tests
demonstrate it.

## Caveats / Notes for the Research Doc

These don't refute P1 but the L3 design might want to address them:

1. **`[String]` → institute-`Array<String>` bridge required.** `Swift.Array`
   does not have `Indexed<Tag>` — that's a member of the institute's
   `Array_Primitives_Core.Array`. The bridge in `ArgvInput.swift` walks
   `Swift.Array<String>` element-by-element and appends to the institute
   array. A `swift-arguments` L3 should provide this bridge as a
   public initializer (e.g.
   `ArgvInput.init(commandLine: [String])`).

2. **Module-resolution gotcha with `InternalImportsByDefault`.** Even
   though `Array_Dynamic_Primitives` does `public import
   Array_Primitives_Core`, downstream consumers of *just*
   `Array_Dynamic_Primitives` did not see `Array_Primitives_Core.Array`
   shadow `Swift.Array`. The fix was to add an explicit
   `public import Array_Primitives_Core` and depend on the product
   directly. This is a discoverability hazard worth a note in the L3
   docs.

3. **Combinator `Failure` types accumulate quickly.** A three-branch
   `Parser.OneOf.Sequence` produces `Product<F0, F1, F2>` (via
   `Parser.OneOf.Three`). With `Parser.Take.Sequence` and `Parser.Many`
   stacked on top, the inferred `Failure` of the composed parser was
   non-trivial enough that we relied on `Parser.Many.Error` (the
   outermost wrapper) for the public surface. For a real `swift-arguments`
   L3, surface a domain error type via `.error.map(...)` at each layer
   to keep the public API legible.

4. **`Parser.Take.Sequence` two-element output via `.map`.** The
   `MatchLiteral("--count")` branch produces `String`; `IntString()`
   produces `Int`. Combining them with the Take builder gives
   `(String, Int)`. The closure form `.map { (_: String, value: Int) in ... }`
   works cleanly — no explicit tuple destructuring gymnastics needed.

5. **`Parser.Many.Simple` requires `Parser.Input.Protocol` (backtracking).**
   `Input.Slice<Array<String>.Indexed<String>>` satisfies that, so the
   greedy-with-backtrack semantics work end-to-end on `String` element
   streams. Confirmed by the test where `Many` correctly stops at end
   of input (rather than failing).

## Premise P2 — visitor over Schema emits help + completion

> A visitor over the parsed Schema can emit (a) formatted help text and
> (b) a minimal bash-completion script for the same `Repeat` example
> without ad-hoc reflection or string-tag dispatch.

### Verdict

**P2: CONFIRMED** for the `Argument.Positional` / `Argument.Option` /
`Argument.Flag` schema shape. **PARTIAL** for the broader claim that the
visitor walks an arbitrary `Parser.Body` tree — see hazard 6 below.

### What was built

Three new source files (`Sources/ArgvParserSpike/`):

- `ArgumentSchema.swift` — data-only schema types: `Argument.Positional<V>`,
  `Argument.Option<V>`, `Argument.Flag`, the `Argument.Schema.Node`
  protocol with `accept(_:)`, and the `Argument.Schema.Visitor` protocol
  mirroring §2.2 of the research doc. The shapes are Copyable per v1.0.3.
- `HelpVisitor.swift` — `Argument.Schema.Visitor` conformer that
  collects per-row metadata and renders the canonical
  USAGE/ARGUMENTS/OPTIONS layout. Output for `Repeat` matches the
  reference example in the task brief byte-for-byte.
- `BashCompletionVisitor.swift` — second visitor that walks the same
  schema and emits a minimal `compgen`/`complete`-based bash function.
  Covers option/flag long-name completion (not positional-value
  completion, which is out of scope for this spike).
- `RepeatSchema.swift` — the canonical `Argument.Command` instance for
  `Repeat`, plus `SchemaDrivenRepeatParser` — a `Parser.Protocol`
  conformer whose option/flag names come from the Schema, not from
  string literals. This is the single-source-of-truth bridge.

### Three new tests (all passing)

1. **Help visitor produces expected help text for Repeat** — exact-string
   match against the reference help layout.
2. **Bash completion visitor produces well-formed completion script** —
   structural checks (shebang, function declaration, `complete -F`
   registration, option-name inclusion).
3. **Same Schema drives both parsing and emission** — parses `["--count",
   "5", "--include-counter", "hello"]` via `SchemaDrivenRepeatParser`,
   then runs both visitors over the same `parser.command` value, and
   asserts that the rendered artifacts reference the names that drove
   parsing. The schema instance is the load-bearing single source of
   truth.

### What this confirms

- **Static dispatch holds end-to-end.** Every visit point dispatches on
  a value-typed schema node (`Argument.Positional<String>`,
  `Argument.Option<Int>`, `Argument.Flag`). No string-tag switch, no
  `Mirror`, no key paths. The visitor receives the value type `V` as a
  generic parameter at the call site.
- **One schema, two directions.** `RepeatSchema.command` is consulted
  for parsing (the parser reads `countOption.name` rather than hard-coding
  `"--count"`) and for emission (both visitors walk
  `command.nodes`). Renaming the option in `RepeatSchema` would
  propagate to all three call sites mechanically — there is no parallel
  metadata table.
- **Adding a new visitor is purely additive.** A zsh-completion visitor,
  manpage visitor, or shell-script-generator would only require a new
  `Argument.Schema.Visitor` conformer; the Schema itself is untouched.

### Concrete hazards surfaced

1. **Heterogeneous Schema list requires existentials.** The
   `Argument.Command.nodes` field is `[any Argument.Schema.Node]`,
   because `Positional<String>` and `Option<Int>` have distinct generic
   parameters. The double-dispatch via `accept(_:)` recovers the static
   value type *at the visit-site*, so this is not a static-typing loss
   in practice, but it does mean the `Sendable` and `Copyable`
   constraints on `Node` cannot be tightened beyond what
   `any Argument.Schema.Node` permits. The v1.0.3 Copyable-by-default
   decision is compatible with this; the deferred `~Copyable` opt-in
   would need a parallel `~Copyable`-flavored `Schema.Node` protocol
   (or `~Copyable` existentials, which Swift 6 does not yet support
   ergonomically).

2. **`Sendable & Equatable` value-type constraint is load-bearing.**
   `Argument.Positional<V>` and `Argument.Option<V>` require
   `V: Sendable & Equatable` so the schema types themselves can be
   `Sendable & Equatable`. For real CLI value types (filesystem paths,
   URLs, etc.) this is unproblematic; for `~Copyable` value types it
   would not compose. Track as part of the deferred `~Copyable` opt-in
   item.

3. **Default-value rendering uses `String(describing:)`.** The
   `HelpVisitor` renders `option.defaultValue` via Swift's
   default-conformance string conversion. Numeric and string defaults
   render cleanly; complex types would need a `CustomStringConvertible`
   or an explicit `helpDefault: String` field on `Option`. Not a
   hazard for the `Repeat` example; flag for the L3.

4. **Typed-throws on visitors warns when `Failure == Never`.** The
   `Argument.Schema.Visitor` protocol's `visit(...)` methods are
   `throws(Failure)`. When the concrete visitor's `Failure == Never`,
   call sites that `try` the visit emit a "no calls to throwing
   functions" warning. Worked around in tests by dropping `try` when
   the concrete visitor type is known statically. For the L3, consider
   providing default-`Never`-typed convenience `accept` overloads that
   avoid `try` at the call site.

5. **Positional-value completion is out of scope.** The
   `BashCompletionVisitor` completes option/flag names only. Positional
   completion (filename, hostname, enum-value lists) would require
   attaching a `CompletionSource` per positional. This is a separate
   L3 design surface, not a hazard for P2.

6. **Visitor walks `Argument.*` schema combinators only, NOT arbitrary
   `Parser.*` combinators.** *This is the load-bearing PARTIAL caveat
   on the P2 verdict.* The visitor pattern as implemented works on the
   `Argument.Schema.Node` family. It does NOT walk arbitrary
   `Parser.OneOf.Sequence`, `Parser.Take.Sequence`, `Parser.Many`
   nodes that a Body-builder might compose. If the L3's `Command.Body`
   were typed as `some Parser.Protocol` and freely compose
   `Argument.*` with non-`Argument.*` combinators (e.g., custom user
   parsers that don't conform to `Argument.Schema.Node`), the visitor
   would have no way to walk the non-`Argument` portion. The Schema
   must be **restricted to `Argument.Schema.Node` conformers** for the
   bidirectional pattern to hold.

   The implication for the research doc §2.2: state explicitly that
   "the Body of a `Command.Protocol` is constrained to
   `some Argument.Schema.Node` (or a result-builder that produces
   one), not arbitrary `Parser.Protocol`." Generic
   `Parser.Protocol`-shaped Body would lose the metadata
   round-trippability that powers help/completion. This isn't a
   refutation — it's a constraint that has to be stated.

### Bidirectional single-source-of-truth: confirmed

The test "Same Schema drives both parsing and emission" demonstrates
that `RepeatSchema.command` is the only place where the names
`--count`, `--include-counter`, and `phrase` appear as canonical
references — the parser reads them from the schema instance and the
visitors walk the same instance. Renaming any option in
`RepeatSchema` would propagate without further edits, with the sole
exception of the ad-hoc `Repeat` result struct's stored properties
(which are user-domain types, not schema).

## Build
