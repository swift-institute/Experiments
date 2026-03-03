// MARK: - Protocol Diamond ~Copyable Refinement
// Purpose: Validate that Witness.Key can refine both Dependency.Key (L1) and
//          __WitnessKeyTest when both declare `associatedtype Value: ~Copyable & Sendable`,
//          with `= Self` default from __WitnessKeyTest, under SuppressedAssociatedTypes.
//
// Context: dependency-witness-store-coherence.md Option D requires this to work.
//          The protocol diamond is:
//
//              Sendable
//             /        \
//   Dependency.Key    __WitnessKeyTest
//             \        /
//          Witness.Key
//
// Hypothesis: The diamond compiles, defaults resolve correctly for both Copyable
//             and ~Copyable conformers, and subscripts with `where K.Value: Copyable`
//             accept types from both protocol paths.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 8 variants pass (build + runtime assertions)
//
// Evidence:
//   V1: Diamond compiles, default chain testValue → previewValue → liveValue works
//   V2: Custom previewValue propagates to testValue correctly
//   V3: L1-only DependencyKey conformer unaffected by diamond
//   V4: ~Copyable value with explicit test/preview works through diamond
//   V5: ~Copyable DependencyKey-only conformer works with explicit testValue
//   V6: WitnessKey types resolve through `K: DependencyKey` constraint (IS-A)
//       FileSystem.testValue returns "preview" through DependencyKey store — correct
//   V7: `Value = Self` default from WitnessKeyTest works through diamond
//   V8: Mode-based resolution works for WitnessKey types
//
// Date: 2026-03-03

// ============================================================================
// MARK: - L1 Protocol (mirrors swift-dependency-primitives)
// ============================================================================

/// L1's Dependency.Key — with ~Copyable relaxation (the proposed change).
protocol DependencyKey: Sendable {
    associatedtype Value: ~Copyable & Sendable
    static var liveValue: Value { get }
    static var testValue: Value { get }
}

extension DependencyKey where Value: Copyable {
    static var testValue: Value { liveValue }
}

// ============================================================================
// MARK: - L3 Protocols (mirrors swift-witnesses)
// ============================================================================

/// Hoisted protocol (Swift limitation: protocols cannot nest in protocols).
/// Mirrors __WitnessKeyTest.
protocol WitnessKeyTest<Value>: Sendable {
    associatedtype Value: ~Copyable & Sendable = Self
    static var testValue: Value { get }
    static var previewValue: Value { get }
}

extension WitnessKeyTest where Value: Copyable {
    static var previewValue: Value { testValue }
}

/// L3's Witness.Key — THE DIAMOND: refines both DependencyKey AND WitnessKeyTest.
protocol WitnessKey<Value>: DependencyKey, WitnessKeyTest {
    static var liveValue: Value { get }
}

extension WitnessKey where Value: Copyable {
    static var previewValue: Value { liveValue }
    static var testValue: Value { previewValue }
}

// ============================================================================
// MARK: - L1 Values Store (mirrors Dependency.Values)
// ============================================================================

/// Simplified L1 store with `where K.Value: Copyable` guard.
struct DependencyValues: Sendable {
    private var storage: [ObjectIdentifier: any Sendable] = [:]
    var isTestContext: Bool = false

    subscript<K: DependencyKey>(key: K.Type) -> K.Value where K.Value: Copyable {
        get {
            if let value = storage[ObjectIdentifier(key)] as? K.Value {
                return value
            }
            return isTestContext ? K.testValue : K.liveValue
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }
}

// ============================================================================
// MARK: - Variant 1: Copyable type conforming to WitnessKey (diamond)
// Hypothesis: Compiles. Default chain: testValue → previewValue → liveValue.
// ============================================================================

struct Clock: WitnessKey {
    typealias Value = Clock
    var name: String

    static var liveValue: Clock { Clock(name: "live") }
    // previewValue defaults to liveValue (via WitnessKey extension)
    // testValue defaults to previewValue (via WitnessKey extension)
}

// ============================================================================
// MARK: - Variant 2: Copyable type conforming to WitnessKey with custom preview
// Hypothesis: Custom previewValue propagates to testValue.
// ============================================================================

struct FileSystem: WitnessKey {
    typealias Value = FileSystem
    var name: String

    static var liveValue: FileSystem { FileSystem(name: "live") }
    static var previewValue: FileSystem { FileSystem(name: "preview") }
    // testValue defaults to previewValue → "preview"
}

// ============================================================================
// MARK: - Variant 3: Copyable type conforming ONLY to DependencyKey (L1-only)
// Hypothesis: Still works. testValue defaults to liveValue.
// ============================================================================

struct Hash: DependencyKey {
    typealias Value = Hash
    var name: String

    static var liveValue: Hash { Hash(name: "live") }
    // testValue defaults to liveValue → "live"
}

// ============================================================================
// MARK: - Variant 4: ~Copyable type conforming to WitnessKey
// Hypothesis: Compiles with explicit testValue and previewValue.
// ============================================================================

struct UniqueHandle: ~Copyable, Sendable {
    let id: Int
}

struct HandleProvider: WitnessKey {
    typealias Value = UniqueHandle

    static var liveValue: UniqueHandle { UniqueHandle(id: 1) }
    static var testValue: UniqueHandle { UniqueHandle(id: 99) }
    static var previewValue: UniqueHandle { UniqueHandle(id: 50) }
}

// ============================================================================
// MARK: - Variant 5: ~Copyable type with DependencyKey unconstrained default
// Hypothesis: DependencyKey's unconstrained `testValue { liveValue }` does NOT
//             apply because it's guarded by `where Value: Copyable`. ~Copyable
//             conformers must provide explicit testValue.
//             UPDATE: Actually, DependencyKey has TWO defaults:
//             - `where Value: Copyable`: testValue { liveValue }
//             The ~Copyable path has NO default, so explicit testValue is required.
// ============================================================================

// Uncomment to verify compiler error for missing testValue on ~Copyable:
// struct BrokenHandle: DependencyKey {
//     typealias Value = UniqueHandle
//     static var liveValue: UniqueHandle { UniqueHandle(id: 1) }
//     // ERROR expected: missing testValue (no default for ~Copyable)
// }

struct WorkingHandle: DependencyKey {
    typealias Value = UniqueHandle
    static var liveValue: UniqueHandle { UniqueHandle(id: 1) }
    static var testValue: UniqueHandle { UniqueHandle(id: 2) }
}

// ============================================================================
// MARK: - Variant 6: WitnessKey type usable through DependencyKey subscript
// Hypothesis: WitnessKey conformer satisfies `K: DependencyKey` constraint
//             because WitnessKey: DependencyKey.
// ============================================================================

func resolveViaL1Store<K: DependencyKey>(_ key: K.Type, store: DependencyValues) -> K.Value
    where K.Value: Copyable
{
    store[key]
}

// ============================================================================
// MARK: - Variant 7: Value = Self default from WitnessKeyTest
// Hypothesis: The `= Self` default from WitnessKeyTest works through the diamond.
//             A conformer that IS its own Value type doesn't need `typealias Value`.
// ============================================================================

struct APIClient: WitnessKey, Sendable {
    // No `typealias Value` — defaults to Self via WitnessKeyTest
    var endpoint: String

    static var liveValue: APIClient { APIClient(endpoint: "prod") }
}

// ============================================================================
// MARK: - Variant 8: Mode enum + mode-based resolution (mirrors Witness.Context)
// Hypothesis: A mode-based lookup function works for WitnessKey types,
//             and DependencyKey-only types can be looked up via the store subscript.
// ============================================================================

enum Mode: Sendable {
    case live, preview, test
}

func resolve<K: WitnessKey>(_ key: K.Type, mode: Mode) -> K.Value where K.Value: Copyable {
    switch mode {
    case .live: K.liveValue
    case .preview: K.previewValue
    case .test: K.testValue
    }
}

// ============================================================================
// MARK: - Execution
// ============================================================================

// --- Variant 1: Default chain ---
let clock = Clock.liveValue
let clockTest = Clock.testValue
let clockPreview = Clock.previewValue
print("V1 Clock: live=\(clock.name), test=\(clockTest.name), preview=\(clockPreview.name)")
assert(clockTest.name == "live", "V1: testValue should default to previewValue → liveValue")
assert(clockPreview.name == "live", "V1: previewValue should default to liveValue")

// --- Variant 2: Custom preview propagates ---
let fs = FileSystem.liveValue
let fsTest = FileSystem.testValue
let fsPreview = FileSystem.previewValue
print("V2 FileSystem: live=\(fs.name), test=\(fsTest.name), preview=\(fsPreview.name)")
assert(fsTest.name == "preview", "V2: testValue should default to previewValue")
assert(fsPreview.name == "preview", "V2: previewValue should be custom")

// --- Variant 3: L1-only key ---
let hash = Hash.liveValue
let hashTest = Hash.testValue
print("V3 Hash: live=\(hash.name), test=\(hashTest.name)")
assert(hashTest.name == "live", "V3: DependencyKey testValue defaults to liveValue")

// --- Variant 4: ~Copyable explicit ---
let handle = HandleProvider.liveValue
let handleTest = HandleProvider.testValue
let handlePreview = HandleProvider.previewValue
print("V4 HandleProvider: live=\(handle.id), test=\(handleTest.id), preview=\(handlePreview.id)")
assert(handleTest.id == 99, "V4: explicit testValue")
assert(handlePreview.id == 50, "V4: explicit previewValue")

// --- Variant 5: ~Copyable L1-only ---
let wh = WorkingHandle.liveValue
let whTest = WorkingHandle.testValue
print("V5 WorkingHandle: live=\(wh.id), test=\(whTest.id)")
assert(whTest.id == 2, "V5: explicit testValue for ~Copyable DependencyKey")

// --- Variant 6: WitnessKey through DependencyKey subscript ---
var store = DependencyValues()
let resolved = resolveViaL1Store(Clock.self, store: store)
print("V6 resolveViaL1Store(Clock): \(resolved.name)")
assert(resolved.name == "live", "V6: WitnessKey resolves through DependencyKey constraint")

store.isTestContext = true
let resolvedTest = resolveViaL1Store(Clock.self, store: store)
print("V6 resolveViaL1Store(Clock, test): \(resolvedTest.name)")
assert(resolvedTest.name == "live", "V6: DependencyKey testValue default (liveValue) used in store")
// Note: the store uses DependencyKey's testValue, not WitnessKey's.
// WitnessKey's testValue → previewValue → liveValue.
// DependencyKey's testValue → liveValue.
// Since WitnessKey: DependencyKey, and WitnessKey provides a more specific
// default, Clock.testValue should be WitnessKey's version → "live" (via previewValue → liveValue).
// Either way, for Clock with no custom values, testValue == liveValue == "live".

// Test with FileSystem which has custom previewValue:
let fsResolved = resolveViaL1Store(FileSystem.self, store: store)
print("V6 resolveViaL1Store(FileSystem, test): \(fsResolved.name)")
assert(fsResolved.name == "preview", "V6: WitnessKey testValue → previewValue used through DependencyKey store")

// Also verify L1-only key works:
let hashResolved = resolveViaL1Store(Hash.self, store: store)
print("V6 resolveViaL1Store(Hash, test): \(hashResolved.name)")
assert(hashResolved.name == "live", "V6: DependencyKey-only testValue → liveValue")

// --- Variant 7: Value = Self default ---
let api = APIClient.liveValue
print("V7 APIClient: live=\(api.endpoint)")
assert(api.endpoint == "prod", "V7: Value = Self default works through diamond")

// --- Variant 8: Mode-based resolution ---
let clockMode = resolve(Clock.self, mode: .test)
let fsMode = resolve(FileSystem.self, mode: .preview)
print("V8 resolve(Clock, .test): \(clockMode.name)")
print("V8 resolve(FileSystem, .preview): \(fsMode.name)")
assert(clockMode.name == "live", "V8: mode-based test resolution")
assert(fsMode.name == "preview", "V8: mode-based preview resolution")

print("\nAll variants passed.")
