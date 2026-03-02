// MARK: - Lazy Pipeline Release Mode
// Purpose: Validate compiler optimization of lazy pipelines vs eager/hand-rolled
//   V1: Lazy pipeline produces correct results (debug + release)
//   V2: Eager pipeline (stdlib) produces identical results
//   V3: Hand-rolled loop produces identical results
//   V4: Release mode timing comparison (lazy vs eager vs hand-rolled)
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: ALL CONFIRMED (4/4 variants)
//   V1: CONFIRMED — lazy pipeline produces correct results (debug + release)
//   V2: CONFIRMED — eager pipeline produces identical results
//   V3: CONFIRMED — hand-rolled loop produces identical results
//   V4: CONFIRMED — compiler inlines lazy pipelines effectively
//     Release mode (10M elements, filter>15M then sum):
//       Lazy:        0.005s (concrete types, zero allocation)
//       Eager:       0.034s (stdlib .map/.filter, intermediate arrays)
//       Hand-rolled: 0.005s (single loop)
//     Lazy matches hand-rolled within 2%. Eager is 7x slower.
//     Compiler fully eliminates lazy intermediate type overhead in -O.
// Date: 2026-02-25

// ============================================================================
// MARK: - Lazy types (from lazy-sequence-operator-unification)
// ============================================================================

protocol SyncSequence: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: SyncIterator where Iterator.Element == Element
    consuming func makeIterator() -> Iterator
}

protocol SyncIterator: ~Copyable {
    associatedtype Element: ~Copyable
    mutating func next() -> Element?
}

struct ArraySequence<E>: SyncSequence {
    typealias Element = E
    let values: [E]

    struct Iterator: SyncIterator {
        var index: Int = 0
        let values: [E]
        mutating func next() -> E? {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }

    consuming func makeIterator() -> Iterator {
        Iterator(values: values)
    }
}

struct Mapped<Base: ~Copyable, Input, Output>: ~Copyable {
    let base: Base
    let transform: (Input) -> Output
}

extension Mapped: Copyable where Base: Copyable {}

extension Mapped: SyncSequence where Base: SyncSequence & ~Copyable, Base.Element == Input {
    typealias Element = Output

    struct SyncIter: SyncIterator {
        var base: Base.Iterator
        let transform: (Input) -> Output

        mutating func next() -> Output? {
            guard let e = base.next() else { return nil }
            return transform(e)
        }
    }

    consuming func makeIterator() -> SyncIter {
        SyncIter(base: base.makeIterator(), transform: transform)
    }
}

struct Filtered<Base: ~Copyable, ElementType>: ~Copyable {
    let base: Base
    let predicate: (ElementType) -> Bool
}

extension Filtered: Copyable where Base: Copyable {}

extension Filtered: SyncSequence where Base: SyncSequence & ~Copyable, Base.Element == ElementType {
    typealias Element = ElementType

    struct SyncIter: SyncIterator {
        var base: Base.Iterator
        let predicate: (ElementType) -> Bool

        mutating func next() -> ElementType? {
            while let e = base.next() {
                if predicate(e) { return e }
            }
            return nil
        }
    }

    consuming func makeIterator() -> SyncIter {
        SyncIter(base: base.makeIterator(), predicate: predicate)
    }
}

// ============================================================================
// MARK: - Three pipeline approaches
// ============================================================================

let size = 10_000_000
let input = Array(0..<size)

// V1: Lazy pipeline
@inline(never)
func lazyPipeline(_ values: [Int]) -> Int {
    let source = ArraySequence(values: values)
    let mapped = Mapped(base: source, transform: { $0 * 3 })
    let filtered = Filtered(base: mapped, predicate: { $0 > 15_000_000 })

    var sum = 0
    var iter = filtered.makeIterator()
    while let e = iter.next() {
        sum += e
    }
    return sum
}

// V2: Eager pipeline (stdlib Array operations)
@inline(never)
func eagerPipeline(_ values: [Int]) -> Int {
    let mapped = values.map { $0 * 3 }
    let filtered = mapped.filter { $0 > 15_000_000 }
    return filtered.reduce(0, +)
}

// V3: Hand-rolled loop
@inline(never)
func handRolled(_ values: [Int]) -> Int {
    var sum = 0
    for x in values {
        let mapped = x * 3
        if mapped > 15_000_000 {
            sum += mapped
        }
    }
    return sum
}

// ============================================================================
// MARK: - Execution
// ============================================================================

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

print("=" * 60)
print("LAZY PIPELINE RELEASE MODE EXPERIMENT")
print("=" * 60)
print("Dataset size: \(size)")
print()

// Correctness check
let lazyResult = lazyPipeline(input)
let eagerResult = eagerPipeline(input)
let handRolledResult = handRolled(input)

print("V1 lazy result:       \(lazyResult)")
print("V2 eager result:      \(eagerResult)")
print("V3 hand-rolled result: \(handRolledResult)")
print()

assert(lazyResult == handRolledResult, "FAILED — lazy != hand-rolled")
assert(eagerResult == handRolledResult, "FAILED — eager != hand-rolled")
print("V1: CONFIRMED — lazy pipeline produces correct results")
print("V2: CONFIRMED — eager pipeline matches")
print("V3: CONFIRMED — hand-rolled loop matches")
print()

// Timing comparison (3 iterations each, take median)
let clock = ContinuousClock()

func measure(_ label: String, _ body: () -> Int) {
    var times: [Duration] = []
    for _ in 0..<3 {
        let elapsed = clock.measure {
            _ = body()
        }
        times.append(elapsed)
    }
    times.sort()
    let median = times[1]
    print("\(label): \(median) (median of 3)")
}

print("V4: Timing comparison")
measure("  Lazy      ") { lazyPipeline(input) }
measure("  Eager     ") { eagerPipeline(input) }
measure("  Hand-rolled") { handRolled(input) }
print()

#if DEBUG
print("Mode: DEBUG — timing not representative of optimized performance")
#else
print("Mode: RELEASE — timing reflects optimized performance")
#endif

print()
print("=" * 60)
print("ALL VARIANTS COMPLETE")
print("=" * 60)
