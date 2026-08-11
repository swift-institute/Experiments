// MARK: - ~Copyable Close Ownership Patterns
// Purpose: Find the best close() ownership convention for ~Copyable Kernel.Descriptor.
//          Test consuming vs borrowing, deinit compatibility, defer compatibility,
//          use-after-close prevention, and overload resolution.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — V5 (labeled borrowing) is the best-of-all-worlds pattern.
//
//   V1 consuming only:    CONFIRMED — prevents use-after-close, but unusable in deinit/defer
//   V2 borrowing only:    CONFIRMED — works in deinit/defer, but allows use-after-close
//   V3 unlabeled overload: REFUTED  — "ambiguous use of 'close'" — compiler can't disambiguate
//   V4 discard self:       REFUTED  — "can only discard trivially-destroyed" — ~Copyable blocks it
//   V5 labeled borrowing:  CONFIRMED — consuming (unlabeled) + borrowing (labeled) coexist cleanly
//   V6 discard+deinit:     REFUTED  — same discard limitation as V4
//
//   V5 gives: consuming `close(fd)` for public API (prevents use-after-close)
//             borrowing `close(borrowing: fd)` for deinit/defer (no ownership transfer)
//             No ambiguity. No raw values. No underscore hacks.
//
// Date: 2026-03-30

// Minimal descriptor model
struct Descriptor: ~Copyable, Sendable {
    let raw: Int32
    init(_ raw: Int32) { self.raw = raw }
}

// ============================================================================
// MARK: - Variant 1: Consuming close only
// Hypothesis: Consuming close prevents use-after-close but cannot be called from deinit.
// Result: (pending)
// ============================================================================

enum V1 {
    static func close(_ descriptor: consuming Descriptor) {
        print("V1: closed fd \(descriptor.raw)")
    }

    // 1a: Basic consuming — should prevent use-after-close
    static func test_basic() {
        let fd = Descriptor(10)
        close(fd)
        // fd is consumed — any subsequent use would be a compile error
        print("V1.1a: consuming close works")
    }

    // 1b: Consuming close in defer — does this compile?
    // static func test_defer() {
    //     let fd = Descriptor(11)
    //     defer { close(fd) }  // Can defer consume?
    //     print("V1.1b: defer with consuming")
    // }

    // 1c: Type with deinit trying to call consuming close
    struct Owner: ~Copyable {
        let descriptor: Descriptor
        // deinit {
        //     V1.close(descriptor)  // Expected: ERROR — can't consume stored property in deinit
        // }
    }
}

// ============================================================================
// MARK: - Variant 2: Borrowing close only
// Hypothesis: Borrowing close works in deinit and defer but allows use-after-close.
// Result: (pending)
// ============================================================================

enum V2 {
    static func close(_ descriptor: borrowing Descriptor) {
        print("V2: closed fd \(descriptor.raw)")
    }

    // 2a: Basic borrowing
    static func test_basic() {
        let fd = Descriptor(20)
        close(fd)
        print("V2.2a: borrowing close works")
    }

    // 2b: Use-after-close — does the compiler allow this? (undesirable)
    static func test_use_after_close() {
        let fd = Descriptor(21)
        close(fd)
        // Can we still read fd? (This would be a bug in real code)
        print("V2.2b: use-after-close reads fd=\(fd.raw)")  // Expected: compiles (bad)
    }

    // 2c: Borrowing close in defer
    static func test_defer() {
        let fd = Descriptor(22)
        defer { close(fd) }
        print("V2.2c: defer with borrowing close")
    }

    // 2d: Type with deinit calling borrowing close
    struct Owner: ~Copyable {
        let descriptor: Descriptor
        deinit {
            V2.close(descriptor)  // Expected: works — borrows stored property
        }
    }

    static func test_deinit() {
        let _ = Owner(descriptor: Descriptor(23))
        print("V2.2d: deinit with borrowing close")
    }
}

// ============================================================================
// MARK: - Variant 3: Both overloads (consuming + borrowing)
// Hypothesis: Swift can resolve overloads differing only in ownership convention.
// Result: (pending)
// ============================================================================

enum V3 {
    static func close(_ descriptor: consuming Descriptor) {
        print("V3: consuming close fd \(descriptor.raw)")
    }

    static func close(_ descriptor: borrowing Descriptor) {
        print("V3: borrowing close fd \(descriptor.raw)")
    }

    // 3a-3c: ALL REFUTED — ambiguous use of 'close', compiler cannot
    // disambiguate overloads differing only in ownership convention.
    static func test_basic() { print("V3: REFUTED — ambiguous overload") }
    static func test_deinit() { print("V3: REFUTED — ambiguous overload") }
}

// ============================================================================
// MARK: - Variant 4: Consuming method with discard self
// Hypothesis: A consuming method can move out stored properties and discard self
//             to skip deinit, enabling descriptor return.
// Result: (pending)
// ============================================================================

enum V4 {
    // REFUTED: "can only 'discard' type if it contains trivially-destroyed
    // stored properties at this time" — Descriptor: ~Copyable is not trivially
    // destructible. Also: "cannot partially consume 'self' when it has a deinitializer"
    static func test_release() { print("V4: REFUTED — discard self requires trivially-destroyed properties") }
    static func test_drop() { print("V4: REFUTED") }
}

// ============================================================================
// MARK: - Variant 5: Labeled borrowing variant
// Hypothesis: A labeled parameter can distinguish consuming from borrowing
//             without overload ambiguity.
// Result: (pending)
// ============================================================================

enum V5 {
    // Public API: consuming
    static func close(_ descriptor: consuming Descriptor) {
        print("V5: consuming close fd \(descriptor.raw)")
    }

    // Deinit/defer API: borrowing, distinguished by label
    static func close(borrowing descriptor: borrowing Descriptor) {
        print("V5: borrowing close fd \(descriptor.raw)")
    }

    // 5a: consuming (no label)
    static func test_consuming() {
        let fd = Descriptor(50)
        close(fd)
        print("V5.5a: consuming close")
    }

    // 5b: borrowing (with label)
    static func test_borrowing() {
        let fd = Descriptor(51)
        close(borrowing: fd)
        print("V5.5b: borrowing close (labeled)")
    }

    // 5c: deinit uses labeled borrowing
    struct Owner: ~Copyable {
        let descriptor: Descriptor
        deinit {
            V5.close(borrowing: descriptor)
        }
    }

    static func test_deinit() {
        let _ = Owner(descriptor: Descriptor(52))
        print("V5.5c: deinit with labeled borrowing")
    }

    // 5d: defer uses labeled borrowing
    static func test_defer() {
        let fd = Descriptor(53)
        defer { V5.close(borrowing: fd) }
        print("V5.5d: defer with labeled borrowing")
    }
}

// ============================================================================
// MARK: - Variant 6: Owner with consuming close + discard + deinit backstop
// Hypothesis: Best-of-all-worlds — Owner has both consuming close() that returns
//             the descriptor (via discard self) AND a deinit backstop that closes
//             without returning.
// Result: (pending)
// ============================================================================

enum V6 {
    // REFUTED: Same discard self limitation as V4.
    // Cannot discard types with ~Copyable stored properties.
    static func test_explicit_close() { print("V6: REFUTED — same as V4") }
    static func test_deinit_close() { print("V6: REFUTED") }
}

// ============================================================================
// MARK: - Run all
// ============================================================================

print("=== V1: Consuming only ===")
V1.test_basic()

print("\n=== V2: Borrowing only ===")
V2.test_basic()
V2.test_use_after_close()
V2.test_defer()
V2.test_deinit()

print("\n=== V3: Both overloads ===")
V3.test_basic()
// V3.test_force_borrow()
V3.test_deinit()

print("\n=== V4: Discard self ===")
V4.test_release()
V4.test_drop()

print("\n=== V5: Labeled borrowing ===")
V5.test_consuming()
V5.test_borrowing()
V5.test_deinit()
V5.test_defer()

print("\n=== V6: Owner with close + deinit ===")
V6.test_explicit_close()
V6.test_deinit_close()

print("\n=== Results Summary ===")
print("V1: Consuming close — prevents use-after-close, cannot be called from deinit/defer")
print("V2: Borrowing close — works in deinit/defer, allows use-after-close")
print("V3: Both overloads — check if compiler resolves correctly")
print("V4: discard self — consuming method can skip deinit and return descriptor")
print("V5: Labeled borrowing — explicit disambiguation")
print("V6: Owner pattern — close() + deinit backstop via discard")
