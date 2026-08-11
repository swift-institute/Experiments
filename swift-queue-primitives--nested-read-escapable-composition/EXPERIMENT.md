# Nested _read + ~Escapable Composition

## Hypothesis

The nested `_read` coroutine limitation for `~Escapable` values ([MEM-LIFE-005]) may be
specific to the Property.View indirection pattern rather than fundamental to coroutine
scoping. If a direct `_read` on a buffer can yield a `~Escapable` value that an outer
`_read` on a queue can re-yield, then the limitation is View-specific and a non-View
path is viable.

## Variants

1. **Direct nested _read**: `Buffer._read` yields `Borrow<Element>`, `Queue._read` re-yields it
2. **Single-level _read**: `Queue._read` directly accesses buffer storage (no inner _read)
3. **Property.View chain**: Reproduce the failure from the production investigation

## Expected Results

- Variant 1: If CONFIRMED, the limitation is View-specific; a direct buffer access path could
  enable property-based peek for ~Copyable elements without View indirection
- Variant 1: If REJECTED, the limitation is fundamental to nested coroutine scoping —
  closure-based peek is the correct terminal design
- Variant 2: Should CONFIRM (single _read has no nesting issue)
- Variant 3: Should REJECT (reproduces the known failure)

## Status

PENDING — experiment stub created during reflections-processing triage.

## Provenance

- Source reflection: 2026-03-31-noncopyable-peek-escapable-scope-nesting-limit.md
- Related: [MEM-LIFE-005], [IMPL-079]
