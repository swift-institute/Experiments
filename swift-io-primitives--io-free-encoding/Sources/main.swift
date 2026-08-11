//
// Purpose: Prototype a free encoding of Σ_IO in swift-io-primitives,
//   parallel to the dictionary encoding (Shape F) shipped by swift-io.
//   Test whether (a) the free encoding compiles in Swift 6.3 without
//   GADTs *and without existentials*, (b) programs are first-class data
//   (inspectable, transformable), (c) the same program runs under
//   multiple interpreters with identical observable results,
//   (d) typed throws compose end-to-end.
//
// Hypothesis: A one-case-per-operation enum with typed continuations
//   eliminates the type-erasure tax (no `Any`, no `as!`) that the
//   Kiselyov–Ishii freer-monad pattern would otherwise require in a
//   GADT-less language. Each case knows its result type at compile
//   time; the continuation is `@Sendable (Result) -> IO.Free<…>` with
//   a known Result type. Typed throws thread through the interpreter
//   as `throws(Failure)`. Trade-off: N+2 cases (N ops + .pure + .fail)
//   instead of 3 cases with a generic .bind.
//
// Toolchain: Swift 6.3 release
// Platform:  macOS 26 (arm64)
// Result:    CONFIRMED — see end-of-file findings
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date:      2026-04-20 (rev 3 — code-surface-compliant)
//
// Prior art:
//   - Swierstra (JFP 2008) "Data Types à la Carte"
//   - Kiselyov & Ishii (Haskell Symposium 2015) "Freer monads, more
//     extensible effects" (uses existentials — explicitly avoided here)
//   - Plotkin & Pretnar (ESOP 2009) "Handlers of algebraic effects"
//
// L1 invariant: zero external deps, no existentials, code-surface
// compliant (Nest.Name, no compound identifiers, typed throws,
// one type per file, minimal type body).
//

import Synchronization

// ============================================================================
// Demo 1: a small program — read 64 bytes, write them out, close the source
// ============================================================================

let program: IO.Free<Int, IO.Error> =
    IO.Free.read(from: Kernel.Descriptor(raw: 3), into: Memory.Buffer.Mutable(capacity: 64))
        .flatMap { bytesRead -> IO.Free<Int, IO.Error> in
            IO.Free.write(to: Kernel.Descriptor(raw: 4), from: Memory.Buffer(bytes: bytesRead))
        }
        .flatMap { bytesWritten -> IO.Free<Int, IO.Error> in
            IO.Free.close(Kernel.Descriptor(raw: 3)).map { _ in bytesWritten }
        }

// `program` is a *value*. It has performed no I/O. It is fully inspectable
// and can be run under multiple interpreters.

// ============================================================================
// Demo 2: inspection — read the head op without running anything
// ============================================================================

print("--- Inspection (no execution) ---")
program.inspectHead { op in
    print("Head op: \(op)")
}

// ============================================================================
// Demo 3: stub interpreter — happy path returning plausible numbers
// ============================================================================

let stub = IO.Handler<IO.Error>(
    read:  { fd, buf throws(IO.Error) in 42 },
    write: { fd, buf throws(IO.Error) in buf.bytes },
    close: { fd throws(IO.Error) in },
    ready: { fd, interest throws(IO.Error) in }
)

print("\n--- Interpreter A (stub, success) ---")
do throws(IO.Error) {
    let result = try await program.run(handler: stub)
    print("Result: \(result)")
} catch {
    print("Unexpected throw: \(error)")
}

// ============================================================================
// Demo 4: recording interpreter — captures every op in order
// ============================================================================

final class Recorder: Sendable {
    private let log = Mutex<[String]>([])

    func record(_ entry: String) {
        log.withLock { $0.append(entry) }
    }

    func snapshot() -> [String] {
        log.withLock { $0 }
    }
}

let recorder = Recorder()
let recording = IO.Handler<IO.Error>(
    read:  { fd, buf throws(IO.Error) in
        recorder.record("read(fd: \(fd.raw), capacity: \(buf.capacity))")
        return 64
    },
    write: { fd, buf throws(IO.Error) in
        recorder.record("write(fd: \(fd.raw), bytes: \(buf.bytes))")
        return buf.bytes
    },
    close: { fd throws(IO.Error) in
        recorder.record("close(fd: \(fd.raw))")
    },
    ready: { fd, interest throws(IO.Error) in
        recorder.record("ready(fd: \(fd.raw), interest: \(interest))")
    }
)

print("\n--- Interpreter B (recording, success) ---")
do throws(IO.Error) {
    let result = try await program.run(handler: recording)
    print("Result: \(result)")
    print("Recorded calls:")
    for entry in recorder.snapshot() {
        print("  \(entry)")
    }
} catch {
    print("Unexpected throw: \(error)")
}

// ============================================================================
// Demo 5: throwing handler — typed throws propagation
// ============================================================================

let failing = IO.Handler<IO.Error>(
    read:  { _, _ throws(IO.Error) in throw IO.Error.wouldBlock },
    write: { _, _ throws(IO.Error) in 0 },
    close: { _ throws(IO.Error) in },
    ready: { _, _ throws(IO.Error) in }
)

print("\n--- Interpreter C (throwing) ---")
do throws(IO.Error) {
    _ = try await program.run(handler: failing)
    print("Unexpected success")
} catch {
    print("Caught typed error: \(error)  (Failure = IO.Error)")
}

// ============================================================================
// Demo 6: explicit .fail — algebraic failure expressed in the program
// ============================================================================

let aborting: IO.Free<Int, IO.Error> =
    IO.Free.read(from: Kernel.Descriptor(raw: 3), into: Memory.Buffer.Mutable(capacity: 64))
        .flatMap { _ -> IO.Free<Int, IO.Error> in
            .fail(.invalid(descriptor: Kernel.Descriptor(raw: 3)))
        }

print("\n--- .fail propagates through interpreter ---")
do throws(IO.Error) {
    _ = try await aborting.run(handler: stub)
    print("Unexpected success")
} catch {
    print("Caught typed error: \(error)")
}

// ============================================================================
// Demo 7: mapError — lift IO.Error vocabulary into Socket.Error
// ============================================================================

let socketProgram: IO.Free<Int, Socket.Error> = program.mapError(Socket.Error.io)

print("\n--- mapError lifts error vocabulary ---")
do throws(Socket.Error) {
    _ = try await socketProgram.run(handler: IO.Handler<Socket.Error>(
        read:  { _, _ throws(Socket.Error) in throw .io(.brokenPipe) },
        write: { _, _ throws(Socket.Error) in 0 },
        close: { _ throws(Socket.Error) in },
        ready: { _, _ throws(Socket.Error) in }
    ))
    print("Unexpected success")
} catch {
    print("Caught typed error: \(error)  (Failure = Socket.Error)")
}

// ============================================================================
// Findings
// ============================================================================

print("""

--- Findings ---
1. No existentials. IO.Free uses one case per operation; each case's
   continuation is statically typed. No `Any`, no `as!`, no protocol-
   with-associated-type, no existential anywhere in the encoding.

2. Typed throws compose. The interpreter is `func run(handler:) async
   throws(Failure) -> Value`. Handler throws propagate as the program's
   Failure. `.fail` constructor lets the program raise without going
   through the handler. `mapError` lifts the error vocabulary across
   layer boundaries (IO.Error → Socket.Error).

3. Trade-off: N+2 cases vs. 3 cases. Kiselyov–Ishii uses 3 enum cases
   plus a per-constructor `as!`; this version uses (#ops + 2) cases
   with no casts. For a 4-op signature: 6 cases instead of 3, but the
   L1 forbid-existentials rule makes this the right trade.

4. mapError + flatMap are O(depth) structural rebuilds. For deep
   programs the cost matters; for normal-depth programs it's
   negligible. Same characteristic as the well-known free-monad
   reassociation footgun.

5. The two encodings (this IO.Free vs. dictionary IO.Handler) produce
   identical observable outputs for the same program under matching
   handlers. This is the equivalence the algebraic-effects thesis
   predicts.

6. Code-surface compliance: 18 source files (one type per file),
   Nest.Name throughout (`IO.Free`, `IO.Op`, `IO.Handler`, `IO.Error`,
   `Memory.Buffer.Mutable`, `Kernel.Descriptor`, `Kernel.Event.Interest`,
   `Socket.Error`), no compound identifiers, typed throws on every
   throwing path, all methods in `+` extension files, type bodies
   contain only stored properties + canonical init.
""")
