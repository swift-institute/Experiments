// MARK: - Phase 7 (Gap c) — CROSS-MODULE: DOWNSTREAM conformers in the EXECUTABLE module
// conforming the LIB module's family protocols, inheriting the LIB's default bodies across the
// module boundary. This is the real [EXP-017] test: a consumer module rides upstream family
// defaults for D1 (copy-self makeIterator), route-3 forEach (C), and route-2 (consuming drain).
//
// These conformers are `internal` — the honest shape for a leaf EXECUTABLE consuming an upstream
// library (nothing downstream re-imports them, so no `public import` is needed). The conformances
// to the LIB's protocols ARE the cross-module test; the inherited default bodies live in the lib.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), arm64-apple-macosx26.0
// Result: CONFIRMED — D1, route-3 forEach (C), and route-2 ALL survive a module boundary in
//   debug AND release, warning-clean. Downstream conformers (this module) inherit default bodies
//   defined in the lib module.
//   Runs:  gap (c) cross-module D1 ........ [14, 25, 36]
//          gap (c) cross-module forEach ... sum=600
//          gap (c) cross-module route-2 ... total=10
// One expected cross-module effect surfaced (NOT a defect): under InternalImportsByDefault +
// MemberImportVisibility (ecosystem flags), the consumer must `import iteration_architecture_toy_lib`
// for the inherited `makeIteratorD1()` / `next()` / `forEach` members to be visible at the call
// site; and a leaf executable's conformers are best left `internal` (a `public` conformance to an
// internally-imported protocol requires `public import`). Diagnostics seen pre-fix:
//   error: instance method 'makeIteratorD1()' is not available due to missing import of defining
//          module 'iteration_architecture_toy_lib' [#MemberImportVisibility]
//   error: cannot use protocol 'Sequenceable' in a public or '@usableFromInline' conformance;
//          'iteration_architecture_toy_lib' was not imported publicly
// Both are routine consumer-side import discipline, resolved by adding the import (call site) and
// using internal conformers (leaf executable). The D1/C/route-2 mechanics themselves are unchanged
// across the boundary.

import iteration_architecture_toy_lib

// MARK: XM D1 — downstream conformer of the lib's FamD.`Protocol`. The makeIteratorD1 BODY lives in
// the lib; XMFamDImpl inherits it across the module boundary. The ~Escapable CopyView also lib-side.
struct XMFamDImpl: ~Copyable {
    var storage: [Int]
    init(_ storage: [Int]) { self.storage = storage }
}

extension XMFamDImpl: iteration_architecture_toy_lib.FamD.`Protocol` {
    typealias Element = Int
    typealias View = iteration_architecture_toy_lib.Memory.CopyView<Int>
    var view: iteration_architecture_toy_lib.Memory.CopyView<Int> {
        @_lifetime(borrow self) get {
            iteration_architecture_toy_lib.Memory.CopyView(storage.span)
        }
    }
    // makeIteratorD1() inherited from the LIB's FamD.`Protocol` default — cross-module delegation.
}

// MARK: XM route-3 (C) — downstream ~Copyable conformer riding the lib's MyFamily forEach default.
// Reuses the executable module's own `Resource` (~Copyable) element + a lib-side SpanView backing.
@safe
struct XMOwned: ~Copyable {
    let buffer: UnsafeMutableBufferPointer<Resource>
    init(_ ids: [Int]) {
        unsafe buffer = .allocate(capacity: ids.count)
        for i in ids.indices {
            unsafe buffer.initializeElement(at: i, to: Resource(id: ids[i]))
        }
    }
    deinit {
        unsafe buffer.deinitialize()
        unsafe buffer.deallocate()
    }
    var span: Span<Resource> {
        @_lifetime(borrow self) get {
            let s = unsafe Span(_unsafeElements: UnsafeBufferPointer(buffer))
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

extension XMOwned: iteration_architecture_toy_lib.MyFamily.`Protocol` {
    typealias Element = Resource
    typealias Backing = iteration_architecture_toy_lib.Memory.SpanView<Resource>
    var backing: iteration_architecture_toy_lib.Memory.SpanView<Resource> {
        @_lifetime(borrow self) get {
            iteration_architecture_toy_lib.Memory.SpanView(self.span)
        }
    }
    // forEach((borrowing Resource) -> Void) inherited from the LIB's MyFamily default — cross-module.
}

// MARK: XM route-2 — downstream conformer riding the lib's Memory.Contiguous + Sequenceable defaults.
struct XMDrainable: ~Copyable {
    var storage: [Int]
    init(_ storage: [Int]) { self.storage = storage }
}

extension XMDrainable: iteration_architecture_toy_lib.Memory.Contiguous {
    typealias Element = Int
    var span: Span<Int> {
        @_lifetime(borrow self) get { storage.span }
    }
}

extension XMDrainable: iteration_architecture_toy_lib.Sequenceable {
    typealias Iterator = iteration_architecture_toy_lib.Iterator.Drain<XMDrainable>
    // makeIterator() consuming inherited from the LIB's Route-2 family default — cross-module.
}

// MARK: VERDICT (Gap c — cross-module): CONFIRMED. The D1 copy-self makeIterator delegation, the
// route-3 forEach (shape C), and the route-2 consuming drain ALL compose across a real module
// boundary (lib target → executable target) in debug AND release, warning-clean under the full
// ecosystem settings. The family-default bodies live in the upstream lib; downstream conformers
// inherit them. The only cross-module deltas are routine import discipline (consumer must import
// the lib; leaf-executable conformers stay internal), NOT changes to the lifetime mechanics.
// IMPLICATION: the §5 single-module caveat of the envelope v1.1.0 is lifted for D1/C/route-2 —
// they are validated cross-module + release, the shape real-package fan-out will use.
