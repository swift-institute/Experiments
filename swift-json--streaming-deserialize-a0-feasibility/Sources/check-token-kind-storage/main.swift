// Check #1 — Token.Kind storage in a ~Copyable & ~Escapable struct.
//
// Verifies the Phase A0 spike #1 premise from
// swift-institute/Research/streaming-json-deserialize-comparative-analysis.md
// §4.1 + §5.
//
// Why this matters: the Phase A1 Span Parser bug-bypass documented at
//   swift-ietf/swift-rfc-8259/Sources/RFC 8259/RFC_8259.Parser.Span.swift:18-28
// triggered on `Optional<RFC_8259.Token>` (payload-carrying — String /
// RFC_8259.Number). Option B's EventStream design returns
// `RFC_8259.Token.Kind` from `next()` to sidestep the bug.
//
// `RFC_8259.Token.Kind` (swift-rfc-8259/Sources/RFC 8259/RFC_8259.Token.Kind.swift)
// has 11 payload-free cases (objectStart, objectEnd, arrayStart, arrayEnd,
// colon, comma, null, true, false, string, number) plus `case unknown(UInt8)`
// at line 23. `UInt8` is a primitive POD — but the original compiler bug's
// structural cause was a noncopyable-typed-value copy, and the assumption
// that trivial POD payloads compose cleanly is empirical, not syntactic.
//
// The spike exercises BOTH:
//   (a) no-payload cases — store Optional<Token.Kind> = .objectStart /
//       .string / etc., read across mutating methods, switch-extract.
//   (b) the `.unknown(UInt8)` case in the SAME storage — construct
//       `Token.Kind = .unknown(0xFF)`, assign, read back, switch-extract
//       the inner UInt8.
//
// The struct has @_lifetime(self: copy self) mutating methods that read
// and write the storage field. The struct holds a Span<UInt8> like the
// EventStream design's lexer, plus an Optional<Token.Kind> field.

import RFC_8259

// MARK: - The cursor-shaped storage struct
//
// Mirrors RFC_8259.Span.EventStream's planned shape per the comparative
// analysis §4.1. The `lastTokenKind` storage is the bug-suspect field —
// Optional<RFC_8259.Token.Kind> held across mutating-method boundaries
// inside a ~Copyable & ~Escapable struct.

@safe
struct EventStreamProbe: ~Copyable, ~Escapable {
    @usableFromInline
    internal let bytes: Span<UInt8>

    @usableFromInline
    internal var position: Int

    /// Storage under test. Optional payload-carrying enum inside
    /// ~Copyable & ~Escapable struct — the same shape that tripped
    /// the compiler bug per RFC_8259.Parser.Span.swift:18-28 (with
    /// Token instead of Token.Kind).
    @usableFromInline
    internal var lastTokenKind: RFC_8259.Token.Kind?

    /// Parallel storage for the .unknown(UInt8) case verification —
    /// kept distinct so we exercise BOTH payload-free assignment
    /// (lastTokenKind) AND payload-carrying assignment (unknownKind)
    /// in the same struct's lifetime.
    @usableFromInline
    internal var unknownKind: RFC_8259.Token.Kind?

    @inlinable
    @_lifetime(borrow bytes)
    init(_ bytes: borrowing Span<UInt8>) {
        self.bytes = copy bytes
        self.position = 0
        self.lastTokenKind = nil
        self.unknownKind = nil
    }
}

extension EventStreamProbe {
    /// Mutating method that READS and WRITES `lastTokenKind`.
    /// This is the operation that the original Token-storage bug fired on.
    @inlinable
    @_lifetime(self: copy self)
    mutating func storePayloadFree(_ kind: RFC_8259.Token.Kind) {
        // Write — assignment into Optional<Token.Kind> field on
        // ~Copyable & ~Escapable struct.
        self.lastTokenKind = kind
        self.position &+= 1
    }

    /// Mutating method that reads back `lastTokenKind` and reports
    /// what was stored. Returns Optional to keep the read explicit.
    @inlinable
    @_lifetime(self: copy self)
    mutating func readBack() -> RFC_8259.Token.Kind? {
        // Read of Optional<Token.Kind> field. If the bug fires, this is
        // where the "copy of noncopyable typed value" diagnostic typically
        // appears.
        let kind = self.lastTokenKind
        self.lastTokenKind = nil
        return kind
    }

    /// Mutating method that stores a `.unknown(UInt8)` payload — the
    /// trivial-POD case under test in spike #1's (b) sub-case.
    @inlinable
    @_lifetime(self: copy self)
    mutating func storeUnknown(_ byte: UInt8) {
        self.unknownKind = .unknown(byte)
        self.position &+= 1
    }

    /// Mutating method that reads back the `.unknown(UInt8)` payload
    /// via switch extraction.
    @inlinable
    @_lifetime(self: copy self)
    mutating func extractUnknownByte() -> UInt8? {
        guard let stored = self.unknownKind else { return nil }
        switch stored {
        case .unknown(let byte):
            self.unknownKind = nil
            return byte
        default:
            self.unknownKind = nil
            return nil
        }
    }
}

// MARK: - Probes

print("=== check-token-kind-storage ===")
print("Verifies: Optional<RFC_8259.Token.Kind> storage inside")
print("          ~Copyable & ~Escapable struct, exercising both")
print("          payload-free cases AND .unknown(UInt8) payload-carrying case.")
print("")

// State for [PASS] / [FAIL] tracking. `nonisolated(unsafe)` per the
// spike's single-threaded driver — top-level code runs as the sole
// caller; no concurrent access.
nonisolated(unsafe) var failureCount = 0
nonisolated(unsafe) var passCount = 0

func report(_ label: String, _ passed: Bool, detail: String = "") {
    if passed {
        passCount &+= 1
        print("  [PASS] \(label)\(detail.isEmpty ? "" : " — \(detail)")")
    } else {
        failureCount &+= 1
        print("  [FAIL] \(label)\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

// Source bytes the cursor borrows. Content irrelevant for this spike — we
// only need the lifetime relationship for the @_lifetime annotations to
// fire. `Swift.Array` qualifier disambiguates from any `Array` namespace
// type pulled in by RFC_8259's transitive dependencies (e.g.,
// `Array_Primitives.Array`).
let sourceBytes: Swift.Array<UInt8> = Swift.Array(repeating: UInt8(0x20), count: 64)

// ------------------------------------------------------------
// (a) No-payload cases — exercise all 11
// ------------------------------------------------------------
print("--- (a) Payload-free cases ---")

let payloadFreeCases: [(label: String, kind: RFC_8259.Token.Kind)] = [
    ("objectStart", .objectStart),
    ("objectEnd",   .objectEnd),
    ("arrayStart",  .arrayStart),
    ("arrayEnd",    .arrayEnd),
    ("colon",       .colon),
    ("comma",       .comma),
    ("null",        .null),
    ("true",        .true),
    ("false",       .false),
    ("string",      .string),
    ("number",      .number),
]

sourceBytes.withUnsafeBufferPointer { buf in
    let span: Span<UInt8> = buf.span
    var probe = EventStreamProbe(span)

    for (label, expected) in payloadFreeCases {
        probe.storePayloadFree(expected)
        let read = probe.readBack()
        switch (read, expected) {
        case (.some(let r), let e) where r == e:
            report("store+read \(label)", true)
        case (.some(let r), let e):
            report("store+read \(label)", false, detail: "got \(r) expected \(e)")
        case (.none, _):
            report("store+read \(label)", false, detail: "read returned nil")
        }
    }

    // Sanity: after readBack, the field should be cleared. The
    // `position` counter advanced once per store; verifying it
    // matches the case count is a cheap consistency check.
    let expectedPosition = payloadFreeCases.count
    if probe.position != expectedPosition {
        report("position after 11 stores",
               false,
               detail: "got \(probe.position) expected \(expectedPosition)")
    } else {
        report("position counter consistency across stores", true)
    }
}

// ------------------------------------------------------------
// (b) .unknown(UInt8) payload-carrying case
// ------------------------------------------------------------
print("")
print("--- (b) .unknown(UInt8) case ---")

let unknownBytes: [UInt8] = [0x00, 0x20, 0x41, 0x7F, 0x80, 0xC0, 0xFE, 0xFF]

sourceBytes.withUnsafeBufferPointer { buf in
    let span: Span<UInt8> = buf.span
    var probe = EventStreamProbe(span)

    for byte in unknownBytes {
        // Construct the .unknown(UInt8) case at the call site exactly as
        // the spike brief requires:
        //   let kind: RFC_8259.Token.Kind = .unknown(0xFF)
        let kind: RFC_8259.Token.Kind = .unknown(byte)

        // Store into the ~Copyable & ~Escapable struct's Optional<Token.Kind>
        // field via a mutating method.
        probe.unknownKind = kind
        probe.position &+= 1

        // Read back via switch-extract through a mutating method.
        let extracted = probe.extractUnknownByte()

        switch extracted {
        case .some(let b) where b == byte:
            report("store+extract .unknown(0x\(String(byte, radix: 16, uppercase: true)))", true)
        case .some(let b):
            report("store+extract .unknown(0x\(String(byte, radix: 16, uppercase: true)))", false, detail: "extracted 0x\(String(b, radix: 16, uppercase: true))")
        case .none:
            report("store+extract .unknown(0x\(String(byte, radix: 16, uppercase: true)))", false, detail: "extract returned nil")
        }
    }

    // Cross-cutting: store a no-payload case AND a .unknown(UInt8) case
    // in the SAME struct lifetime, alternating, to confirm both storage
    // shapes coexist inside the same ~Copyable & ~Escapable scope.
    probe.storePayloadFree(.objectStart)
    probe.storeUnknown(0xAB)

    let payloadFreeRead = probe.readBack()
    let unknownRead = probe.extractUnknownByte()

    switch (payloadFreeRead, unknownRead) {
    case (.some(.objectStart), .some(0xAB)):
        report("coexistence: payload-free + unknown(0xAB) in same probe", true)
    default:
        report("coexistence: payload-free + unknown(0xAB) in same probe", false,
               detail: "payloadFree=\(String(describing: payloadFreeRead)) unknown=\(String(describing: unknownRead))")
    }
}

// ------------------------------------------------------------
// (c) Switch-extract from a Token.Kind value across function boundaries.
//     This is the operation the bug-bypass note specifically describes
//     ("doing all dispatch at the byte level rather than via Token
//     storage"). If switch-extraction over Token.Kind works inside a
//     mutating method on a ~Copyable & ~Escapable struct, the design
//     is good.
// ------------------------------------------------------------
print("")
print("--- (c) Switch dispatch over stored Token.Kind ---")

sourceBytes.withUnsafeBufferPointer { buf in
    let span: Span<UInt8> = buf.span
    var probe = EventStreamProbe(span)

    let allCases: [RFC_8259.Token.Kind] = payloadFreeCases.map { $0.kind } + [.unknown(0x42)]
    var dispatchedCount = 0

    for kind in allCases {
        probe.lastTokenKind = kind
        // Drive a switch dispatch on the stored Optional<Token.Kind>.
        // This is the hot loop shape Option B's EventStream consumer
        // (e.g. Symbol.deserialize(events:)) writes against.
        if let stored = probe.lastTokenKind {
            switch stored {
            case .objectStart, .objectEnd, .arrayStart, .arrayEnd:
                dispatchedCount &+= 1
            case .colon, .comma:
                dispatchedCount &+= 1
            case .null, .true, .false:
                dispatchedCount &+= 1
            case .string, .number:
                dispatchedCount &+= 1
            case .unknown(let byte):
                if byte == 0x42 { dispatchedCount &+= 1 }
            }
        }
        probe.lastTokenKind = nil
    }

    report("switch-dispatch over all 12 Token.Kind cases", dispatchedCount == allCases.count,
           detail: "dispatched \(dispatchedCount)/\(allCases.count)")
}

// ------------------------------------------------------------
// Disposition
// ------------------------------------------------------------
print("")
print("--- Disposition ---")
print("  pass: \(passCount)")
print("  fail: \(failureCount)")
print("")

if failureCount == 0 {
    print("PREMISE 1: GREEN")
    print("  Optional<RFC_8259.Token.Kind> storage in ~Copyable & ~Escapable")
    print("  struct compiles and runs cleanly across mutating methods for")
    print("  BOTH payload-free cases AND .unknown(UInt8) — the §4.1 design")
    print("  premise holds on the current toolchain.")
} else {
    print("PREMISE 1: RED")
    print("  One or more cases failed at runtime — see [FAIL] lines above.")
    print("  Option B's cursor design depends on this storage; if RED, the")
    print("  fallback (UInt8 raw-value + parallel errorByte field) per §5")
    print("  spike #1 disposition applies.")
}
