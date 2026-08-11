# Experiment Discovery: Property.View via Protocol Extension

## Question

Can we have the protocol require Property.View directly, without intermediate method requirements?

## Answer

**Not directly as a requirement**, but **YES via protocol extension**.

The Property.View is provided by **protocol extension**, not as a protocol requirement. This is the same pattern used by `Comparison.Protocol` in swift-comparison-primitives.

## The Pattern

```swift
// 1. Tag type
public enum RemoveTag {}

// 2. Protocol with PRIMITIVE requirements
public protocol Removable {
    associatedtype Element
    mutating func removeLast() -> Element?
    mutating func removeAll()
}

// 3. Protocol EXTENSION provides Property.View AUTOMATICALLY
extension Removable {
    public var remove: Property<RemoveTag, Self>.View {
        mutating _read {
            yield unsafe Property<RemoveTag, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<RemoveTag, Self>.View(&self)
            yield &view
        }
    }
}

// 4. Property.View extension provides FLUENT API
extension Property.View where Tag == RemoveTag, Base: Removable {
    @_lifetime(&self)
    public mutating func last() -> Base.Element? {
        unsafe base.pointee.removeLast()
    }

    @_lifetime(&self)
    public mutating func all() {
        unsafe base.pointee.removeAll()
    }
}
```

## What Conformers Implement

```swift
extension MyType: Removable {
    mutating func removeLast() -> Element? { ... }
    mutating func removeAll() { ... }
}
```

That's it. Two methods.

## What Conformers Get for FREE

```swift
myInstance.remove          // Property.View (from protocol extension)
myInstance.remove.last()   // Fluent API (from Property.View extension)
myInstance.remove.all()    // Fluent API (from Property.View extension)
```

## Why This Works

1. **Protocol extension** can use `mutating _read` / `mutating _modify` accessors
2. **Protocol requirement** cannot (must use `{ get }` or `{ get set }`)
3. Protocol extension provides the Property.View without being a requirement
4. Conformers don't need to implement the property - they get it automatically

## Analogy: Comparison.Protocol

This is exactly how `Comparison.Protocol` works:

| Aspect | Comparison.Protocol | Removable |
|--------|---------------------|-----------|
| **Required** | `<` and `==` | `removeLast()` and `removeAll()` |
| **Extension provides** | `var compare: Property<...>.View` | `var remove: Property<...>.View` |
| **Fluent API** | `.compare.to()`, `.compare.isLess(than:)` | `.remove.last()`, `.remove.all()` |

## Key Insight

The **protocol requirement IS the primitive** (`removeLast`, `removeAll`).
The **Property.View is provided automatically** by protocol extension.
The **fluent API is provided automatically** by Property.View extension.

Conformers implement the minimal primitive. Everything else is free.

## Swift Language Constraint

Why can't the protocol require Property.View directly?

- Protocol properties must use `{ get }` or `{ get set }`
- Property.View needs `mutating _read` / `mutating _modify` for `~Copyable` support
- These accessor forms cannot witness a protocol requirement

The protocol extension workaround provides the same end result: conformers get the Property.View automatically.

## Verification

```
=== Protocol Extension Pattern Test ===

Initial: count = 5
array.remove.last(): 5
array.remove.last(): 4
After removes: count = 3
After remove.all(): count = 0

=== Protocol Extension Pattern CONFIRMED ===
```

## Recommendation

Adopt this pattern for `Collection.Remove` in swift-collection-primitives:

1. Protocol requires primitives: `removeLast()`, `removeAll()`, etc.
2. Protocol extension provides: `var remove: Property<Collection.Remove, Self>.View`
3. Property.View extension provides: `.remove.last()`, `.remove.all()`, `.remove.first()`

Conformers implement only the primitives. They get the fluent API for free.
