// MARK: - V1: Bare generic Cursor type with conditional Copyable/Escapable
//
// Purpose: Test whether a single generic `Cursor<Storage>` type can be
// declared `~Copyable, ~Escapable` and have conditional Copyable/Escapable
// conformance lifted via `extension Cursor: Copyable where Storage: ...`
// — mirroring the `Tagged<Tag, Underlying>` precedent at
// swift-tagged-primitives.
//
// Hypothesis: Compiles. Tagged proves the pattern works in production.
//
// Toolchain: Swift 6.3.1 (Apple Swift 6.3, macOS 26 / arm64e)
// Platform: macOS 26 / arm64e
//
// Status: CONFIRMED (for V1's narrow hypothesis); see EXPERIMENT.md for the
// full 6-variant verdict — Shape A is structurally achievable with one
// caveat (V2's W2-inadvertently-Copyable bug requires a ~Copyable wrapper
// for the Span substrate; V3/V4 Mode-discriminator approaches REFUTED).

public import Tagged_Primitives
public import Ordinal_Primitives
public import Cardinal_Primitives

public enum CursorV1 {}

extension CursorV1 {
    /// Hypothetical unified cursor — Shape A from cursor-abstractions doc.
    /// Storage is fully generic; the type defaults to the most-suppressed
    /// shape (`~Copyable & ~Escapable`) and conditional conformances lift
    /// the suppression based on Storage's own attributes.
    @safe
    public struct Cursor<Storage: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
        @usableFromInline
        internal let storage: Storage

        @inlinable
        @_lifetime(borrow storage)
        public init(_ storage: borrowing Storage) where Storage: Copyable {
            self.storage = copy storage
        }
    }
}

// MARK: - Conditional conformances (Tagged-style)
//
// Hypothesis under test: these compile cleanly.

extension CursorV1.Cursor: Copyable
where Storage: Copyable & ~Escapable {}

extension CursorV1.Cursor: Escapable
where Storage: Escapable & ~Copyable {}
