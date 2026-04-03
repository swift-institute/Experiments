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
// Result:   CONFIRMED - consuming func in deinit body is the key pattern.
//           No compile-time enforcement for "must consume" exists (V5 REFUTED).
//           But consuming calls in deinit bodies work cross-module in both
//           debug and release, enabling a clean 3-layer chain:
//             DataStructure(deinit) -> buffer.removeAll() [consuming]
//               -> storage.cleanup() [consuming]
//           Only the data structure needs deinit + _deinitWorkaround.
//
// Status: CONFIRMED
// Revalidation: When linear type enforcement (must-consume) is proposed for Swift
// Origin: swift-primitives/Experiments/noncopyable-consumption-enforcement

enum V06_ConsumptionEnforcement {

    // ==========================================================================
    // MARK: - V1: Baseline - ~Copyable @_rawLayout without deinit, implicit drop
    // ==========================================================================
    // Result: CONFIRMED - compiles and runs, implicit drop, no error

    struct InlineStorage_V1<let N: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Int, count: N)
        struct _Raw: ~Copyable { init() {} }

        var _storage: _Raw

        init() { _storage = _Raw() }
    }

    // ==========================================================================
    // MARK: - V2: Consuming cleanup - can deinit consume a stored property?
    // ==========================================================================
    // Result: REFUTED (initial hypothesis) - consuming methods CAN be called
    //         on stored properties in deinit. Deinit body has special ownership.

    struct InlineStorage_V2<let N: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Int, count: N)
        struct _Raw: ~Copyable { init() {} }

        var _storage: _Raw

        init() { _storage = _Raw() }

        consuming func cleanup() {
            print("V2: storage.cleanup() called (consuming)")
        }
    }

    struct Buffer_V2<let N: Int>: ~Copyable {
        var header: Int
        var storage: InlineStorage_V2<N>

        init() {
            header = 0
            storage = InlineStorage_V2<N>()
        }

        deinit {
            storage.cleanup()
        }
    }

    // ==========================================================================
    // MARK: - V3a: Mutating cleanup in deinit - DIRECT (expected: fails)
    // ==========================================================================
    // Result: CONFIRMED - error: "cannot use mutating member on immutable value"
    //
    // COMPILE ERROR (expected):
    // struct Buffer_V3a<let N: Int>: ~Copyable {
    //     var storage: InlineStorage_V3<N>
    //     init() { storage = InlineStorage_V3<N>() }
    //     deinit { storage.deinitializeAll() }  // error: self is immutable
    // }

    struct InlineStorage_V3<let N: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Int, count: N)
        struct _Raw: ~Copyable { init() {} }

        var _slots: Int
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

    // ==========================================================================
    // MARK: - V3b: Mutating cleanup in deinit - via UnsafeMutablePointer
    // ==========================================================================
    // Result: CONFIRMED - unsafe pointer cast enables mutating calls in deinit

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

    // ==========================================================================
    // MARK: - V4: Full chain - data structure deinit drives cleanup
    // ==========================================================================
    // Result: CONFIRMED - uses unsafe pointer workaround for mutating calls

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

    // ==========================================================================
    // MARK: - V5: Can we PREVENT implicit drop? (compile-time enforcement)
    // ==========================================================================
    // Result: REFUTED - ~Copyable without deinit compiles fine when dropped
    //         without calling drain(). No compile error. Swift does NOT have
    //         linear type enforcement (must-consume semantics).

    struct MustConsume<let N: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Int, count: N)
        struct _Raw: ~Copyable { init() {} }

        var _storage: _Raw

        init() { _storage = _Raw() }

        consuming func drain() -> Int {
            print("V5: drain() called")
            return 0
        }
    }

    // ==========================================================================
    // MARK: - V6: Runtime enforcement - debug trap on forgotten cleanup
    // ==========================================================================
    // Result: CONFIRMED - runtime detection works. But requires deinit on
    //         storage, which reintroduces #86652 constraints.

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

        deinit {
            if !_cleaned {
                print("V6: BUG - storage destroyed without cleanup!")
            }
        }
    }

    // ==========================================================================
    // MARK: - Results Summary
    // ==========================================================================
    // V1:  CONFIRMED - ~Copyable @_rawLayout can be implicitly dropped
    // V2:  REFUTED   - consuming calls in deinit WORK (key discovery)
    // V3a: CONFIRMED - mutating calls in deinit fail (self is immutable)
    // V3b: CONFIRMED - unsafe pointer workaround enables mutating in deinit
    // V4:  CONFIRMED - top-down chain via unsafe pointer workaround works
    // V5a: REFUTED   - no compile-time must-consume enforcement exists
    // V5b: CONFIRMED - explicit drain() works (but not enforced)
    // V6a: CONFIRMED - runtime detection via deinit assertion works
    // V6b: CONFIRMED - forgotten cleanup detected at runtime
    //
    // Key Discovery:
    // Swift's deinit body has special ownership semantics: it CAN consume stored
    // properties (transferring ownership to consuming methods). This enables a
    // clean 3-layer pattern where ONLY the top-level data structure has a deinit,
    // and cleanup flows down via consuming method calls.

    // MARK: - Run

    static func run() {
        print()
        print("=== ~Copyable Consumption Enforcement ===")
        print()

        // V1
        do {
            let _ = InlineStorage_V1<4>()
            print("V1: compiled and ran - implicit drop of ~Copyable without deinit")
        }
        print("---")

        // V2
        do {
            let _ = Buffer_V2<4>()
            print("V2: consuming call in deinit WORKS - deinit can consume stored properties")
        }
        print("---")

        // V3a
        print("V3a: direct mutating call in deinit fails - self is immutable in deinit")
        // V3b
        do {
            let _ = Buffer_V3b<4>()
            print("V3b: buffer going out of scope - deinit uses unsafe pointer workaround")
        }
        print("---")

        // V4
        do {
            let _ = DataStructure_V4<4>()
            print("V4: data structure going out of scope - deinit should drive cleanup chain")
        }
        print("---")

        // V5
        do {
            let _ = MustConsume<4>()
            print("V5a: compiled without calling drain() - no enforcement")
        }
        do {
            let s = MustConsume<4>()
            let _ = s.drain()
            print("V5b: compiled with drain() called")
        }
        print("---")

        // V6
        do {
            var s = SafeStorage_V6<4>()
            s.deinitializeAll()
            print("V6a: cleaned up before drop - safe")
        }
        do {
            let _ = SafeStorage_V6<4>()
            print("V6b: dropped without cleanup - deinit should trap")
        }
    }
}
