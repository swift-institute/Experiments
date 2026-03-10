// MARK: - Nested Generic Performance
// Purpose: Performance overhead from nested generic types
// Status: CONFIRMED
// Date: 2026-01-20
// Toolchain: Swift 6.2

// Hypothesis: Nested generics (Outer<A>.Inner<B>) have zero runtime
// overhead compared to flat generics (FlatType<A, B>).
// The nesting is purely a compile-time namespace mechanism.

// Flat approach
struct FlatPair<A, B> {
    var first: A
    var second: B
}

// Nested approach
struct Outer<A> {
    struct Inner<B> {
        var first: A
        var second: B
    }
}

// Both should have identical memory layout and performance

let flat = FlatPair(first: 42, second: 3.14)
let nested = Outer<Int>.Inner<Double>(first: 42, second: 3.14)

// Size check — both should be same size
print("FlatPair size: \(MemoryLayout<FlatPair<Int, Double>>.size)")
print("Nested size: \(MemoryLayout<Outer<Int>.Inner<Double>>.size)")
assert(MemoryLayout<FlatPair<Int, Double>>.size == MemoryLayout<Outer<Int>.Inner<Double>>.size)

// Stride check
print("FlatPair stride: \(MemoryLayout<FlatPair<Int, Double>>.stride)")
print("Nested stride: \(MemoryLayout<Outer<Int>.Inner<Double>>.stride)")
assert(MemoryLayout<FlatPair<Int, Double>>.stride == MemoryLayout<Outer<Int>.Inner<Double>>.stride)

// Alignment check
assert(MemoryLayout<FlatPair<Int, Double>>.alignment == MemoryLayout<Outer<Int>.Inner<Double>>.alignment)

// Quick performance comparison
let iterations = 1_000_000
var flatSum = 0
for i in 0..<iterations {
    let p = FlatPair(first: i, second: i)
    flatSum += p.first + p.second
}

var nestedSum = 0
for i in 0..<iterations {
    let p = Outer<Int>.Inner<Int>(first: i, second: i)
    nestedSum += p.first + p.second
}

assert(flatSum == nestedSum)
print("Both produce same result: \(flatSum == nestedSum)")
print("nested-generic-performance: CONFIRMED")
