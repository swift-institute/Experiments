// SUPERSEDED: See noncopyable-access-patterns
// MARK: - ~Copyable Consumption Enforcement for Inline Storage Cleanup
//
// Purpose:  Can Swift's ~Copyable ownership rules enforce compile-time
//           cleanup guarantees for inline storage types — preventing silent
//           element leaks when a consumer forgets to call cleanup?
//
// Context:  The buffer-primitives architecture needs a guarantee that inline
//           storage elements are deinitialized before the storage struct is
//           destroyed. Currently this relies on convention (consumer calls
//           removeAll()) or deinit chains broken by #86652. If ~Copyable
//           types WITHOUT deinit force explicit consumption, the compiler
//           itself would enforce the cleanup contract.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform:  macOS 26.0 (arm64)
//
// Result:   CONFIRMED — consuming func in deinit body is the key pattern.
//           No compile-time enforcement for "must consume" exists (V5 REFUTED).
//           But consuming calls in deinit bodies work cross-module in both
//           debug and release, enabling a clean 3-layer chain:
//             DataStructure(deinit) → buffer.removeAll() [consuming]
//               → storage.cleanup() [consuming]
//           Only the data structure needs deinit + _deinitWorkaround.
// Date:     2026-04-01


// ==========================================================================
// MARK: - V1: Baseline — ~Copyable @_rawLayout without deinit, implicit drop
// ==========================================================================
// Hypothesis: A ~Copyable struct without deinit that holds @_rawLayout can
//             go out of scope without explicit consumption. The compiler
//             does implicit member destruction — no compile error.
// Result: CONFIRMED — compiles and runs, implicit drop, no error

struct InlineStorage_V1<let N: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: Int, count: N)
    struct _Raw: ~Copyable { init() {} }

    var _storage: _Raw

    init() { _storage = _Raw() }
}

func test_v1() {
    let _ = InlineStorage_V1<4>()
    // Goes out of scope — does this compile without explicit consumption?
    print("V1: compiled and ran — implicit drop of ~Copyable without deinit")
}


// ==========================================================================
// MARK: - V2: Consuming cleanup — can deinit consume a stored property?
// ==========================================================================
// Hypothesis: A `consuming func cleanup()` on storage cannot be called from
//             the owning struct's deinit, because deinit does not transfer
//             ownership of stored properties to the deinit body.
// Result: REFUTED — consuming methods CAN be called on stored properties
//         in deinit. Deinit body has special ownership: it can consume
//         members as part of destruction. Verified same-module and cross-
//         module with @_rawLayout + value generics, debug and release.
//
// IMPORTANT: A type with deinit CANNOT have a separate `consuming func`
//            that consumes stored properties ("cannot partially consume
//            'self' when it has a deinitializer"). Only the deinit body
//            itself gets this privilege.
//
// NOTE: `discard self` requires a deinit on the type (SE-0390), so we
//       cannot use it on a type without deinit. This variant tests whether
//       consuming methods are callable on stored properties inside deinit.

struct InlineStorage_V2<let N: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: Int, count: N)
    struct _Raw: ~Copyable { init() {} }

    var _storage: _Raw

    init() { _storage = _Raw() }

    consuming func cleanup() {
        print("V2: storage.cleanup() called (consuming)")
        // In real code: iterate tracking, deinitialize elements
    }
}

struct Buffer_V2<let N: Int>: ~Copyable {
    var header: Int
    var storage: InlineStorage_V2<N>

    init() {
        header = 0
        storage = InlineStorage_V2<N>()
    }

    // Consuming call in deinit WORKS — contrary to initial hypothesis.
    // Uncommented to demonstrate:
    deinit {
        storage.cleanup()
    }
}

func test_v2() {
    let _ = Buffer_V2<4>()
    print("V2: consuming call in deinit WORKS — deinit can consume stored properties")
}


// ==========================================================================
// MARK: - V3a: Mutating cleanup in deinit — DIRECT (expected: fails)
// ==========================================================================
// Hypothesis: A mutating method on storage CANNOT be called directly from
//             deinit because `self` is immutable in deinit.
// Result: CONFIRMED — error: "cannot use mutating member on immutable value"
//
// UNCOMMENT TO TEST (expected compile error):
// struct Buffer_V3a<let N: Int>: ~Copyable {
//     var storage: InlineStorage_V3<N>
//     init() { storage = InlineStorage_V3<N>() }
//     deinit { storage.deinitializeAll() }  // error: self is immutable
// }

struct InlineStorage_V3<let N: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: Int, count: N)
    struct _Raw: ~Copyable { init() {} }

    var _slots: Int  // simulates bitvector
    var _storage: _Raw

    init() {
        _slots = 0
        _storage = _Raw()
    }

    mutating func deinitializeAll() {
        print("V3: storage.deinitializeAll() called (mutating)")
        _slots = 0
    }
}

func test_v3a() {
    print("V3a: direct mutating call in deinit fails — self is immutable in deinit")
}


// ==========================================================================
// MARK: - V3b: Mutating cleanup in deinit — via UnsafeMutablePointer
// ==========================================================================
// Hypothesis: The unsafe pointer cast workaround used by Tree.N.Inline
//             allows mutating methods to be called from deinit.
//             This is the pattern that actually works in production.
// Result: CONFIRMED — unsafe pointer cast enables mutating calls in deinit.
//         However, V2 shows consuming calls work directly — the unsafe
//         pointer workaround may be unnecessary for the consuming pattern.

struct Buffer_V3b<let N: Int>: ~Copyable {
    var header: Int
    var storage: InlineStorage_V3<N>

    init() {
        header = 0
        storage = InlineStorage_V3<N>()
    }

    deinit {
        unsafe withUnsafePointer(to: storage) { ptr in
            unsafe UnsafeMutablePointer(mutating: ptr).pointee.deinitializeAll()
        }
    }
}

func test_v3b() {
    let _ = Buffer_V3b<4>()
    print("V3b: buffer going out of scope — deinit uses unsafe pointer workaround")
}


// ==========================================================================
// MARK: - V4: Full chain — data structure deinit drives cleanup, no buffer deinit
// ==========================================================================
// Hypothesis: With no deinit on buffer or storage, the data structure's
//             deinit can drive cleanup via method calls through the chain.
//             Buffer and storage are implicitly destroyed (no element cleanup)
//             AFTER the data structure's deinit has already drained them.
// Result: CONFIRMED — uses unsafe pointer workaround for mutating calls.
//         See cross-module experiment (/tmp/three-layer-consuming/) for the
//         consuming-based variant that avoids the unsafe workaround entirely.

struct InlineStorage_V4<let N: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: Int, count: N)
    struct _Raw: ~Copyable { init() {} }

    var _slots: Int
    var _storage: _Raw

    init() {
        _slots = 0
        _storage = _Raw()
    }

    mutating func deinitializeAll() {
        print("V4: storage.deinitializeAll() called")
        _slots = 0
    }
}

struct Buffer_V4<let N: Int>: ~Copyable {
    var header: Int
    var storage: InlineStorage_V4<N>
    // NO deinit

    init() {
        header = 0
        storage = InlineStorage_V4<N>()
    }

    mutating func removeAll() {
        print("V4: buffer.removeAll() called")
        storage.deinitializeAll()
        header = 0
    }
}

struct DataStructure_V4<let N: Int>: ~Copyable {
    private var _deinitWorkaround: AnyObject? = nil
    var buffer: Buffer_V4<N>

    init() {
        buffer = Buffer_V4<N>()
    }

    deinit {
        unsafe withUnsafePointer(to: buffer) { ptr in
            unsafe UnsafeMutablePointer(mutating: ptr).pointee.removeAll()
        }
    }
}

func test_v4() {
    let _ = DataStructure_V4<4>()
    print("V4: data structure going out of scope — deinit should drive cleanup chain")
}


// ==========================================================================
// MARK: - V5: Can we PREVENT implicit drop? (compile-time enforcement)
// ==========================================================================
// Hypothesis: There is NO Swift mechanism that makes it a compile error to
//             let a ~Copyable value go out of scope without explicit
//             consumption. ~Copyable means "cannot be copied", not "must be
//             explicitly consumed." The compiler always auto-destroys members.
//
// Test: Create a ~Copyable type with only consuming cleanup API. See if the
//       compiler forces the consumer to call it.
// Result: REFUTED — ~Copyable without deinit compiles fine when dropped
//         without calling drain(). No compile error. Swift does NOT have
//         linear type enforcement (must-consume semantics).

struct MustConsume<let N: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: Int, count: N)
    struct _Raw: ~Copyable { init() {} }

    var _storage: _Raw

    init() { _storage = _Raw() }

    // Only cleanup path is consuming
    consuming func drain() -> Int {
        print("V5: drain() called")
        return 0
    }
}

func test_v5_without_drain() {
    let _ = MustConsume<4>()
    // Does this compile? If yes → no enforcement
    // Does this error? If yes → enforcement exists
    print("V5a: compiled without calling drain() — no enforcement")
}

func test_v5_with_drain() {
    let s = MustConsume<4>()
    let _ = s.drain()
    print("V5b: compiled with drain() called")
}


// ==========================================================================
// MARK: - V6: Runtime enforcement — debug trap on forgotten cleanup
// ==========================================================================
// Hypothesis: If compile-time enforcement is impossible, a runtime assertion
//             in deinit ("was cleaned up" flag) is the best available safety
//             mechanism.
// Result: CONFIRMED — runtime detection works (prints BUG message on
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
//         forgotten cleanup). But requires deinit on storage, which
//         reintroduces #86652 constraints. Trade-off: safety vs composability.

struct SafeStorage_V6<let N: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: Int, count: N)
    struct _Raw: ~Copyable { init() {} }

    var _cleaned: Bool
    var _storage: _Raw

    init() {
        _cleaned = false
        _storage = _Raw()
    }

    mutating func deinitializeAll() {
        print("V6: deinitializeAll() called")
        _cleaned = true
    }

    // Note: this deinit EXISTS but only asserts — it doesn't do element cleanup.
    // The actual cleanup is via deinitializeAll(). Deinit is just a safety check.
    // This requires _deinitWorkaround at the data structure level to fire.
    deinit {
        if !_cleaned {
            print("V6: BUG — storage destroyed without cleanup!")
            // In production: preconditionFailure("...")
        }
    }
}

func test_v6_safe() {
    var s = SafeStorage_V6<4>()
    s.deinitializeAll()
    print("V6a: cleaned up before drop — safe")
}

func test_v6_unsafe() {
    let _ = SafeStorage_V6<4>()
    print("V6b: dropped without cleanup — deinit should trap")
}


// ==========================================================================
// MARK: - Run All
// ==========================================================================

test_v1()
print("---")
test_v2()
print("---")
test_v3a()
test_v3b()
print("---")
test_v4()
print("---")
test_v5_without_drain()
test_v5_with_drain()
print("---")
test_v6_safe()
test_v6_unsafe()

// ==========================================================================
// MARK: - Results Summary
// ==========================================================================
// V1:  CONFIRMED — ~Copyable @_rawLayout can be implicitly dropped (no enforcement)
// V2:  REFUTED   — consuming calls in deinit WORK (key discovery)
// V3a: CONFIRMED — mutating calls in deinit fail (self is immutable)
// V3b: CONFIRMED — unsafe pointer workaround enables mutating in deinit
// V4:  CONFIRMED — top-down chain via unsafe pointer workaround works
// V5a: REFUTED   — no compile-time must-consume enforcement exists
// V5b: CONFIRMED — explicit drain() works (but not enforced)
// V6a: CONFIRMED — runtime detection via deinit assertion works
// V6b: CONFIRMED — forgotten cleanup detected at runtime
//
// ==========================================================================
// MARK: - Cross-Module Experiments (outside this package)
// ==========================================================================
// CM1: 2-module (StorageLib → BufferLib → Consumer)
//      WITHOUT _deinitWorkaround: FAILS — deinit doesn't fire (#86652)
//      WITH _deinitWorkaround:    CONFIRMED — debug + release
//
// CM2: 3-module consuming chain (StorageLib → BufferLib → DataStructureLib → Consumer)
//      Pattern: Tree.deinit → buffer.removeAll() [consuming] → storage.cleanup() [consuming]
//      Only Tree has deinit + _deinitWorkaround. Buffer and Storage have NO deinit.
//      CONFIRMED — debug + release, all elements properly deinitialized
//
// ==========================================================================
// MARK: - Key Discovery
// ==========================================================================
// Swift's deinit body has special ownership semantics: it CAN consume stored
// properties (transferring ownership to consuming methods). This is different
// from `self` being immutable (which blocks mutating calls) — consuming takes
// ownership rather than mutating.
//
// This enables a clean 3-layer pattern where ONLY the top-level data structure
// has a deinit, and cleanup flows down via consuming method calls:
//
//   DataStructure(deinit + _deinitWorkaround)
//     → buffer.removeAll()    [consuming — no Buffer deinit needed]
//       → storage.cleanup()   [consuming — no Storage deinit needed]
//
// No #86652 triggers on Storage or Buffer because they have no deinit.
// No unsafe pointer workaround needed because consuming (not mutating).
// Only one _deinitWorkaround per type hierarchy (at data structure level).
//
// Trade-off: standalone buffer use without a data structure wrapper will
// silently leak elements (no deinit to catch it). This is acceptable if
// inline buffers are treated as composition primitives, not user-facing types.
//
// Constraint discovered: a type WITH deinit cannot have a separate
// `consuming func` that consumes stored properties. Error: "cannot partially
// consume 'self' when it has a deinitializer". Only the deinit body itself
// gets this privilege. Types WITHOUT deinit can freely have consuming funcs.
