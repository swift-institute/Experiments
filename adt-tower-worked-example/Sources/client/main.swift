// MARK: - client — cross-module consumer of the worked example ([EXP-017])
//
// Result: CONFIRMED debug+release — "canonical: [3, 3, 7, 19, 25, 42] · small: min=1
//         then 1 2 8 9 · jobs: first=1 remaining=2". See HeapKit/Heap.swift header.

import HeapKit
import Comparison_Primitives

// Canonical (heap-allocated column) — push out of order, pop sorted.
var pq = Heap<Int>()
for x in [42, 7, 19, 3, 25, 3] { pq.push(x) }
var drained: [Int] = []
while !pq.isEmpty { drained.append(pq.pop()) }
print("canonical:", drained)

// Small variant (inline budget 64 bytes, spills to heap) — same ops, ZERO new op code.
var sq = Heap<Int>.Small<64>()
for x in [9, 1, 8, 2] { sq.push(x) }
print("small: min=\(sq.min) then", sq.pop(), sq.pop(), sq.pop(), sq.pop())

// FULL ~Copyable element through the same chain (move-only payload).
struct Job: ~Copyable, Comparison.`Protocol` {
    var priority: Int
    init(_ p: Int) { self.priority = p }
    static func < (lhs: borrowing Job, rhs: borrowing Job) -> Bool { lhs.priority < rhs.priority }
    static func == (lhs: borrowing Job, rhs: borrowing Job) -> Bool { lhs.priority == rhs.priority }
}
var jobs = Heap<Job>()
jobs.push(Job(5))
jobs.push(Job(1))
jobs.push(Job(3))
let first = jobs.pop()
print("jobs: first=\(first.priority) remaining=\(Int(jobs.count.underlying.rawValue))")
