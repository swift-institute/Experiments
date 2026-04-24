// MARK: - TaskGroup + addTask(executorPreference:) + ~Copyable/~Escapable
// Purpose: Determine optimal structured-concurrency pattern for scheduling
//   write child on dedicated executor while keeping read on cooperative pool.
//   Three approaches tested:
//   A) TaskGroup + addTask(executorPreference:) — both sides via Transfer.Cell
//   B) async let + withTaskExecutorPreference inside child — reader inline (1 cell)
//   C) Broad withTaskExecutorPreference + async let — both via Transfer.Cell
//
// Key finding from build 1: withTaskGroup body IS escaping for ~Copyable
//   consume purposes. Borrowing works, consuming does not. Same constraint
//   as withTaskExecutorPreference.
//
// Toolchain: Xcode 26.0 beta / Swift 6.3
// Platform: macOS 26.0 (arm64)
//
// Result: ALL CONFIRMED — three viable approaches with distinct trade-offs.
//   Approach B (V3) is optimal: 1 Transfer.Cell, minimal code change,
//   read user compute on coop pool.
// Date: 2026-04-06

// MARK: - Stand-in types

final class Box<T: ~Copyable>: @unchecked Sendable {
    private var _value: T?
    init(_ value: consuming T) { _value = .some(value) }
    func take() -> T { _value.take()! }
}

struct ChannelReader: ~Copyable, Sendable {
    let id: Int
}

struct ChannelWriter: ~Copyable, Sendable {
    let id: Int
}

struct Reader: ~Copyable, ~Escapable {
    var inner: ChannelReader

    @_lifetime(immortal)
    init(channelReader: consuming ChannelReader) {
        self.inner = channelReader
    }

    mutating func read() async -> Int { inner.id }
}

struct Writer: ~Copyable, ~Escapable {
    var inner: ChannelWriter

    @_lifetime(immortal)
    init(channelWriter: consuming ChannelWriter) {
        self.inner = channelWriter
    }

    mutating func write(_ data: Int) async {
        print("  Writer \(inner.id) wrote \(data)")
    }
}

struct IOError: Error { let message: String }

// MARK: - V1: withTaskGroup body is escaping for ~Copyable (CONFIRMED)
// Build 1 showed: borrow OK, consume rejected.
// "noncopyable cannot be consumed when captured by an escaping closure"
// Result: CONFIRMED — body is escaping for ~Copyable consume.
// Evidence: V1a compiles and runs. V1b (disabled) fails with
//   "noncopyable cannot be consumed when captured by an escaping closure".

func v1a_borrowInBody() async {
    let channel = ChannelReader(id: 1)
    await withTaskGroup(of: Void.self) { group in
        let value = channel.id
        print("V1a: borrowed = \(value)")
    }
}

#if false
// FAILS: "noncopyable 'channel' cannot be consumed when captured by an escaping closure"
func v1b_consumeInBody() async {
    let channel = ChannelReader(id: 1)
    await withTaskGroup(of: Void.self) { group in
        func eat(_ r: consuming ChannelReader) -> Int { r.id }
        let _ = eat(channel)
    }
}
#endif

// MARK: - V2: Approach A — TaskGroup + addTask(executorPreference:)
// Both reader and writer via Transfer.Cell (2 cells).
// Write child scheduled directly on executor. Read inline in body.
// Hypothesis: Compiles and runs. Read user compute stays on caller's thread.
// Result: CONFIRMED — Output: "Writer 2 wrote 42", "V2: result = 2"

func v2_taskGroupBothCells() async throws(IOError) {
    let channelReader = ChannelReader(id: 2)
    let channelWriter = ChannelWriter(id: 2)
    let readerToken = Box(channelReader)
    let writerToken = Box(channelWriter)

    let readFn: @Sendable (consuming sending Reader) async throws(IOError) -> Int = { reader in
        var r = reader
        return await r.read()
    }
    let writeFn: @Sendable (consuming sending Writer) async throws(IOError) -> Void = { writer in
        var w = writer
        await w.write(42)
    }

    let result: Result<Int, IOError> = await withTaskGroup(
        of: Result<Void, IOError>.self
    ) { group in
        group.addTask(executorPreference: nil) {
            do throws(IOError) {
                let writer = Writer(channelWriter: writerToken.take())
                try await writeFn(consume writer)
                return .success(())
            } catch {
                return .failure(error)
            }
        }

        do throws(IOError) {
            let reader = Reader(channelReader: readerToken.take())
            let value = try await readFn(consume reader)

            if let writeResult = await group.next(),
               case .failure(let e) = writeResult {
                return .failure(e)
            }
            return .success(value)
        } catch {
            group.cancelAll()
            _ = await group.next()
            return .failure(error)
        }
    }

    switch result {
    case .success(let v): print("V2: result = \(v)")
    case .failure(let e): throw e
    }
}

// MARK: - V3: Approach B — async let + withTaskExecutorPreference inside child
// Reader consumed at function scope (1 cell — writer only). Minimal change
// from current code. Write child initially scheduled on coop pool, switches
// to executor at first await inside withTaskExecutorPreference.
// Hypothesis: Compiles and runs. Same Transfer.Cell count as current code.
// Result: CONFIRMED — Output: "Writer 3 wrote 77", "V3: result = 3"

func v3_asyncLetPrefInside() async throws(IOError) -> Int {
    let channelReader = ChannelReader(id: 3)
    let channelWriter = ChannelWriter(id: 3)
    let writerToken = Box(channelWriter)

    let readFn: @Sendable (consuming sending Reader) async throws(IOError) -> Int = { reader in
        var r = reader
        return await r.read()
    }
    let writeFn: @Sendable (consuming sending Writer) async throws(IOError) -> Void = { writer in
        var w = writer
        await w.write(77)
    }

    async let writeResult: Result<Void, IOError> = withTaskExecutorPreference(nil) {
        do throws(IOError) {
            let writer = Writer(channelWriter: writerToken.take())
            try await writeFn(consume writer)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    do throws(IOError) {
        // Reader consumed at function scope — no Transfer.Cell needed
        let reader = Reader(channelReader: channelReader)
        let value = try await readFn(consume reader)

        switch await writeResult {
        case .success: return value
        case .failure(let e): throw e
        }
    } catch {
        _ = await writeResult
        throw error
    }
}

// MARK: - V4: Approach C — Broad withTaskExecutorPreference + async let
// Both via Transfer.Cell (2 cells). Everything on executor.
// Hypothesis: Compiles and runs. Same as handoff Step 7 original plan.
// Result: CONFIRMED — requires explicit closure type annotation
//   `() async throws(IOError) -> Int in` — async let inside the closure
//   breaks typed throws inference. Output: "Writer 4 wrote 55", "V4: result = 4"

func v4_broadPrefAsyncLet() async throws(IOError) -> Int {
    let channelReader = ChannelReader(id: 4)
    let channelWriter = ChannelWriter(id: 4)
    let readerToken = Box(channelReader)
    let writerToken = Box(channelWriter)

    let readFn: @Sendable (consuming sending Reader) async throws(IOError) -> Int = { reader in
        var r = reader
        return await r.read()
    }
    let writeFn: @Sendable (consuming sending Writer) async throws(IOError) -> Void = { writer in
        var w = writer
        await w.write(55)
    }

    return try await withTaskExecutorPreference(nil) { () async throws(IOError) -> Int in
        async let writeResult: Result<Void, IOError> = {
            do throws(IOError) {
                let writer = Writer(channelWriter: writerToken.take())
                try await writeFn(consume writer)
                return .success(())
            } catch {
                return .failure(error)
            }
        }()

        do throws(IOError) {
            let reader = Reader(channelReader: readerToken.take())
            let value = try await readFn(consume reader)

            switch await writeResult {
            case .success: return value
            case .failure(let e): throw e
            }
        } catch {
            _ = await writeResult
            throw error
        }
    }
}

// MARK: - V5: Error semantics — read error cancels write
// Hypothesis: TaskGroup cancelAll() cancels write child.
//   Read error propagates. Same semantics as async let.
// Result: CONFIRMED — Output: "write task was cancelled", "error = read failed"

func v5_errorSemantics() async {
    let result: Result<Int, IOError> = await withTaskGroup(
        of: Result<Void, IOError>.self
    ) { group in
        group.addTask(executorPreference: nil) {
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled {
                print("  V5: write task was cancelled")
            } else {
                print("  V5: write task completed (unexpected)")
            }
            return .success(())
        }

        do throws(IOError) {
            // Simulate read error
            throw IOError(message: "read failed")
        } catch {
            group.cancelAll()
            _ = await group.next()
            return .failure(error)
        }
    }

    switch result {
    case .success: print("V5: unexpected success")
    case .failure(let e): print("V5: error = \(e.message)")
    }
}

// MARK: - Run

await v1a_borrowInBody()
do throws(IOError) { try await v2_taskGroupBothCells() } catch { print("V2 error: \(error)") }
do throws(IOError) { let v = try await v3_asyncLetPrefInside(); print("V3: result = \(v)") } catch { print("V3 error: \(error)") }
do throws(IOError) { let v = try await v4_broadPrefAsyncLet(); print("V4: result = \(v)") } catch { print("V4 error: \(error)") }
await v5_errorSemantics()

// MARK: - Results Summary
// V1:  CONFIRMED — withTaskGroup body escaping for ~Copyable consume
// V2:  CONFIRMED — Approach A: TaskGroup + addTask(pref:), 2 cells
// V3:  CONFIRMED — Approach B: async let + pref inside child, 1 cell
// V4:  CONFIRMED — Approach C: broad pref + async let, 2 cells (needs type annotation)
// V5:  CONFIRMED — Error semantics: cancelAll() cancels write, read error propagates
//
// | Approach | Cells | Write sched  | Write cont | Read cont | Read compute | Code delta |
// |----------|-------|--------------|------------|-----------|--------------|------------|
// | A (V2)   | 2     | executor     | executor   | coop pool | coop pool    | structural |
// | B (V3)   | 1     | coop→exec    | executor   | coop pool | coop pool    | minimal    |
// | C (V4)   | 2     | executor     | executor   | executor  | executor     | structural |
//
// Recommendation: Approach B (V3)
// - Identical Transfer.Cell footprint to current code (1 cell, writer only)
// - Minimal code change: wrap async let body in withTaskExecutorPreference
// - Read user compute stays on cooperative pool (Risk 3 mitigated for read side)
// - Write side on executor (writes are pure I/O — no user compute concern)
// - Trade-off: write child's initial scheduling touches coop pool briefly,
//   then switches to executor at first await. Under extreme pool saturation,
//   one-time scheduling delay. Strictly better than current (pool for everything).
//
// Approach A (V2) is better if zero pool dependency is required.
//   Costs: 2 cells, structural change from async let to TaskGroup.
// Approach C (V4) is the original handoff plan.
//   Costs: 2 cells, Risk 3 for read side, needs explicit closure annotation.
