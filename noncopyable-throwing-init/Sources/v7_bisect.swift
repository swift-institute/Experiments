// MARK: - V7 Bisection: isolate which addition to V7c triggers the error
// V7c compiles. V7d fails. Each variant below adds ONE feature from V7d to V7c.

// ============================================================================
// V7e: V7c + more stored properties (7 total, matching real Map)
// ============================================================================

struct V7e: ~Copyable {
    var region: Int?
    let offsetDelta: Int
    let userLength: Int
    let access: String
    let sharing: String
    let safety: String
    var lockToken: NestedToken?

    init(fd: borrowing FakeDescriptor, needsLock: Bool, lockFails: Bool) throws(V7Error) {
        self.region = Int(fd.rawValue) * 100
        self.offsetDelta = 0
        self.userLength = 4096
        self.access = "read"
        self.sharing = "shared"
        self.safety = needsLock ? "coordinated" : "unchecked"
        self.lockToken = nil

        if needsLock {
            do {
                self.lockToken = try NestedToken.acquire(
                    descriptor: fd, range: 42, shouldFail: lockFails
                )
            } catch {
                throw .lock
            }
        }
    }

    deinit { print("  V7e deinit") }
}

// ============================================================================
// V7f: V7c + `if case .coordinated` instead of `if needsLock`
// ============================================================================

struct V7f: ~Copyable {
    var region: Int?
    let delta: Int
    var lockToken: NestedToken?

    init(fd: borrowing FakeDescriptor, safety: V7Safety, lockFails: Bool) throws(V7Error) {
        self.region = Int(fd.rawValue) * 100
        self.delta = 0
        self.lockToken = nil

        if case .coordinated(let kind, let scope) = safety {
            let lockRange = kind + scope
            do {
                self.lockToken = try NestedToken.acquire(
                    descriptor: fd, range: lockRange, shouldFail: lockFails
                )
            } catch {
                throw .lock
            }
        }
    }

    deinit { print("  V7f deinit") }
}

// ============================================================================
// V7g: V7c + switch block before Phase 3 (no do throws)
// ============================================================================

struct V7g: ~Copyable {
    var region: Int?
    let delta: Int
    var lockToken: NestedToken?

    init(
        fd: borrowing FakeDescriptor,
        range: V7Range,
        needsLock: Bool,
        lockFails: Bool
    ) throws(V7Error) {
        // Phase 1: switch before any self access
        let userLen: Int
        switch range {
        case .bytes(_, let length):
            userLen = length
        case .whole:
            userLen = 4096
        }
        _ = userLen

        // Phase 3: initialize
        self.region = Int(fd.rawValue) * 100
        self.delta = 0
        self.lockToken = nil

        // Phase 4
        if needsLock {
            do {
                self.lockToken = try NestedToken.acquire(
                    descriptor: fd, range: 42, shouldFail: lockFails
                )
            } catch {
                throw .lock
            }
        }
    }

    deinit { print("  V7g deinit") }
}

// V7h: V7c + do throws(T) block before Phase 3 — DOES NOT COMPILE
// V7i: V7c + switch with throw inside case — DOES NOT COMPILE
// V7j: V7c + switch + do throws(T) inside case — DOES NOT COMPILE
//
// All three fail with: "conditional initialization or destruction of noncopyable
// types is not supported"
//
// Root cause: pre-init throw paths + post-init conditional mutation of Optional<~Copyable>
// Fix: move ~Copyable resource acquisition into locals before self init (see v7_fix.swift)

// ============================================================================
// Runner
// ============================================================================

func testV7Bisect() {
    print("\n=== V7 Bisection ===\n")

    print("V7e (more stored properties):")
    do {
        let fd = FakeDescriptor(rawValue: 1)
        test("  with lock") { try V7e(fd: fd, needsLock: true, lockFails: false) }
    }

    print("\nV7f (if case .coordinated):")
    do {
        let fd = FakeDescriptor(rawValue: 2)
        test("  coordinated") { try V7f(fd: fd, safety: .coordinated(kind: 1, scope: 0), lockFails: false) }
    }

    print("\nV7g (switch, no throws in cases):")
    do {
        let fd = FakeDescriptor(rawValue: 3)
        test("  whole") { try V7g(fd: fd, range: .whole, needsLock: true, lockFails: false) }
    }

    // V7h, V7i, V7j commented out — all trigger the compiler error
    print("\nV7h/V7i/V7j: SKIPPED (do not compile — see comments above)")
}
