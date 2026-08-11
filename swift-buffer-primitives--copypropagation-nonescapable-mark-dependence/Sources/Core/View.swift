// MARK: - CopyPropagation mark_dependence [nonescaping] vs [escaping] for ~Escapable coroutine yields
// Purpose: Reproduce Bug 2 (SIL CopyPropagation false positive) with a minimal
//          ~Copyable ~Escapable view type yielded from a _read coroutine accessor,
//          used across control flow paths in an @inlinable consumer function.
//
// Hypothesis: The mark_dependence instruction created for @_lifetime(borrow base)
//             on a ~Escapable type is classified as PointerEscape (not [nonescaping]),
//             causing OSSACanonicalizeOwned to bail out. In deep @inlinable chains,
//             this partial bailout leaves SIL inconsistent → ownership verification crash.
//
// Methodology: [EXP-004a] Incremental construction.
//   V1: ~Escapable view + _read accessor + control flow across 2 modules
//   V2: Remove ~Escapable + @_lifetime from View types
//   V3: Keep ~Escapable, add @_optimize(none) on _read accessor
//   V4: Keep ~Escapable, add @_optimize(none) on View.Typed.init
//
// Toolchain: Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
// Platform: macOS 26.0 (arm64)
//
// Results:
//   V1: CONFIRMED — double end_lifetime in Wrapper.clearAndCheck().
//       CopyPropagation pass #1257: "Found over consume?!" on View.Typed value.
//       Two end_lifetime for the same value (%7 at %8 and %16).
//       Build command: rm -rf .build && swift build -c release
//   V2: CONFIRMED FIX — removing ~Escapable + @_lifetime eliminates crash.
//       Release build succeeds, binary runs correctly.
//   V3: CONFIRMED FIX — @_optimize(none) on _read accessor eliminates crash.
//       Release build succeeds, binary runs correctly.
//   V4: REFUTED — @_optimize(none) on View.Typed.init does NOT fix crash.
//       Same double end_lifetime error. Init optimization is not the issue.
//
// Conclusion: The crash is caused by mark_dependence instructions generated for
//   ~Escapable types with @_lifetime(borrow). CopyPropagation's canonicalizer
//   interacts badly with these lifetime dependencies across control flow joins.
//   Two fixes work:
//   A) Remove ~Escapable (eliminates mark_dependence entirely)
//   B) @_optimize(none) on _read accessor (prevents accessor inlining,
//      keeping mark_dependence behind function call boundary)
// Date: 2026-03-22
//
// Swift 6.3: FIXED — workaround no longer required
// Status: SUPERSEDED (2026-04-14) — bug fixed in Swift 6.3, workaround removed from production code
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)

// ─── Tag namespace (mirrors Property pattern) ───

public enum Remove {}
public enum Access {}

// ─── View type (~Copyable, ~Escapable, @_lifetime) ───

@safe
public struct View<Tag, Base: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline
    internal let _base: UnsafeMutablePointer<Base>

    @inlinable
    @_lifetime(borrow base)
    public init(_ base: UnsafeMutablePointer<Base>) {
        unsafe _base = base
    }

    @inlinable
    public var base: UnsafeMutablePointer<Base> {
        unsafe _base
    }
}

// ─── View.Typed (mirrors Property.View.Typed) ───

extension View where Base: ~Copyable {
    @safe
    public struct Typed<Element: ~Copyable>: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _base: UnsafeMutablePointer<Base>

        @inlinable
        @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            unsafe _base = base
        }

        @inlinable
        public var base: UnsafeMutablePointer<Base> {
            unsafe _base
        }
    }
}

// ─── Container with _read accessor yielding View ───

public struct Container<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _storage: UnsafeMutableBufferPointer<Element>

    @usableFromInline
    internal var _count: Int

    @inlinable
    public init(capacity: Int) {
        unsafe _storage = .allocate(capacity: capacity)
        _count = 0
    }

    @inlinable
    public var remove: View<Remove, Self>.Typed<Element> {
        mutating _read {
            yield unsafe View.Typed(&self)
        }
    }

    @inlinable
    public var access: View<Access, Self>.Typed<Element> {
        mutating _read {
            yield unsafe View.Typed(&self)
        }
    }
}

// ─── Methods on View.Typed for Remove tag ───

extension View.Typed
where Tag == Remove,
      Base == Container<Element>,
      Element: ~Copyable
{
    @inlinable
    public func all() {
        unsafe base.pointee._count = 0
    }
}

// ─── Methods on View.Typed for Access tag ───

extension View.Typed
where Tag == Access,
      Base == Container<Element>,
      Element: ~Copyable
{
    @inlinable
    public var count: Int {
        unsafe base.pointee._count
    }
}
