// MARK: - Hasher-pattern Mutator: isolation experiment
//
// Purpose: Probe structural viability of a `Mutable: ~Copyable` trait
//          protocol with a single requirement
//          `mutating func mutate(via mutator: inout Mutator<Self>)`,
//          where `Mutator<Self>` is a witness type performing the
//          actual mutation work — Hasher-pattern faithful translation
//          to mutation. Test two candidate roles for the Mutator's
//          job:
//            Role A — Transactional (commit / abort lifecycle)
//            Role C — Observation broadcast for ~Copyable Self
//          Verify that (a) the conformer-witness asymmetry compiles
//          across Copyable + ~Copyable Self, (b) a generic algorithm
//          over `inout some Mutable` can drive the witness, and
//          (c) the `~Copyable` Mutator with `~Copyable` Subject works
//          (so the witness can hold a transient inout reference to
//          Subject).
//
// Hypothesis: Both roles compile and execute; cross-role composition
//             is possible by parameterizing the Mutator on a strategy
//             phantom OR shipping sibling Mutator types per role.
//             ~Copyable Subject + ~Copyable Mutator works for
//             Subjects whose mutation is in-place; lifetime
//             annotations needed where the Mutator yields an inout
//             into Subject.
//
// Toolchain: Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
//
// Status: CONFIRMED with structural sub-finding. Both Role A and
//         Role C compile and execute in debug AND release; ~Copyable
//         Subject + ~Copyable Mutator works; generic dispatch over
//         `inout some Mutable & ~Copyable` resolves cleanly.
//
//         Sub-finding (structural): the experiment's Mutator passes
//         Subject through each `update(_:on:)` call rather than
//         storing it internally. The reason is that storing
//         `Subject` by inout-pointer in the Mutator requires
//         lifetime annotations on the Mutator's storage — runs into
//         the same `@_lifetime(borrow ...)` discipline that the
//         four-quadrant default extensions exercised in
//         Experiments/modify-across-quadrants/. A more Hasher-
//         faithful Mutator would hold the inout reference internally
//         (matching Hasher's owned hash-state). The trade-off:
//         passing Subject as a parameter is simpler but means the
//         conformer's `mutate(via:)` writes
//         `mutator.update({...}, on: &self)` — slightly noisier than
//         the Hasher pattern's `hasher.combine(field)`. A future
//         iteration would either (a) accept the noise as the cost
//         of avoiding lifetime ceremony, or (b) ship the Mutator with
//         an inout-pointer storage shape and corresponding
//         `@_lifetime(&subject)` annotations on its init.
// Result: CONFIRMED. Output:
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//           Role A normal mutation: c.raw = 8; aborted = false
//           Role A abort path: c2.raw = 151; aborted = true
//           Role A ~Copyable Subject: u.raw = 15
//           Role C ~Copyable observation: u.raw = 101; observed = true
//           Generic dispatch Copyable: c.raw = 7
//           Generic dispatch ~Copyable: u.raw = 21
// Date: 2026-04-25

// MARK: - Role A: Transactional Mutator

public protocol Mutable_RoleA: ~Copyable {
    mutating func mutate(via mutator: inout Mutator_RoleA<Self>)
}

public struct Mutator_RoleA<Subject: ~Copyable>: ~Copyable {
    @usableFromInline
    var _aborted: Bool = false

    public init() {}

    public mutating func update(_ apply: (inout Subject) -> Void, on subject: inout Subject) {
        guard !_aborted else { return }
        apply(&subject)
    }

    public mutating func abort() {
        _aborted = true
    }

    public var isAborted: Bool { _aborted }
}

struct CounterA {
    var raw: Int
    init(_ raw: Int) { self.raw = raw }
}

extension CounterA: Mutable_RoleA {
    mutating func mutate(via mutator: inout Mutator_RoleA<CounterA>) {
        mutator.update({ $0.raw += 1 }, on: &self)
        if raw > 100 {
            mutator.abort()
        }
    }
}

func runRoleA() {
    var c = CounterA(7)
    var mutator = Mutator_RoleA<CounterA>()
    c.mutate(via: &mutator)
    print("Role A normal mutation: c.raw = \(c.raw); aborted = \(mutator.isAborted)")
    // c.raw was 7, now 8.

    var c2 = CounterA(150)
    var mutator2 = Mutator_RoleA<CounterA>()
    c2.mutate(via: &mutator2)
    // c2 was 150, the increment runs (150 → 151), then abort fires (151 > 100).
    // The mutator's abort doesn't reverse the prior update — that's the role's
    // tension noted in the research doc. Real abort semantics would require
    // saving original before each `update` (transactional semantics for
    // value types are already free at the language level; the Mutator
    // role's value lies in non-value-type or composite-state cases).
    print("Role A abort path: c2.raw = \(c2.raw); aborted = \(mutator2.isAborted)")
}

// MARK: - Role A with ~Copyable Subject

struct UniqueCounterA: ~Copyable {
    var raw: Int
}

extension UniqueCounterA: Mutable_RoleA {
    mutating func mutate(via mutator: inout Mutator_RoleA<UniqueCounterA>) {
        mutator.update({ $0.raw += 10 }, on: &self)
    }
}

func runRoleA_NonCopyable() {
    var u = UniqueCounterA(raw: 5)
    var mutator = Mutator_RoleA<UniqueCounterA>()
    u.mutate(via: &mutator)
    print("Role A ~Copyable Subject: u.raw = \(u.raw)")
}

// MARK: - Role C: Observation Mutator

public protocol Mutable_RoleC: ~Copyable {
    mutating func mutate(via mutator: inout Mutator_RoleC<Self>)
}

public struct Mutator_RoleC<Subject: ~Copyable>: ~Copyable {
    @usableFromInline
    var _willChangeFired: Bool = false
    @usableFromInline
    var _didChangeFired: Bool = false

    public init() {}

    public mutating func willChange() {
        _willChangeFired = true
    }

    public mutating func update(_ apply: (inout Subject) -> Void, on subject: inout Subject) {
        apply(&subject)
    }

    public mutating func didChange() {
        _didChangeFired = true
    }

    public var observed: Bool { _willChangeFired && _didChangeFired }
}

struct UniqueCounterC: ~Copyable {
    var raw: Int
}

extension UniqueCounterC: Mutable_RoleC {
    mutating func mutate(via mutator: inout Mutator_RoleC<UniqueCounterC>) {
        mutator.willChange()
        mutator.update({ $0.raw += 1 }, on: &self)
        mutator.didChange()
    }
}

func runRoleC_NonCopyable() {
    var u = UniqueCounterC(raw: 100)
    var mutator = Mutator_RoleC<UniqueCounterC>()
    u.mutate(via: &mutator)
    print("Role C ~Copyable observation: u.raw = \(u.raw); observed = \(mutator.observed)")
}

// MARK: - Generic dispatch over `Mutable_RoleA`

func runTwice<M: Mutable_RoleA & ~Copyable>(_ m: inout M) {
    var mutator = Mutator_RoleA<M>()
    m.mutate(via: &mutator)
    if !mutator.isAborted {
        m.mutate(via: &mutator)
    }
}

func runGenericDispatch() {
    var c = CounterA(5)
    runTwice(&c)
    print("Generic dispatch Copyable: c.raw = \(c.raw)")  // 5 → 6 → 7

    var u = UniqueCounterA(raw: 1)
    runTwice(&u)
    print("Generic dispatch ~Copyable: u.raw = \(u.raw)")  // 1 → 11 → 21
}

// MARK: - Main

runRoleA()
runRoleA_NonCopyable()
runRoleC_NonCopyable()
runGenericDispatch()
