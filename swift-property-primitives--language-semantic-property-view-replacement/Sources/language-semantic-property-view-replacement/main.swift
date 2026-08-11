// MARK: - Language-Semantic Property.View Replacement
//
// Purpose: Determine whether `Property.View` / `Property.View.Read` — the
// pointer-indirection accessor family for `~Copyable` bases — can be
// replaced by pure Swift 6.3 language constructs (`~Copyable`, `~Escapable`,
// `@_lifetime`, `borrowing` methods, `borrowing` init parameters) without
// the generic phantom-tag machinery.
//
// Canonical usage (from Tests/Support/Box.swift):
//
//   extension Box {
//       var inspect: Property<Inspect, Box>.View.Read {
//           mutating _read {
//               yield unsafe Property<Inspect, Box>.View.Read(
//                   unsafe UnsafePointer(Property<Inspect, Box>.View(&self).base)
//               )
//           }
//       }
//       var borrow: Property<Borrow, Box>.View.Read {
//           _read { yield Property<Borrow, Box>.View.Read(self) }
//       }
//   }
//   extension Property.View.Read where Tag == Box.Inspect, Base == Box {
//       var current: Int { unsafe self.base.pointee.value }
//   }
//
// Call site:  box.inspect.current / box.borrow.current
//
// Hypothesis: Pure-language replacement per namespace is mechanically
// straightforward — declare a per-namespace view struct with
// `~Copyable, ~Escapable` + `@_lifetime(borrow base)` and expose a
// non-mutating `_read` accessor. The generic phantom-tag machinery is not
// load-bearing for the capability; it is load-bearing for the amortization.
//
// Toolchain: swift-6.3.1 (2026-04-17)
// Platform: macOS 26.0 (arm64)
// Feature flags (Package.swift): LifetimeDependence, Lifetimes.
//
// These experimental flags are REQUIRED for pure-language replacement:
//   - `@_lifetime(borrow base)` requires `Lifetimes`.
//   - The Swift 6.3 rule "a mutating method cannot return a ~Escapable
//     result" is lifted by the same flag, making `mutating _read`/`_modify`
//     yielding a ~Escapable view legal.
// The shipped package enables both flags ecosystem-wide (Package.swift
// lines 157-158), so "pure language" here means "the same language surface
// the production package builds against."
//
// Status: V1 CONFIRMED, V2 CONFIRMED.
// Result: PARTIALLY-REPLACEABLE — same amortization loss as experiments
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//     #1, #2, #3. Pure language supplies every mechanism Property.View uses;
//     Property.View's value is packaging the pointer-plus-lifetime recipe
//     into one reusable generic type.
// Date: 2026-04-21

// MARK: - V1: Pure language — per-namespace read-only view, borrow init
//
// Hypothesis: Reproduce `box.borrow.current` by hand-rolling a `BorrowView`
// struct carrying the pointer + lifetime + borrowing-init pattern directly.

public struct V1Box: ~Copyable {
    var value: Int
    var storage: (Int, Int, Int, Int)
    public init(value: Int) {
        self.value = value
        self.storage = (1, 2, 3, 4)
    }
}

extension V1Box {
    @safe
    public struct BorrowView: ~Copyable, ~Escapable {
        @usableFromInline let _base: UnsafePointer<V1Box>

            @_lifetime(borrow base)
        public init(_ base: borrowing V1Box) {
            unsafe _base = withUnsafePointer(to: base) { unsafe $0 }
        }

            public var current: Int { unsafe _base.pointee.value }

            public var first: Int { unsafe _base.pointee.storage.0 }
    }

    public var borrow: BorrowView {
        _read { yield BorrowView(self) }
    }
}

// Call-site check: identical shape to production.
func v1Demo() {
    let box = V1Box(value: 42)
    print("V1 borrow.current=\(box.borrow.current) borrow.first=\(box.borrow.first)")
    // Output: V1 borrow.current=42 borrow.first=1
}
v1Demo()

// MARK: - V2: Pure language — per-namespace mutable view via `&self`
//
// Hypothesis: Reproduce `Property.View` (mutable pointer indirection) by
// hand-rolling a `ResizeView` struct that wraps `UnsafeMutablePointer<Box>`
// and supports a `mutating` method.

public struct V2Slice<Element: ~Copyable>: ~Copyable {
    @usableFromInline var count: Int
    public init(count: Int) { self.count = count }
}

extension V2Slice {
    @safe
    public struct AccessView: ~Copyable, ~Escapable {
        @usableFromInline let _base: UnsafeMutablePointer<V2Slice<Element>>

        @inlinable
        @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<V2Slice<Element>>) {
            unsafe _base = base
        }

        @inlinable
        public var size: Int { unsafe _base.pointee.count }

        @inlinable
        public mutating func resize(to newCount: Int) {
            unsafe _base.pointee.count = newCount
        }
    }

    public var access: AccessView {
        mutating _read {
            yield unsafe AccessView(withUnsafeMutablePointer(to: &self) { unsafe $0 })
        }
        mutating _modify {
            var view = unsafe AccessView(withUnsafeMutablePointer(to: &self) { unsafe $0 })
            yield &view
        }
    }
}

func v2Demo() {
    var slice = V2Slice<Int>(count: 5)
    print("V2 access.size=\(slice.access.size)")
    // Output: V2 access.size=5
    slice.access.resize(to: 10)
    print("V2 access.size=\(slice.access.size)")
    // Output: V2 access.size=10
}
v2Demo()

// MARK: - V3: Direct method — no view struct at all
//
// Hypothesis: For the read-only case with no mutation and no
// namespace-discrimination need, a direct computed property on the
// `~Copyable` base is simpler than any view.

public struct V3Box: ~Copyable {
    var value: Int
    public init(value: Int) { self.value = value }
    public var current: Int { value }  // direct — no view, no pointer, no phantom tag
}

func v3Demo() {
    let box = V3Box(value: 99)
    print("V3 direct.current=\(box.current)")
    // Output: V3 direct.current=99
}
v3Demo()

// MARK: - Results Summary
//
// V1 (pure-language read-only view): CONFIRMED. Reproduces
//     `box.borrow.current` with `~Copyable, ~Escapable` + `@_lifetime(borrow
//     base)` + a borrowing init. Semantically identical to Property.View.Read.
//     Cost: ~15 lines of view-struct declaration per namespace.
//
// V2 (pure-language mutable view): CONFIRMED. Reproduces `Property.View`'s
//     `UnsafeMutablePointer`-based mutation with an explicit `AccessView`
//     struct that takes `UnsafeMutablePointer<Base>` via `withUnsafeMutablePointer(to: &self)`.
//     Cost: equivalent per-namespace boilerplate.
//
// V3 (no view): demonstrates that `Property.View` is NOT required for the
//     degenerate case of a single read-only accessor on a ~Copyable type
//     with no namespace discrimination. Direct computed properties work.
//     When a type has only ONE borrow-namespace and no mutation, the
//     view-struct layer is overhead.
//
// Verdict for Property.View family: PARTIALLY-REPLACEABLE.
//   Every mechanism `Property.View*` uses — `~Copyable, ~Escapable`,
//   `@_lifetime(borrow base)`, `mutating _read`/`_modify`, `borrowing` init,
//   pointer indirection — is pure Swift 6.3 language vocabulary. There is
//   NO compile-time capability provided by `Property.View` that pure
//   language cannot reproduce per-namespace.
//
//   The value of `Property.View*` is ecosystem-scale amortization:
//     - One declaration in Property View Primitives + one typealias per
//       container vs. N hand-rolled view structs across consumers.
//     - A uniform documented pattern for the tricky
//       withUnsafePointer(to:)/Builtin.addressOfBorrow interaction that
//       earlier research (`borrowing-read-accessor-test` v2) had to
//       discover through experimentation.
//     - A centralized `@_optimize(none)` / workaround anchor point if
//       upstream compiler bugs affecting this pattern re-emerge
//       (historically 149 sites regained full optimization when
//       `~Escapable` was removed, now restored — see
//       Research/property-view-escapable-removal.md).
//
// The ecosystem currently documents 19 consumer call-site migrations across
// 6 consumer packages (Research/borrowing-label-drop-rationale.md §3).
// Replacing `Property.View*` with pure language would require ~20-30 view
// struct declarations across those consumers, each one a potential site for
// the compiler bugs Property.View's centralized shape currently absorbs.
