// MARK: - Implicit Graph Diff Benchmark
// Purpose: Compare Myers O(ND) diff against 0-1 BFS on implicit edit graph
//          to determine if graph-primitives can subsume sequence diff.
// Hypothesis: 0-1 BFS with diagonal chasing will be within 2-3x of Myers
//             for practical diff sizes (N <= 10000, D <= 100), making a
//             unified graph-based implementation viable.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: REFUTED — 0-1 BFS is 10-110x slower than Myers across all practical
//         sizes, with O(N*M) space making it infeasible for N > ~5000.
//
//   Correctness: All three variants produce identical minimal edit distances.
//
//   Performance (release build):
//     Small  (N=100,  D=7):   BFS 14.3x, Chasing  9.7x slower
//     Medium (N=1000, D=27):  BFS 91.2x, Chasing 57.9x slower
//     Large  (N=5000, D=69):  BFS 110.5x, Chasing 59.3x slower
//     Worst  (N=500,  D=484): BFS  3.9x, Chasing  4.2x slower
//
//   Space: Myers O(N+M+D²) vs BFS O(N*M). At N=50000, BFS needs ~20GB.
//
//   Conclusion: The implicit edit graph model is theoretically sound but
//   practically unviable as a foundation for sequence diff. Myers' diagonal
//   exploration + snake chasing is not merely an optimization of 0-1 BFS —
//   it is a fundamentally different algorithm that exploits the edit graph's
//   structure to achieve O(ND) time and O(D²) space. A generic graph
//   framework cannot capture this without becoming Myers-specific.
//   Keep specialized Myers in Sequence Difference Primitives.
//
// Date: 2026-02-27

import Foundation  // For timing only — not in production primitives

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Shared Types
// ═══════════════════════════════════════════════════════════════════════════

enum Change<Element> {
    case first(Element)   // in old only (removed)
    case second(Element)  // in new only (inserted)
    case both(Element)    // in both (matched)
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Variant 1: Myers O(ND) — Baseline
// Hypothesis: This is the fastest possible for small D / large N.
// ═══════════════════════════════════════════════════════════════════════════

enum Myers {
    static func diff<Element: Hashable>(
        _ old: [Element],
        _ new: [Element]
    ) -> [Change<Element>] {
        let n = old.count
        let m = new.count

        if n == 0 { return new.map { .second($0) } }
        if m == 0 { return old.map { .first($0) } }

        let max = n + m
        let size = 2 * max + 1
        let offset = max

        var v = [Int](repeating: 0, count: size)
        v[1 + offset] = 0
        var trace: [[Int]] = []

        for d in 0...max {
            trace.append(v)
            for k in stride(from: -d, through: d, by: 2) {
                var x: Int
                if k == -d || (k != d && v[k - 1 + offset] < v[k + 1 + offset]) {
                    x = v[k + 1 + offset]
                } else {
                    x = v[k - 1 + offset] + 1
                }
                var y = x - k
                while x < n && y < m && old[x] == new[y] {
                    x += 1
                    y += 1
                }
                v[k + offset] = x
                if x >= n && y >= m {
                    return backtrack(trace: trace, old: old, new: new, offset: offset)
                }
            }
        }

        return old.map { .first($0) } + new.map { .second($0) }
    }

    private static func backtrack<Element: Hashable>(
        trace: [[Int]],
        old: [Element],
        new: [Element],
        offset: Int
    ) -> [Change<Element>] {
        var x = old.count
        var y = new.count
        var changes: [Change<Element>] = []

        for d in stride(from: trace.count - 1, through: 0, by: -1) {
            let v = trace[d]
            let k = x - y
            let prevK: Int
            if k == -d || (k != d && v[k - 1 + offset] < v[k + 1 + offset]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }
            let prevX = v[prevK + offset]
            let prevY = prevX - prevK

            while x > prevX && y > prevY {
                x -= 1
                y -= 1
                changes.append(.both(old[x]))
            }
            if d > 0 {
                if x == prevX {
                    y -= 1
                    changes.append(.second(new[y]))
                } else {
                    x -= 1
                    changes.append(.first(old[x]))
                }
            }
        }

        changes.reverse()
        return changes
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Variant 2: Plain 0-1 BFS on Implicit Edit Graph
// Hypothesis: Correct but slower due to per-cell visited tracking.
// ═══════════════════════════════════════════════════════════════════════════

enum ZeroOneBFS {
    struct Point: Hashable {
        let x: Int
        let y: Int
    }

    static func diff<Element: Hashable>(
        _ old: [Element],
        _ new: [Element]
    ) -> [Change<Element>] {
        let n = old.count
        let m = new.count

        if n == 0 { return new.map { .second($0) } }
        if m == 0 { return old.map { .first($0) } }

        // Deque for 0-1 BFS (Array-based: popFirst from front, append to back)
        var deque: [Point] = [Point(x: 0, y: 0)]
        var dequeHead = 0

        // Distance and predecessor tracking
        var dist = [[Int]](repeating: [Int](repeating: Int.max, count: m + 1), count: n + 1)
        var prev = [[Point?]](repeating: [Point?](repeating: nil, count: m + 1), count: n + 1)
        dist[0][0] = 0

        while dequeHead < deque.count {
            let p = deque[dequeHead]
            dequeHead += 1

            let currentDist = dist[p.x][p.y]
            if p.x == n && p.y == m { break }

            // Diagonal (cost 0) — match
            if p.x < n && p.y < m && old[p.x] == new[p.y] {
                let nd = currentDist
                if nd < dist[p.x + 1][p.y + 1] {
                    dist[p.x + 1][p.y + 1] = nd
                    prev[p.x + 1][p.y + 1] = p
                    deque.insert(Point(x: p.x + 1, y: p.y + 1), at: dequeHead)
                }
            }

            // Right (cost 1) — delete from old
            if p.x < n {
                let nd = currentDist + 1
                if nd < dist[p.x + 1][p.y] {
                    dist[p.x + 1][p.y] = nd
                    prev[p.x + 1][p.y] = p
                    deque.append(Point(x: p.x + 1, y: p.y))
                }
            }

            // Down (cost 1) — insert from new
            if p.y < m {
                let nd = currentDist + 1
                if nd < dist[p.x][p.y + 1] {
                    dist[p.x][p.y + 1] = nd
                    prev[p.x][p.y + 1] = p
                    deque.append(Point(x: p.x, y: p.y + 1))
                }
            }
        }

        // Backtrack
        return reconstructPath(prev: prev, old: old, new: new)
    }

    private static func reconstructPath<Element: Hashable>(
        prev: [[Point?]],
        old: [Element],
        new: [Element]
    ) -> [Change<Element>] {
        var path: [Point] = []
        var current = Point(x: old.count, y: new.count)
        while true {
            path.append(current)
            guard let p = prev[current.x][current.y] else { break }
            current = p
        }
        path.reverse()

        var changes: [Change<Element>] = []
        for i in 1..<path.count {
            let dx = path[i].x - path[i - 1].x
            let dy = path[i].y - path[i - 1].y
            if dx == 1 && dy == 1 {
                changes.append(.both(old[path[i - 1].x]))
            } else if dx == 1 {
                changes.append(.first(old[path[i - 1].x]))
            } else {
                changes.append(.second(new[path[i - 1].y]))
            }
        }
        return changes
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Variant 3: 0-1 BFS with Diagonal Chasing
// Hypothesis: Approaches Myers performance by greedily following diagonals
//             instead of enqueuing each diagonal cell individually.
// ═══════════════════════════════════════════════════════════════════════════

enum ZeroOneBFSChasing {
    static func diff<Element: Hashable>(
        _ old: [Element],
        _ new: [Element]
    ) -> [Change<Element>] {
        let n = old.count
        let m = new.count

        if n == 0 { return new.map { .second($0) } }
        if m == 0 { return old.map { .first($0) } }

        // Deque for 0-1 BFS
        var deque: [(x: Int, y: Int)] = [(0, 0)]
        var dequeHead = 0

        var dist = [[Int]](repeating: [Int](repeating: Int.max, count: m + 1), count: n + 1)
        var prev = [[(Int, Int)?]](repeating: [(Int, Int)?](repeating: nil, count: m + 1), count: n + 1)

        // Chase diagonal from starting point
        var sx = 0, sy = 0
        while sx < n && sy < m && old[sx] == new[sy] {
            let nx = sx + 1, ny = sy + 1
            dist[nx][ny] = 0
            prev[nx][ny] = (sx, sy)
            sx = nx
            sy = ny
        }
        dist[0][0] = 0
        deque[0] = (sx, sy)

        while dequeHead < deque.count {
            let (px, py) = deque[dequeHead]
            dequeHead += 1

            let currentDist = dist[px][py]
            if currentDist > dist[px][py] { continue }  // stale entry
            if px == n && py == m { break }

            // Right (cost 1) — delete from old, then chase diagonal
            if px < n {
                var x = px + 1
                var y = py
                let nd = currentDist + 1
                if nd < dist[x][y] {
                    dist[x][y] = nd
                    prev[x][y] = (px, py)
                    // Chase diagonal
                    while x < n && y < m && old[x] == new[y] {
                        let nx = x + 1, ny = y + 1
                        if nd < dist[nx][ny] {
                            dist[nx][ny] = nd
                            prev[nx][ny] = (x, y)
                        }
                        x = nx
                        y = ny
                    }
                    deque.append((x, y))
                }
            }

            // Down (cost 1) — insert from new, then chase diagonal
            if py < m {
                var x = px
                var y = py + 1
                let nd = currentDist + 1
                if nd < dist[x][y] {
                    dist[x][y] = nd
                    prev[x][y] = (px, py)
                    // Chase diagonal
                    while x < n && y < m && old[x] == new[y] {
                        let nx = x + 1, ny = y + 1
                        if nd < dist[nx][ny] {
                            dist[nx][ny] = nd
                            prev[nx][ny] = (x, y)
                        }
                        x = nx
                        y = ny
                    }
                    deque.append((x, y))
                }
            }
        }

        // Backtrack
        var path: [(Int, Int)] = []
        var current = (n, m)
        while true {
            path.append(current)
            guard let p = prev[current.0][current.1] else { break }
            current = p
        }
        path.reverse()

        var changes: [Change<Element>] = []
        for i in 1..<path.count {
            let dx = path[i].0 - path[i - 1].0
            let dy = path[i].1 - path[i - 1].1
            if dx == 1 && dy == 1 {
                changes.append(.both(old[path[i - 1].0]))
            } else if dx == 1 && dy == 0 {
                changes.append(.first(old[path[i - 1].0]))
            } else if dx == 0 && dy == 1 {
                changes.append(.second(new[path[i - 1].1]))
            }
        }
        return changes
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Test Input Generation
// ═══════════════════════════════════════════════════════════════════════════

func generateInput(
    size n: Int,
    editDistance d: Int,
    seed: UInt64 = 42
) -> (old: [Int], new: [Int]) {
    // Generate a base sequence, then apply d random edits
    var rng = seed
    func nextRandom() -> UInt64 {
        rng = rng &* 6364136223846793005 &+ 1442695040888963407
        return rng
    }

    let old = (0..<n).map { $0 }
    var new = old

    for _ in 0..<d {
        let pos = Int(nextRandom() % UInt64(max(new.count, 1)))
        let action = nextRandom() % 3
        switch action {
        case 0 where !new.isEmpty:
            // Delete
            new.remove(at: min(pos, new.count - 1))
        case 1:
            // Insert
            new.insert(Int(truncatingIfNeeded: nextRandom()), at: min(pos, new.count))
        default:
            // Replace
            if !new.isEmpty {
                new[min(pos, new.count - 1)] = Int(truncatingIfNeeded: nextRandom())
            }
        }
    }
    return (old, new)
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Correctness Verification
// ═══════════════════════════════════════════════════════════════════════════

func editDistance<E>(_ changes: [Change<E>]) -> Int {
    changes.reduce(0) { acc, c in
        switch c {
        case .first, .second: acc + 1
        case .both: acc
        }
    }
}

func verifyCorrectness() {
    print("=== Correctness Verification ===\n")

    let tests: [(old: [String], new: [String], label: String)] = [
        (["A", "C", "B"], ["B", "A", "C"], "Greedy-trap case"),
        (["A", "B", "C"], ["A", "C", "D"], "Simple edit"),
        ([], ["A", "B"], "Empty old"),
        (["A", "B"], [], "Empty new"),
        (["A", "B", "C"], ["A", "B", "C"], "Identical"),
        (["A", "B", "C", "D", "E"], ["A", "X", "C", "Y", "E"], "Scattered edits"),
    ]

    for test in tests {
        let m = Myers.diff(test.old, test.new)
        let b = ZeroOneBFS.diff(test.old, test.new)
        let c = ZeroOneBFSChasing.diff(test.old, test.new)

        let dm = editDistance(m)
        let db = editDistance(b)
        let dc = editDistance(c)

        let match = dm == db && db == dc
        print("  \(test.label): Myers=\(dm) BFS=\(db) Chasing=\(dc) \(match ? "OK" : "MISMATCH")")
    }

    // Random tests
    var failures = 0
    for i in 0..<100 {
        let (old, new) = generateInput(size: 50, editDistance: 10, seed: UInt64(i))
        let dm = editDistance(Myers.diff(old, new))
        let db = editDistance(ZeroOneBFS.diff(old, new))
        let dc = editDistance(ZeroOneBFSChasing.diff(old, new))
        if dm != db || db != dc { failures += 1 }
    }
    print("  Random (100 cases, N=50, D~10): \(failures == 0 ? "ALL OK" : "\(failures) FAILURES")")
    print()
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Benchmark
// ═══════════════════════════════════════════════════════════════════════════

func seconds(_ d: Duration) -> Double {
    let c = d.components
    return Double(c.seconds) + Double(c.attoseconds) * 1e-18
}

/// Full benchmark comparing all three variants. BFS variants use O(N*M)
/// space, so this is only feasible for moderate N.
func benchmark(
    label: String,
    old: [Int],
    new: [Int],
    iterations: Int
) {
    print("  \(label) (N=\(old.count), iterations=\(iterations))")

    // Warmup
    _ = Myers.diff(old, new)
    _ = ZeroOneBFS.diff(old, new)
    _ = ZeroOneBFSChasing.diff(old, new)

    // Myers
    let t0 = ContinuousClock.now
    for _ in 0..<iterations {
        _ = Myers.diff(old, new)
    }
    let myersTime = ContinuousClock.now - t0

    // 0-1 BFS
    let t1 = ContinuousClock.now
    for _ in 0..<iterations {
        _ = ZeroOneBFS.diff(old, new)
    }
    let bfsTime = ContinuousClock.now - t1

    // 0-1 BFS + Chasing
    let t2 = ContinuousClock.now
    for _ in 0..<iterations {
        _ = ZeroOneBFSChasing.diff(old, new)
    }
    let chasingTime = ContinuousClock.now - t2

    let dm = editDistance(Myers.diff(old, new))

    print("    Edit distance: \(dm)")
    print("    Myers:         \(myersTime)")
    print("    0-1 BFS:       \(bfsTime)")
    print("    BFS+Chasing:   \(chasingTime)")

    let myersS = seconds(myersTime)
    let bfsRatio = seconds(bfsTime) / max(myersS, 1e-12)
    let chasingRatio = seconds(chasingTime) / max(myersS, 1e-12)
    print("    Ratio BFS/Myers:     \(String(format: "%.1f", bfsRatio))x")
    print("    Ratio Chasing/Myers: \(String(format: "%.1f", chasingRatio))x")
    print()
}

/// Myers-only benchmark for sizes where BFS O(N*M) space is infeasible.
func benchmarkMyersOnly(
    label: String,
    old: [Int],
    new: [Int],
    iterations: Int
) {
    print("  \(label) (N=\(old.count), iterations=\(iterations)) [Myers only — BFS O(N*M) infeasible]")

    _ = Myers.diff(old, new)

    let t0 = ContinuousClock.now
    for _ in 0..<iterations {
        _ = Myers.diff(old, new)
    }
    let myersTime = ContinuousClock.now - t0

    let dm = editDistance(Myers.diff(old, new))
    print("    Edit distance: \(dm)")
    print("    Myers:         \(myersTime)")
    print()
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Run
// ═══════════════════════════════════════════════════════════════════════════

verifyCorrectness()

print("=== Performance Benchmark ===\n")

// Small: typical unit test diff
let small = generateInput(size: 100, editDistance: 5)
benchmark(label: "Small", old: small.old, new: small.new, iterations: 10000)

// Medium: typical file diff
let medium = generateInput(size: 1000, editDistance: 20)
benchmark(label: "Medium", old: medium.old, new: medium.new, iterations: 1000)

// Large: large file diff — BFS allocates ~800MB for dist alone
let large = generateInput(size: 5000, editDistance: 50)
benchmark(label: "Large", old: large.old, new: large.new, iterations: 50)

// Worst case: completely different (D ≈ N)
let worst = generateInput(size: 500, editDistance: 500)
benchmark(label: "Worst case (D≈N)", old: worst.old, new: worst.new, iterations: 100)

// Myers-only scaling tests
let xlarge = generateInput(size: 50000, editDistance: 20)
benchmarkMyersOnly(label: "Very large, small D", old: xlarge.old, new: xlarge.new, iterations: 10)

print("=== Space Complexity Note ===")
print("  Myers:       O(N+M+D²) — scales to any input size")
print("  0-1 BFS:     O(N*M) — 5000×5000 = 200MB, 50000×50000 = 20GB")
print("  BFS+Chasing: O(N*M) — same as plain BFS")
print()

// MARK: - Results Summary
//
// V1 (Myers O(ND)):       BASELINE — O(ND) time, O(N+M+D²) space
// V2 (Plain 0-1 BFS):     10-110x slower, O(N*M) space — REJECTED
// V3 (0-1 BFS + Chasing): 4-60x slower, O(N*M) space — REJECTED
//
// Key insight: Myers is not "BFS + optimization". Its diagonal-first
// exploration strategy is what gives it sub-quadratic performance.
// Generic 0-1 BFS on the same graph cannot replicate this without
// becoming the Myers algorithm.
