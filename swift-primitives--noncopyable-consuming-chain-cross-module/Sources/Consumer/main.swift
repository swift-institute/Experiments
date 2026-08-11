// SUPERSEDED: See noncopyable-access-patterns
// MARK: - 3-Layer Consuming Cleanup Chain (Cross-Module)
//
// Purpose:  Verify that a consuming cleanup chain works across 4 separate
//           modules: StorageLib -> BufferLib -> DataStructureLib -> Consumer.
//           Only the data structure has deinit + _deinitWorkaround. Buffer
//           and Storage have NO deinit — they provide consuming cleanup methods.
//
// Hypothesis: Consuming method calls in deinit body transfer ownership of
//             stored properties, enabling cleanup delegation without struct
//             deinit chains. No #86652 triggers because only one type has deinit.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform:  macOS 26.0 (arm64)
//
// Result: CONFIRMED — debug + release, all elements properly deinitialized
//         Output: "Deinit order: [1, 2, 3]"
// Date:   2026-04-01

import DataStructureLib

final class Tracker: @unchecked Sendable {
    var order: [Int] = []
    func append(_ id: Int) { order.append(id) }
}

struct TrackedElement: ~Copyable {
    let id: Int
    let tracker: Tracker
    deinit { tracker.append(id) }
}

let tracker = Tracker()
do {
    var tree = Tree<TrackedElement, 8>()
    tree.buffer.storage.store(TrackedElement(id: 1, tracker: tracker), at: 0)
    tree.buffer.storage.store(TrackedElement(id: 2, tracker: tracker), at: 1)
    tree.buffer.storage.store(TrackedElement(id: 3, tracker: tracker), at: 2)
}
print("Deinit order: \(tracker.order)")
assert(tracker.order == [1, 2, 3], "Expected [1, 2, 3], got \(tracker.order)")
print("CONFIRMED: 3-layer consuming chain works cross-module")
