# Experiment

@Metadata {
    @TitleHeading("Swift Institute")
}

Foundation infrastructure for creating experiment packages—isolated Swift packages that verify compiler behavior, test hypotheses, and document empirical findings.

## Overview

This document defines the shared infrastructure for *experiment packages*—isolated Swift packages in dedicated `Experiments/` directories that reduce a question or issue to its core, enabling empirical verification of compiler behavior, runtime semantics, or language mechanics. Experiments are git-tracked, preserving institutional knowledge for collaboration and historical reference.

### Document Family

This is the **foundation document** for experiment packages. Two companion documents define specific workflows:

| Document | Purpose | Entry Point |
|----------|---------|-------------|
| <doc:Experiment> | Shared infrastructure (this document) | — |
| <doc:Experiment-Investigation> | Reactive workflow | Something failed or behaves unexpectedly |
| <doc:Experiment-Discovery> | Proactive workflow | Audit a package, verify assumptions, find improvements |

**Routing guidance**:
 Start with <doc:Experiment-Investigation>
 Start with <doc:Experiment-Discovery>
- Both workflows use the infrastructure defined here

### Normative Precedence

Experiment.md is canonical for shared infrastructure. The workflow documents (Investigation, Discovery) may restate rules for context but MUST NOT diverge. If conflict exists, this document governs.

### Rule Numbering Scheme

Rule IDs are partitioned across the document family:

| Document | Reserved Range | Focus |
|----------|---------------|-------|
| Pattern Experiment (this document) | EXP-002 – EXP-010 | Shared infrastructure |
| Pattern Experiment Investigation | EXP-001, EXP-004, EXP-011 | Reactive triggers and methodology |
| Pattern Experiment Discovery | EXP-012 – EXP-017 | Proactive triggers and methodology |

Future rules MUST use IDs from the appropriate range. Do not reassign existing IDs.

### Experiment vs Unit Test

Before creating an experiment, determine whether a unit test is more appropriate. Use unit tests for verifying your implementation works correctly. Use experiments for verifying Swift compiler/language capabilities exist.

**Decision tree**:

```text
What are you testing?
 Unit Test
 Unit Test
 Experiment
 Experiment
 Experiment
 Experiment
```

**Examples**:

| Scenario | Choice | Reason |
|----------|--------|--------|
| "Does Heap.insert maintain heap property?" | Unit Test | Testing your implementation |
| "Does ~Copyable work with typed throws?" | Experiment | Testing Swift capability |
| "Does my Sendable conformance compile?" | Unit Test | Testing your code compiles |
| "Can ANY ~Copyable type conform to Sendable?" | Experiment | Testing language semantics |
| "Regression: bug #123 stays fixed" | Unit Test | Ongoing CI guard |
| "Swift 6.2 snapshot: does X link?" | Experiment | Toolchain-specific verification |

**Key differences**:

| Aspect | Unit Test | Experiment |
|--------|-----------|------------|
| Subject | Your code | Swift compiler/language |
| Runs on CI | Every build | One-time or manual |
| Compile failure means | Broken code | Often the answer itself |
| Toolchain variance | Should pass on all supported | May vary by version |
| Lifecycle | Ongoing regression guard | Point-in-time verification |

See <doc:Testing-Requirements> for unit test organization patterns.

---

## [EXP-002] Package Location Convention

**Scope**: File system location for experiment packages.

**Statement**: Experiment packages MUST be created in an `Experiments/` directory with a descriptive, kebab-case name indicating the topic being investigated. The location depends on the experiment's scope (see [EXP-002a]).

### Experiment Directory Locations

| Scope | Location Pattern | Example |
|-------|------------------|---------|
| Package-specific | `{package-repo}/Experiments/` | `swift-heap-primitives/Experiments/` |
| Ecosystem-wide | `swift-institute/.docc/Experiments/` | `swift-institute/Sources/Swift Institute/Swift Institute.docc/Experiments/` |

### Package-Specific Locations

Package-specific experiments go in the `Experiments/` directory at the root of the relevant package repository:

```text
swift-heap-primitives/Experiments/
swift-buffer-primitives/Experiments/
swift-rfc-4122/Experiments/
swift-file/Experiments/
```

### Ecosystem-Wide Location

Ecosystem-wide experiments go in the documentation catalog:

```text
swift-institute/Sources/Swift Institute/Swift Institute.docc/Experiments/
```

**Correct**:
```text
swift-primitives/Experiments/sendable-closure-test/
swift-primitives/Experiments/noncopyable-deinit-order/
swift-institute/.../Experiments/embedded-async-verification/
swift-institute/.../Experiments/cross-package-isolation-test/
```

**Incorrect**:
```text
/tmp/sendable-closure-test/     ❌ Ephemeral—lost on reboot
~/Developer/test/               ❌ Not in Experiments/—pollutes workspace
Experiments/test/               ❌ Non-descriptive—cannot identify later
Experiments/MyTest/             ❌ Not kebab-case—inconsistent naming
Experiments/t1/                 ❌ Cryptic—no indication of purpose
```

**Rationale**: Experiments have lasting value for reference, collaboration, and historical record. Placing them in dedicated `Experiments/` directories preserves this value while keeping them organized. Nested packages with their own `Package.swift` are invisible to SPM dependency resolution—consumers are unaffected.

**Cross-references**: [EXP-002a], [EXP-008]

---

## [EXP-002a] Experiment Triage

**Scope**: Deciding where to place an experiment package.

**Statement**: Before creating an experiment, determine whether it is package-specific or ecosystem-wide. This decision determines the experiment's location.

### Triage Decision Tree

```text
Is this experiment about behavior specific to one package?
 Place in {package-repo}/Experiments/
│        Examples:
│        • Testing swift-heap-primitives' ~Copyable interaction
│        • Verifying swift-rfc-4122's typed throws behavior
│        • Debugging swift-file's async implementation
│
 Place in swift-institute/.../Experiments/
        Examples:
        • Cross-package interaction testing
        • General Swift compiler behavior
        • Embedded Swift capabilities
        • Language feature exploration
        • Patterns applicable across multiple packages
```

### Decision Criteria

| Criterion | Package-Specific | Ecosystem-Wide |
|-----------|------------------|----------------|
| Involves types from one package | ✓ | |
| Tests general Swift behavior | | ✓ |
| Reproduces bug in specific module | ✓ | |
| Explores language feature broadly | | ✓ |
| Result affects one package's implementation | ✓ | |
| Result informs architecture decisions | | ✓ |
| Tests cross-package interactions | | ✓ |

**Correct**:
```text
Question: "Does Heap's deinit order work with ~Copyable?"
Decision: Package-specific (Heap is in swift-heap-primitives)
Location: swift-heap-primitives/Experiments/heap-deinit-order/

Question: "Can #isolation be used in Embedded Swift?"
Decision: Ecosystem-wide (affects all packages, general Swift behavior)
Location: swift-institute/.../Experiments/embedded-isolation-test/

Question: "How do swift-buffer-primitives types interact with swift-rfc-4122 protocols?"
Decision: Ecosystem-wide (cross-package interaction)
Location: swift-institute/.../Experiments/buffer-rfc4122-interaction/
```

**Incorrect**:
```text
Question: "Does Heap's deinit order work with ~Copyable?"
Decision: Ecosystem-wide  ❌ This is specific to one package

Question: "Can Sendable closures be used in Embedded Swift?"
Decision: Package-specific (put in swift-heap-primitives)  ❌ General Swift behavior
```

**Rationale**: Proper triage ensures experiments are discoverable by developers working in the relevant context. Package-specific experiments stay with the package; broadly applicable findings go to the central documentation.

**Cross-references**: [EXP-002], [EXP-006a]

---

## [EXP-002b] Package Isolation

**Scope**: SPM isolation of experiment packages from parent repositories.

**Statement**: Each experiment directory MUST contain its own `Package.swift`. The parent package MUST NOT reference experiments as targets, products, or dependencies.

**Correct**:
```text
swift-heap-primitives/
├── Package.swift              # Parent package—no reference to Experiments/
├── Sources/
├── Tests/
└── Experiments/
    └── heap-deinit-order/
        ├── Package.swift      # Experiment's own manifest
        └── Sources/
            └── main.swift
```

**Incorrect**:
```swift
// Parent Package.swift
let package = Package(
    name: "swift-heap-primitives",
    targets: [
        .executableTarget(
            name: "heap-deinit-order",
            path: "Experiments/heap-deinit-order/Sources"  // ❌ Referencing experiment
        )
    ]
)
```

**Caution**: If your repository uses custom scripts for workspace or test discovery, ensure they exclude `Experiments/` directories.

**Rationale**: Experiment packages are nested packages invisible to SPM dependency resolution. This isolation ensures consumers of the parent package are unaffected by experiments, and experiments can use different Swift tools versions or settings than the parent.

**Cross-references**: [EXP-002], [EXP-003]

---

## [EXP-003] Minimal Package Structure

**Scope**: Required files and directory layout for experiment packages.

**Statement**: Experiment packages MUST contain the minimum structure required to verify the behavior in question. Dependencies beyond what is being tested MUST NOT be included.

### Directory Structure

**Correct**:
```text
Experiments/sendable-closure-test/
├── Package.swift
└── Sources/
    └── main.swift
```

**Incorrect**:
```text
Experiments/sendable-closure-test/
├── Package.swift
├── Sources/
│   ├── main.swift
│   ├── Helpers.swift        ❌ Unnecessary file
│   └── Extensions.swift     ❌ Unnecessary file
├── Tests/                   ❌ Unnecessary directory
└── README.md                ❌ Unnecessary file
```

**Rationale**: Minimal structure reduces variables. Every additional file is a potential source of confusion about what the experiment actually tests.

**Cross-references**: [EXP-003a], [EXP-003b]

---

## [EXP-003a] Package.swift Template

**Scope**: Standard Package.swift content for experiment packages.

**Statement**: The Package.swift file MUST specify only the minimum configuration required for the experiment. Experiments MUST use Swift 6.2 and v26 platforms (macOS v26, iOS v26, watchOS v26, tvOS v26, visionOS v26).

**Correct**:
```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "sendable-closure-test",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "sendable-closure-test",
            swiftSettings: [
                // Only include flags being tested:
                // .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
```

**Incorrect**:
```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "sendable-closure-test",
    platforms: [.macOS(.v26), .iOS(.v26), .watchOS(.v26)],  // ❌ Unnecessary platforms
    products: [
        .library(name: "SendableClosureTest", targets: ["sendable-closure-test"]),  // ❌ Unnecessary product
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),  // ❌ Unnecessary dependency
    ],
    targets: [
        .executableTarget(
            name: "sendable-closure-test",
            dependencies: [.product(name: "Collections", package: "swift-collections")],  // ❌ Unnecessary
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableExperimentalFeature("Lifetimes"),  // ❌ Include only if being tested
            ]
        )
    ]
)
```

**Rationale**: Extra configuration obscures what is being tested and can introduce confounding variables.

**Cross-references**: [EXP-003], [EXP-003b]

---

## [EXP-003b] main.swift Template

**Scope**: Standard main.swift header format for experiment packages.

**Statement**: The main.swift file MUST include a header comment documenting the experiment's purpose, hypothesis, and results.

**Correct**:
```swift
// MARK: - Sendable Closure Verification
// Purpose: Verify @Sendable closures compile in Embedded Swift
//
// Hypothesis: @Sendable attribute is available without runtime
// Test: Declare and use @Sendable closure
//
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-01-18-a
// Platform: macOS 15.0 (arm64)
//
// Result: CONFIRMED - compiles and links successfully
// Date: 2026-01-19

func takeSendableClosure(_ closure: @Sendable () -> Int) -> Int {
    return closure()
}

let result = takeSendableClosure { 42 }
print(result)  // Output: 42
```

**Incorrect**:
```swift
// Test file  ❌ No purpose stated

func takeSendableClosure(_ closure: @Sendable () -> Int) -> Int {
    return closure()
}

let result = takeSendableClosure { 42 }
print(result)
// ❌ No hypothesis, no toolchain, no result recorded
```

**Rationale**: The header makes experiments self-documenting. Without it, revisiting the package later requires re-inferring what was being tested.

**Cross-references**: [EXP-005], [EXP-006]

---

## [EXP-003c] Output Artifacts

**Scope**: Handling of build and execution output files.

**Statement**: Output artifacts are ephemeral by default. During execution, outputs SHOULD be captured to support debugging. Output files MUST NOT be committed unless the header excerpt is insufficient to document the result.

### Output File Policy

| Rule | Requirement |
|------|-------------|
| Capture during execution | SHOULD (use `tee` to preserve diagnostics) |
| Commit to repository | MUST NOT by default |
| Commit exception | MAY commit when header excerpt is insufficient (multi-page diagnostics, benchmark tables, traces) |
| Location if committed | MUST use `Outputs/` directory |
| Repository hygiene | `Outputs/` SHOULD be git-ignored at repository level |

### Stable Output Names

If outputs are committed, they MUST use these stable names:

| File | Purpose |
|------|---------|
| `Outputs/build.txt` | Standard debug build output |
| `Outputs/build-release.txt` | Release build output |
| `Outputs/run.txt` | Runtime execution output |
| `Outputs/build-embedded.txt` | Embedded Swift build output |

**Correct**:
```text
Experiments/sendable-closure-test/
├── Package.swift
├── Sources/
│   └── main.swift           # Header contains result + key diagnostic
└── Outputs/                 # Only if header excerpt insufficient
    └── build.txt            # Committed with justification in header
```

**Incorrect**:
```text
Experiments/sendable-closure-test/
├── Package.swift
├── Sources/
│   └── main.swift
├── build-output.txt         # ❌ Not in Outputs/
├── my-log.txt               # ❌ Non-standard name
└── Outputs/
    └── debug-2026-01-20.txt # ❌ Non-standard name with date
```

### Git Ignore Guidance

Add to repository `.gitignore`:

```gitignore
# Experiment outputs (ephemeral by default)
**/Experiments/*/Outputs/
```

When committing outputs is warranted, use `git add -f` to override.

**Rationale**: Outputs are working artifacts, not primary evidence. The main.swift header is the institutional record. Keeping outputs ephemeral by default maintains minimality while allowing escalation when complex diagnostics require preservation.

**Cross-references**: [EXP-003], [EXP-005], [EXP-006]

---

## [EXP-003d] Naming Alignment

**Scope**: Consistency between directory name, package name, and target name.

**Statement**: The experiment directory name, `Package.name`, and executable target name MUST be identical unless a different module name is justified in the header.

**Correct**:
```text
Directory: Experiments/sendable-closure-test/
```

```swift
// Package.swift
let package = Package(
    name: "sendable-closure-test",        // ✓ Matches directory
    targets: [
        .executableTarget(
            name: "sendable-closure-test" // ✓ Matches package name
        )
    ]
)
```

**Incorrect**:
```text
Directory: Experiments/sendable-closure-test/
```

```swift
// Package.swift
let package = Package(
    name: "SendableClosureTest",          // ❌ Doesn't match directory
    targets: [
        .executableTarget(
            name: "test"                  // ❌ Doesn't match package name
        )
    ]
)
```

**Exception**: If a different module name is required (e.g., testing module name conflicts), document the reason in the main.swift header.

**Rationale**: Naming alignment eliminates a class of confusion. When directory, package, and target share one name, navigation and tooling work predictably.

**Cross-references**: [EXP-002], [EXP-003], [EXP-003a]

---

## [EXP-003e] Experiment Index

**Scope**: Discoverability of experiments within a repository.

**Statement**: If `Experiments/` contains two or more experiment directories, `Experiments/_index.md` MUST exist. If `Experiments/` contains exactly one experiment, `_index.md` SHOULD exist. `_index.md` is the only allowed non-experiment file under `Experiments/`.

### Index Format

The index MUST contain a table with these minimum fields:

| Field | Description |
|-------|-------------|
| Directory | Experiment directory name |
| Purpose | One-line description |
| Date | Date last run |
| Toolchain | Toolchain used |
| Status | CONFIRMED / REFUTED / SUPERSEDED |

**Correct**:
```markdown
# Experiments Index

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| heap-deinit-order | Verify ~Copyable deinit ordering | 2026-01-18 | Swift 6.0 | CONFIRMED |
| heap-noncopyable-generics | Test value generics with ~Copyable | 2026-01-19 | Swift 6.0 | REFUTED |
| heap-sendable-conformance | Verify conditional Sendable | 2026-01-20 | Swift 6.0 | CONFIRMED |
```

**Incorrect**:
```text
Experiments/
├── README.md                    # ❌ Wrong filename
├── heap-deinit-order/
└── heap-noncopyable-generics/
```

```text
Experiments/
├── _index.md                    # File exists but...
└── heap-deinit-order/           # ❌ Only one experiment—index is SHOULD, not violated
```

**Rationale**: As experiments accumulate, discoverability degrades without an index. The threshold of two experiments balances minimal bureaucracy against practical navigation needs.

**Cross-references**: [EXP-002], [EXP-008]

---

## [EXP-005] Execution Protocol

**Scope**: Commands for building and testing experiment packages.

**Statement**: Experiment packages MUST be built using standard commands with output captured verbatim. Output files are ephemeral by default (see [EXP-003c]).

### Standard Build

**Correct**:
```bash
cd Experiments/sendable-closure-test
mkdir -p Outputs
swift package clean
swift build 2>&1 | tee Outputs/build.txt
```

**Incorrect**:
```bash
cd Experiments/sendable-closure-test
swift build  # ❌ Output not captured
# "It compiled" ❌ Paraphrased result, not verbatim
```

### Release Build (for optimization-dependent behavior)

```bash
swift build -c release 2>&1 | tee Outputs/build-release.txt
```

### Runtime Test

```bash
swift run 2>&1 | tee Outputs/run.txt
```

### Embedded Swift Build

```bash
/path/to/swift-DEVELOPMENT-SNAPSHOT-*/usr/bin/swift build \
  -Xswiftc -enable-experimental-feature -Xswiftc Embedded \
  -Xswiftc -wmo \
  -c release \
  2>&1 | tee Outputs/build-embedded.txt
```

**Note**: Output files captured via `tee` are working artifacts for debugging. They are NOT committed by default. The main.swift header is the primary evidence record. See [EXP-003c] for when to commit outputs.

**Rationale**: Verbatim output enables reproducibility. Paraphrased results lose diagnostic details that may be significant.

**Cross-references**: [EXP-003c], [EXP-006], [EXP-007]

---

## [EXP-006] Result Documentation

**Scope**: Recording experiment outcomes.

**Statement**: Experiment results MUST be documented in the main.swift header comment immediately after execution. Significant findings SHOULD be promoted to authoritative documentation.

### Result Categories

| Outcome | Action |
|---------|--------|
| Hypothesis confirmed | Update header with `Result: CONFIRMED` + evidence (see [EXP-006b]) |
| Hypothesis refuted | Update header with `Result: REFUTED` + primary diagnostic |
| Unexpected behavior | Update header, consider filing bug report |
| Compiler limitation | Update header, reference in relevant docs |

### Diagnostic Requirements for REFUTED Results

If `Result: REFUTED` or unexpected behavior, the header MUST include:

1. The **primary diagnostic line(s)** — the first line that identifies the failing subsystem (compiler error headline, linker error, runtime exception)
2. The **command that produced it** — so the diagnostic can be reproduced
3. A **pointer to full output** — only if output is committed per [EXP-003c]

**Correct**:
```swift
// MARK: - Isolation Parameter Test
// Purpose: Test #isolation macro in Embedded Swift
//
// Hypothesis: #isolation compiles in Embedded mode
// Result: REFUTED - links fail with undefined symbol swift_task_isCurrentExecutor
// Date: 2026-01-18
//
// Command: swift build -c release 2>&1
// Primary Diagnostic:
// Undefined symbols for architecture arm64:
//   "_swift_task_isCurrentExecutor", referenced from: ...
```

**Incorrect**:
```swift
// MARK: - Isolation Parameter Test
// Purpose: Test #isolation macro in Embedded Swift
//
// Result: Didn't work  ❌ Vague—no specific error recorded
// ❌ No date, no command, no diagnostic
```

```swift
// Result: REFUTED - see Outputs/build.txt  ❌ No inline diagnostic
```

**Rationale**: Precise documentation enables others to understand findings without re-running experiments. The header must be self-contained; output files are supplementary.

**Cross-references**: [EXP-006a], [EXP-006b], [EXP-003b], [EXP-003c], [DOC-CONTENT-003] (Documentation Requirements.md)

---

## [EXP-006a] Documentation Promotion

**Scope**: Elevating significant findings to authoritative documentation.

**Statement**: When experiment results reveal behavior that affects Swift Institute packages, findings MUST be promoted to the relevant documentation in `swift-institute/Sources/Swift Institute/Swift Institute.docc/`.

### Promotion Template

**Correct**:
```markdown
### [EMB-CONC-003] Isolation Parameter Availability

**Scope**: `#isolation` macro in Embedded Swift.

**Statement**: The `#isolation` macro compiles but fails to link in Embedded Swift on macOS and ARM targets.

| Code | Result |
|------|--------|
| `func f(isolation: isolated (any Actor)?)` | Links successfully |
| `#isolation` macro | Linker error: `swift_task_isCurrentExecutor` undefined |

Test package: `swift-institute/.../Experiments/isolation-embedded-test/`
Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-01-18-a
Date: 2026-01-18
```

**Incorrect**:
```markdown
### Isolation doesn't work

The #isolation thing doesn't work in Embedded.  ❌ No rule ID
❌ No test package reference
❌ No toolchain version
❌ No date
```

**Rationale**: Promoted documentation enables others to benefit from findings without repeating experiments.

**Cross-references**: [EXP-006], [DOC-CONTENT-003] (Documentation Requirements.md), [DOC-CONTENT-004] (Documentation Requirements.md)

---

## [EXP-006b] Confirmation Evidence

**Scope**: Required evidence for confirmed experiments.

**Statement**: If `Result: CONFIRMED`, the header MUST include at least one form of concrete evidence. A bare "CONFIRMED" without evidence is insufficient.

### Required Evidence (at least one)

| Evidence Type | Example |
|---------------|---------|
| Output snippet | `// Output: 42` |
| Measured value | `// Time: 0.003s for 1000 iterations` |
| Compile-time proof | `// Build Succeeded (type-check passed with signature X)` |

**Correct**:
```swift
// MARK: - Sendable Closure Verification
// Purpose: Verify @Sendable closures compile in Embedded Swift
//
// Hypothesis: @Sendable attribute is available without runtime
// Result: CONFIRMED - compiles and links successfully
// Date: 2026-01-19
//
// Evidence: Build Succeeded, executable runs without error
// Output: 42
```

```swift
// MARK: - Heap Insert Performance
// Purpose: Verify insert is O(log n)
//
// Hypothesis: Doubling n increases time by constant factor
// Result: CONFIRMED
// Date: 2026-01-20
//
// Evidence:
// n=1000: 0.0012s
// n=4000: 0.0028s (2.3x for 4x size)
// n=16000: 0.0065s (2.3x for 4x size)
```

**Incorrect**:
```swift
// Result: CONFIRMED  ❌ No evidence provided
```

```swift
// Result: CONFIRMED - it worked  ❌ "it worked" is not evidence
```

**Rationale**: "CONFIRMED" without evidence provides no institutional value. Future readers cannot distinguish a rigorous confirmation from a casual "it seemed to work."

**Cross-references**: [EXP-006], [EXP-003b]

---

## [EXP-007] Toolchain Specification

**Scope**: Recording toolchain versions for reproducibility.

**Statement**: Experiment results MUST record the exact toolchain used. Development snapshot results MUST include the snapshot date.

### Determining Toolchain

```bash
# Standard toolchain
swift --version
# Swift version 6.0 (swift-6.0-RELEASE)

# Development snapshot
/Users/coen/Library/Developer/Toolchains/swift-DEVELOPMENT-SNAPSHOT-2026-01-18-a.xctoolchain/usr/bin/swift --version
# Swift version 6.2-dev (LLVM ..., Swift ...)
```

**Correct**:
```swift
// Toolchain: swift-DEVELOPMENT-SNAPSHOT-2026-01-18-a
// Platform: macOS 15.0 (arm64)
// Xcode: 16.2
```

**Incorrect**:
```swift
// Toolchain: latest  ❌ Not reproducible
// Toolchain: development snapshot  ❌ Which snapshot?
// ❌ No platform specified
```

**Rationale**: Swift behavior changes between releases. Without toolchain version, results cannot be reproduced or validated.

**Cross-references**: [EXP-005], [EXP-006]

---

## [EXP-008] Experiment Package Lifecycle

**Scope**: Managing experiment packages over time.

**Statement**: Experiments are persistent and git-tracked. They serve as a living reference for the team and future contributors.

### Lifecycle Stages

| Stage | Duration | Action |
|-------|----------|--------|
| Active | During investigation | Iterate on code, record results in main.swift header |
| Documented | After conclusion | Finalize main.swift header with results, commit |
| Referenced | Ongoing | Available for future reference, reproduction, extension |
| Superseded | When obsolete | Add note to header indicating superseding experiment or reason for obsolescence |
| Archived | Optional cleanup | Move to `Experiments/_archived/` if cluttering active experiments |

### Git Tracking

Experiments are version-controlled. This provides:

- **Historical record**: Git history shows when behavior changed between Swift versions
- **Collaboration**: Team members can reproduce, review, and extend experiments
- **Discoverability**: `git log --oneline Experiments/` shows experiment history
- **Bisection**: If behavior regresses, experiments help identify which toolchain broke it

### Directory Structure

**Correct**:
```text
swift-heap-primitives/
├── Package.swift
├── Sources/
├── Tests/
└── Experiments/
    ├── heap-deinit-order/
    │   ├── Package.swift
    │   └── Sources/
    │       └── main.swift
    ├── heap-noncopyable-generics/
    │   ├── Package.swift
    │   └── Sources/
    │       └── main.swift
    └── _archived/              # Optional: obsolete experiments
        └── heap-old-api-test/
```

**Incorrect**:
```text
/tmp/heap-deinit-order/     ❌ Ephemeral—lost on reboot
Experiments/heap-test/      ❌ Non-descriptive name
```

### Superseding Experiments

When an experiment becomes obsolete (e.g., Swift fixed the bug, API changed), add a header note:

```swift
// MARK: - SUPERSEDED
// This experiment is obsolete as of Swift 6.1.
// The behavior tested here was fixed in https://github.com/swiftlang/swift/pull/12345
// See: heap-deinit-order-v2/ for updated experiment
//
// Original experiment preserved for historical reference.
```

**Rationale**: Persistent experiments accumulate institutional knowledge. Unlike ephemeral `/tmp` experiments, tracked experiments enable collaboration and serve as regression tests for compiler behavior.

**Cross-references**: [EXP-002], [EXP-002a], [EXP-006a]

---

## [EXP-009] Multi-Variant Testing

**Scope**: Testing multiple variations of the same question.

**Statement**: When testing multiple related scenarios, variants SHOULD be organized in clearly delimited sections with individual results recorded.

### Single-File Organization

**Correct**:
```swift
// MARK: - Variant 1: Basic Sendable
// Hypothesis: Basic Sendable struct compiles
// Result: CONFIRMED

struct V1: Sendable {
    let value: Int
}

// MARK: - Variant 2: Sendable with closure
// Hypothesis: Sendable with @Sendable closure compiles
// Result: CONFIRMED

struct V2: Sendable {
    let action: @Sendable () -> Void
}

// MARK: - Variant 3: Sendable class
// Hypothesis: Final Sendable class compiles
// Result: CONFIRMED

final class V3: Sendable {
    let value: Int
    init(value: Int) { self.value = value }
}

// MARK: - Results Summary
// V1: CONFIRMED
// V2: CONFIRMED
// V3: CONFIRMED
```

**Incorrect**:
```swift
struct V1: Sendable { let value: Int }
struct V2: Sendable { let action: @Sendable () -> Void }
final class V3: Sendable { let value: Int; init(value: Int) { self.value = value } }
// All worked  ❌ No individual tracking, unclear what was tested
```

### Multi-File Organization (for complex variants)

```text
Experiments/sendable-variants/
├── Package.swift
└── Sources/
    ├── main.swift              # Entry point, summary
    ├── Variant1_Basic.swift    # Individual variant
    ├── Variant2_Closure.swift
    └── Variant3_Class.swift
```

**Rationale**: Organized variants enable systematic testing. If one variant fails, you know exactly which one without re-testing all.

**Cross-references**: [EXP-003], [EXP-006]

---

## [EXP-010] Common Experiment Patterns

**Scope**: Templates for frequently needed experiment types.

**Statement**: Experiments SHOULD follow established templates for common investigation types. Using consistent templates ensures complete documentation and enables comparison across experiments.

**Rationale**: Standardized templates reduce cognitive overhead when creating experiments and ensure no critical information (toolchain, hypothesis, result) is omitted. Templates also make experiments easier to parse programmatically.

**Cross-references**: [EXP-003b], [EXP-006]

---

### [EXP-010a] Feature Availability Test

**Scope**: Testing whether a compiler feature compiles with a given configuration.

**Statement**: Feature availability experiments MUST use the following template to ensure consistent structure and complete documentation.

**Template**:
```swift
// MARK: - Feature Availability: {Feature Name}
// Purpose: Does {feature} compile with {configuration}?
// Hypothesis: {expected behavior}
//
// Toolchain: {version}
// Result: {CONFIRMED/REFUTED}
// Date: {YYYY-MM-DD}

// --- Minimal code using feature ---
{feature code}

// --- Build command ---
// swift build 2>&1

// --- Expected ---
// Build Succeeded / error: {specific error}
```

**Rationale**: Feature availability is the most common experiment type. A standardized template ensures all necessary information (toolchain, hypothesis, result) is captured consistently.

**Cross-references**: [EXP-003b]

---

### [EXP-010b] Runtime Behavior Test

**Scope**: Testing what code actually does at runtime.

**Statement**: Runtime behavior experiments MUST use the following template, including explicit input/output logging to capture actual vs expected behavior.

**Template**:
```swift
// MARK: - Runtime Behavior: {Operation}
// Purpose: What does {operation} actually do?
// Hypothesis: {expected output}
//
// Toolchain: {version}
// Result: {CONFIRMED/REFUTED - actual output}
// Date: {YYYY-MM-DD}

func test() {
    let initial = /* setup */
    let result = /* operation under test */

    print("Input: \(initial)")
    print("Output: \(result)")
}

test()

// --- Run command ---
// swift run 2>&1

// --- Expected output ---
// Input: ...
// Output: ...
```

**Rationale**: Runtime tests require observable output to verify behavior. Explicit print statements ensure results are captured verbatim rather than inferred.

**Cross-references**: [EXP-005]

---

### [EXP-010c] Error Message Discovery

**Scope**: Capturing exact compiler diagnostics for invalid code.

**Statement**: Error discovery experiments MUST use the following template, capturing the exact diagnostic text verbatim for documentation purposes.

**Template**:
```swift
// MARK: - Error Discovery: {Invalid Pattern}
// Purpose: What error does {invalid code} produce?
// Hypothesis: Error message contains "{expected text}"
//
// Toolchain: {version}
// Result: {actual error message}
// Date: {YYYY-MM-DD}

// --- Intentionally invalid code ---
{code expected to fail}

// --- Build command ---
// swift build 2>&1

// --- Captured error ---
// error: {exact diagnostic}
```

**Rationale**: Exact error messages enable accurate documentation of compiler behavior. Paraphrased errors lose nuance that may be significant for users encountering the same diagnostic.

**Cross-references**: [DOC-CONTENT-003] (Documentation Requirements.md)

---

### [EXP-010d] Configuration Comparison

**Scope**: Testing behavior differences across build configurations.

**Statement**: Configuration comparison experiments MUST test both debug and release builds, documenting any behavioral differences explicitly.

**Template**:
```swift
// MARK: - Configuration Comparison: {Behavior}
// Purpose: Does {behavior} differ between debug and release?
// Hypothesis: {expected difference or none}
//
// Toolchain: {version}
// Date: {YYYY-MM-DD}
//
// Results:
// - Debug: {behavior}
// - Release: {behavior}
// - Difference: {yes/no, description}

{test code}

// --- Commands ---
// swift build -c debug && swift run
// swift build -c release && swift run
```

**Rationale**: Optimization-dependent behavior is a common source of production bugs. Explicitly comparing configurations reveals issues that only manifest in release builds.

**Cross-references**: [EXP-005]

---

## Topics

### Workflow Documents

- <doc:Experiment-Investigation> — Reactive workflow for debugging failures
- <doc:Experiment-Discovery> — Proactive workflow for package audits
- <doc:Issue-Submission> — Workflow for submitting compiler bugs

### Related Documents

- <doc:API-Design> — API design rules and patterns
- <doc:Documentation-Requirements> — Documentation standards
- <doc:Implementation> — Implementation patterns index

### Cross-Reference Index

| ID | Title | Focus |
|----|-------|-------|
| EXP-002 | Package Location Convention | Where to create |
| EXP-002a | Experiment Triage | Package vs ecosystem scope |
| EXP-002b | Package Isolation | SPM isolation from parent |
| EXP-003 | Minimal Package Structure | Directory layout |
| EXP-003a | Package.swift Template | Manifest format |
| EXP-003b | main.swift Template | Source file format |
| EXP-003c | Output Artifacts | Ephemeral outputs policy |
| EXP-003d | Naming Alignment | Directory/package/target consistency |
| EXP-003e | Experiment Index | Discoverability via _index.md |
| EXP-005 | Execution Protocol | Build commands |
| EXP-006 | Result Documentation | Recording outcomes |
| EXP-006a | Documentation Promotion | Elevating findings |
| EXP-006b | Confirmation Evidence | Required evidence for CONFIRMED |
| EXP-007 | Toolchain Specification | Version recording |
| EXP-008 | Experiment Package Lifecycle | Package management |
| EXP-009 | Multi-Variant Testing | Testing variations |
| EXP-010 | Common Experiment Patterns | Templates |
| EXP-010a | Feature Availability Test | Compile-time testing |
| EXP-010b | Runtime Behavior Test | Runtime testing |
| EXP-010c | Error Message Discovery | Diagnostic capture |
| EXP-010d | Configuration Comparison | Debug vs release |

