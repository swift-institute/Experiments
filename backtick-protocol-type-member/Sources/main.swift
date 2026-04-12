// MARK: - Backtick Protocol Type Member
// Purpose: Verify that a type named `Protocol` (backtick-escaped Swift keyword)
//   can be used as a nested type, a computed property type, and in expression position.
// Hypothesis: `Outer.`Protocol`` resolves to the nested struct, not the .Protocol metatype.
//
// Toolchain: swift:6.3 (Docker)
// Platform: Linux (aarch64)
//
// Result: PARTIAL — type annotation works, expression position does NOT
// Date: 2026-04-12

// MARK: - Setup

struct Socket {
    struct `Protocol`: RawRepresentable, Sendable, Equatable, Hashable {
        let rawValue: Int32
        init(rawValue: Int32) { self.rawValue = rawValue }
        static let auto = `Protocol`(rawValue: 0)
        static let tcp = `Protocol`(rawValue: 6)
    }
}

// MARK: - Variant 1: Type annotation position
// Hypothesis: `Socket.`Protocol`` compiles as a type annotation.
// Result: CONFIRMED

let x: Socket.`Protocol` = .tcp
print("V1: \(x.rawValue)")  // Output: 6

// MARK: - Variant 2: Expression position (FAILS)
// Hypothesis: `Socket.`Protocol`(rawValue:)` compiles as a constructor call.
// Result: REFUTED — "cannot use 'Protocol' with non-protocol type 'Socket'"
// Diagnostic: error at expression position, Swift parses .Protocol as metatype accessor

// let y = Socket.`Protocol`(rawValue: 6)  // DOES NOT COMPILE

// MARK: - Variant 3: Local typealias workaround
// Hypothesis: A typealias avoids the expression-position issue.

typealias SocketProtocol = Socket.`Protocol`
let y = SocketProtocol(rawValue: 6)
print("V3: \(y.rawValue)")  // Output: 6

// MARK: - Variant 4: Computed property with typealias in body
// Hypothesis: Use typealias inside the getter body.

struct View4 {
    var pointer: UnsafeMutablePointer<Int32>

    var `protocol`: Socket.`Protocol` {
        get {
            typealias P = Socket.`Protocol`
            return P(rawValue: pointer.pointee)
        }
        nonmutating set { pointer.pointee = newValue.rawValue }
    }
}

// MARK: - Variant 5: Implicit member expression
// Hypothesis: .init(rawValue:) avoids the issue since type is inferred.

struct View5 {
    var pointer: UnsafeMutablePointer<Int32>

    var `protocol`: Socket.`Protocol` {
        get { .init(rawValue: pointer.pointee) }
        nonmutating set { pointer.pointee = newValue.rawValue }
    }
}

var storage: Int32 = 0
withUnsafeMutablePointer(to: &storage) { ptr in
    let v5 = View5(pointer: ptr)
    v5.`protocol` = .tcp
    print("V5: \(v5.`protocol`.rawValue)")
}

// MARK: - Results Summary
// V1: CONFIRMED — type annotation position works
// V2: REFUTED — expression position fails
// V3: CONFIRMED — typealias workaround compiles
// V4: CONFIRMED — typealias inside getter body works
// V5: CONFIRMED — .init(rawValue:) implicit member expression works (CLEANEST)
