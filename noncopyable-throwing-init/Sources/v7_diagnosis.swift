// MARK: - Variant 7: Diagnose Memory.Map init error
// Purpose: Incrementally add features from real Memory.Map to V6's working pattern
//          to find the exact trigger for "conditional initialization or destruction
//          of noncopyable types is not supported"
//
// Approach: Each sub-variant adds exactly one feature from the real code.
//   V7a: Throwing assignment to Optional<~Copyable> (no do-catch)
//   V7b: V7a + do-catch with error conversion
//   V7c: V7b + Token wraps a ~Copyable field
//   V7d: V7c + borrowing ~Copyable parameter + do throws(T) blocks + switch
//
// Date: 2026-03-30

// ============================================================================
// Shared types for V7 variants
// ============================================================================

enum V7Error: Error { case validation, mapping, lock }
enum V7LockError: Error { case failed }

struct V7Token: ~Copyable, Sendable {
    let value: Int

    static func acquire(fd: Int, shouldFail: Bool) throws(V7LockError) -> V7Token {
        if shouldFail { throw .failed }
        return V7Token(value: fd)
    }

    static func acquireV7Error(fd: Int, shouldFail: Bool) throws(V7Error) -> V7Token {
        if shouldFail { throw .lock }
        return V7Token(value: fd)
    }

    deinit { print("  V7Token(\(value)) deinit") }
}

// ============================================================================
// V7a: V6 + throwing assignment (same error type, no do-catch)
// ============================================================================

struct V7a: ~Copyable {
    var region: Int?
    let delta: Int
    var lockToken: V7Token?

    init(fd: Int, needsLock: Bool, lockFails: Bool) throws(V7Error) {
        self.region = fd * 100
        self.delta = fd * 2
        self.lockToken = nil

        if needsLock {
            // Throwing assignment — error types match, no do-catch needed
            self.lockToken = try V7Token.acquireV7Error(fd: fd, shouldFail: lockFails)
        }
    }

    deinit {
        print("  V7a deinit (token: \(lockToken != nil ? "set" : "nil"))")
    }
}

// ============================================================================
// V7b: V7a + do-catch with error conversion (matches real Map pattern)
// ============================================================================

struct V7b: ~Copyable {
    var region: Int?
    let delta: Int
    var lockToken: V7Token?

    init(fd: Int, needsLock: Bool, lockFails: Bool) throws(V7Error) {
        self.region = fd * 100
        self.delta = fd * 2
        self.lockToken = nil

        if needsLock {
            do {
                self.lockToken = try V7Token.acquire(fd: fd, shouldFail: lockFails)
            } catch {
                throw .lock
            }
        }
    }

    deinit {
        print("  V7b deinit (token: \(lockToken != nil ? "set" : "nil"))")
    }
}

// ============================================================================
// V7c: V7b + Token wraps a ~Copyable field (like real Lock.Token wraps Descriptor)
// ============================================================================

struct FakeDescriptor: ~Copyable, Sendable {
    let rawValue: Int32

    static func dup(_ fd: borrowing FakeDescriptor) -> FakeDescriptor {
        FakeDescriptor(rawValue: fd.rawValue)
    }

    deinit { print("  FakeDescriptor(\(rawValue)) close") }
}

struct NestedToken: ~Copyable, Sendable {
    private let descriptor: FakeDescriptor
    private let range: Int
    private var isReleased: Bool

    static func acquire(
        descriptor: borrowing FakeDescriptor,
        range: Int,
        shouldFail: Bool
    ) throws(V7LockError) -> NestedToken {
        let duped = FakeDescriptor.dup(descriptor)
        if shouldFail { throw .failed }
        return NestedToken(descriptor: duped, range: range, isReleased: false)
    }

    deinit {
        if !isReleased { print("  NestedToken unlock") }
    }
}

struct V7c: ~Copyable {
    var region: Int?
    let delta: Int
    var lockToken: NestedToken?

    init(fd: borrowing FakeDescriptor, needsLock: Bool, lockFails: Bool) throws(V7Error) {
        self.region = Int(fd.rawValue) * 100
        self.delta = Int(fd.rawValue) * 2
        self.lockToken = nil

        if needsLock {
            do {
                self.lockToken = try NestedToken.acquire(
                    descriptor: fd,
                    range: 42,
                    shouldFail: lockFails
                )
            } catch {
                throw .lock
            }
        }
    }

    deinit {
        print("  V7c deinit (token: \(lockToken != nil ? "set" : "nil"))")
    }
}

// ============================================================================
// V7d: Full reproduction — V7c + switch + do throws(T) + enum matching
// Mirrors real Memory.Map init structure as closely as possible.
// ============================================================================

enum V7Range {
    case bytes(offset: Int, length: Int)
    case whole
}

enum V7Safety: Equatable {
    case coordinated(kind: Int, scope: Int)
    case unchecked
}

// V7d: Full reproduction — DOES NOT COMPILE (pre-init throws + post-init conditional mutation)
// Moved to v7_fix.swift as V7_fix_full with the workaround applied.

// ============================================================================
// Test runner
// ============================================================================

func testV7() {
    print("\n=== V7 Diagnosis ===\n")

    print("V7a (throwing assignment, no do-catch):")
    test("  no lock")   { try V7a(fd: 1, needsLock: false, lockFails: false) }
    test("  with lock") { try V7a(fd: 2, needsLock: true, lockFails: false) }
    test("  lock fail")  { try V7a(fd: 3, needsLock: true, lockFails: true) }

    print("\nV7b (throwing assignment + do-catch):")
    test("  no lock")   { try V7b(fd: 1, needsLock: false, lockFails: false) }
    test("  with lock") { try V7b(fd: 2, needsLock: true, lockFails: false) }
    test("  lock fail")  { try V7b(fd: 3, needsLock: true, lockFails: true) }

    print("\nV7c (nested ~Copyable + borrowing):")
    do {
        let fd1 = FakeDescriptor(rawValue: 10)
        test("  no lock") { try V7c(fd: fd1, needsLock: false, lockFails: false) }
    }
    do {
        let fd2 = FakeDescriptor(rawValue: 20)
        test("  with lock") { try V7c(fd: fd2, needsLock: true, lockFails: false) }
    }
    do {
        let fd3 = FakeDescriptor(rawValue: 30)
        test("  lock fail") { try V7c(fd: fd3, needsLock: true, lockFails: true) }
    }

    // V7d: commented out — does not compile (see v7_fix.swift for fixed version)
    print("\nV7d: SKIPPED (does not compile — see v7_fix.swift)")
}
