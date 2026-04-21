// MARK: - DocC Tutorial Host-Target Necessity — Experiment
// Purpose: Validate whether a DocC `.tutorial` file needs a separate build target
//   to hold the Swift source files referenced by its `@Code` directives, or
//   whether `.docc/Resources/*.swift` is sufficient.
//
// Three hypotheses distinguished:
//   H1: Host target required — tutorial Swift files must belong to a SwiftPM target.
//   H2: Catalog-resident — .docc/Resources/*.swift is sufficient, no target needed.
//   H3: Non-compiled — @Code renders file contents as text, no Swift compilation.
//
// Toolchain: Apple Swift 6.3.1 (Xcode 26.4.1, build 17E202)
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — H2 and H3 both hold; H1 is REFUTED.
// Build: ** BUILD DOCUMENTATION SUCCEEDED ** via `xcodebuild docbuild`.
// Evidence:
//   - .docc/Resources/step-01-empty.swift, step-02-with-api.swift render
//     correctly in tutorials/demo/gettingstarted (confirmed in rendered
//     doccarchive JSON + HTML).
//   - step-03-invalid.swift containing intentionally invalid Swift
//     (`import NonExistentModule`, bad grammar, type mismatches, empty bodies)
//     ALSO renders; docbuild succeeds despite invalid code → DocC treats step
//     source files as text, NOT as compiled Swift.
//   - Code content is embedded verbatim in tutorial JSON's "references" map
//     under `"content": [<lines>]`.
//
// Corollary: DocC does NOT verify tutorial code correctness at doc-build time.
// If a timeless release requires tutorial code to stay in sync with the API
// as it evolves, that verification needs a SEPARATE mechanism — a test target
// mirroring the tutorial step's final state, a CI step that runs `swiftc` on
// each step file, or manual review discipline. No tutorial-host target is
// needed to RENDER the tutorial; one would be needed only to COMPILE-CHECK
// the snippets.
//
// Minimum viable setup (no host target):
//   Sources/{Module}/
//     {Module}.swift
//     {Module}.docc/
//       {Module}.md                         (catalog root)
//       Tutorials.tutorial                  (@Tutorials table-of-contents)
//       {TutorialName}.tutorial             (@Tutorial with @Step + @Code)
//       Resources/
//         step-01-xxx.swift                 (catalog-resident step sources)
//         step-02-xxx.swift
//
// Gotcha: @Tutorial files require a @Tutorials table-of-contents file
// somewhere in the catalog. Without it, docbuild emits a "Missing tutorial
// table of contents page" warning and omits the tutorial from the rendered
// archive. With the @Tutorials TOC present, tutorials render correctly.
//
// Date: 2026-04-21

public enum Demo {
    /// Say hello from the Demo module.
    public static func hello() -> String {
        "hello from Demo"
    }
}
