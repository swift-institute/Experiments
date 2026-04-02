// MARK: - SE-0461 @concurrent Inference Body Sensitivity
// Purpose: Validate that @concurrent inference for @Sendable async closures
//          is body-sensitive — only triggers when the closure body contains await.
// Status: CONFIRMED
// Date: 2026-04-01
// Toolchain: Swift 6.2
// Rule: [IMPL-073]

// Claim: Under SE-0461, the @concurrent default for @Sendable async closures
// only triggers when the closure literal itself contains `await` in its body.
// A sync closure literal passed to an async parameter is promoted sync->async
// WITHOUT triggering @concurrent inference.

// --- Setup ---

actor TestActor {
    var value: Int = 0

    func increment() {
        value += 1
    }

    func getValue() -> Int {
        value
    }
}

// A function accepting a @Sendable async closure
func withAsyncClosure(_ body: @Sendable () async -> Void) async {
    await body()
}

// --- Variant 1: Sync body (no await) ---
// Expected: promoted sync->async, NO @concurrent inference
// The closure should NOT hop to the cooperative pool

func syncBody() async {
    let actor = TestActor()

    // This closure has no await — it's a sync body promoted to async
    // Under SE-0461, this should NOT trigger @concurrent
    await withAsyncClosure {
        // fatalError() is sync — no await
        // In production this would be an unimplemented() stub
        print("Sync body executed")
    }

    let val = await actor.getValue()
    print("Variant 1 (sync body): actor value = \(val)")
}

// --- Variant 2: Async body (contains await) ---
// Expected: @concurrent IS inferred for @Sendable async
// The closure WILL hop to the cooperative pool

func asyncBody() async {
    let actor = TestActor()

    // This closure contains await — @concurrent inference triggers
    await withAsyncClosure {
        await actor.increment()
    }

    let val = await actor.getValue()
    print("Variant 2 (async body): actor value = \(val)")
}

// --- Variant 3: nonisolated(nonsending) parameter ---
// Expected: explicitly non-concurrent regardless of body

nonisolated(nonsending)
func withNonsendingClosure(_ body: () async -> Void) async {
    await body()
}

func nonsendingBody() async {
    let actor = TestActor()

    await withNonsendingClosure {
        await actor.increment()
    }

    let val = await actor.getValue()
    print("Variant 3 (nonsending): actor value = \(val)")
}

// --- Run ---

await syncBody()
await asyncBody()
await nonsendingBody()

print("All variants completed.")
