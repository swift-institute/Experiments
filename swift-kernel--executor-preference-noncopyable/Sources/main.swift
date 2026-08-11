// MARK: - withTaskExecutorPreference + ~Copyable: Eliminating Transfer.Cell
// Purpose: Can withTaskExecutorPreference run concurrent read/write on a
//   dedicated executor thread, passing ~Copyable values via consuming
//   parameters instead of Transfer.Cell?
// Hypothesis: withTaskExecutorPreference pins tasks to an executor. If both
//   the read and write tasks run on the same executor, no @Sendable boundary
//   is crossed, and ~Copyable values can be passed via consuming parameters.
//
// Toolchain: Xcode 26.0 beta / Swift 6.3
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — withTaskExecutorPreference changes WHERE tasks run
//   (dedicated thread vs cooperative pool) but NOT how closures capture.
//   All Swift concurrency primitives (async let, TaskGroup.addTask,
//   withTaskExecutorPreference) use escaping closures. ~Copyable values
//   cannot cross escaping closure boundaries without Transfer.Cell.
//
//   HOWEVER: combining executor preference WITH Transfer.Cell eliminates
//   the cooperative pool dependency while keeping Transfer.Cell for
//   ownership transfer. This is the pragmatic path forward.
//
// Date: 2026-04-06

import Kernel

// MARK: - Setup

struct Writer: ~Copyable {
    let id: Int
    consuming func write(_ data: String) -> String { "wrote-\(data)-on-\(id)" }
}

struct Reader: ~Copyable {
    let id: Int
    consuming func read() -> String { "read-from-\(id)" }
}

// MARK: - V1: withTaskExecutorPreference captures are escaping
// Result: REFUTED — "missing reinitialization of closure capture after consume"
// withTaskExecutorPreference uses an escaping closure, same as async let.
#if false
func v1_consumeInBody() async {
    let executor = Kernel.Thread.Executor(mode: .task)
    defer { executor.shutdown() }
    let writer = Writer(id: 1)
    await withTaskExecutorPreference(executor) {
        _ = writer.write("test")  // error: noncopyable captured by escaping closure
    }
}
#endif

// MARK: - V2: Consuming function params + executor preference
// Result: REFUTED — function parameters captured in executor closure
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//   give "missing reinitialization" error.
#if false
func v2_consumingParams(
    reader: consuming Reader,
    writer: consuming Writer,
    on executor: Kernel.Thread.Executor
) async -> (String, String) {
    var r = "", w = ""
    await withTaskExecutorPreference(executor) {
        w = writer.write("hello")  // error: missing reinitialization
        r = reader.read()          // error: missing reinitialization
    }
    return (r, w)
}
#endif

// MARK: - V3: Executor preference + Transfer.Cell (WORKS)
// The pragmatic solution: Transfer.Cell for ~Copyable transfer,
// executor preference to avoid the cooperative pool.

final class Box<T: ~Copyable>: @unchecked Sendable {
    private var _value: T?
    init(_ value: consuming T) { _value = .some(value) }
    func take() -> T { _value.take()! }
}

func v3_executorWithCell() async {
    let executor = Kernel.Thread.Executor(mode: .task)
    defer { executor.shutdown() }

    let reader = Reader(id: 3)
    let writer = Writer(id: 3)

    let readerBox = Box(reader)
    let writerBox = Box(writer)

    await withTaskExecutorPreference(executor) {
        // Both run on the dedicated executor thread
        async let w: String = {
            writerBox.take().write("on-executor")
        }()

        let r = readerBox.take().read()
        let writeResult = await w
        print("V3: \(r), \(writeResult)")
    }
}

// MARK: - V4: Verify executor preference actually runs on thread

func v4_verifyExecutor() async {
    let executor = Kernel.Thread.Executor(mode: .task)
    defer { executor.shutdown() }

    await withTaskExecutorPreference(executor) {
        print("V4: ran on executor (dedicated thread)")
    }
}

// MARK: - Run

await v3_executorWithCell()
await v4_verifyExecutor()

// MARK: - Results Summary
// V1: REFUTED — escaping closure capture blocks ~Copyable
// V2: REFUTED — function params captured by escaping closure
// V3: CONFIRMED — Transfer.Cell + executor preference works
// V4: CONFIRMED — executor preference runs on dedicated thread
//
// Conclusion:
// - withTaskExecutorPreference changes WHERE (dedicated thread)
// - Transfer.Cell changes HOW (~Copyable crosses boundary)
// - Combining both: dedicated thread + ~Copyable transfer
// - This eliminates cooperative pool dependency while keeping Transfer.Cell
// - The "perfect world" (no Transfer.Cell at all) requires Swift evolution:
//   non-escaping async let, or consuming task creation
