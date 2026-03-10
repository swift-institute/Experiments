// MARK: - ~Copyable Inline Storage Deinit Bug
// Purpose: ~Copyable structs may fail to call element deinitializers
// Status: BUG REPRODUCED (2026-01-20, Swift 6.2)
// Revalidation: FIXED in Swift 6.2.4 — deinits fire correctly (2026-03-10)

// Track deinit calls via a global counter
nonisolated(unsafe) var deinitCount = 0

struct Resource: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { deinitCount += 1; print("  deinit Resource(\(id))") }
}

struct InlineStorage: ~Copyable {
    var a: Resource
    var b: Resource

    init() {
        a = Resource(1)
        b = Resource(2)
    }

    deinit {
        print("InlineStorage deinit called")
        // Elements should be destroyed automatically
    }
}

print("Before scope:")
deinitCount = 0
do {
    let _ = InlineStorage()
    print("  Inside scope")
}
print("After scope: deinitCount = \(deinitCount)")
print(deinitCount == 2 ? "PASS: Both elements deinitialized" : "FAIL: Expected 2 deinits, got \(deinitCount)")
