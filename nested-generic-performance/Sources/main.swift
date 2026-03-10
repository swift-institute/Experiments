// MARK: - Nested Generic Layout Equivalence
// Purpose: Zero-overhead verification for nested generic types
// Status: CONFIRMED (layout equivalence)
// Date: 2026-01-20
// Toolchain: Swift 6.2
//
// Note: Nested generics are purely a compile-time namespace mechanism.
//       This experiment confirms identical memory layout. Runtime performance
//       equivalence is validated by the lazy-pipeline-release-mode experiment
//       which shows nested type chains are fully optimized away in -O mode.

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

// Both should have identical memory layout

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

// The MemoryLayout equivalence proves nesting is zero-overhead at the type level.
// For runtime verification, build with -c release and check assembly output,
// or see: swift-institute/Experiments/lazy-pipeline-release-mode/

print("nested-generic-performance: CONFIRMED (layout equivalence)")
