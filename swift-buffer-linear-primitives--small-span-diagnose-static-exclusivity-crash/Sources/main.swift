// MARK: - DiagnoseStaticExclusivity SIGSEGV — borrow returned through a ~Copyable enum payload
//
// Purpose:    Regression guard + search-space record for the DiagnoseStaticExclusivity
//             compiler crash that blocks the "elegant" delegation form of
//             Buffer.Linear.Small's borrow-yielding ops (span / mutableSpan /
//             ~Copyable subscript / peek). The refined-C (A) implementation routes
//             around it via package windows + non-@inlinable ops; this experiment
//             records WHY that routing is necessary and acts as the FIXED-verdict
//             guard for when the crash is resolved upstream.
//
// Hypothesis: "The crash reproduces from a minimal standalone shape — a ~Copyable
//             enum whose payload exposes a borrowing `Span` getter, with an outer
//             accessor returning `payload.span` from inside a `switch`."
//
// Result:     REFUTED for the standalone shape (this file compiles clean); the crash
//             is CONTEXT-SENSITIVE to the production Buffer.Linear.Small machinery.
//             See the "Context-sensitive reproducer" and "Candidate triggers"
//             sections below. Per [EXP-004a]/[EXP-018] a context-sensitive
//             reproducer's value is narrowing the search space, not standalone filing.
//
// Toolchain:  Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), Xcode default toolchain
// SDK:        MacOSX26.5.sdk
// Platform:   macOS 26 (arm64)
// Status:     STILL CRASHES (in-package, as of Swift 6.3.2) — standalone shape clean
// Date:       2026-05-24
//
// Revalidate the IN-PACKAGE probe (below) on each new toolchain per [META-006]/[EXP-006c].
// When the in-package probe compiles clean, flip Status to FIXED, remove the
// `// TODO(C):` markers in swift-buffer-linear-primitives, and re-`@inlinable` the
// borrow ops + restore the elegant `.span` delegation.

// MARK: - Standalone reduction variants (all REFUTED — compile clean)
//
// Each adds one ingredient over the last per [EXP-021]; none reproduces the crash.
// Verified via: swiftc -emit-module -experimental-skip-non-inlinable-function-bodies-without-types
//   V1: concrete element, non-inlinable getter, no deinit           -> clean
//   V2: generic <Element: ~Copyable>, @inlinable getter             -> clean
//   V3: V2 + deinit on the inner ~Copyable type (this file)         -> clean
// What this rules out: the crash is NOT caused by {~Copyable enum + Span-borrow
// delegation + generics + @inlinable + deinit} alone. The missing trigger lives in
// the production payload types (see "Candidate triggers").

public struct V3_Inner<Element: ~Copyable>: ~Copyable {
    @usableFromInline var base: UnsafeMutablePointer<Element>
    @usableFromInline var count: Int
    @inlinable init(base: UnsafeMutablePointer<Element>, count: Int) {
        unsafe self.base = base
        self.count = count
    }
    deinit {}
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable borrowing get { unsafe Span(_unsafeStart: base, count: count) }
    }
}

@usableFromInline enum V3_Repr<Element: ~Copyable>: ~Copyable {
    case a(V3_Inner<Element>)
    case b(V3_Inner<Element>)
}

public struct V3_Outer<Element: ~Copyable>: ~Copyable {
    @usableFromInline var repr: V3_Repr<Element>
    @inlinable init(repr: consuming V3_Repr<Element>) { self.repr = repr }
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable borrowing get {
            switch repr {
            // Compiles clean here — but the production analogue (below) SIGSEGVs.
            case .a(let inner): return inner.span
            case .b(let inner): return inner.span
            }
        }
    }
}

// MARK: - Context-sensitive reproducer (IN-PACKAGE — DOES crash)
//
// The crash reproduces ONLY when the above shape is realized with the production
// Buffer.Linear / Buffer.Linear.Inline payloads, accessing Small's
// `@usableFromInline internal _storage` (so it cannot be a consumer/standalone
// probe — that is the context-sensitivity). Re-applying EITHER probe below as an
// extension inside swift-buffer-linear-primitives and running `swift build`
// crashes the compiler:
//
//   emit-module command failed due to signal 11
//   While running pass #N SILModuleTransform "DiagnoseStaticExclusivity".
//   DiagnoseStaticExclusivity::run() + 5000
//
// Probe 1 — Span borrow delegated through the enum payload (the §6b form):
//
//     extension Buffer.Linear.Small where Element: ~Copyable {
//         public var _spanDelegatedProbe: Span<Element> {
//             @_lifetime(borrow self) @inlinable borrowing get {
//                 switch _storage {
//                 case .heap(let heap):  return heap.span    // <-- SIGSEGV
//                 case .inline(let buf): return buf.span
//                 }
//             }
//         }
//     }
//
// Probe 2 — `_read` borrow-VIEW projection delegated through the enum payload
// (discovered 2026-05-24; the crash class is broader than §6b documented — it is
// NOT limited to `.span`). `peek` is a `_read` accessor yielding `Peek.View(self)`,
// so this borrows through the payload even though `.front` ultimately returns a
// COPY:
//
//     extension Property.Borrow.Typed.Valued
//     where Tag == Buffer<Element>.Linear.Peek, Base == ..Small<n>, Element: Copyable {
//         @inlinable public var front: Element {
//             switch base.value._storage {
//             case .heap(let heap):  return heap.peek.front   // <-- SIGSEGV
//             case .inline(let buf): return buf.peek.front
//             }
//         }
//     }
//
// Generalized trigger: any op returning a borrow — Span, MutableSpan, or a
// `_read`/borrow-view projection — out of a `switch` over a ~Copyable enum payload.

// MARK: - Candidate triggers (untested ingredients, for the pre-filing reduction)
//
// The delta between the clean V3 shape and the crashing in-package shape:
//   1. Storage.Heap — a class-backed ~Copyable handle as the payload's field
//      (V3 uses a raw UnsafeMutablePointer instead).
//   2. @_rawLayout(likeArrayOf:count:) on Buffer.Linear.Inline's storage.
//   3. The inner `.span` getter itself does `_overrideLifetime(span, borrowing: self)`
//      (a lifetime-dependence override) rather than returning a bare Span.
//   4. A two-level delegation (Small.span -> Buffer.Linear.span -> Storage pointer).
// Per [EXP-021], the pre-filing reduction adds these ONE at a time over V3.

print("small-span-diagnose-static-exclusivity-crash: standalone variants compile clean (crash is context-sensitive; see header)")
