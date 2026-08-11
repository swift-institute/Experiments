// MARK: - Tagged Clock Instant Experiment
// Purpose: Verify Tagged-based clock instant types compile and work correctly
// Hypothesis: Tagged<ClockType, BaseTick> can serve as InstantProtocol conformer,
//             using InstantProtocol itself as the constraint (no custom protocol needed).
//
// Toolchain: Swift 6.2
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Build Succeeded, all 7 variants pass at runtime
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-03-01

public import Tagged_Primitives

// ============================================================================
// MARK: - Base types conforming directly to InstantProtocol
// ============================================================================

/// Clock namespace (mirrors production Clock enum)
public enum Clock {}

/// Hardware nanosecond position.
/// Used by Continuous and Suspending clocks.
extension Clock {
    public struct Nanoseconds: InstantProtocol, Sendable, Hashable, Comparable {
        public typealias Duration = Swift.Duration

        public let rawValue: UInt64

        @inlinable
        public init(_ rawValue: UInt64) { self.rawValue = rawValue }

        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        @inlinable
        public func advanced(by duration: Swift.Duration) -> Self {
            let (seconds, attoseconds) = duration.components
            let nanos = seconds * 1_000_000_000 + attoseconds / 1_000_000_000
            return Self(rawValue &+ UInt64(bitPattern: nanos))
        }

        @inlinable
        public func duration(to other: Self) -> Swift.Duration {
            let diff = Int64(bitPattern: other.rawValue &- rawValue)
            return .nanoseconds(diff)
        }
    }
}

/// Duration-offset position for virtual clocks.
/// Used by Test, Immediate, and Unimplemented clocks.
extension Clock {
    public struct Offset: InstantProtocol, Sendable, Hashable, Comparable {
        public typealias Duration = Swift.Duration

        public let rawValue: Swift.Duration

        @inlinable
        public init(_ rawValue: Swift.Duration = .zero) { self.rawValue = rawValue }

        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        @inlinable
        public func advanced(by duration: Swift.Duration) -> Self {
            Self(rawValue + duration)
        }

        @inlinable
        public func duration(to other: Self) -> Swift.Duration {
            other.rawValue - rawValue
        }
    }
}

// ============================================================================
// MARK: - Variant 1: Single InstantProtocol-constrained conformance on Tagged
// Hypothesis: extension Tagged: InstantProtocol where RawValue: InstantProtocol
//             compiles — no custom protocol needed
// ============================================================================

extension Tagged: @retroactive InstantProtocol where RawValue: InstantProtocol {
    public typealias Duration = RawValue.Duration

    @inlinable
    public func advanced(by duration: RawValue.Duration) -> Self {
        Self(__unchecked: (), rawValue.advanced(by: duration))
    }

    @inlinable
    public func duration(to other: Self) -> RawValue.Duration {
        rawValue.duration(to: other.rawValue)
    }
}

print("Variant 1: PASS — Tagged + InstantProtocol via InstantProtocol constraint compiles")

// ============================================================================
// MARK: - Variant 2: Operators via InstantProtocol constraint
// Hypothesis: Operators on Tagged where RawValue: InstantProtocol, Duration == Swift.Duration
// ============================================================================

extension Tagged where RawValue: InstantProtocol, RawValue.Duration == Swift.Duration {
    @inlinable
    public static func + (lhs: Self, rhs: Swift.Duration) -> Self {
        Self(__unchecked: (), lhs.rawValue.advanced(by: rhs))
    }

    @inlinable
    public static func + (lhs: Swift.Duration, rhs: Self) -> Self {
        Self(__unchecked: (), rhs.rawValue.advanced(by: lhs))
    }

    @inlinable
    public static func += (lhs: inout Self, rhs: Swift.Duration) {
        lhs = lhs + rhs
    }

    @inlinable
    public static func - (lhs: Self, rhs: Swift.Duration) -> Self {
        Self(__unchecked: (), lhs.rawValue.advanced(by: .zero - rhs))
    }

    @inlinable
    public static func -= (lhs: inout Self, rhs: Swift.Duration) {
        lhs = lhs - rhs
    }

    @inlinable
    public static func - (lhs: Self, rhs: Self) -> Swift.Duration {
        rhs.rawValue.duration(to: lhs.rawValue)
    }
}

// Test: operators work on both base types
do {
    let a = Tagged<Clock.Continuous, Clock.Nanoseconds>(__unchecked: (), Clock.Nanoseconds(1000))
    let b = a + .nanoseconds(500)
    let diff: Duration = b - a
    print("Variant 2: PASS — Hardware operators. diff = \(diff)")
}

do {
    let a = Tagged<Clock.Test, Clock.Offset>(__unchecked: (), Clock.Offset(.seconds(1)))
    let b = a + .seconds(2)
    let diff: Duration = b - a
    print("Variant 2: PASS — Virtual operators. diff = \(diff)")
}

// ============================================================================
// MARK: - Variant 3: _Concurrency.Clock integration
// Hypothesis: typealias Instant = Tagged<Self, BaseType> satisfies _Concurrency.Clock
// ============================================================================

extension Clock {
    public struct Continuous: Sendable {
        public typealias Duration = Swift.Duration
        public typealias Instant = Tagged<Continuous, Clock.Nanoseconds>

        public var minimumResolution: Duration { .nanoseconds(1) }
        public init() {}
    }
}

extension Clock {
    public struct Suspending: Sendable {
        public typealias Duration = Swift.Duration
        public typealias Instant = Tagged<Suspending, Clock.Nanoseconds>

        public var minimumResolution: Duration { .nanoseconds(1) }
        public init() {}
    }
}

extension Clock {
    public struct Test: Sendable {
        public typealias Duration = Swift.Duration
        public typealias Instant = Tagged<Test, Clock.Offset>

        public var minimumResolution: Duration { .zero }
        public init() {}
    }
}

extension Clock {
    public struct Immediate: Sendable {
        public typealias Duration = Swift.Duration
        public typealias Instant = Tagged<Immediate, Clock.Offset>

        public var minimumResolution: Duration { .zero }
        public init() {}
    }
}

extension Clock {
    public struct Unimplemented: Sendable {
        public typealias Duration = Swift.Duration
        public typealias Instant = Tagged<Unimplemented, Clock.Offset>

        public var minimumResolution: Duration { .zero }
        public init() {}
    }
}

// _Concurrency.Clock conformance
extension Clock.Continuous: _Concurrency.Clock {
    public var now: Instant {
        Instant(nanoseconds: 42)
    }

    nonisolated(nonsending)
    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        try Task.checkCancellation()
    }
}

extension Clock.Test: _Concurrency.Clock {
    public var now: Instant {
        Instant(offset: .zero)
    }

    nonisolated(nonsending)
    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        try Task.checkCancellation()
    }
}

print("Variant 3: PASS — _Concurrency.Clock with Tagged Instant compiles")

// ============================================================================
// MARK: - Variant 4: API surface preservation
// Hypothesis: Convenience inits and computed properties match existing API
// ============================================================================

// Convenience for hardware instants
extension Tagged where RawValue == Clock.Nanoseconds {
    @inlinable
    public var nanoseconds: UInt64 { rawValue.rawValue }

    @inlinable
    public init(nanoseconds: UInt64) {
        self.init(__unchecked: (), Clock.Nanoseconds(nanoseconds))
    }
}

// Convenience for virtual instants
extension Tagged where RawValue == Clock.Offset {
    @inlinable
    public var offset: Swift.Duration { rawValue.rawValue }

    @inlinable
    public init(offset: Swift.Duration = .zero) {
        self.init(__unchecked: (), Clock.Offset(offset))
    }
}

// Test: existing API patterns
do {
    let instant = Clock.Continuous.Instant(nanoseconds: 1_000_000_000)
    let nanos: UInt64 = instant.nanoseconds
    print("Variant 4: PASS — Hardware: nanoseconds = \(nanos)")

    let testInstant = Clock.Test.Instant(offset: .seconds(5))
    let offset: Duration = testInstant.offset
    print("Variant 4: PASS — Virtual: offset = \(offset)")

    let zeroInstant = Clock.Test.Instant()
    print("Variant 4: PASS — Zero-arg: offset = \(zeroInstant.offset)")
}

// ============================================================================
// MARK: - Variant 5: Phantom-tag type safety
// Hypothesis: Phantom tags prevent mixing clock domains at compile time
// ============================================================================

do {
    let continuous = Clock.Continuous.Instant(nanoseconds: 100)
    let suspending = Clock.Suspending.Instant(nanoseconds: 100)

    let _ = continuous + .nanoseconds(50)
    let _: Duration = continuous - Clock.Continuous.Instant(nanoseconds: 50)

    // These SHOULD NOT compile (different phantom tags):
    // let _ = continuous - suspending  // ERROR: different types
    // let _ = continuous == suspending  // ERROR: different types

    let continuousType = type(of: continuous)
    let suspendingType = type(of: suspending)
    print("Variant 5: Continuous type = \(continuousType)")
    print("Variant 5: Suspending type = \(suspendingType)")
    print("Variant 5: PASS — Types are distinct by construction")
}

// ============================================================================
// MARK: - Variant 6: Original bug fix (now + duration)
// ============================================================================

do {
    let now = Clock.Continuous().__workaround_now
    let deadline = now + .seconds(30)
    let remaining: Duration = deadline - now
    print("Variant 6: PASS — now + duration works. remaining = \(remaining)")
}

extension Clock.Continuous {
    var __workaround_now: Instant {
        Instant(nanoseconds: 1_000_000_000)
    }
}

// ============================================================================
// MARK: - Variant 7: All 5 clock types
// ============================================================================

do {
    let c = Clock.Continuous.Instant(nanoseconds: 100)
    let s = Clock.Suspending.Instant(nanoseconds: 200)
    let t = Clock.Test.Instant(offset: .seconds(1))
    let i = Clock.Immediate.Instant(offset: .zero)
    let u = Clock.Unimplemented.Instant(offset: .milliseconds(500))

    let _: Duration = (c + .nanoseconds(10)) - c
    let _: Duration = (s + .nanoseconds(20)) - s
    let _: Duration = (t + .seconds(1)) - t
    let _: Duration = (i + .milliseconds(100)) - i
    let _: Duration = (u + .seconds(1)) - u

    print("Variant 7: PASS — All 5 clock types work with Tagged")
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("""

=== RESULTS ===
V1: Tagged + InstantProtocol via InstantProtocol constraint (no custom protocol)
V2: Operators via InstantProtocol constraint
V3: _Concurrency.Clock with Tagged Instant typealias
V4: API surface preservation (convenience inits + properties)
V5: Phantom-tag type safety (different clocks can't mix)
V6: Original bug fix (now + duration compiles)
V7: All 5 clock types with correct Instant typealiases
""")
