// MARK: - Improvement Discovery: Input.Checkpoint using existing primitives
// Purpose: Refactor checkpoint types to reuse Index<Element> from index-primitives
// Hypothesis: Checkpoint validation can use existing primitives, not ad-hoc types
// Baseline: Input.Buffer uses raw Int, validation is scattered
//
// Toolchain: swift-6.2-RELEASE
// Date: 2026-01-21
// Result: CONFIRMED — Checkpoint should use Index<Element> phantom type.
//   checkpointRange.contains() centralizes validation. Pattern prevents
//   cross-input checkpoint misuse.

// ============================================================================
// CURRENT STATE (Baseline)
// ============================================================================
//
// Input.Buffer:
//   typealias Checkpoint = Int
//   func __isValidCheckpoint(_ cp: Int) -> Bool {
//       cp >= 0 && cp <= totalCount
//   }
//
// Input.Slice:
//   typealias Checkpoint = Base.Index
//   func __isValidCheckpoint(_ cp: Base.Index) -> Bool {
//       cp >= base.startIndex && cp <= endIndex
//   }
//
// Problems:
// 1. Buffer uses raw Int - no phantom typing
// 2. Validation logic is duplicated/scattered
// 3. No reuse of existing primitives

// ============================================================================
// AVAILABLE PRIMITIVES (from swift-index-primitives, swift-affine-primitives)
// ============================================================================
//
// Index<Element>
//   - Phantom-typed wrapper around Affine.Discrete.Position
//   - Sendable, Comparable, Hashable
//   - Non-negative guarantee (from Position)
//   - Affine arithmetic (Index + Offset → Index)
//
// Index<Element>.Bounded<N>
//   - Compile-time bounded variant
//   - Guaranteed in range 0..<N
//
// Affine.Discrete.Position
//   - Non-negative discrete position
//   - Foundation for Index<Element>
//
// ClosedRange<T> (stdlib)
//   - .contains(_:) for validation
//   - .lowerBound, .upperBound

// ============================================================================
// PROPOSED DESIGN: Reuse Index<Element>
// ============================================================================

// Simulate Index<Element> (in real code, import from index-primitives)
struct Index<Element>: Sendable, Hashable, Comparable {
    let rawValue: Int

    init(_ rawValue: Int) throws {
        guard rawValue >= 0 else { throw IndexError.negativePosition }
        self.rawValue = rawValue
    }

    init(__unchecked rawValue: Int) {
        self.rawValue = rawValue
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum IndexError: Error {
    case negativePosition
}

// ============================================================================
// REFACTORED INPUT.BUFFER
// ============================================================================

enum Input {}

extension Input {
    struct Buffer<Element: Sendable>: Sendable {
        var storage: [Element]
        var position: Int

        init(_ elements: [Element]) {
            self.storage = elements
            self.position = 0
        }
    }
}

// BEFORE: typealias Checkpoint = Int
// AFTER:  typealias Checkpoint = Index<Element>

extension Input.Buffer {
    typealias Checkpoint = Index<Element>

    var count: Int { storage.count - position }
    var isEmpty: Bool { position >= storage.count }
    var totalCount: Int { storage.count }

    var checkpoint: Checkpoint {
        Checkpoint(__unchecked: position)
    }

    // NEW: Expose range for centralized validation
    var checkpointRange: ClosedRange<Checkpoint> {
        Checkpoint(__unchecked: 0)...Checkpoint(__unchecked: totalCount)
    }

    // Validation now uses range.contains
    func __isValidCheckpoint(_ cp: Checkpoint) -> Bool {
        checkpointRange.contains(cp)
    }

    mutating func __restoreUnchecked(to cp: Checkpoint) {
        position = cp.rawValue
    }
}

// ============================================================================
// TEST: Phantom Typing Prevents Cross-Input Checkpoint Misuse
// ============================================================================

func testPhantomTyping() {
    print("=== Phantom Typing Test ===\n")

    var intBuffer = Input.Buffer([1, 2, 3, 4, 5])
    var stringBuffer = Input.Buffer(["a", "b", "c"])

    let intCheckpoint = intBuffer.checkpoint
    let stringCheckpoint = stringBuffer.checkpoint

    print("Int buffer checkpoint: \(intCheckpoint)")
    print("String buffer checkpoint: \(stringCheckpoint)")

    // These are different types!
    // Index<Int> vs Index<String>
    print("")
    print("intCheckpoint type: Index<Int>")
    print("stringCheckpoint type: Index<String>")
    print("")
    print("Attempting to use intCheckpoint with stringBuffer:")
    print("  stringBuffer.__isValidCheckpoint(intCheckpoint)")
    print("  → COMPILE ERROR: cannot convert Index<Int> to Index<String>")
    print("")
    print("This prevents accidentally using a checkpoint from the wrong input!")

    // In real code, this wouldn't compile:
    // stringBuffer.__isValidCheckpoint(intCheckpoint)  // ❌ Type mismatch
}

// ============================================================================
// TEST: Centralized Validation via checkpointRange
// ============================================================================

func testCentralizedValidation() {
    print("\n=== Centralized Validation Test ===\n")

    let buffer = Input.Buffer([1, 2, 3, 4, 5])

    print("Buffer totalCount: \(buffer.totalCount)")
    print("Checkpoint range: \(buffer.checkpointRange)")
    print("")

    let valid = Index<Int>(__unchecked: 3)
    let invalid = Index<Int>(__unchecked: 10)

    print("Checkpoint 3 valid: \(buffer.__isValidCheckpoint(valid))")    // true
    print("Checkpoint 10 valid: \(buffer.__isValidCheckpoint(invalid))") // false
    print("")
    print("Validation is now: checkpointRange.contains(cp)")
    print("No need for each conformer to implement bounds logic!")
}

// ============================================================================
// SLICE: Already uses Base.Index (no change needed)
// ============================================================================

func testSlice() {
    print("\n=== Slice (no change needed) ===\n")
    print("Input.Slice already uses Base.Index as Checkpoint")
    print("Base.Index is the collection's native index type")
    print("")
    print("For Slice, checkpointRange would be:")
    print("  base.startIndex...endIndex")
    print("")
    print("The pattern is the same - expose range, use contains()")
}

// ============================================================================
// PROTOCOL DESIGN
// ============================================================================

func showProtocolDesign() {
    print("\n" + String(repeating: "=", count: 60))
    print("PROPOSED PROTOCOL DESIGN")
    print(String(repeating: "=", count: 60))
    print("""

    // In Input.Protocol.swift:

    public protocol `Protocol`<Element>: Streaming {
        associatedtype Checkpoint: Sendable & Comparable

        var checkpoint: Checkpoint { get }

        /// The range of valid checkpoint positions.
        var checkpointRange: ClosedRange<Checkpoint> { get }

        mutating func __restoreUnchecked(to checkpoint: Checkpoint)
    }

    // Default validation implementation:
    extension Input.`Protocol` {
        public func __isValidCheckpoint(_ cp: Checkpoint) -> Bool {
            checkpointRange.contains(cp)
        }
    }

    // Input.Buffer conformance:
    extension Input.Buffer {
        public typealias Checkpoint = Index<Element>  // From index-primitives!

        public var checkpointRange: ClosedRange<Checkpoint> {
            Index(__unchecked: 0)...Index(__unchecked: totalCount)
        }
    }

    // Input.Slice conformance:
    extension Input.Slice {
        public typealias Checkpoint = Base.Index  // Already correct

        public var checkpointRange: ClosedRange<Checkpoint> {
            base.startIndex...endIndex
        }
    }
    """)
}

// ============================================================================
// BENEFITS
// ============================================================================

func showBenefits() {
    print("\n" + String(repeating: "=", count: 60))
    print("BENEFITS OF REUSING PRIMITIVES")
    print(String(repeating: "=", count: 60))
    print("""

    1. PHANTOM TYPING (Index<Element>)
       - Checkpoints for Buffer<Int> and Buffer<String> are incompatible
       - Type system prevents cross-input checkpoint misuse
       - No runtime overhead (phantom type erased at compile time)

    2. NON-NEGATIVE GUARANTEE (from Affine.Discrete.Position)
       - Index<Element> cannot hold negative values
       - Eliminates need for `cp >= 0` check
       - Invariant enforced at construction

    3. CENTRALIZED VALIDATION (via checkpointRange)
       - Single implementation: `checkpointRange.contains(cp)`
       - Conformers only provide bounds, not validation logic
       - Uses stdlib ClosedRange - no ad-hoc range type

    4. SENDABLE + COMPARABLE FOR FREE
       - Index<Element> already conforms
       - No need for manual conformance

    5. AFFINE ARITHMETIC
       - Index + Offset → Index
       - Index - Index → Offset
       - Semantically correct (positions aren't addable)

    6. CONSISTENCY WITH ARRAY PRIMITIVES
       - Array.Bounded, Array.Inline use Array<Element>.Index
       - Input.Buffer uses Input<Element>.Checkpoint = Index<Element>
       - Same patterns throughout the ecosystem
    """)
}

// ============================================================================
// WHAT'S ACTUALLY NEEDED IN INPUT.CHECKPOINT NAMESPACE
// ============================================================================

func showMinimalNamespace() {
    print("\n" + String(repeating: "=", count: 60))
    print("MINIMAL INPUT.CHECKPOINT NAMESPACE")
    print(String(repeating: "=", count: 60))
    print("""

    Given that we reuse existing primitives, Input.Checkpoint namespace
    might only need a protocol marker (or nothing at all):

    OPTION A: No namespace, just use existing types

        associatedtype Checkpoint: Sendable & Comparable

        (Checkpoint is Index<Element> for Buffer, Base.Index for Slice)

    OPTION B: Thin protocol for documentation

        extension Input {
            enum Checkpoint {}
        }

        extension Input.Checkpoint {
            /// Marker protocol for checkpoint types.
            /// Conformers: Index<Element>, any Collection.Index
            protocol `Protocol`: Sendable, Comparable {}
        }

        extension Index: Input.Checkpoint.`Protocol` {}
        extension String.Index: Input.Checkpoint.`Protocol` {}
        // etc.

    OPTION C: Just use Index<Element>.Protocol if it exists

        // If index-primitives has Index.Protocol, reuse that

    Recommendation: Start with Option A (no new types).
    Add namespace later if needed for extensibility.
    """)
}

// Run all tests
testPhantomTyping()
testCentralizedValidation()
testSlice()
showProtocolDesign()
showBenefits()
showMinimalNamespace()
