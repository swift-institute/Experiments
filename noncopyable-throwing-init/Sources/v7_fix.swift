// MARK: - V7 Fix verification
//
// Root cause: pre-init throw paths + post-init conditional mutation of Optional<~Copyable>
// Fix: acquire the ~Copyable resource into a local BEFORE self init, then assign once.

// ============================================================================
// V7_min: Minimal reproduction of the compiler error
// ============================================================================

// V7_min: Minimal reproduction — DOES NOT COMPILE (kept as documentation)
//
// struct V7_min: ~Copyable {
//     var lockToken: V7Token?
//     init(mapFails: Bool, needsLock: Bool, lockFails: Bool) throws(V7Error) {
//         if mapFails { throw .mapping }          // pre-init throw
//         self.lockToken = nil                     // Phase 3
//         if needsLock {                           // Phase 4 conditional mutation
//             do {
//                 self.lockToken = try V7Token.acquire(fd: 1, shouldFail: lockFails)
//             } catch { throw .lock }
//         }
//     }
// }

// ============================================================================
// V7_fix: Same logic, restructured to avoid the bug
// Move lock acquisition into a local, assign to self once.
// ============================================================================

struct V7_fix: ~Copyable {
    var lockToken: V7Token?

    init(mapFails: Bool, needsLock: Bool, lockFails: Bool) throws(V7Error) {
        // Pre-init throw (same as V7_min)
        if mapFails { throw .mapping }

        // Acquire into local (still before self init)
        let token: V7Token?
        if needsLock {
            do {
                token = try V7Token.acquire(fd: 1, shouldFail: lockFails)
            } catch {
                throw .lock
            }
        } else {
            token = nil
        }

        // Phase 3: single unconditional assignment (no post-init mutation)
        self.lockToken = token
    }

    deinit { print("  V7_fix deinit") }
}

// ============================================================================
// V7_fix_full: Full reproduction (V7d pattern) with the fix applied
// ============================================================================

struct V7_fix_full: ~Copyable {
    var region: Int?
    let offsetDelta: Int
    let userLength: Int
    let access: String
    let sharing: String
    let safety: V7Safety
    var lockToken: NestedToken?

    init(
        fd: borrowing FakeDescriptor,
        range: V7Range,
        safety: V7Safety,
        statFails: Bool,
        mapFails: Bool,
        lockFails: Bool
    ) throws(V7Error) {
        // Phase 1: Validation with switch (throws before self)
        let userLen: Int
        switch range {
        case .bytes(_, let length):
            userLen = length
        case .whole:
            do throws(V7LockError) {
                if statFails { throw V7LockError.failed }
            } catch {
                throw .validation
            }
            userLen = 4096
        }

        let delta = 0

        // Phase 2: Map (throws before self)
        let baseAddress: Int
        do throws(V7LockError) {
            if mapFails { throw V7LockError.failed }
            baseAddress = Int(fd.rawValue) * 100
        } catch {
            throw .mapping
        }

        // Phase 2.5: Lock acquisition into local (throws before self)
        let lockToken: NestedToken?
        if case .coordinated(let kind, let scope) = safety {
            let lockRange = kind + scope
            do {
                lockToken = try NestedToken.acquire(
                    descriptor: fd,
                    range: lockRange,
                    shouldFail: lockFails
                )
            } catch {
                // In real code: try? Kernel.Memory.Map.unmap(region)
                throw .lock
            }
        } else {
            lockToken = nil
        }

        // Phase 3: Initialize ALL stored properties — no throws, no conditional mutation
        self.region = baseAddress
        self.offsetDelta = delta
        self.userLength = userLen
        self.access = "read"
        self.sharing = "shared"
        self.safety = safety
        self.lockToken = lockToken
    }

    deinit {
        print("  V7_fix_full deinit (token: \(lockToken != nil ? "set" : "nil"))")
    }
}

// ============================================================================
// Runner
// ============================================================================

func testV7Fix() {
    print("\n=== V7 Fix Verification ===\n")

    // V7_min is expected to fail compilation — commented out
    // test("V7_min") { try V7_min(mapFails: false, needsLock: true, lockFails: false) }

    print("V7_fix (minimal fix):")
    test("  no lock")      { try V7_fix(mapFails: false, needsLock: false, lockFails: false) }
    test("  with lock")    { try V7_fix(mapFails: false, needsLock: true, lockFails: false) }
    test("  lock fail")    { try V7_fix(mapFails: false, needsLock: true, lockFails: true) }
    test("  map fail")     { try V7_fix(mapFails: true, needsLock: true, lockFails: false) }

    print("\nV7_fix_full (full reproduction with fix):")
    do {
        let fd1 = FakeDescriptor(rawValue: 40)
        test("  unchecked") {
            try V7_fix_full(fd: fd1, range: .whole, safety: .unchecked,
                            statFails: false, mapFails: false, lockFails: false)
        }
    }
    do {
        let fd2 = FakeDescriptor(rawValue: 50)
        test("  coordinated") {
            try V7_fix_full(fd: fd2, range: .whole, safety: .coordinated(kind: 1, scope: 0),
                            statFails: false, mapFails: false, lockFails: false)
        }
    }
    do {
        let fd3 = FakeDescriptor(rawValue: 60)
        test("  lock fail") {
            try V7_fix_full(fd: fd3, range: .bytes(offset: 0, length: 1024),
                            safety: .coordinated(kind: 1, scope: 0),
                            statFails: false, mapFails: false, lockFails: true)
        }
    }
    do {
        let fd4 = FakeDescriptor(rawValue: 70)
        test("  stat fail") {
            try V7_fix_full(fd: fd4, range: .whole, safety: .unchecked,
                            statFails: true, mapFails: false, lockFails: false)
        }
    }
    do {
        let fd5 = FakeDescriptor(rawValue: 80)
        test("  map fail") {
            try V7_fix_full(fd: fd5, range: .whole, safety: .coordinated(kind: 1, scope: 0),
                            statFails: false, mapFails: true, lockFails: false)
        }
    }
}
