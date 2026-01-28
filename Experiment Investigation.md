# Experiment Investigation

<!--
---
title: Experiment Investigation
version: 2.0.0
last_updated: 2026-01-20
applies_to: [swift-primitives, swift-institute, swift-standards, swift-foundations]
normative: true
llm_optimized: true
---
-->

@Metadata {
    @TitleHeading("Swift Institute")
}

Reactive workflow for creating experiment packages when you encounter failures, unexpected behavior, or technical uncertainty.

## Overview

This document defines the *investigation workflow* for experiment packages—the process you follow when something fails, behaves unexpectedly, or when a technical claim cannot be verified without executing code.

**Entry point**: You hit an error, see unexpected behavior, or need to resolve a technical debate empirically.

**Prerequisite**: Read <doc:Experiment> for package structure, execution protocol, and documentation requirements.

**Applies to**: Debugging failures, resolving technical debates, verifying compiler behavior, isolating root causes.

**Does not apply to**: Proactive package audits or systematic verification—see <doc:Experiment-Discovery> instead.

---

## Quick Reference: When to Create an Investigation Experiment

**Scope**: Decision criteria for creating investigation experiments. See [EXP-001] for the normative rule.

| Trigger | Example | See Also |
|---------|---------|----------|
| Technical debate rests on compiler behavior | "Does `~Copyable` work with `async`?" | [EXP-004a] |
| Documentation conflicts with observed behavior | "The docs say X, but I'm seeing Y" | [EXP-006] (Pattern Experiment.md) |
| Feature availability is uncertain | "Can Embedded Swift use `Sendable`?" | [EXP-010a] (Pattern Experiment.md) |
| Error message is ambiguous | "What exactly triggers this diagnostic?" | [EXP-010c] (Pattern Experiment.md) |
| Behavior differs across configurations | "Does this work in release but not debug?" | [EXP-010d] (Pattern Experiment.md) |
| Multiple interacting features obscure root cause | "Is it the generics, the `~Copyable`, or the `@inlinable`?" | [EXP-004] |
| Production code fails with uncertain cause | "Does this capability even work?" | [EXP-011] |

**Cross-references**: [EXP-001], [API-DESIGN-004] (API Design.md), [API-DESIGN-007] (API Design.md), [PATTERN-023] (Pattern Advanced.md), [DOC-CONTENT-003] (Documentation Requirements.md)

---

## [EXP-001] Investigation Triggers

**Scope**: Conditions that warrant creating an investigation experiment.

**Statement**: An investigation experiment MUST be created when a technical claim cannot be verified without executing code. An investigation experiment SHOULD NOT be created when existing documentation or project code can answer the question.

**Correct**:
```text
Claim: "~Copyable types cannot conform to Sendable"
Action: Create Experiments/noncopyable-sendable-test/ to verify
Result: Empirical answer with compiler output
```

**Incorrect**:
```text
Claim: "What is the syntax for typed throws?"
Action: Create experiment package
Result: Wasted effort—documentation answers this directly
```

### Trigger Categories

| Category | Description | Action |
|----------|-------------|--------|
| Compiler behavior uncertainty | "Does X compile?" | Create experiment |
| Documentation contradiction | "Docs say X, I see Y" | Create experiment |
| Feature interaction | "Do A and B work together?" | Create experiment |
| Error diagnosis | "What causes this error?" | Create experiment |
| Syntax question | "What's the syntax for X?" | Read documentation first |
| API lookup | "What method does Y?" | Read documentation first |

**Rationale**: Experiment packages require setup time. Reserve them for questions where documentation is insufficient, ambiguous, or contradicted by observation.

**Cross-references**: [API-DESIGN-004] (API Design.md), [DOC-CONTENT-003] (Documentation Requirements.md)

---

## [EXP-004] Reduction Methodology

**Scope**: Process for minimizing code to isolate behavior.

**Statement**: Code MUST be reduced until removing any single element would eliminate the behavior being tested.

### Reduction Steps

| Step | Action | Verification |
|------|--------|--------------|
| 1 | Start with failing/interesting code | Confirm behavior exists |
| 2 | Remove imports not required | Behavior still present |
| 3 | Remove types not involved | Behavior still present |
| 4 | Inline function calls | Behavior still present |
| 5 | Remove properties/methods not exercised | Behavior still present |
| 6 | Simplify type hierarchies | Behavior still present |
| 7 | Remove generic parameters if possible | Behavior still present |

**Correct**:
```swift
// Testing: Does ~Copyable work with typed throws?

struct Resource: ~Copyable {
    consuming func use() throws(SimpleError) { }
}

enum SimpleError: Error { case failed }

func test() throws(SimpleError) {
    let r = Resource()
    try r.use()
}
```

**Incorrect**:
```swift
// Not minimal—includes unrelated complexity

import Foundation  // Not needed for the test

struct Resource: ~Copyable, CustomStringConvertible {  // CustomStringConvertible irrelevant
    let id: UUID       // Not exercised
    let name: String   // Not exercised
    var description: String { "Resource(\(name))" }  // Not exercised

    init(name: String) {
        self.id = UUID()
        self.name = name
    }

    consuming func use() throws(ResourceError) {
        print("Using \(self)")  // Adds complexity
    }
}

enum ResourceError: Error, LocalizedError {  // LocalizedError irrelevant
    case notFound      // Not used
    case accessDenied  // Not used
    case timeout(seconds: Int)  // Not used

    var errorDescription: String? { nil }  // Not exercised
}
```

**Rationale**: Minimal reproductions isolate the exact cause. Extra code creates uncertainty about which element triggers the behavior.

**Cross-references**: [PATTERN-023] (Pattern Advanced.md), [API-DESIGN-004] (API Design.md)

---

## [EXP-004a] Incremental Construction Methodology

**Scope**: Building up complexity to find where behavior changes.

**Statement**: When investigating a hypothesis without existing failing code, complexity SHOULD be added incrementally—one feature at a time—until the behavior under test appears.

This is the inverse of [EXP-004] Reduction Methodology. Reduction starts from complex failing code and strips it down. Incremental construction starts from the simplest possible case and builds up.

### Construction Steps

| Step | Action | Verification |
|------|--------|--------------|
| 1 | Implement simplest possible case | Confirm expected behavior |
| 2 | Add one feature | Still works? Continue. Fails? Trigger found. |
| 3 | Add next feature | Still works? Continue. Fails? Trigger found. |
| n | Continue until failure or complete | Failure point identifies trigger |

**Correct**:
```text
Hypothesis: "~Copyable doesn't work with value generics in nested types"

Test progression:
1. Simplest nested type with value generic -> passed
2. Add InlineArray storage -> passed
3. Add deinit -> passed
4. Add @inlinable annotations -> passed
5. Add public access modifier -> passed
6. Switch from inline declaration to extension declaration -> FAILED

Conclusion: Extension declaration site is the trigger, not value generics
```

**Incorrect**:
```text
Test: Copy entire production struct with all 15 features
Result: Fails with "type 'X' does not conform to 'Copyable'"
Conclusion: "Something about ~Copyable doesn't work" — No isolation
```

### When to Use Construction vs Reduction

| Situation | Methodology |
|-----------|-------------|
| Existing code fails with unclear cause | [EXP-004] Reduction |
| Testing a hypothesis about compiler capability | [EXP-004a] Construction |
| Production code has 100+ lines of interacting features | [EXP-004a] Construction (don't port complexity) |
| Minimal reproduction already exists | [EXP-004] Reduction (if still too complex) |

### Context-Sensitive Bugs: When All Experiments Pass

Sometimes all experiment variants pass while production fails. This paradox indicates a **context-sensitive bug**—one that requires the **interaction** of multiple factors, not any single factor in isolation.

**Example**:

| Variant | Configuration | Result |
|---------|---------------|--------|
| V1 | Empty enum, cross-module storage | PASS |
| V2 | Struct with no stored properties | PASS |
| V3 | Struct with unrelated property (Int) | PASS |
| V4 | Struct with Storage class | PASS |
| V5 | Nested type in extension | PASS |
| V6 | Nested type in body | PASS |
| V7 | Intermediate local wrapper | PASS |
| V8 | @_exported import | PASS |

When all pass but production fails, the bug requires the **combination** of factors present in production. The experiments proved that no single factor causes the bug—only their interaction does.

**Guidance**:

1. **Minimal reproductions can be TOO minimal**. Sometimes you need to reproduce the structural complexity, not just the specific pattern.

2. **When experiments pass but production fails**, the bug is likely context-sensitive. Look at what the production code has that the experiment lacks.

3. **Document what the experiments PROVED**, not just what they tested. "All individual factors pass" is valuable information—it proves the bug is combinatorial.

4. **Experiments that "fail to reproduce" are still valuable**. They narrow the search space and eliminate hypotheses.

**Rationale**: Production code often has dozens of interacting features. Debugging by removal is O(n) bisection; construction from scratch isolates the trigger in O(1) to O(n) additions, often finding it much faster.

**Cross-references**: [EXP-004], [EXP-011]

---

## [EXP-011] Experiment-First Debugging

**Scope**: Debugging production code failures through isolated experimentation.

**Statement**: When production code fails and the cause is uncertain, an experiment package SHOULD be created to verify the capability works in isolation BEFORE debugging the production code.

### The Experiment-First Sequence

| Step | Action | Outcome |
|------|--------|---------|
| 1 | Identify uncertainty | "Can X work at all?" |
| 2 | Create minimal experiment | Proves positive case in isolation |
| 3 | Run experiment | Success -> capability works; Failure -> stop here |
| 4 | Apply to production | Make equivalent change |
| 5 | If production fails | Compare experiment vs production to find delta |

**Correct**:
```text
Production fails with: "type 'Element' does not conform to 'Copyable'"
after adding `throws(Container<Element>.Error)` to a method.

Step 1: "Can typealiases be used in typed throws at all?"
Step 2: Create Experiments/typed-throws-test/ with minimal typealias + throws
Step 3: Experiment compiles -> typealiases work
Step 4: Return to production
Step 5: Compare extensions -> production lacks `where Element: ~Copyable`
```

**Incorrect**:
```text
Production fails with: "type 'Element' does not conform to 'Copyable'"
Reaction: "Typealiases must not work in typed throws. Use hoisted type directly."
— Wrong conclusion from insufficient evidence
```

### Why This Works

When the experiment succeeds but production fails, the failure is in the **delta** between experiment and production—not in the fundamental capability. This narrows the search space from "everything about the feature" to "what's different between working and failing code."

The upfront time cost (creating the experiment) is repaid many times over by avoiding misdirected debugging.

### The Workaround Validation Trap

Minimal reproductions can validate that a bug exists. They CANNOT validate that a workaround will work at scale.

**Example**:
```swift
// Minimal reproduction: workaround compiles
// Container.swift
struct Container<Element: ~Copyable & Ordering>: ~Copyable {
    struct Bounded: ~Copyable { ... }
}
extension Container.Bounded: Sequence where Element: Copyable { ... }

// In SAME file (workaround):
extension Container.Bounded where Element: ~Copyable {
    func withMin<R>(_ body: (borrowing Element) -> R) -> R? { ... }
}
```

This workaround compiles in isolation. But applying it to the full production codebase fails with the same error. The minimal reproduction has:
- 2 source files, one nested type, simple storage, one borrowing method

The production code has:
- 12 source files, multiple nested types, ManagedBuffer inheritance, extensive pointer manipulation, multiple extension files

The complexity difference triggers different compiler behavior.

**Guidance for workaround validation**:

1. **Don't trust minimal reproductions for workaround validation**. They validate that the bug exists; they don't validate that a workaround works at scale.

2. **Test workarounds in the actual codebase**. The only reliable test is applying the change and running the full build.

3. **When a workaround fails unexpectedly**, the production code has structural properties the reproduction lacks. Ask: what does the real code have that the test code doesn't?

4. **Document both successes and failures**. The failed workaround attempt is valuable information. It narrows the solution space for future attempts.

**Rationale**: Experiments prove positive cases quickly. Debugging production without knowing if the capability works at all leads to false conclusions about language limitations.

**Cross-references**: [EXP-001], [EXP-004a]

---

## Case Study: Heap Module Emission Bug

This case study demonstrates the methodology in action, showing how systematic experiments transformed an opaque compiler error into a documented bug with working workaround.

**Initial state**: swift-heap-primitives fails with "type 'Element' does not conform to protocol 'Copyable'" when enabling Sequence conformance.

**Investigation sequence**:

| Step | Method | Question | Answer |
|------|--------|----------|--------|
| 1 | [EXP-002] Package | Reproduce in isolation | Minimal package created |
| 2 | [EXP-004] Binary search | Which code block triggers? | Sequence conformance |
| 3 | [EXP-004] Binary search | Which condition? | `borrowing Element` closures |
| 4 | [EXP-004a] Construction | Does same-file fix it? | Yes (in isolation) |
| 5 | [EXP-011] Production | Does that fix work at scale? | No |
| 6 | [EXP-004a] Construction | Does single-file fix it? | Yes (in production) |

**Outcome**: 6 trigger conditions isolated, Swift issue #86669 filed, single-file workaround implemented.

**Key insight**: The methodology turned a multi-day investigation into focused questions answered sequentially. Each experiment eliminated hypotheses or confirmed conditions.

---

## Investigation Workflow Summary

```text
+-------------------------------------------------------------+
|                    INVESTIGATION WORKFLOW                    |
+-------------------------------------------------------------+

1. TRIGGER IDENTIFICATION
   |
   +- Production failure? ------------------+
   +- Technical debate? --------------------+
   +- Documentation contradiction? ---------+
   +- Feature interaction question? --------+
                                            |
                                            v
2. TRIAGE [EXP-002a]
   |
   +- Package-specific? -> {package}/Experiments/
   +- Ecosystem-wide? ---> swift-institute/.../Experiments/
                                            |
                                            v
3. EXPERIMENT CREATION
   |
   +- Create package structure [EXP-003]
   +- Write Package.swift [EXP-003a]
   +- Write main.swift with header [EXP-003b]
                                            |
                                            v
4. METHODOLOGY SELECTION
   |
   +- Have failing code? -----> Reduction [EXP-004]
   +- Testing hypothesis? ----> Construction [EXP-004a]
                                            |
                                            v
5. EXECUTION [EXP-005]
   |
   +- swift package clean
   +- swift build 2>&1 | tee build-output.txt
   +- Record verbatim output
                                            |
                                            v
6. DOCUMENTATION [EXP-006]
   |
   +- Update main.swift header with result
   +- Record CONFIRMED/REFUTED + evidence
   +- Promote to docs if significant [EXP-006a]
```

---

## Topics

### Foundation Document

- <doc:Experiment> — Shared infrastructure for all experiments

### Related Workflow

- <doc:Experiment-Discovery> — Proactive package audit workflow

### Related Documents

- <doc:Design> — API design rules and patterns
- <doc:Documentation-Requirements> — Documentation standards
- <doc:Implementation> — Implementation patterns index

### Cross-Reference Index

| ID | Title | Focus |
|----|-------|-------|
| EXP-001 | Investigation Triggers | When to create investigation experiments |
| EXP-004 | Reduction Methodology | Code minimization |
| EXP-004a | Incremental Construction Methodology | Building up complexity |
| EXP-011 | Experiment-First Debugging | Isolation before debugging |
