# Experiment: Conditional Copyable for Array Types

## Hypothesis

`Array.Bounded` can be made conditionally Copyable (like `Stack.Bounded`) by switching from raw pointer storage to ManagedBuffer-based storage.

## Background

### Current State

| Type | Has deinit? | Conditionally Copyable? | Sequence conformance? |
|------|-------------|-------------------------|----------------------|
| `Array.Bounded` | YES (raw pointer) | NO | NO |
| `Array.Unbounded` | NO (ManagedBuffer) | YES | Could add |
| `Array.Inline` | YES (inline cleanup) | NO | NO |
| `Array.Small` | YES (inline cleanup) | NO | NO |

### Stack Primitives (Reference)

| Type | Has deinit? | Conditionally Copyable? | Sequence conformance? |
|------|-------------|-------------------------|----------------------|
| `Stack` | NO (ManagedBuffer) | YES | YES (when Element: Copyable) |
| `Stack.Bounded` | NO (uses Stack.Storage) | YES | YES (when Element: Copyable) |
| `Stack.Inline` | YES | NO | NO |
| `Stack.Small` | YES | NO | NO |

## Key Insight

The difference between `Stack.Bounded` (conditionally Copyable) and `Array.Bounded` (unconditionally ~Copyable) is:

- **Stack.Bounded**: Uses nested `Stack.Storage` class (ManagedBuffer-based), struct has NO deinit
- **Array.Bounded**: Uses raw `UnsafeMutablePointer<Element>`, struct HAS deinit

Types with `deinit` cannot be Copyable (Swift language constraint).

## Experiment Design

Refactor `Array.Bounded` to:
1. Use a nested `Storage` class based on ManagedBuffer
2. Remove the deinit from the struct (let Storage handle cleanup)
3. Add `extension Array.Bounded: Copyable where Element: Copyable {}`
4. Add `extension Array.Bounded: Sequence where Element: Copyable {}`

## Expected Benefits

1. **Conditional Copyable**: `Array.Bounded` becomes Copyable when Element is Copyable
2. **Sequence conformance**: `for-in` loops work when Element is Copyable
3. **Copy-on-Write**: Efficient value semantics with shared storage until mutation
4. **Move-only support**: Still works with ~Copyable elements

## Files

- `Sources/Array.Bounded.Experiment.swift` - The experimental implementation
- `Tests/ConditionalCopyableTests.swift` - Tests verifying the behavior

## Success Criteria

1. Compiles without errors
2. `Array.Bounded<CopyableElement>` is Copyable
3. `Array.Bounded<NonCopyableElement>` is ~Copyable
4. Sequence conformance works for Copyable elements
5. All invariants preserved
