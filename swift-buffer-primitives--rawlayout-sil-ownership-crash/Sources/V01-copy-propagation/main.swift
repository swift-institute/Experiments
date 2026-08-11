// MARK: - V01: CopyPropagation Crash — ~Copyable Enum Payload Consumption
// Purpose: Reproduce CopyPropagation SIL pass crash (signal 6) in release builds
//          when consuming ~Copyable values inside enum switch cases.
//
// Two distinct patterns trigger the crash in production (buffer-primitives):
//   Pattern A: Consuming a ~Copyable parameter inside switch on @frozen ~Copyable enum
//   Pattern B: Conditionally moving ~Copyable elements in a loop with bitmap checks
//
// Toolchain: Swift 6.2.4 (Xcode, arm64 macOS 26)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — crash does not reproduce in isolation. Context-sensitive bug
//         per [EXP-004a]. Requires the full production codebase interaction
//         (5+ layers of @inlinable typed infrastructure cascading through
//         cross-module generic specialization).
// Date: 2026-03-21
//
// Consolidates: copy-propagation-noncopyable-enum (V3-V5)
// Supports: SIL ownership crash is context-sensitive

import V01_copy_propagation_lib

// --- V3: Nested in generic enum (matches Buffer<Element> pattern) ---

enum Container<Element: ~Copyable> {

    struct Inline: ~Copyable {
        var storage: InlineStorage<Element>
        var count: Int

        init(capacity: Int) {
            self.storage = InlineStorage(capacity: capacity)
            self.count = 0
        }

        mutating func append(_ element: consuming Element) {
            storage.initialize(to: consume element, at: count)
            count += 1
        }

        func move(at index: Int) -> Element {
            storage.move(at: index)
        }
    }

    struct Small: ~Copyable {
        @frozen
        enum _Representation: ~Copyable {
            case inline(Inline)
            case heap(HeapStorage<Element>)
        }

        var _storage: _Representation

        init(capacity: Int) {
            self._storage = .inline(Inline(capacity: capacity))
        }

        init(_storage: consuming _Representation) {
            self._storage = consume _storage
        }

        mutating func append(_ element: consuming Element) {
            switch _storage {
            case .inline(var buf):
                if buf.count < buf.storage.capacity {
                    buf.append(element)
                    self = Small(_storage: .inline(consume buf))
                } else {
                    let heap = HeapStorage<Element>(capacity: buf.storage.capacity * 2)
                    for i in 0..<buf.count {
                        heap.append(buf.move(at: i))
                    }
                    self = Small(_storage: .heap(heap))
                    _appendToHeap(element)
                }
            case .heap(var heap):
                heap.append(element)
                self = Small(_storage: .heap(consume heap))
            }
        }

        mutating func _appendToHeap(_ element: consuming Element) {
            switch _storage {
            case .inline(var buf):
                self = Small(_storage: .inline(consume buf))
                fatalError("Expected heap")
            case .heap(var heap):
                heap.append(element)
                self = Small(_storage: .heap(consume heap))
            }
        }
    }
}

// --- V5: Slab with value generic + bitmap ---

enum SlabContainer<Element: ~Copyable> {

    struct Inline<let wordCount: Int>: ~Copyable {
        var storage: InlineStorage<Element>
        var bitmap: UInt64

        init() {
            self.storage = InlineStorage(capacity: wordCount)
            self.bitmap = 0
        }

        func isOccupied(_ index: Int) -> Bool {
            (bitmap >> index) & 1 == 1
        }

        mutating func insert(_ element: consuming Element, at index: Int) {
            storage.initialize(to: element, at: index)
            bitmap |= (1 << index)
        }

        mutating func removeAll() {
            for i in 0..<wordCount {
                if isOccupied(i) {
                    storage.deinitialize(at: i)
                    bitmap &= ~(1 << i)
                }
            }
        }

        deinit {
            for i in 0..<wordCount {
                if isOccupied(i) {
                    storage.deinitialize(at: i)
                }
            }
        }
    }
}

// --- Tests ---

func testSmall() {
    var buf = Container<NCElement>.Small(capacity: 2)
    buf.append(NCElement(1))
    buf.append(NCElement(2))
    buf.append(NCElement(3))
    print("V01-Small: enum switch + consuming — OK")
}

func testSlab() {
    var slab = SlabContainer<NCElement>.Inline<8>()
    slab.insert(NCElement(10), at: 0)
    slab.insert(NCElement(20), at: 3)
    slab.removeAll()
    print("V01-Slab: bitmap loop + conditional move — OK")
}

testSmall()
testSlab()
print("\nAll V01 variants pass in isolation.")
print("NOTE: In production, CopyPropagation crashes with 'Found ownership error?!'")
print("      SIL ownership crash is PRE-EXISTING — happens with all 4 Inline deinits intact.")
print("      Was masked by LLVM verifier crash preventing Core from building.")
