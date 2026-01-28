# Experiment Discovery

@Metadata {
    @TitleHeading("Swift Institute")
}

Proactive workflow for systematically auditing packages, verifying assumptions, and discovering improvements through empirical experimentation.

## Overview

This document defines the *discovery workflow* for experiment packages—the process you follow when you want to proactively verify a package's assumptions, test its boundaries, or find improvements without an existing failure prompting the investigation.

**Entry point**: You want to audit a package, verify claims, or systematically explore behavior.

**Prerequisite**: Read <doc:Experiment> for package structure, execution protocol, and documentation requirements.

**Applies to**: Package audits, assumption verification, claim testing, boundary exploration, improvement discovery.

**Does not apply to**: Debugging specific failures or resolving immediate technical disputes—see <doc:Experiment-Investigation> instead.

---

## Quick Reference: When to Create a Discovery Experiment

**Scope**: Decision criteria for creating discovery experiments. See [EXP-012] for the normative rule.

| Trigger | Example | See Also |
|---------|---------|----------|
| New package ready for verification | "Let's verify swift-heap-primitives' claims" | [EXP-013] |
| Implicit assumption identified | "We assume ~Copyable works with async here" | [EXP-014] |
| Documentation makes testable claim | "Docs say this is O(1)" | [EXP-015] |
| Boundary conditions unexplored | "What happens at capacity limits?" | [EXP-016] |
| Potential improvement identified | "Could we use InlineArray here?" | [EXP-017] |
| Toolchain upgrade | "Does our code still work on Swift 6.1?" | [EXP-015] |
| Cross-package integration | "Do these two packages compose correctly?" | [EXP-013] |

**Cross-references**: [EXP-012], [EXP-002a] (Pattern Experiment.md)

---

## [EXP-012] Discovery Triggers

**Scope**: Conditions that warrant creating a discovery experiment.

**Statement**: A discovery experiment SHOULD be created when proactive verification would increase confidence in a package's correctness, document empirical evidence for claims, or identify improvement opportunities.

### Trigger Categories

| Category | Description | Priority |
|----------|-------------|----------|
| Package milestone | Package reaches v1.0 or major release | High |
| Toolchain update | New Swift version available | High |
| Assumption audit | Implicit assumptions identified during review | Medium |
| Claim verification | Testable claims in docs or comments | Medium |
| Boundary exploration | Edge cases not covered by tests | Medium |
| Improvement hypothesis | "This might be faster/simpler" | Low |
| Cross-package verification | Integration behavior between packages | Medium |

### Discovery vs Investigation

| Aspect | Investigation | Discovery |
|--------|---------------|-----------|
| Trigger | Failure or uncertainty | Proactive audit |
| Starting point | Broken code | Working code |
| Goal | Find what's wrong | Verify what's right |
| Outcome | Fix or workaround | Evidence or improvement |
| Urgency | Usually blocking | Usually scheduled |

**Correct**:
```text
Context: swift-heap-primitives reaches v1.0
Action: Create discovery experiments for all public API claims
Result: Documented evidence that Heap behaves as specified
```

**Incorrect**:
```text
Context: swift-heap-primitives reaches v1.0
Action: "It works, ship it"
Result: Undocumented assumptions, potential surprises  ❌
```

**Rationale**: Proactive verification catches issues before they become production failures. Discovery experiments create empirical evidence that serves as living documentation.

**Cross-references**: [EXP-001] (Pattern Experiment Investigation.md), [EXP-002a] (Pattern Experiment.md)

---

## [EXP-013] Package Audit Methodology

**Scope**: Systematic process for auditing a package through experiments.

**Statement**: Package audits MUST follow a systematic methodology that identifies all verifiable claims and assumptions, then creates experiments to test them.

### Audit Process

| Phase | Action | Output |
|-------|--------|--------|
| 1. Inventory | List all public types and APIs | Type catalog |
| 2. Extract claims | Identify testable statements | Claim list |
| 3. Identify assumptions | Find implicit dependencies | Assumption list |
| 4. Prioritize | Rank by risk and importance | Prioritized list |
| 5. Generate experiments | Create experiment for each item | Experiment packages |
| 6. Execute | Run all experiments | Results |
| 7. Document | Record findings, promote significant results | Documentation |

### Phase 1: Inventory

Enumerate the package's public surface:

```text
Package: swift-heap-primitives

Public Types:
- Heap<Element>
- Heap.Index
- Heap.Iterator

Public APIs:
- init()
- init(minimumCapacity:)
- insert(_:)
- removeMin() -> Element?
- min -> Element?
- count -> Int
- isEmpty -> Bool
```

### Phase 2: Extract Claims

Identify testable statements from:
- Documentation comments
- README assertions
- Code comments
- Type constraints
- Protocol conformances

```text
Claims extracted from swift-heap-primitives:

[CLAIM-001] "insert(_:) is O(log n)"
[CLAIM-002] "removeMin() is O(log n)"
[CLAIM-003] "min is O(1)"
[CLAIM-004] "Heap conforms to Sendable when Element: Sendable"
[CLAIM-005] "Works with ~Copyable elements"
```

### Phase 3: Identify Assumptions

Find implicit dependencies not stated explicitly:

```text
Assumptions identified:

[ASSUMP-001] Comparable.< is transitive (required for heap property)
[ASSUMP-002] Element can be moved (for heap operations)
[ASSUMP-003] No concurrent modification during iteration
[ASSUMP-004] Memory layout is stable across Swift versions
```

### Phase 4: Prioritize

Rank items by risk (what breaks if wrong) and importance (how critical to package):

| ID | Item | Risk | Importance | Priority |
|----|------|------|------------|----------|
| CLAIM-005 | ~Copyable support | High | High | P0 |
| CLAIM-004 | Sendable conformance | High | High | P0 |
| ASSUMP-002 | Element movability | High | High | P0 |
| CLAIM-001 | insert O(log n) | Medium | Medium | P1 |
| CLAIM-003 | min O(1) | Low | Medium | P2 |

### Phase 5-7: Generate, Execute, Document

For each prioritized item, follow [EXP-003] through [EXP-006] from <doc:Experiment>.

**Rationale**: Systematic audits ensure nothing is missed. Ad-hoc verification leaves gaps that become production surprises.

**Cross-references**: [EXP-014], [EXP-015], [EXP-016]

---

## [EXP-014] Assumption Inventory

**Scope**: Identifying and documenting implicit assumptions for verification.

**Statement**: Before creating experiments, implicit assumptions MUST be inventoried by examining code patterns, type constraints, and undocumented dependencies.

### Common Assumption Categories

| Category | What to Look For | Example |
|----------|------------------|---------|
| Type constraints | Generic `where` clauses, protocol requirements | "Element must be Comparable" |
| Memory semantics | Ownership annotations, ~Copyable usage | "Element is moved, not copied" |
| Concurrency | Sendable conformance, isolation requirements | "Safe to access from any thread" |
| Platform | Conditional compilation, availability checks | "Requires macOS 15+" |
| Performance | Algorithmic complexity, memory allocation | "O(1) access" |
| Compiler features | Experimental features, language version | "Requires Swift 6" |

### Assumption Extraction Template

```text
// Source: Heap.swift:47
// Code: consuming func removeMin() -> Element?
//
// Assumptions:
// 1. `consuming` implies Element supports move semantics
// 2. Optional return implies empty heap is valid state
 assumes single-threaded access OR Sendable safety
```

### Experiment Generation from Assumptions

Each assumption becomes an experiment hypothesis:

```text
Assumption: "consuming implies Element supports move semantics"

Experiment: heap-noncopyable-remove/
Hypothesis: Heap<NonCopyableElement>.removeMin() compiles and executes correctly
Test: Create ~Copyable element type, insert, remove
```

**Correct**:
```swift
// MARK: - Assumption Verification: ~Copyable removeMin
// Purpose: Verify removeMin works with ~Copyable elements
// Assumption: consuming annotation enables move-only element support
//
// Toolchain: swift-6.0-RELEASE
// Result: CONFIRMED
// Date: 2026-01-20

struct Token: ~Copyable {
    let id: Int
}

extension Token: Comparable {
    static func < (lhs: Token, rhs: Token) -> Bool { lhs.id < rhs.id }
}

var heap = Heap<Token>()
heap.insert(Token(id: 1))
let removed = heap.removeMin()
print(removed?.id as Any)  // Output: Optional(1)
```

**Incorrect**:
```text
Assumption: "consuming implies Element supports move semantics"
Action: "Seems right, no need to test"
Result: Unverified assumption  ❌
```

**Rationale**: Implicit assumptions are the most dangerous—they fail silently when violated. Explicit verification converts assumptions into documented facts.

**Cross-references**: [EXP-013], [EXP-015]

---

## [EXP-015] Claim Verification

**Scope**: Testing explicit claims made in documentation or comments.

**Statement**: Testable claims in documentation SHOULD be verified through experiments that produce empirical evidence supporting or refuting the claim.

### Claim Categories

| Category | Verification Method | Example |
|----------|---------------------|---------|
| Complexity | Benchmark with varying input sizes | "O(log n) insertion" |
| Conformance | Compile-time check | "Sendable when Element: Sendable" |
| Behavior | Runtime test with assertions | "Returns nil when empty" |
| Compatibility | Cross-version compilation | "Works with Swift 6+" |
| Interoperability | Integration test | "Compatible with Foundation.Data" |

### Claim Verification Template

```swift
// MARK: - Claim Verification: {Claim ID}
// Source: {file:line or documentation location}
// Claim: "{exact claim text}"
//
// Verification method: {complexity/conformance/behavior/compatibility/interop}
// Toolchain: {version}
// Result: {VERIFIED/REFUTED - evidence}
// Date: {YYYY-MM-DD}

{verification code}

// --- Evidence ---
// {output or compiler result demonstrating claim}
```

### Example: Complexity Claim

```swift
// MARK: - Claim Verification: CLAIM-001
// Source: Heap.swift documentation
// Claim: "insert(_:) is O(log n)"
//
// Verification method: Benchmark with doubling input sizes
// Toolchain: swift-6.0-RELEASE
// Result: VERIFIED - time roughly doubles when size quadruples
// Date: 2026-01-20

import Foundation

func benchmark(size: Int) -> Double {
    var heap = Heap<Int>()
    let start = CFAbsoluteTimeGetCurrent()
    for i in 0..<size {
        heap.insert(i)
    }
    return CFAbsoluteTimeGetCurrent() - start
}

let sizes = [1000, 4000, 16000, 64000]
for size in sizes {
    let time = benchmark(size: size)
    print("n=\(size): \(String(format: "%.4f", time))s")
}

// --- Evidence ---
// n=1000: 0.0012s
 O(log n) consistent)
 O(log n) consistent)
 O(log n) consistent)
```

### Example: Conformance Claim

```swift
// MARK: - Claim Verification: CLAIM-004
// Source: Heap.swift:12
// Claim: "Heap conforms to Sendable when Element: Sendable"
//
// Verification method: Compile-time conformance check
// Toolchain: swift-6.0-RELEASE
// Result: VERIFIED - compiles without warnings
// Date: 2026-01-20

func requireSendable<T: Sendable>(_ value: T) { }

let heap = Heap<Int>()  // Int: Sendable
 Heap<Int>: Sendable

// --- Evidence ---
// Build Succeeded (no Sendable warnings)
```

**Rationale**: Claims without evidence are assertions. Claims with experiments are documentation. Verified claims build trust; refuted claims prevent bugs.

**Cross-references**: [EXP-013], [EXP-014]

---

## [EXP-016] Boundary Exploration

**Scope**: Testing behavior at edge cases and limits.

**Statement**: Boundary experiments SHOULD test behavior at edge cases including empty states, capacity limits, type extremes, and error conditions.

### Boundary Categories

| Category | Boundaries to Test | Example |
|----------|-------------------|---------|
| Collection size | Empty, one, many, max capacity | `Heap()`, `Heap([1])`, `Heap(0..<Int.max)` |
| Numeric limits | Min, max, overflow, underflow | `Int.min`, `Int.max`, `Int.max + 1` |
| String edge cases | Empty, single char, very long, unicode | `""`, `"a"`, `String(repeating: "x", count: 1_000_000)` |
| Optional states | nil, some | `Optional<Int>.none`, `.some(42)` |
| Error paths | All throwing cases | Each error type from typed throws |
| Concurrency | No contention, high contention | Single thread, 100 concurrent tasks |

### Boundary Exploration Template

```swift
// MARK: - Boundary Exploration: {Boundary Category}
// Purpose: Test behavior at {specific boundary}
// Expected: {expected behavior}
//
// Toolchain: {version}
// Result: {CONFIRMED/UNEXPECTED - description}
// Date: {YYYY-MM-DD}

// --- Boundary: {name} ---
{test code}

// --- Observed ---
// {actual behavior}
```

### Example: Empty State Boundary

```swift
// MARK: - Boundary Exploration: Empty Heap
// Purpose: Test all operations on empty heap
// Expected: No crashes, sensible return values
//
// Toolchain: swift-6.0-RELEASE
// Result: CONFIRMED - all operations handle empty state correctly
// Date: 2026-01-20

var heap = Heap<Int>()

// --- Boundary: count on empty ---
print("count: \(heap.count)")  // Expected: 0

// --- Boundary: isEmpty on empty ---
print("isEmpty: \(heap.isEmpty)")  // Expected: true

// --- Boundary: min on empty ---
print("min: \(heap.min as Any)")  // Expected: nil

// --- Boundary: removeMin on empty ---
print("removeMin: \(heap.removeMin() as Any)")  // Expected: nil

// --- Observed ---
// count: 0
// isEmpty: true
// min: nil
// removeMin: nil
// All boundaries handled correctly ✓
```

### Example: Capacity Boundary

```swift
// MARK: - Boundary Exploration: Large Capacity
// Purpose: Test behavior with very large element count
// Expected: No memory issues, correct behavior
//
// Toolchain: swift-6.0-RELEASE
// Result: CONFIRMED - handles 10M elements correctly
// Date: 2026-01-20

var heap = Heap<Int>()
let count = 10_000_000

for i in 0..<count {
    heap.insert(i)
}

print("count: \(heap.count)")  // Expected: 10_000_000
print("min: \(heap.min!)")     // Expected: 0

// --- Observed ---
// count: 10000000
// min: 0
// Memory usage: ~80MB (8 bytes × 10M)
```

**Rationale**: Bugs cluster at boundaries. Systematic boundary testing catches edge cases that normal usage never exercises.

**Cross-references**: [EXP-013], [EXP-009] (Pattern Experiment.md)

---

## [EXP-017] Improvement Discovery

**Scope**: Using experiments to test potential improvements.

**Statement**: When a potential improvement is identified, an experiment SHOULD be created to test whether the improvement is valid and beneficial.

### Improvement Categories

| Category | What to Test | Measurement |
|----------|--------------|-------------|
| Performance | Alternative algorithm or data structure | Benchmark comparison |
| API ergonomics | Alternative API design | Code sample comparison |
| Memory efficiency | Alternative storage strategy | Memory profiling |
| Code simplification | Alternative implementation | Line count, complexity metrics |
| Feature addition | New capability | Feasibility and integration |

### Improvement Experiment Template

```swift
// MARK: - Improvement Discovery: {Improvement Description}
// Purpose: Test whether {proposed change} improves {metric}
// Hypothesis: {expected improvement}
// Baseline: {current behavior/performance}
//
// Toolchain: {version}
// Result: {BENEFICIAL/NOT BENEFICIAL/MIXED - evidence}
// Date: {YYYY-MM-DD}

// --- Baseline Implementation ---
{current code}

// --- Proposed Implementation ---
{improved code}

// --- Comparison ---
{benchmark or comparison code}

// --- Evidence ---
// Baseline: {measurement}
// Proposed: {measurement}
// Improvement: {percentage or description}
```

### Example: Performance Improvement

```swift
// MARK: - Improvement Discovery: InlineArray for Small Heaps
// Purpose: Test whether InlineArray improves small heap performance
// Hypothesis: Inline storage eliminates allocation for heaps ≤ 8 elements
// Baseline: Always heap-allocated storage
//
// Toolchain: swift-6.0-RELEASE
// Result: BENEFICIAL - 3x faster for small heaps, no regression for large
// Date: 2026-01-20

// --- Baseline: HeapAllocated ---
struct HeapAllocated<Element: Comparable> {
    private var storage: [Element] = []
    mutating func insert(_ element: Element) { /* ... */ }
}

// --- Proposed: InlineOptimized ---
struct InlineOptimized<Element: Comparable> {
    private var inline: InlineArray<8, Element?> = .init(repeating: nil)
    private var overflow: [Element]? = nil
    private var count: Int = 0
    mutating func insert(_ element: Element) { /* ... */ }
}

// --- Comparison ---
func benchmarkSmall<H: HeapProtocol>(_ heap: H.Type) -> Double { /* ... */ }
func benchmarkLarge<H: HeapProtocol>(_ heap: H.Type) -> Double { /* ... */ }

// --- Evidence ---
// Small heap (5 elements), 100K iterations:
//   Baseline: 0.45s
//   Proposed: 0.15s
//   Improvement: 3x faster
//
// Large heap (10K elements), 1K iterations:
//   Baseline: 2.1s
//   Proposed: 2.1s
//   Improvement: No regression
```

### Decision Criteria

| Evidence | Decision |
|----------|----------|
| Significant improvement, no regression | Recommend adoption |
| Marginal improvement, added complexity | Document, defer decision |
| No improvement | Document findings, do not adopt |
| Regression in some cases | Document tradeoffs, require explicit opt-in |

**Rationale**: Experiments provide empirical evidence for or against improvements. This prevents both premature optimization and missed opportunities.

**Cross-references**: [EXP-013], [EXP-015]

---

## Discovery Workflow Summary

```text
┌─────────────────────────────────────────────────────────────┐
│                     DISCOVERY WORKFLOW                       │
└─────────────────────────────────────────────────────────────┘

1. TRIGGER IDENTIFICATION [EXP-012]
   │
   ├─ Package milestone? ───────────────────┐
   ├─ Toolchain update? ────────────────────┤
   ├─ Code review finding? ─────────────────┤
   └─ Improvement hypothesis? ──────────────┘
                                            │
                                            ▼
2. AUDIT METHODOLOGY [EXP-013]
   │
   ├─ Inventory public surface
   ├─ Extract claims [EXP-015]
   ├─ Identify assumptions [EXP-014]
   ├─ Map boundaries [EXP-016]
   └─ Prioritize by risk
                                            │
                                            ▼
3. EXPERIMENT GENERATION
   │
   ├─ Create package per item [EXP-003]
   ├─ Use appropriate template [EXP-010*]
   └─ Document hypothesis and method
                                            │
                                            ▼
4. EXECUTION [EXP-005]
   │
   ├─ Run all experiments
   ├─ Capture verbatim output
   └─ Record results in headers
                                            │
                                            ▼
5. DOCUMENTATION [EXP-006]
   │
   ├─ Update experiment headers
   ├─ Promote significant findings [EXP-006a]
   └─ Update package documentation with evidence
                                            │
                                            ▼
6. ACTION
   │
 Document evidence
 Fix docs or implementation
 Create proposal [EXP-017]
 Create investigation [EXP-001]
```

---

## Topics

### Foundation Document

- <doc:Experiment> — Shared infrastructure for all experiments

### Related Workflow

- <doc:Experiment-Investigation> — Reactive workflow for debugging failures

### Related Documents

- <doc:API-Design> — API design rules and patterns
- <doc:Documentation-Requirements> — Documentation standards
- <doc:Testing-Requirements> — Testing requirements

### Cross-Reference Index

| ID | Title | Focus |
|----|-------|-------|
| EXP-012 | Discovery Triggers | When to create discovery experiments |
| EXP-013 | Package Audit Methodology | Systematic package verification |
| EXP-014 | Assumption Inventory | Identifying implicit assumptions |
| EXP-015 | Claim Verification | Testing explicit claims |
| EXP-016 | Boundary Exploration | Testing edge cases |
| EXP-017 | Improvement Discovery | Testing potential improvements |

