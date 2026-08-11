// MARK: - ~Escapable output as a plain Iterator.Protocol Element (real-protocol conformance)
//
// Purpose: confirm that an iterator PRODUCING a genuinely ~Escapable borrowed view conforms to the
//          REAL foundation Iterator.Protocol (associatedtype Element: ~Copyable & ~Escapable,
//          @_lifetime(&self) mutating func next()) and builds+runs on 6.3.2. This is the
//          decompose-and-compose answer for ~Escapable output: reuse the general foundation
//          primitive directly — NO Ownership.Borrow wrapping, NO bespoke per-Map protocol.
// Hypothesis: the genuine P4 borrowed-view shape (proven in `escapable-output-borrow-lend`) satisfies
//             the real Iterator.Protocol requirement unchanged — the conformance is the only new variable.
//
// Toolchain: Apple Swift 6.3.2 (swift-6.3.2-RELEASE)
// Platform: macOS 26 (arm64)
// Result: CONFIRMED — builds + runs on 6.3.2, debug AND release; output `sum = 30`. A genuine
//         ~Escapable borrowed-view iterator conforms to the real foundation Iterator.Protocol
//         (Element: ~Escapable) directly, yielded under @_lifetime(&self); teardown via deinit (no
//         finish() footgun). So ~Escapable output reuses the general primitive — no Ownership.Borrow
//         wrapping, no bespoke per-Map protocol. Date: 2026-05-26.

import Iterator_Primitives

// A genuine ~Escapable borrowed view over iterator-owned storage (mirrors experiment P4 — a real
// borrow via a pointer, lifetime-tied to its owner; NOT an immortal cheat).
public struct Borrowed: ~Escapable {
    @usableFromInline let p: UnsafePointer<Int>
    @_lifetime(borrow owner)
    public init(_ p: UnsafePointer<Int>, borrowing owner: borrowing some ~Copyable & ~Escapable) {
        self.p = p
    }
    public var value: Int { unsafe p.pointee }
}

// An iterator that produces the ~Escapable `Borrowed` view per step — conforming to the REAL
// Iterator.Protocol with Element == Borrowed. Slot teardown via deinit (proven OK on a
// ~Copyable & ~Escapable struct), so no manual finish().
public struct EscMap: ~Copyable, ~Escapable {
    @usableFromInline let slot: UnsafeMutablePointer<Int>
    @usableFromInline var index: Int

    @_lifetime(immortal)
    public init() {
        slot = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        slot.initialize(to: 0)
        index = 0
    }

    deinit {
        slot.deinitialize(count: 1)
        slot.deallocate()
    }

    @_lifetime(&self)
    public mutating func next() -> Borrowed? {
        guard index < 3 else { return nil }
        slot.pointee = index * 10
        index += 1
        return Borrowed(UnsafePointer(slot), borrowing: self)
    }
}

// The only new thing under test: does EscMap satisfy the REAL Iterator.Protocol?
extension EscMap: Iterator.`Protocol` {
    public typealias Element = Borrowed
    public typealias Failure = Never
}

var it = EscMap()
var sum = 0
while let v = it.next() {
    sum += v.value   // 0 + 10 + 20
}
print("escapable-element Iterator.Protocol conformance: sum = \(sum)")  // expect 30
