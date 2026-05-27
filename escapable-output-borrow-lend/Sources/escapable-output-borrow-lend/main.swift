// MARK: - Escapable-Output Borrow Lend
//
// Purpose: Determine whether a borrowing-Map-shaped iterator (~Copyable &
//   ~Escapable, @_lifetime(&self) mutating next()) can lend a genuinely
//   ~Escapable OUTPUT (a borrowed view) tied to self — and classify the result
//   as FUNDAMENTAL wall / PRODUCTION-GATED / ACHIEVABLE-TODAY.
//
// Claim under test: `swift-institute/Research/sequencer-primitives-reconciliation-refactor.md`
//   §15 asserts a ~Escapable output "walls in BOTH worlds" because
//   (W1) the slot is `UnsafeMutablePointer<Out>` requiring `Out: Escapable`, and
//   (W2) `Ownership.Borrow.value` read-back is `where Value: Escapable` — "awaits SE-0519".
//   This experiment shows W1/W2 are properties of ONE design (Ownership.Borrow +
//   pointer slot), not a fundamental limit: the bespoke-vending shape lends a
//   ~Escapable output TODAY on 6.3.2.
//
// Prior art (cited, not duplicated):
//   - swift-institute/Experiments/pointer-nonescapable-storage
//   - swift-institute/Experiments/nonescapable-patterns
//   - swift-institute/Experiments/ownership-borrow-protocol-unification
//
// Toolchain matrix (selected via swiftly):
//   A = Apple Swift 6.3.2 (swift-6.3.2-RELEASE)          — latest RELEASE
//   B = Apple Swift 6.5-dev (main-snapshot-2026-05-12-a) — dev line (SE-0507/0519 surface)
// Platform: macOS 26.0 (arm64). Debug AND release ([EXP-017]).
// Base experimental features (all probes): LifetimeDependence, Lifetimes,
//   SuppressedAssociatedTypes. P2b/P3 additionally: BorrowAndMutateAccessors.
//
// Status: per-probe verdicts below (typecheck matrix in Outputs/matrix.txt;
//   achievable-today shapes additionally built+run cross-module, debug+release).
// Date: 2026-05-26
//
// ============================================================================
// RESULT MATRIX  (CONFIRMED = compiles as intended; REFUTED = walled)
// ============================================================================
//
//   Probe                                       | A 6.3.2 (dbg/rel) | B dev (dbg/rel)
//   --------------------------------------------+-------------------+----------------
//   P1  UnsafeMutablePointer<~Escapable> slot    | REFUTED / REFUTED | REFUTED/REFUTED
//   P2a stored prop, plain return @_lifetime     | CONFIRMED/CONFIRM | CONFIRM/CONFIRM
//   P2b `borrow` accessor (SE-0507)              | REFUTED / REFUTED | CONFIRM/CONFIRM
//   P2c `_read` coroutine accessor               | CONFIRMED/CONFIRM | CONFIRM/CONFIRM
//   P3  stdlib SE-0519 (`Ref<T>`) construct+read | REFUTED / REFUTED | CONFIRM/CONFIRM
//   P4  bespoke ~Escapable Borrowed vending      | CONFIRMED/CONFIRM | CONFIRM/CONFIRM
//
// Exact diagnostics for REFUTED:
//   P1 (both A+B): `error: type 'View' does not conform to protocol 'Escapable'`
//      cmd: swiftc -typecheck P1.swift -enable-experimental-feature Lifetimes …
//      → W1 CONFIRMED as a real wall *for the pointer-slot design*: UnsafeMutablePointer<T>
//        requires T: Escapable on every available toolchain.
//   P2b (A only): `error: experimental feature 'BorrowAndMutateAccessors' cannot be
//      enabled in production compiler` → the SE-0507 `borrow` accessor is PRODUCTION-GATED.
//   P3 (A only):  `error: experimental feature 'BorrowAndMutateAccessors' cannot be
//      enabled in production compiler`. On B the type exists but is named `Ref<Value>`
//      (NOT `Borrow`), @available(anyAppleOS 9999) = unreleased ABI; its `.value`
//      read-back is a `borrow` accessor gated on $BorrowAndMutateAccessors. So SE-0519
//      does NOT carry the W2 `where Value: Escapable` limit — read-back of a ~Escapable
//      value works via the borrow accessor, but only on the dev line.
//
// ============================================================================
// VERDICT
// ============================================================================
//
//   Lending a ~Escapable output is ACHIEVABLE TODAY on 6.3.2 (option 3), via TWO
//   independent shapes that do NOT use UnsafeMutablePointer<~Escapable> and do NOT
//   use Ownership.Borrow's Escapable-gated read-back: (P2a) a plain stored
//   ~Escapable property returned under @_lifetime(&self), and (P4) a bespoke nested
//   ~Escapable `Borrowed` vending struct that points into an iterator-owned
//   Escapable (Int) slot and is lifetime-tied to self. Both compile AND run,
//   cross-module, debug AND release, on Apple Swift 6.3.2. The §15 "walls in both
//   worlds" claim is therefore scoped, not fundamental: W1 (pointer slot needs
//   Escapable) and W2 (Ownership.Borrow.value needs Escapable) are real BUT are
//   limitations of the *Ownership.Borrow-based* Map design specifically — they
//   fall away the moment the output is vended by a bespoke ~Escapable view rather
//   than stored in UnsafeMutablePointer<Out> and read back through Ownership.Borrow.
//   The ergonomic stdlib path (SE-0519 `Ref<T>` + SE-0507 `borrow` accessor read-
//   back of a ~Escapable value) is PRODUCTION-GATED (option 2): present on the dev
//   line under BorrowAndMutateAccessors + @available(9999), absent on 6.3.2 — it
//   ships when those reach a production compiler. Nothing here is fundamentally
//   impossible on any available toolchain.
//
// ============================================================================

import BorrowLendKit

// MARK: - Run P2a cross-module (achievable-today, stored-property lend)

func runP2a() {
    var it = IterP2a()
    var sum = 0
    while let out = it.next() {
        sum += out.value          // read the lent ~Escapable output
    }
    print("P2a sum =", sum)        // expect 0 + 100 + 200 = 300
}

// MARK: - Run P4 cross-module (achievable-today, bespoke vending struct)

func runP4() {
    var it = IterP4()
    var sum = 0
    while let view = it.next() {
        sum += view.value          // read the lent ~Escapable Borrowed view
    }
    it.finish()
    print("P4 sum =", sum)         // expect 0 + 10 + 20 = 30
}

runP2a()
runP4()
