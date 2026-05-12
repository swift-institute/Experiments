# Experiments

Standalone Swift packages that verify compiler and runtime behaviour for the [Swift Institute](https://swift-institute.org) ecosystem — receipts for blog posts and research documents.

## Overview

Each subdirectory is a Swift package isolating one hypothesis (a compiler behaviour, a language constraint, an architectural approach) with a runnable build readers can clone and verify. Multi-variant experiments encode related claims as separate targets within the same package.

When a blog post claims "the compiler rejects this pattern," the experiment proves it. When research says "approach A compiles but approach B does not," the experiment shows both.

The convention for this repository is documented at [swift-institute.org](https://swift-institute.org/documentation/swift-institute/experiments). The companion research repository is at [swift-institute/Research](https://github.com/swift-institute/Research).

## Building

Each experiment is a standalone Swift package. Clone this repository and run `swift build` (or `swift run`) inside the experiment directory:

```
git clone https://github.com/swift-institute/Experiments.git
cd Experiments/{experiment-name}
swift build
```

Requires Swift 6.3 or newer.

## Browse

The canonical browsable view of this corpus is the [Experiments dashboard](https://swift-institute.org/dashboard/#experiments) on swift-institute.org — filterable by status, category, and toolchain, with full-text search across directories and purposes.

## Index

[`_index.json`](_index.json) is the authoritative manifest — one entry per experiment with purpose, date, toolchain, status, category, and cross-references.

## Per-experiment CI convention: deferred 2026-05-12

The per-issue precedent at sibling repo
[`swift-institute/Issues`](https://github.com/swift-institute/Issues) (one
test target + one executable target per issue, `withKnownIssue` upstream-fix
detection, per-issue matrix-of-reusable in `.github/workflows/ci.yml`) was
considered for extension to this repo and **deferred**:

- **Repo shape diverges.** Each experiment here is its own standalone
  SwiftPM package with its own `Package.swift`. Issues uses ONE root
  `Package.swift` with per-issue subdirs as paths into test targets.
  Collapsing the per-experiment standalone packages into a monolithic
  root package would discard the per-experiment isolation this repo was
  designed for.
- **Outcome model differs.** Experiments converge to write-time
  conclusions (`CONFIRMED` / `REFUTED` / `CONSOLIDATED` — see
  [`_index.json`](_index.json)). The `withKnownIssue` flip-on-upstream-fix
  mechanism that motivates the per-issue precedent has no analogue here.
- **Mostly executable-only.** 197 of 211 experiment packages have only
  `executableTarget`; only 11 have `testTarget`. The "1 testTarget + 1
  executableTarget per dir" precedent's load-bearing test surface is
  absent for most experiments.

A different CI shape for the experiment corpus is a separate design
question; this note records the deferral so future contributors don't
re-derive it from scratch.

## License

[Apache 2.0](LICENSE.md).
