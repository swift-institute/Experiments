// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// V4: Wrapper on a ~Copyable base fails.
//
// The five-step `_modify` dance requires the base to be transferrable by
// value. A ~Copyable base's ownership is linear — the dance falls apart
// at the "reassign self to a fresh empty value" step.
//
// This file compiles. The failing accessor is commented out with the
// expected compiler errors inline. Uncomment the marked block to reproduce.

public struct Wrapper<Tag, Base: ~Copyable>: ~Copyable {
    @usableFromInline
    var base: Base

    @inlinable
    public init(_ base: consuming Base) {
        self.base = base
    }
}

public struct Ring: ~Copyable {
    @usableFromInline
    var _storage: [Int] = []

    public init() {}

    @usableFromInline
    mutating func _pushBack(_ element: Int) {
        _storage.append(element)
    }
}

extension Ring {
    public enum Push {}

    // ─────────────────────────────────────────────────────────────────────
    // Uncomment the block below to reproduce the failure.
    //
    // public var push: Wrapper<Push, Ring> {
    //     _modify {
    //         var proxy = Wrapper<Push, Ring>(consume self)
    //         self = Ring()                  // error: cannot partially
    //                                        //   consume-and-reinitialize
    //                                        //   storage of a non-copyable
    //                                        //   'self' here
    //         defer { self = proxy.base }    // error: same
    //         yield &proxy
    //     }
    // }
    //
    // Fundamentally: with Copyable, "transfer into proxy, put back on exit"
    // is the idiom. With ~Copyable, there's nothing to transfer — the base
    // is right where it is, and we need the proxy to point at it instead
    // of owning it. V5 takes that next step.
    // ─────────────────────────────────────────────────────────────────────
}

@main
enum Main {
    static func main() {
        let ring = Ring()
        _ = consume ring
        print("V4: Wrapper's _modify dance cannot be applied to a ~Copyable base.")
        print("    Uncomment the block in main.swift to reproduce the compiler error.")
        print("    See V5 for the pointer-backed alternative.")
    }
}
