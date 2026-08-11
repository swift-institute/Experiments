// ============================================================================
// Single-file V1–V5 exception
//
// This file deliberately contains multiple types (`Resource`, `Failure`,
// `Wrapped`, `IO`, `IO.Plain`, `IO.Sendable`) and the V1–V5 attempt
// narrative — it is *not* split into separate `.swift` files per
// [API-IMPL-005]. The V1–V5 incremental-experiment shape is the
// experiment's purpose: each variant documents an attempt and its
// diagnostic outcome. Splitting destroys the side-by-side comparison.
//
// All other code-surface conventions still apply — Nest.Name throughout
// (`IO.Plain`, `IO.Sendable`, `Wrapped.leaf`), no compound identifiers,
// typed throws, minimal type bodies.
// ============================================================================

// ============================================================================
// Purpose: Test whether `mapError(_:)` on a hand-written witness can
//          return `sending` itself. Closures stored in the witness's
//          `_read`/`_write`/`_close` carry the region of the original
//          construction site; even after `consume self`, those closure
//          values inherit that region, so placing them inside a freshly-
//          constructed witness does not move the contained closures
//          into a fresh region.
//
// Hypothesis: REFUTED — region inheritance is intrinsic to closure
//          capture. None of V1–V5 produce a `sending` return without
//          requiring `Sendable` on the leaf failure type.
//
// If CONFIRMED-in-the-surprise-direction (a viable technique exists),
// that technique becomes the canonical pattern for witness
// transformation across mapError / map / etc.
//
// Toolchain: Swift 6.3.1 release
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform:  macOS 26 (arm64)
// Date:      2026-04-16 (renamed for code-surface compliance 2026-04-20)
// ============================================================================

// MARK: - Shared types

struct Resource: ~Copyable, Sendable {
    let value: Int
}

enum Failure: Error {
    case generic(Int32)
    case closed
}

enum Wrapped: Error & Sendable {
    case leaf(Failure)
    case other
}

// MARK: - IO namespace + Plain (non-Sendable storage) + Sendable (Sendable storage)

enum IO {}

extension IO {
    // Plain — base witness with non-@Sendable storage. The underlying
    // closures are NOT @Sendable, so the witness itself is not Sendable
    // and cannot be returned `sending` from a transformation.
    struct Plain<Failure: Error> {
        let _read:  (_ res: borrowing Resource) async throws(Failure) -> Int
        let _write: (_ res: borrowing Resource) async throws(Failure) -> Int
        let _close: (_ res: consuming Resource) async -> Void

        init(
            read:  @escaping (_ res: borrowing Resource) async throws(Failure) -> Int,
            write: @escaping (_ res: borrowing Resource) async throws(Failure) -> Int,
            close: @escaping (_ res: consuming Resource) async -> Void
        ) {
            self._read = read
            self._write = write
            self._close = close
        }
    }
}

extension IO {
    // Sendable — Sendable-storage variant. Requires the leaf failure type
    // itself to be Sendable. The closures are @Sendable; the struct
    // conforms to Sendable; mapError returns `sending IO.Sendable<New>`.
    struct Sendable<Failure: Error & Swift.Sendable>: Swift.Sendable {
        let _read:  @Sendable (_ res: borrowing Resource) async throws(Failure) -> Int
        let _write: @Sendable (_ res: borrowing Resource) async throws(Failure) -> Int
        let _close: @Sendable (_ res: consuming Resource) async -> Void

        init(
            read:  @Sendable @escaping (_ res: borrowing Resource) async throws(Failure) -> Int,
            write: @Sendable @escaping (_ res: borrowing Resource) async throws(Failure) -> Int,
            close: @Sendable @escaping (_ res: consuming Resource) async -> Void
        ) {
            self._read = read
            self._write = write
            self._close = close
        }
    }
}

// ============================================================================
// MARK: - V1: consume self + reconstruction (on IO.Plain)
// Hypothesis: `consume self` moves the witness's storage out, so placing
//             its closures into a fresh IO.Plain<New> should produce a
//             value in a fresh region.
// Outcome:    FAIL.
// Diagnostic (Swift 6.3.1, 2026-04-16):
//   error: task or actor-isolated value cannot be sent
//     at `return IO.Plain<New>( ... )`
//   The binding introduced by `consume self` is still task-isolated; the
//   new IO.Plain<New> inherits that region from the consumed closures.
//   `consume` moves ownership but does not rebase region.
// ============================================================================

// V1 DOES NOT COMPILE. Disabled so the file builds.

// ============================================================================
// MARK: - V2: explicit @Sendable wrapper closures (on IO.Plain)
// Hypothesis: Marking the wrapper closures `@Sendable` at construction of
//             the new IO.Plain may cause region analysis to treat their
//             captures as region-disjoint from `self`.
// Outcome:    FAIL.
// Diagnostic:
//   error: capture of '_read' with non-Sendable type ... in a '@Sendable'
//          closure. The stored closures are NOT @Sendable, so wrapping
//          them in @Sendable closures is rejected at the capture site.
//          Hard stop — fix is at the storage type, not the call site.
// ============================================================================

// V2 DOES NOT COMPILE. Disabled.

// ============================================================================
// MARK: - V3: Sendable constraint on Failure / NewFailure (last resort)
// Hypothesis: If the leaf failure type is Sendable AND the stored
//             closures are declared @Sendable, a freshly-constructed
//             IO.Sendable<New> is region-fresh and can be returned as
//             `sending`. Last-resort option — imposes a Sendable
//             constraint on the leaf failure (violates the ecosystem
//             "no Sendable constraint" preference).
// Outcome:    COMPILES (observed, Swift 6.3.1, 2026-04-16).
// Notes:
//   This is a strictly different witness type (`IO.Sendable`) because
//   the change is not at mapError's call site — it's baked into the
//   storage's function types (@Sendable stored properties). The outer
//   struct is also Sendable. Consequence: the witness shape changes;
//   leaf failures must be Sendable and all closures must be @Sendable.
//   Not "free".
// ============================================================================

extension IO.Sendable {
    func mapError<New: Swift.Error & Swift.Sendable>(
        _ transform: @Sendable @escaping (Failure) -> New
    ) -> sending IO.Sendable<New> {
        IO.Sendable<New>(
            read: { (res) throws(New) in
                do throws(Failure) {
                    return try await self._read(res)
                } catch {
                    throw transform(error)
                }
            },
            write: { (res) throws(New) in
                do throws(Failure) {
                    return try await self._write(res)
                } catch {
                    throw transform(error)
                }
            },
            close: self._close
        )
    }
}

// ============================================================================
// MARK: - V4: `withSending` / sending-parameter trick
// Hypothesis: Pass the witness through a helper whose parameter is
//             `sending`. Inside the helper, the value is in a fresh
//             region; reconstruct there.
// Outcome:    FAIL.
// Diagnostic:
//   The trick pushes the problem one frame up: to pass IO.Plain<F> as a
//   `sending` parameter, the caller must already hold it in a region
//   that is safe to send. IO.Plain<F> is not Sendable, so the caller
//   cannot form a sending argument even with `consume self`.
// ============================================================================

// V4 DOES NOT COMPILE. Disabled.

// ============================================================================
// MARK: - V5: reconstructed closure bodies that internally call originals
// Hypothesis: Writing explicitly fresh `{ }` closure literals (not
//             `self._read` rebinds) may give them a fresh region.
// Outcome:    FAIL.
// Diagnostic:
//   The closure literal still *captures* `self`. A capture of `self`
//   makes the closure inherit self's region. The "freshness" of the
//   closure literal text doesn't matter — region tracking follows
//   captures.
// ============================================================================

// V5 DOES NOT COMPILE. Disabled.

// ============================================================================
// MARK: - Run
//
// `sending` is a parameter/result qualifier, not a type decoration. We
// exercise the return-site check by passing each mapError result into a
// function whose parameter is `sending IO.Sendable<Wrapped>` (V3, the
// only variant that compiles).
//
// V1, V2, V4, V5 are disabled at source because they do not compile.
// Their diagnostics are preserved in the MARK blocks above.
// ============================================================================

func sink(_ io: sending IO.Sendable<Wrapped>) { _ = io }

// Suppress Sendable-capture warnings for the base constructors.
let base = IO.Plain<Failure>(
    read:  { _ in 0 },
    write: { _ in 0 },
    close: { _ in }
)
_ = base

let sbase = IO.Sendable<Failure>(
    read:  { _ in 0 },
    write: { _ in 0 },
    close: { _ in }
)
sink(sbase.mapError { Wrapped.leaf($0) })

print("V3 compiles; V1/V2/V4/V5 do not — see MARK diagnostics.")
