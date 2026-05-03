// SE-0499 verification spike.
//
// Question: Does Swift 6.4 allow `~Copyable` types to conform to the stdlib
// Equatable / Hashable / Comparable protocols, per the proposal text?
//
// Expected result:
//   - Swift 6.3.1 (Xcode default): conformance declarations FAIL to compile
//     because the stdlib protocols still constrain Self: Copyable.
//   - Swift 6.4-dev (DEVELOPMENT-SNAPSHOT-2026-03-16-a or later): conformance
//     declarations COMPILE per SE-0499.
//
// Build:
//   swift build                                  # default toolchain (6.3) — expected FAIL
//   xcrun --toolchain 'swift-DEVELOPMENT-SNAPSHOT-2026-03-16-a' \
//       swift build                              # 6.4-dev — expected PASS

// MARK: - Equatable on a ~Copyable struct

public struct EqToken: ~Copyable, Equatable {
    public let id: Int

    public init(id: Int) { self.id = id }

    public static func == (lhs: borrowing EqToken, rhs: borrowing EqToken) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable on a ~Copyable struct

public struct HashToken: ~Copyable, Hashable {
    public let id: Int

    public init(id: Int) { self.id = id }

    public static func == (lhs: borrowing HashToken, rhs: borrowing HashToken) -> Bool {
        lhs.id == rhs.id
    }

    public borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Comparable on a ~Copyable struct

public struct CmpToken: ~Copyable, Comparable {
    public let id: Int

    public init(id: Int) { self.id = id }

    public static func == (lhs: borrowing CmpToken, rhs: borrowing CmpToken) -> Bool {
        lhs.id == rhs.id
    }

    public static func < (lhs: borrowing CmpToken, rhs: borrowing CmpToken) -> Bool {
        lhs.id < rhs.id
    }
}

// MARK: - Generic constraint use

public func equalIDs<T: Equatable & ~Copyable>(_ lhs: borrowing T, _ rhs: borrowing T) -> Bool {
    lhs == rhs
}

public func smaller<T: Comparable & ~Copyable>(_ lhs: borrowing T, _ rhs: borrowing T) -> Bool {
    lhs < rhs
}
