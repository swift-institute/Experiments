// MARK: - docc merge: multi-archive hosted site
// Purpose: Verify that `docc merge` on the Xcode-bundled DocC combines
//          multiple article-only DocC archives into a single hosted site
//          with unified landing, cross-archive navigation, and search
//          that spans all sources.
//
// Hypothesis: Given three separate article-only DocC archives, the
//             `docc merge` subcommand produces a single archive with:
//             (a) a synthesized landing page that lists all source
//                 archives as top-level sections,
//             (b) working cross-archive navigation between pages in
//                 different source archives,
//             (c) a search index that returns hits across all sources.
//
// Toolchain: swift-6.3.1 (Xcode 26.4.1, swiftlang-6.3.1.1.2)
// Platform:  macOS 26.2 (arm64)
//
// Result:
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//   (a) Unified landing page   — CONFIRMED
//   (b) Cross-archive nav      — CONFIRMED
//   (c) Cross-archive search   — REFUTED
//
// Evidence:
//   (a) Merged archive's data/documentation.json has
//       title="Swift Institute Merge Experiment", topicSectionsStyle=detailedGrid,
//       one topicSection referencing all three sources; browser-rendered landing
//       shows three cards in detailedGrid layout.
//   (b) Merged archive's index/index.json lists all three source archives as
//       sibling modules under the merged root, each with its nested articles;
//       browser sidebar navigation between archives works.
//   (c) The bundled DocC renderer's sidebar "Filter" input and Cmd/⌃-/ QuickNavigation
//       are both title-only (fuzzyMatch against symbol.title only — verified in
//       swift-docc-render-artifact dist/js/documentation-topic.aaf718ac.js, the
//       only two .exec() sites are on the input regex and on t.title). Typing
//       a body-only unique marker ("airplane") returned "No results found."
//       The refutation is NOT merge-specific — stock DocC (Swift 6.3.1) does
//       not ship full-text search for any static-hosted archive, merged or
//       single. See research doc for detail.
//
// Cross-reference:
//   /Users/coen/Developer/swift-institute/Research/docc-search-capabilities-and-merged-site-strategy.md
//
// Date:   2026-04-17
//
// Execution:
//   ./run-experiment.sh
//   # then browse http://localhost:8000/documentation/
//
// This Swift package is a container for the experiment's `.docc`
// catalogs and pipeline script. No Swift behavior is under test.
print("Run ./run-experiment.sh to execute the docc-merge pipeline.")
