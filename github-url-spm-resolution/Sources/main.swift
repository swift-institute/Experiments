// MARK: - GitHub URL + SPM Resolution Verification
// Purpose: Validate GitHub URL patterns, SPM package name uniqueness,
//          and redirect behavior for the reality-* org migration plan
// Hypothesis: See individual variants below
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: See per-variant results below
// Date: 2026-02-23

// MARK: - Variant 1: Basic SPM Resolution
// Hypothesis: SPM resolves a package from github.com/coenttb/{repo-name}
// Result: CONFIRMED — resolved and ran successfully
// Output: "test-algebra-primitives from coenttb"

import TestAlgebraPrimitives
print("V1: \(TestAlgebraPrimitives.identity)")

// MARK: - Variant 2: Second Package Resolution
// Hypothesis: SPM resolves a second package from same org with different name
// Result: CONFIRMED — both resolve in parallel, no conflict
// Output: "test-buffer-primitives from coenttb"

import TestBufferPrimitives
print("V2: \(TestBufferPrimitives.identity)")

// MARK: - Variant 3: Repo Rename Redirect
// Hypothesis: After renaming test-algebra-primitives → test-algebra-primitives-renamed
//             on GitHub, SPM still resolves the OLD URL via GitHub redirect
// Method: Renamed via `gh repo rename`, purged SPM cache, re-resolved from clean state
// Result: CONFIRMED — GitHub provides permanent redirect, SPM follows it transparently
// Evidence: `swift package resolve` + `swift run` succeeded with purged cache

// MARK: - Variant 4: Package.name Collision
// Hypothesis: Two repos with IDENTICAL Package.name but different repo URLs
//             will cause SPM to reject the dependency graph
// Setup: test-buffer-primitives  (Package.name = "test-buffer-primitives")
//        test-buffer-foundations (Package.name = "test-buffer-primitives")  ← intentional
// Result: REFUTED — SPM does NOT use Package.name as identity.
//         SPM derives identity from the URL's last path component (repo name).
//         Both resolved, built, and ran without conflict.
// Evidence: `swift package dump-package` shows identities as:
//   "test-algebra-primitives"  (from URL)
//   "test-buffer-primitives"   (from URL)
//   "test-buffer-foundations"   (from URL, NOT from Package.name)

import TestBufferFoundations
print("V4: \(TestBufferFoundations.identity)")

// MARK: - Derived Finding: Cross-Org Same-Name Collision
// SPM identity = last path component of the URL. Therefore:
//   github.com/reality-primitives/algebra → identity "algebra"
//   github.com/reality-foundations/algebra → identity "algebra"
// These WOULD collide in a consumer that depends on both.
//
// Implication: Repo names must be globally unique across ALL orgs in the
// dependency graph. The layer suffix (-primitives, -foundations) in repo
// names is REQUIRED for SPM, not optional.
//
// The correct URL pattern is:
//   github.com/reality-primitives/algebra-primitives
//   github.com/reality-foundations/algebra  (no collision — different domain name)

// MARK: - Results Summary
// V1: CONFIRMED — basic SPM resolution works
// V2: CONFIRMED — multiple packages from same org works
// V3: CONFIRMED — GitHub redirect after repo rename works with SPM
// V4: REFUTED   — Package.name is NOT the uniqueness constraint; URL identity is
// Derived: repo names must be unique across all dependency-graph orgs
