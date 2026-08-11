// MARK: - Composed Type vs Direct Static Method Usage Benchmark
// Purpose: Measure whether the composed type (Ring.Growable) adds overhead
//          compared to direct static method calls (Ring.pushBack/popFront
//          on raw header + storage), validating the three-layer architecture's
//          cost model.
//
// Hypothesis: Composed type calls (ring.pushBack) compile to identical code
//             as direct static calls (Ring.pushBack(header:storage:)) after
//             optimization, showing negligible (<5%) throughput difference.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Status: SUPERSEDED 2026-04-30 — Storage namespace migrated to Storage<Element>; Modular API moved/renamed; experiment requires re-targeting against current Cyclic_Index_Primitives surface
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED - All 3 variants show <5% difference (release -O).
//   V1: Bulk cycle (10K ops) — 1.007x ratio (+0.7%)
//   V2: Interleaved steady-state (100K pairs) — 1.047x ratio (+4.7%)
//   V3: Small buffer high-wrap (100K pairs, 4-slot) — 0.998x ratio (-0.1%)
//
// Key Finding: The composed type (Ring.Growable) adds no measurable overhead
//              compared to direct static method calls after optimization.
//              The three-layer architecture's cost model is validated:
//              Layer 3 (composed) is a zero-cost wrapper over Layer 2 (static).
//
// Date: 2026-02-03

import Storage_Primitives
import Cyclic_Index_Primitives

// ============================================================
// MARK: - Ring Buffer Implementation (copied from architecture validation)
// ============================================================

enum Ring {}

extension Ring {
    struct Header: Copyable, Sendable, Hashable {
        var head: Index<Storage>
        var count: Index<Storage>.Count
        let capacity: Index<Storage>.Count

        init(capacity: Index<Storage>.Count) {
            self.head = .zero
            self.count = Index<Storage>.Count(Cardinal.zero)
            self.capacity = capacity
        }

        var isEmpty: Bool { count == Index<Storage>.Count(Cardinal.zero) }
        var isFull: Bool { count == capacity }

        var initialization: Storage.Initialization {
            let countCardinal = count.rawValue
            if countCardinal == .zero { return .empty }

            let headOrdinal = head.position
            let capCardinal = capacity.rawValue

            let headPlusCount = Cardinal(headOrdinal.rawValue &+ countCardinal.rawValue)
            if headPlusCount.rawValue <= capCardinal.rawValue {
                let end = try! Index<Storage>(Ordinal(headPlusCount.rawValue))
                return .one(head ..< end)
            } else {
                let capIndex = try! Index<Storage>(Ordinal(capCardinal.rawValue))
                let overflowAmount = headPlusCount.rawValue &- capCardinal.rawValue
                let overflowEnd = try! Index<Storage>(Ordinal(overflowAmount))
                return .two(
                    first: head ..< capIndex,
                    second: Index<Storage>.zero ..< overflowEnd
                )
            }
        }
    }
}

// ============================================================
// MARK: - Layer 2: Static Operations
// ============================================================

extension Ring {
    @inline(always)
    static func pushBack(
        _ element: consuming Int,
        header: inout Header,
        storage: Storage.Heap<Int>
    ) {
        let countOffset = Index<Storage>.Offset(
            fromZero: try! Index<Storage>(Ordinal(header.count.rawValue.rawValue))
        )
        let tail = Modular.advanced(header.head, by: countOffset, capacity: header.capacity)
        storage.initialize(to: consume element, at: tail)
        let newCount = Cardinal(header.count.rawValue.rawValue &+ 1)
        header.count = Index<Storage>.Count(newCount)
        storage.initialization = header.initialization
    }

    @inline(always)
    static func popFront(
        header: inout Header,
        storage: Storage.Heap<Int>
    ) -> Int {
        let element = storage.move(at: header.head)
        header.head = Modular.successor(of: header.head, capacity: header.capacity)
        let newCount = Cardinal(header.count.rawValue.rawValue &- 1)
        header.count = Index<Storage>.Count(newCount)
        storage.initialization = header.initialization
        return element
    }
}

// ============================================================
// MARK: - Layer 3: Composed Type
// ============================================================

extension Ring {
    struct Growable: ~Copyable {
        var header: Header
        var storage: Storage.Heap<Int>

        init(minimumCapacity: Index<Storage>.Count) {
            self.storage = Storage.Heap<Int>.create(minimumCapacity: minimumCapacity)
            self.header = Header(capacity: storage.slotCapacity)
        }

        var count: Index<Storage>.Count { header.count }
        var isEmpty: Bool { header.isEmpty }
        var capacity: Index<Storage>.Count { header.capacity }
        var isFull: Bool { header.isFull }

        @inline(always)
        mutating func pushBack(_ element: consuming Int) {
            Ring.pushBack(consume element, header: &header, storage: storage)
        }

        @inline(always)
        mutating func popFront() -> Int {
            Ring.popFront(header: &header, storage: storage)
        }

        deinit {}
    }
}

// ============================================================
// MARK: - Benchmark Infrastructure
// ============================================================

/// Measure wall-clock time of a closure in nanoseconds using ContinuousClock.
func measure(_ body: () -> Void) -> UInt64 {
    let clock = ContinuousClock()
    let start = clock.now
    body()
    let end = clock.now
    let duration = end - start
    let ns = duration.components
    return UInt64(ns.seconds) * 1_000_000_000 + UInt64(ns.attoseconds / 1_000_000_000)
}

/// Run benchmark multiple times, return median nanoseconds.
func benchmark(iterations: Int, warmup: Int, _ body: () -> Void) -> UInt64 {
    // Warmup
    for _ in 0..<warmup { body() }

    // Collect samples
    var samples: [UInt64] = []
    samples.reserveCapacity(iterations)
    for _ in 0..<iterations {
        samples.append(measure(body))
    }

    // Return median
    samples.sort()
    return samples[iterations / 2]
}

/// Format ratio with 3 decimal places without Foundation.
func formatRatio(_ value: Double) -> String {
    let wholePart = Int(value)
    let fracPart = Int((value - Double(wholePart)) * 1000)
    let absFrac = fracPart < 0 ? -fracPart : fracPart
    return "\(wholePart).\(String(repeating: "0", count: max(0, 3 - "\(absFrac)".count)))\(absFrac)"
}

/// Format percentage difference without Foundation.
func formatPctDiff(_ value: Double) -> String {
    let sign = value >= 0 ? "+" : "-"
    let absVal = value < 0 ? -value : value
    let wholePart = Int(absVal)
    let fracPart = Int((absVal - Double(wholePart)) * 10)
    return "\(sign)\(wholePart).\(fracPart)"
}

/// Extract UInt from Index<Storage>.Count
func capValue(_ c: Index<Storage>.Count) -> UInt {
    c.rawValue.rawValue
}

// ============================================================
// MARK: - Variant 1: Throughput — pushBack/popFront cycle
// ============================================================
// Hypothesis: Composed type throughput within 5% of direct static calls
//             for a pushBack+popFront cycle of 10,000 operations
// Result: CONFIRMED — 1.007x ratio (+0.7%)

do {
    let opsPerRound = 10_000
    let cap = try! Index<Storage>.Count(Cardinal(UInt(opsPerRound + 16)))
    let iterations = 50
    let warmup = 10

    // --- Composed type ---
    let composedNs = benchmark(iterations: iterations, warmup: warmup) {
        var ring = Ring.Growable(minimumCapacity: cap)
        for i in 0..<opsPerRound {
            ring.pushBack(i)
        }
        for _ in 0..<opsPerRound {
            let _ = ring.popFront()
        }
    }

    // --- Direct static calls ---
    let staticNs = benchmark(iterations: iterations, warmup: warmup) {
        let storage = Storage.Heap<Int>.create(minimumCapacity: cap)
        var header = Ring.Header(capacity: storage.slotCapacity)
        storage.initialization = .empty
        for i in 0..<opsPerRound {
            Ring.pushBack(i, header: &header, storage: storage)
        }
        for _ in 0..<opsPerRound {
            let _ = Ring.popFront(header: &header, storage: storage)
        }
    }

    let ratio = Double(composedNs) / Double(staticNs)
    let pctDiff = (ratio - 1.0) * 100.0

    print("Variant 1 - Throughput (pushBack/popFront cycle, \(opsPerRound) ops):")
    print("  Composed (median):  \(composedNs) ns")
    print("  Static (median):    \(staticNs) ns")
    print("  Ratio:              \(formatRatio(ratio))x")
    print("  Difference:         \(formatPctDiff(pctDiff))%")
    print("  Within 5%:          \(abs(pctDiff) < 5.0 ? "CONFIRMED" : "REFUTED")")
}

// ============================================================
// MARK: - Variant 2: Throughput — interleaved push/pop (steady state)
// ============================================================
// Hypothesis: In steady-state (alternating push/pop with wrapping),
//             composed type matches direct static calls
// Result: CONFIRMED — 1.047x ratio (+4.7%)

do {
    let opsPerRound = 100_000
    let cap = try! Index<Storage>.Count(Cardinal(UInt(128)))
    let iterations = 50
    let warmup = 10

    // --- Composed type (interleaved) ---
    let composedNs = benchmark(iterations: iterations, warmup: warmup) {
        var ring = Ring.Growable(minimumCapacity: cap)
        // Pre-fill half
        for i in 0..<64 {
            ring.pushBack(i)
        }
        // Interleaved push/pop
        for i in 0..<opsPerRound {
            ring.pushBack(i)
            let _ = ring.popFront()
        }
        // Drain
        for _ in 0..<64 {
            let _ = ring.popFront()
        }
    }

    // --- Direct static (interleaved) ---
    let staticNs = benchmark(iterations: iterations, warmup: warmup) {
        let storage = Storage.Heap<Int>.create(minimumCapacity: cap)
        var header = Ring.Header(capacity: storage.slotCapacity)
        storage.initialization = .empty
        // Pre-fill half
        for i in 0..<64 {
            Ring.pushBack(i, header: &header, storage: storage)
        }
        // Interleaved push/pop
        for i in 0..<opsPerRound {
            Ring.pushBack(i, header: &header, storage: storage)
            let _ = Ring.popFront(header: &header, storage: storage)
        }
        // Drain
        for _ in 0..<64 {
            let _ = Ring.popFront(header: &header, storage: storage)
        }
    }

    let ratio = Double(composedNs) / Double(staticNs)
    let pctDiff = (ratio - 1.0) * 100.0

    print("\nVariant 2 - Interleaved steady-state (\(opsPerRound) push+pop pairs):")
    print("  Composed (median):  \(composedNs) ns")
    print("  Static (median):    \(staticNs) ns")
    print("  Ratio:              \(formatRatio(ratio))x")
    print("  Difference:         \(formatPctDiff(pctDiff))%")
    print("  Within 5%:          \(abs(pctDiff) < 5.0 ? "CONFIRMED" : "REFUTED")")
}

// ============================================================
// MARK: - Variant 3: Small buffer (high wrap frequency)
// ============================================================
// Hypothesis: Even with very small capacity (4 slots, frequent wrapping),
//             composed type matches direct static calls
// Result: CONFIRMED — 0.998x ratio (-0.1%)

do {
    let opsPerRound = 100_000
    let cap = try! Index<Storage>.Count(Cardinal(UInt(4)))
    let iterations = 50
    let warmup = 10

    // --- Composed type (small buffer, interleaved) ---
    let composedNs = benchmark(iterations: iterations, warmup: warmup) {
        var ring = Ring.Growable(minimumCapacity: cap)
        let actualCap = Int(capValue(ring.capacity))
        // Pre-fill to half actual capacity
        let halfCap = actualCap / 2
        for i in 0..<halfCap {
            ring.pushBack(i)
        }
        for i in 0..<opsPerRound {
            ring.pushBack(i)
            let _ = ring.popFront()
        }
        for _ in 0..<halfCap {
            let _ = ring.popFront()
        }
    }

    // --- Direct static (small buffer, interleaved) ---
    let staticNs = benchmark(iterations: iterations, warmup: warmup) {
        let storage = Storage.Heap<Int>.create(minimumCapacity: cap)
        var header = Ring.Header(capacity: storage.slotCapacity)
        storage.initialization = .empty
        let actualCap = Int(capValue(header.capacity))
        let halfCap = actualCap / 2
        for i in 0..<halfCap {
            Ring.pushBack(i, header: &header, storage: storage)
        }
        for i in 0..<opsPerRound {
            Ring.pushBack(i, header: &header, storage: storage)
            let _ = Ring.popFront(header: &header, storage: storage)
        }
        for _ in 0..<halfCap {
            let _ = Ring.popFront(header: &header, storage: storage)
        }
    }

    let ratio = Double(composedNs) / Double(staticNs)
    let pctDiff = (ratio - 1.0) * 100.0

    print("\nVariant 3 - Small buffer (4 requested, high wrap frequency):")
    print("  Composed (median):  \(composedNs) ns")
    print("  Static (median):    \(staticNs) ns")
    print("  Ratio:              \(formatRatio(ratio))x")
    print("  Difference:         \(formatPctDiff(pctDiff))%")
    print("  Within 5%:          \(abs(pctDiff) < 5.0 ? "CONFIRMED" : "REFUTED")")
}

// ============================================================
// MARK: - Results Summary
// ============================================================
print("\n=== Composed vs Static Benchmark Complete ===")
print("Measured: Composed type (Ring.Growable) vs direct static calls (Ring.pushBack/popFront)")
print("Three variants: bulk cycle, interleaved steady-state, small buffer high-wrap")
print("All measurements: median of 50 iterations after 10 warmup rounds")
