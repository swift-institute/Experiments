# Prompt: Operator Inventory and Canonical Placement Plan

## Your task

Perform a comprehensive inventory of ALL operator declarations (`func +`, `func -`, `func *`, `func <`, `func ==`, `prefix func -`, `func +=`, `func -=`, etc.) across the entire `/Users/coen/Developer/swift-primitives/` directory tree. Then produce a refactoring plan that eliminates all duplication and places every operator in its canonical location.

## Context: The Protocol Abstraction Pattern

We recently introduced three protocol abstractions that allow generic operations over both bare types and their `Tagged<Tag, _>` phantom-typed wrappers:

| Protocol | Defined in | Abstracts over | Accessor | Init |
|----------|-----------|---------------|----------|------|
| `Cardinal.Protocol` | `swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.Protocol.swift` | `Cardinal`, `Tagged<_, Cardinal>` | `.cardinal → Cardinal` | `init(_ cardinal: Cardinal)` |
| `Ordinal.Protocol` | `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Protocol.swift` | `Ordinal`, `Tagged<_, Ordinal>` | `.ordinal → Ordinal` | `init(_ ordinal: Ordinal)` |
| `Affine.Discrete.Vector.Protocol` | **NOT YET CREATED** | `Affine.Discrete.Vector`, `Tagged<_, Affine.Discrete.Vector>` | `.vector → Vector` | `init(_ vector: Vector)` |

These protocols enable a single generic operator definition to replace two concrete ones (bare + tagged). For example, `Memory.Alignment.Align.up` is now generic over `Cardinal.Protocol` — it accepts both `Cardinal` and `Index<T>.Count` (which is `Tagged<T, Cardinal>`).

## What to inventory

For every `.swift` file under `/Users/coen/Developer/swift-primitives/`, find every:

1. **Operator function declaration** — `func +`, `func -`, `func *`, `func /`, `func %`, `func ==`, `func !=`, `func <`, `func <=`, `func >`, `func >=`, `func +=`, `func -=`, `prefix func -`, `prefix func +`, etc.
2. **For each operator, record:**
   - File path and line number
   - Full signature (parameters, return type, throws clause)
   - Whether it's on a bare type (`Cardinal`, `Ordinal`, `Affine.Discrete.Vector`) or a `Tagged<_, _>` wrapper
   - The semantic operation (e.g., "cardinal addition", "ordinal + vector → ordinal", "point - point → vector")

## Packages to search

All packages under `/Users/coen/Developer/swift-primitives/`:
- `swift-cardinal-primitives`
- `swift-ordinal-primitives`
- `swift-affine-primitives`
- `swift-index-primitives`
- `swift-memory-primitives`
- `swift-buffer-primitives`
- `swift-tagged-primitives`
- `swift-equation-primitives`
- `swift-comparison-primitives`
- And any other `swift-*-primitives` directories present

## What to produce

### Part 1: Raw Inventory Table

A table with columns: Package | File | Line | Operator | LHS Type | RHS Type | Return Type | Throws | Semantic Category

### Part 2: Duplication Analysis

For each semantic operation, list all declarations that implement it. Flag pairs where:
- One operates on bare types, the other on `Tagged<_, _>` wrappers
- The implementations are structurally identical (just wrapping/unwrapping)
- They could be unified via `Cardinal.Protocol`, `Ordinal.Protocol`, or `Affine.Discrete.Vector.Protocol`

### Part 3: Canonical Placement Plan

For each group of duplicated operators, specify:
1. **The canonical single definition** — its generic signature using the protocol abstractions
2. **Where it should live** — which package and file (respecting tier layering: identity → equation → comparison → cardinal → ordinal → affine → index → memory → buffer)
3. **What gets deleted** — which existing declarations are superseded
4. **Whether `Affine.Discrete.Vector.Protocol` is needed** — and if so, where it should be defined and what its conformances look like

### Part 4: Non-Duplicated Operators

List operators that are NOT duplicated and are already in their canonical location. These need no changes.

## Key constraints

- **Tier layering**: Packages depend only downward. An operator must live in the lowest package that has visibility of all types in its signature.
- **[API-IMPL-005] One type per file**: New protocol types get their own files.
- **[CONV-001/002] rawValue confinement**: `.rawValue` access must be confined to extension initializers and same-package code, never at call sites.
- **No Foundation imports** — ever.
- **Do not write any code.** This is a research and planning task only. Produce the inventory and plan as markdown.

## Output format

Write the complete inventory and plan to:
`/Users/coen/Developer/swift-primitives/swift-cardinal-primitives/Experiments/cardinal-protocol-abstraction/operator-inventory.md`
