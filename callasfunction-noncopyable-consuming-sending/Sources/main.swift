// MARK: - callAsFunction + ~Copyable + consuming sending + ~Escapable
//
// Purpose: Validate three assumptions from io-events-perfect-public-api.md v2.0
//   E1: consuming func callAsFunction works on ~Copyable struct
//   E2: consuming sending closure params accept ~Copyable ~Escapable values
//   E3: nonisolated(nonsending) composes with consuming sending on same closure param
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: ALL CONFIRMED — E1, E1b, E2, E2b, E3, E3b, E3c pass.
//         The full IO.Stream callAsFunction pattern compiles and runs.
// Date: 2026-04-06

// ═══════════════════════════════════════════════════════════
// Supporting types
// ═══════════════════════════════════════════════════════════

/// Simulates IO.Event.Channel.Reader — the internal type
struct InternalReader: ~Copyable {
    let id: Int
    mutating func read() -> Int {
        print("  InternalReader \(id): read")
        return 42
    }
}

/// Simulates IO.Event.Channel.Writer — the internal type
struct InternalWriter: ~Copyable {
    let id: Int
    mutating func write(_ value: Int) {
        print("  InternalWriter \(id): write(\(value))")
    }
}

/// Simulates Transfer<T> — internal to the framework
final class Transfer<T: ~Copyable>: @unchecked Sendable {
    private var _value: T?
    init(_ value: consuming T) { _value = consume value }
    func take() -> T { _value.take()! }
}

// ═══════════════════════════════════════════════════════════
// MARK: - E1: consuming func callAsFunction on ~Copyable struct
// Hypothesis: Swift 6.3 supports callAsFunction with consuming
//             on a ~Copyable struct. The struct is consumed by
//             calling it.
// Result: CONFIRMED
// ═══════════════════════════════════════════════════════════

struct StreamE1: ~Copyable {
    let id: Int

    consuming func callAsFunction() {
        print("  StreamE1 \(id): consumed via callAsFunction()")
    }
}

func e1_callAsFunction_noncopyable() {
    print("E1: consuming func callAsFunction on ~Copyable")
    let stream = StreamE1(id: 1)
    stream()
    // stream is consumed — using it here would be a compile error
    print("  E1: stream consumed successfully")
}

// ═══════════════════════════════════════════════════════════
// MARK: - E1b: consuming func callAsFunction with closure params
// Hypothesis: callAsFunction can accept closure parameters,
//             enabling multi-trailing-closure syntax.
// Result: CONFIRMED
// ═══════════════════════════════════════════════════════════

struct StreamE1b: ~Copyable {
    let id: Int

    consuming func callAsFunction<R>(
        _ read: (Int) -> R,
        write: (Int) -> Void
    ) -> R {
        print("  StreamE1b \(id): callAsFunction with closures")
        write(99)
        return read(42)
    }
}

func e1b_callAsFunction_closures() {
    print("E1b: callAsFunction with multi-trailing-closure syntax")
    let stream = StreamE1b(id: 2)
    let result = stream { value in
        print("  read closure received: \(value)")
        return "got \(value)"
    } write: { value in
        print("  write closure received: \(value)")
    }
    print("  E1b result: \(result)")
}

// ═══════════════════════════════════════════════════════════
// MARK: - E2: consuming sending closure param with ~Copyable ~Escapable
// Hypothesis: A closure parameter annotated `consuming sending`
//             can receive a ~Copyable ~Escapable value.
// Result: CONFIRMED
// ═══════════════════════════════════════════════════════════

/// ~Copyable ~Escapable reader — the Tier 0 type
struct ReaderE2: ~Copyable, ~Escapable {
    private let base: UnsafeMutablePointer<InternalReader>

    @_lifetime(immortal)
    init(_ reader: inout InternalReader) {
        unsafe self.base = .init(&reader)
    }

    mutating func read() -> Int {
        unsafe base.pointee.read()
    }
}

/// ~Copyable ~Escapable writer — the Tier 0 type
struct WriterE2: ~Copyable, ~Escapable {
    private let base: UnsafeMutablePointer<InternalWriter>

    @_lifetime(immortal)
    init(_ writer: inout InternalWriter) {
        unsafe self.base = .init(&writer)
    }

    func write(_ value: Int) {
        unsafe base.pointee.write(value)
    }
}

/// Function that accepts consuming sending ~Copyable ~Escapable
func acceptReader(_ reader: consuming sending ReaderE2) -> Int {
    var reader = reader
    return reader.read()
}

func e2_consuming_sending_noncopyable_nonescapable() {
    print("E2: consuming sending with ~Copyable ~Escapable")
    var internal_reader = InternalReader(id: 20)
    let reader = ReaderE2(&internal_reader)
    let result = acceptReader(reader)
    print("  E2 result: \(result)")
}

// ═══════════════════════════════════════════════════════════
// MARK: - E2b: consuming sending as closure parameter
// Hypothesis: A closure type can have a consuming sending parameter
//             that is ~Copyable ~Escapable.
// Result: CONFIRMED
// ═══════════════════════════════════════════════════════════

func withReader<R>(
    _ body: (consuming sending ReaderE2) -> R
) -> R {
    var internal_reader = InternalReader(id: 21)
    let reader = ReaderE2(&internal_reader)
    return body(reader)
}

func e2b_consuming_sending_closure_param() {
    print("E2b: consuming sending as closure parameter")
    let result = withReader { reader in
        var reader = reader
        return reader.read()
    }
    print("  E2b result: \(result)")
}

// ═══════════════════════════════════════════════════════════
// MARK: - E3: nonisolated(nonsending) + consuming sending on same param
// Hypothesis: A closure can be nonisolated(nonsending) while also
//             having a consuming sending parameter.
// Note: nonisolated(nonsending) only applies to async function types
//       per [IMPL-062]. Sync closures error: "cannot use
//       'nonisolated(nonsending)' on non-async function type".
// Result: CONFIRMED (async variant)
// ═══════════════════════════════════════════════════════════

func withReaderNonisolated<R>(
    _ body: nonisolated(nonsending) (consuming sending ReaderE2) async -> R
) async -> R {
    var internal_reader = InternalReader(id: 30)
    let reader = ReaderE2(&internal_reader)
    return await body(reader)
}

func e3_nonisolated_nonsending_consuming_sending() async {
    print("E3: nonisolated(nonsending) + consuming sending")
    let result = await withReaderNonisolated { reader in
        var reader = reader
        return reader.read()
    }
    print("  E3 result: \(result)")
}

// ═══════════════════════════════════════════════════════════
// MARK: - E3b: Full composition — callAsFunction + async + consuming sending
//              + nonisolated(nonsending) + ~Copyable ~Escapable
// Hypothesis: Everything composes in the full IO.Stream pattern.
// Result: CONFIRMED
// ═══════════════════════════════════════════════════════════

struct StreamE3b: ~Copyable {
    var internalReader: InternalReader
    var internalWriter: InternalWriter

    consuming func callAsFunction<R>(
        _ read: nonisolated(nonsending) (consuming sending ReaderE2) async -> R,
        write: nonisolated(nonsending) (consuming sending WriterE2) async -> Void
    ) async -> R {
        // Framework creates ~Escapable halves internally
        var r = internalReader
        var w = internalWriter
        let reader = ReaderE2(&r)
        let writer = WriterE2(&w)

        // Framework manages concurrency — for this experiment,
        // run sequentially (concurrent execution tested separately)
        await write(writer)
        return await read(reader)
    }
}

func e3b_full_composition() async {
    print("E3b: Full composition — callAsFunction + async + consuming sending + nonisolated(nonsending)")
    let stream = StreamE3b(
        internalReader: InternalReader(id: 31),
        internalWriter: InternalWriter(id: 32)
    )

    let result = await stream { reader in
        var reader = reader
        return reader.read()
    } write: { writer in
        writer.write(99)
    }
    print("  E3b result: \(result)")
}

// ═══════════════════════════════════════════════════════════
// MARK: - E3c: Full composition WITH typed throws + Either
// Hypothesis: throws(Either<IO.Error, E>) composes with everything else.
// Result: CONFIRMED
// ═══════════════════════════════════════════════════════════

enum IOError: Error { case broken }
enum UserError: Error { case bad }

enum TestEither<Left: Error, Right: Error>: Error {
    case left(Left)
    case right(Right)
}

struct StreamE3c: ~Copyable {
    var internalReader: InternalReader
    var internalWriter: InternalWriter

    consuming func callAsFunction<R, E: Error & Sendable>(
        _ read: nonisolated(nonsending) (consuming sending ReaderE2) async throws(E) -> R,
        write: nonisolated(nonsending) (consuming sending WriterE2) async throws(E) -> Void
    ) async throws(TestEither<IOError, E>) -> R {
        var r = internalReader
        var w = internalWriter
        let reader = ReaderE2(&r)
        let writer = WriterE2(&w)

        do {
            try await write(writer)
        } catch {
            throw .right(error)
        }
        do {
            return try await read(reader)
        } catch {
            throw .right(error)
        }
    }
}

func e3c_full_composition_typed_throws() async throws {
    print("E3c: Full composition with typed throws + Either")
    let stream = StreamE3c(
        internalReader: InternalReader(id: 33),
        internalWriter: InternalWriter(id: 34)
    )

    let result = try await stream { reader in
        var reader = reader
        return reader.read()
    } write: { writer in
        writer.write(77)
    }
    print("  E3c result: \(result)")
}

// ═══════════════════════════════════════════════════════════
// MARK: - Entry Point
// ═══════════════════════════════════════════════════════════

e1_callAsFunction_noncopyable()
e1b_callAsFunction_closures()
e2_consuming_sending_noncopyable_nonescapable()
e2b_consuming_sending_closure_param()
await e3_nonisolated_nonsending_consuming_sending()
await e3b_full_composition()
try await e3c_full_composition_typed_throws()

print("\n--- All experiments completed ---")
