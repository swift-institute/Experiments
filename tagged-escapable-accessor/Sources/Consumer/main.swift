// MARK: - Tagged ~Escapable Accessor Upgrade
// Purpose: Determine which public accessor on Tagged enables @_lifetime
//          propagation for ~Escapable views across PACKAGE boundaries
//          (not just module boundaries).
//
// Prior art:
//   tagged-string-crossmodule — D' works cross-module (package access on _storage)
//   tagged-string-literal — _read blocks @_lifetime in withView closure pattern
//   memory-contiguous-owned — stored property access propagates @_lifetime
//   Heap.Small ~Copyable.swift:323 — borrowing _read + _overrideLifetime WORKS
//   escapable-deinit-lifetime.md — _read fails in deinit contexts specifically
//
// Key constraint: TaggedLib is a SEPARATE PACKAGE from StringLib/Consumer.
//   package access does NOT cross this boundary. Only public API works.
//   This mirrors: swift-identity-primitives → swift-string-primitives.
//
// Hypothesis: _overrideLifetime in a borrowing get property may work through
//   rawValue._read across packages, because the coroutine scope boundary
//   is overridden by the unsafe _overrideLifetime re-parenting to self.
//   If not, public stored property rawValue is the fallback.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26, arm64
//
// Result: V1 REFUTED, V2 CONFIRMED, V3 REFUTED, V4 CONFIRMED, V5 REFUTED
// Date: 2026-02-27

import StringLib

// ============================================================================
// MARK: - V1: Span through Tagged.rawValue (_read coroutine, cross-package)
// ============================================================================
// Result: REFUTED — does not compile
//   error: lifetime-dependent variable 's' escapes its scope
//   rawValue.pointer depends on _read coroutine scope; _overrideLifetime
//   cannot re-parent the Span's lifetime from the coroutine to self.

// testV1() disabled — V1 extension #if false'd in String.swift

// ============================================================================
// MARK: - V2: Span through TaggedStored.rawValue (stored property, cross-package)
// ============================================================================
// Result: CONFIRMED

func testV2() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf.initialize(from: [65, 66, 67, 0], count: 4)
    let s: TaggedStored<PathTag, Memory.Contiguous<Char>> = .init(Memory.Contiguous<Char>(adopting: buf, count: 3))
    let sp = s.span
    precondition(sp.count == 3, "V2: span count should be 3")
    precondition(sp[0] == 65, "V2: first byte should be 65")
    print("V2 (stored → Span): CONFIRMED — count = \(sp.count), first = \(sp[0])")
}

// ============================================================================
// MARK: - V3: ~Escapable View through Tagged.rawValue (_read, cross-package)
// ============================================================================
// Result: REFUTED — does not compile
//   error: lifetime-dependent variable 'v' escapes its scope
//   Same mechanism as V1: rawValue.pointer from _read coroutine scope
//   cannot be re-parented to self via _overrideLifetime.

// testV3() disabled — V3 extension #if false'd in String.swift

// ============================================================================
// MARK: - V4: ~Escapable View through TaggedStored.rawValue (stored, cross-package)
// ============================================================================
// Result: CONFIRMED

func testV4() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [47, 116, 109, 112, 0], count: 5)
    let s: TaggedStored<PathTag, Memory.Contiguous<Char>> = .init(Memory.Contiguous<Char>(adopting: buf, count: 4))
    let v = s.view
    precondition(v.length == 4, "V4: view length should be 4")
    let sp = v.span
    precondition(sp[0] == 47, "V4: first byte should be '/' (47)")
    print("V4 (stored → View → Span): CONFIRMED — length = \(v.length), first = \(sp[0])")
}

// ============================================================================
// MARK: - V5: Chained Span through rawValue.span (production Tagged)
// ============================================================================
// Result: REFUTED — does not compile
//   error: lifetime-dependent variable 's' escapes its scope
//   Chaining through rawValue.span still goes through _read coroutine.
//   The intermediate @_lifetime on Memory.Contiguous.span does NOT
//   bypass the _read scope boundary — the chain is still scoped to _read.

// testV5() disabled — V5 extension #if false'd in String.swift

// ============================================================================
// MARK: - Execute Confirmed Variants
// ============================================================================

print("V1 (_read → Span): REFUTED — does not compile")
testV2()
print("V3 (_read → View): REFUTED — does not compile")
testV4()
print("V5 (_read → .span chain): REFUTED — does not compile")

print("\nAll variants complete.")

// MARK: - Results Summary
// V1: REFUTED — Span through _read coroutine (cross-package) — does not compile
// V2: CONFIRMED — Span through stored property (cross-package) — compiles and runs
// V3: REFUTED — ~Escapable View through _read coroutine (cross-package) — does not compile
// V4: CONFIRMED — ~Escapable View through stored property (cross-package) — compiles and runs
// V5: REFUTED — Chained Span through rawValue.span (cross-package) — does not compile
//
// Conclusion: _read coroutine on rawValue UNIVERSALLY blocks @_lifetime
//   propagation across package boundaries. _overrideLifetime cannot escape
//   the _read coroutine scope — not for Span, not for ~Escapable View,
//   not even for chained @_lifetime properties.
//
//   Production Tagged MUST change: replace internal _storage + _read/_modify
//   rawValue with a public stored property rawValue. This is a one-line
//   structural change. The compiler generates implicit _read/_modify for
//   stored properties, but stored property access has different lifetime
//   semantics — the borrow is on self, not on a coroutine scope.
