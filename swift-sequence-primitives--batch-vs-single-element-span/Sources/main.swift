// MARK: - Batch vs Single-Element Span: nextSpan Throughput Benchmark
// Purpose: Validate whether losing batch capability in nextSpan matters
//          for non-contiguous iterators (tree/graph/dictionary traversal).
//
// Hypothesis: For non-contiguous structures, per-element traversal work
//             (stack push/pop, node lookup) dominates the function call
//             and pointer extraction overhead of single-element returns.
//             Therefore, Optional inline (1 element per call) should have
//             negligible throughput difference vs array-buffer batch.
//
// Baseline: var _spanBuffer: [Element] with batch fill + .span
// Proposed: var _element: Element? with single-element + pointer reinterpret
//
// Toolchain: Apple Swift 6.2 (swiftlang-6.2.x)
// Platform: macOS 26.x (arm64)
//
// Result: CONFIRMED — Single-element is 2-3x FASTER than batch for
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//         tree traversal (V1-V4). Array-buffer overhead (removeAll,
//         append, array metadata) exceeds any batching amortization.
//         Sequential access (V5) shows single-element optimized away
//         by compiler (0.0000s) — unreliable, but moot given V1-V4.
//
// Evidence (release mode, arm64):
//   V1 (depth=5,  63 nodes):     batch 0.0685s, single 0.0196s → 0.29x
//   V2 (depth=10, 2047 nodes):   batch 0.1136s, single 0.0496s → 0.44x
//   V3 (depth=15, 65535 nodes):  batch 0.0737s, single 0.0350s → 0.47x
//   V4 (depth=18, 524287 nodes): batch 0.0606s, single 0.0286s → 0.47x
//   next() baseline: ~equal for both patterns (0.02-0.04s)
//
// Conclusion: Proceed with Optional inline for ALL non-contiguous
//             iterators. No batch advantage exists — single-element
//             eliminates array allocation entirely.
//
// Date: 2026-03-04

import Foundation  // only for timing (CFAbsoluteTimeGetCurrent)

// ============================================================================
// MARK: - Simulated Tree Structure
// Mimics Tree.N arena-backed storage with stack-based traversal.
// ============================================================================

struct SimulatedNode {
    let element: Int
    let children: [Int]  // indices into the node array
}

struct SimulatedTree {
    let nodes: [SimulatedNode]

    /// Build a complete binary tree with `depth` levels.
    static func completeBinaryTree(depth: Int) -> SimulatedTree {
        var nodes: [SimulatedNode] = []
        func build(currentDepth: Int) -> Int {
            let index = nodes.count
            nodes.append(SimulatedNode(element: index, children: []))
            if currentDepth < depth {
                let left = build(currentDepth: currentDepth + 1)
                let right = build(currentDepth: currentDepth + 1)
                nodes[index] = SimulatedNode(element: index, children: [left, right])
            }
            return index
        }
        _ = build(currentDepth: 0)
        return SimulatedTree(nodes: nodes)
    }

    var count: Int { nodes.count }
}

// ============================================================================
// MARK: - Array-Buffer Iterator (Baseline)
// Current production pattern: _spanBuffer: [Element] with batch fill.
// ============================================================================

struct ArrayBufferIterator: ~Copyable {
    let tree: SimulatedTree
    var stack: [Int]
    var _spanBuffer: [Int] = []

    init(tree: SimulatedTree) {
        self.tree = tree
        self.stack = tree.nodes.isEmpty ? [] : [0]
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        _spanBuffer.removeAll(keepingCapacity: true)
        var remaining = maximumCount
        while remaining > 0, let index = stack.popLast() {
            let node = tree.nodes[index]
            for child in node.children.reversed() {
                stack.append(child)
            }
            _spanBuffer.append(node.element)
            remaining -= 1
        }
        return _spanBuffer.span
    }

    @_lifetime(self: immortal)
    mutating func next() -> Int? {
        guard let index = stack.popLast() else { return nil }
        let node = tree.nodes[index]
        for child in node.children.reversed() {
            stack.append(child)
        }
        return node.element
    }
}

// ============================================================================
// MARK: - Optional Inline Iterator (Proposed)
// Proposed replacement: _element: Element? with single-element return.
// ============================================================================

struct OptionalInlineIterator: ~Copyable {
    let tree: SimulatedTree
    var stack: [Int]
    var _element: Int? = nil

    init(tree: SimulatedTree) {
        self.tree = tree
        self.stack = tree.nodes.isEmpty ? [] : [0]
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer<Int>(
                unsafe UnsafeRawPointer(p).assumingMemoryBound(to: Int.self)
            )
        }
        guard maximumCount > 0 else {
            let span = unsafe Span(_unsafeStart: ptr, count: 0)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        guard let index = stack.popLast() else {
            let span = unsafe Span(_unsafeStart: ptr, count: 0)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        let node = tree.nodes[index]
        for child in node.children.reversed() {
            stack.append(child)
        }
        _element = node.element
        let span = unsafe Span(_unsafeStart: ptr, count: 1)
        return unsafe _overrideLifetime(span, mutating: &self)
    }

    @_lifetime(self: immortal)
    mutating func next() -> Int? {
        guard let index = stack.popLast() else { return nil }
        let node = tree.nodes[index]
        for child in node.children.reversed() {
            stack.append(child)
        }
        return node.element
    }
}

// ============================================================================
// MARK: - forEach Consumers
// Simulates the production forEach pattern that calls nextSpan(.max).
// ============================================================================

func forEachBatch(_ tree: SimulatedTree) -> Int {
    var iter = ArrayBufferIterator(tree: tree)
    var sum = 0
    while true {
        let span = iter.nextSpan(maximumCount: .max)
        if span.isEmpty { break }
        for i in 0..<span.count {
            sum &+= span[i]
        }
    }
    return sum
}

func forEachSingle(_ tree: SimulatedTree) -> Int {
    var iter = OptionalInlineIterator(tree: tree)
    var sum = 0
    while true {
        let span = iter.nextSpan(maximumCount: .max)
        if span.isEmpty { break }
        for i in 0..<span.count {
            sum &+= span[i]
        }
    }
    return sum
}

// next()-based iteration (both should be identical — no span involved)
func nextBased<I: ~Copyable>(_ makeIter: () -> I, advance: (inout I) -> Int?) -> Int {
    var iter = makeIter()
    var sum = 0
    while let v = advance(&iter) {
        sum &+= v
    }
    return sum
}

// ============================================================================
// MARK: - Benchmark Harness
// ============================================================================

func measure(label: String, iterations: Int, _ body: () -> Int) -> (time: Double, result: Int) {
    // Warmup
    _ = body()
    _ = body()

    let start = CFAbsoluteTimeGetCurrent()
    var result = 0
    for _ in 0..<iterations {
        result = body()
    }
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    return (elapsed, result)
}

func benchmark(depth: Int, iterations: Int) {
    let tree = SimulatedTree.completeBinaryTree(depth: depth)
    let n = tree.count
    print("--- Tree depth=\(depth), nodes=\(n), iterations=\(iterations) ---")

    // forEach via nextSpan (batch vs single)
    let batch = measure(label: "batch", iterations: iterations) {
        forEachBatch(tree)
    }
    let single = measure(label: "single", iterations: iterations) {
        forEachSingle(tree)
    }

    // next()-based (both patterns identical)
    let nextBatch = measure(label: "next-batch", iterations: iterations) {
        nextBased({ ArrayBufferIterator(tree: tree) }, advance: { $0.next() })
    }
    let nextSingle = measure(label: "next-single", iterations: iterations) {
        nextBased({ OptionalInlineIterator(tree: tree) }, advance: { $0.next() })
    }

    // Verify correctness
    assert(batch.result == single.result, "Mismatch: batch=\(batch.result), single=\(single.result)")
    assert(batch.result == nextBatch.result, "Mismatch: batch=\(batch.result), next=\(nextBatch.result)")

    let ratio = single.time / batch.time
    let verdict: String
    if ratio < 1.1 {
        verdict = "NEGLIGIBLE (<10%)"
    } else if ratio < 1.5 {
        verdict = "MODERATE (10-50%)"
    } else if ratio < 2.0 {
        verdict = "SIGNIFICANT (50-100%)"
    } else {
        verdict = "SEVERE (>2x)"
    }

    print("  forEach (batch):   \(String(format: "%.4f", batch.time))s")
    print("  forEach (single):  \(String(format: "%.4f", single.time))s")
    print("  ratio:             \(String(format: "%.2f", ratio))x  → \(verdict)")
    print("  next() (batch):    \(String(format: "%.4f", nextBatch.time))s")
    print("  next() (single):   \(String(format: "%.4f", nextSingle.time))s")
    print("  sum:               \(batch.result)")
    print()
}

// ============================================================================
// MARK: - V1: Small Tree (depth 5, 63 nodes)
// ============================================================================

print("=== Batch vs Single-Element Span: nextSpan Throughput ===\n")

// MARK: - V1: Small tree
// Hypothesis: Negligible difference for small trees
benchmark(depth: 5, iterations: 50_000)

// MARK: - V2: Medium tree
// Hypothesis: Traversal work dominates, difference stays small
benchmark(depth: 10, iterations: 5_000)

// MARK: - V3: Large tree
// Hypothesis: At scale, batch amortization may help — or traversal still dominates
benchmark(depth: 15, iterations: 100)

// MARK: - V4: Very large tree
// Hypothesis: Maximum pressure on batch vs single difference
benchmark(depth: 18, iterations: 10)

// ============================================================================
// MARK: - V5: Dictionary-Like Sequential Access (no traversal overhead)
// This is the worst case for single-element: sequential access with minimal
// per-element work. If batch wins anywhere, it wins here.
// ============================================================================

struct SequentialArrayBufferIterator: ~Copyable {
    let data: [Int]
    var index: Int = 0
    var _spanBuffer: [Int] = []

    init(_ data: [Int]) { self.data = data }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        _spanBuffer.removeAll(keepingCapacity: true)
        var remaining = maximumCount
        while remaining > 0, index < data.count {
            _spanBuffer.append(data[index])
            index += 1
            remaining -= 1
        }
        return _spanBuffer.span
    }
}

struct SequentialOptionalInlineIterator: ~Copyable {
    let data: [Int]
    var index: Int = 0
    var _element: Int? = nil

    init(_ data: [Int]) { self.data = data }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Int> {
        let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer<Int>(
                unsafe UnsafeRawPointer(p).assumingMemoryBound(to: Int.self)
            )
        }
        guard maximumCount > 0, index < data.count else {
            let span = unsafe Span(_unsafeStart: ptr, count: 0)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        _element = data[index]
        index += 1
        let span = unsafe Span(_unsafeStart: ptr, count: 1)
        return unsafe _overrideLifetime(span, mutating: &self)
    }
}

func benchmarkSequential(count: Int, iterations: Int) {
    let data = Array(0..<count)
    print("--- Sequential access, count=\(count), iterations=\(iterations) ---")

    let batch = measure(label: "seq-batch", iterations: iterations) {
        var iter = SequentialArrayBufferIterator(data)
        var sum = 0
        while true {
            let span = iter.nextSpan(maximumCount: .max)
            if span.isEmpty { break }
            for i in 0..<span.count { sum &+= span[i] }
        }
        return sum
    }

    let single = measure(label: "seq-single", iterations: iterations) {
        var iter = SequentialOptionalInlineIterator(data)
        var sum = 0
        while true {
            let span = iter.nextSpan(maximumCount: .max)
            if span.isEmpty { break }
            for i in 0..<span.count { sum &+= span[i] }
        }
        return sum
    }

    assert(batch.result == single.result)
    let ratio = single.time / batch.time
    let verdict: String
    if ratio < 1.1 { verdict = "NEGLIGIBLE (<10%)" }
    else if ratio < 1.5 { verdict = "MODERATE (10-50%)" }
    else if ratio < 2.0 { verdict = "SIGNIFICANT (50-100%)" }
    else { verdict = "SEVERE (>2x)" }

    print("  forEach (batch):   \(String(format: "%.4f", batch.time))s")
    print("  forEach (single):  \(String(format: "%.4f", single.time))s")
    print("  ratio:             \(String(format: "%.2f", ratio))x  → \(verdict)")
    print()
}

print("=== V5: Sequential Access (worst case for single-element) ===\n")
benchmarkSequential(count: 1_000, iterations: 50_000)
benchmarkSequential(count: 10_000, iterations: 5_000)
benchmarkSequential(count: 100_000, iterations: 500)

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("=== Summary ===")
print("V1-V4: Tree traversal (stack-based, non-contiguous)")
print("V5: Sequential access (worst case — minimal per-element work)")
print()
print("If tree traversal shows NEGLIGIBLE: claim validated for non-contiguous.")
print("If sequential shows SIGNIFICANT+: batch mode matters when per-element work is trivial.")
print("Decision boundary: proceed with Optional inline only for non-contiguous iterators")
print("where traversal work dominates. Keep array-buffer for sequential/contiguous.")
