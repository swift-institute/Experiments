// MARK: - Property `consuming get` Coexisting With `_read`
// Purpose: Verify whether Swift permits a single property accessor to declare
//          both `_read { yield }` (borrow) and `consuming get` (consume) on
//          a ~Copyable host, with call-site dispatch by receiver ownership.
//
// Context: Tagged.underlying was a stored `let rawValue: U` field pre-rename,
//          giving both borrow and consume-extract behavior naturally. Post-rename,
//          it's a `_read { yield _storage }` computed accessor — borrow-only.
//          This regression blocked extraction of owned ~Copyable values from
//          Tagged in swift-iso-9945 Pipe.Close.swift.
//
// Hypothesis V1: A property on a ~Copyable host can declare BOTH `_read` and
//                `consuming get`, with the compiler dispatching by receiver
//                ownership (borrow context → _read; consume context → consuming get).
// V1 Result: REFUTED — error: variable cannot provide both a 'read' accessor
//            and a getter (Swift 6.3.1, 2026-05-04)
//
// Hypothesis V2: A property on a ~Copyable host can declare BOTH `borrowing get`
//                and `consuming get` (two getters with distinct ownership modifiers),
//                with dispatch by receiver ownership.
// V2 Result: REFUTED — error: variable already has a getter (Swift 6.3.1, 2026-05-04)
//            Properties admit at most ONE getter; ownership modifier does not
//            disambiguate distinct accessors.
//
// Hypothesis V3: A property on a ~Copyable host with ONLY `consuming get` is
//                permitted, but borrow-context access is then disallowed
//                (consume-only property, useless as a general accessor).
// V3 Result: REFUTED — `consuming get` parses but its body sees `self` as
//            borrowed, not consumed. Cannot extract stored ~Copyable field
//            even with explicit `consume self._storage`. The `consuming get`
//            modifier appears non-functional on properties in Swift 6.3.1.
//            (error: 'self' is borrowed and cannot be consumed)
//
// Hypothesis V4: A `consuming func` method on a ~Copyable host CAN extract
//                a stored ~Copyable field (the proposed fallback).
// V4 Result: CONFIRMED — `_read` property + `consuming func take()` coexist.
//            Borrow uses go through `box.contents.id` (yields _storage).
//            Consume-extract goes through `box.take()` (returns owned NC).
//            Build + run succeed.
//
// Hypothesis V6: A stored `public private(set) var underlying: U` (or
//                `public let underlying: U`) — i.e., direct storage with
//                restricted setter visibility — gives both consume-extract
//                AND satisfies the Carrier protocol's `var underlying
//                { borrowing get }` requirement, AND is read-only externally.
//                This is what pre-rename `public var rawValue` actually was;
//                the rename converted it to a computed `_read` accessor,
//                which was the cause of the regression.
// V6 Result: CONFIRMED. `public private(set) var underlying: NC` on a
//            ~Copyable host:
//            • Compiles cleanly with NC: ~Copyable
//            • Borrow access works: `box.underlying.id`
//            • Direct consume-extract works: `box.underlying` on a consumed
//              `box` partial-consumes storage and yields owned NC
//            • Explicit `consume box.underlying` also works
//            • Read-only externally (private setter blocks external mutation)
//            Build + run output:
//              V6 borrow: id=100
//              V6 extracted: id=100
//              V6 extracted explicit: id=200
//
//            THIS IS THE FIX. The pre-rename behavior was a STORED PROPERTY,
//            and the rename converted it to a COMPUTED ACCESSOR unnecessarily.
//            Reverting to a stored property (with restricted setter to
//            preserve the rename's read-only intent) restores consume-extract.
//
// Hypothesis V5: `_read + _modify` (the standard coroutine pair) on a
//                property satisfies the Carrier protocol AND enables
//                consume-extract via the inout reference yielded by `_modify`.
// V5 Result: PARTIALLY CONFIRMED, PARTIALLY REFUTED.
//            • Conformance: `_read + _modify` satisfies `var underlying
//              { borrowing get }` and is additive over `_read` alone — Tagged
//              today already conforms with `_read`-only; adding `_modify` is
//              syntactically clean, no protocol issue.
//            • Consume-extract: REFUTED. `consume b.contents` rejected with:
//              `error: 'consume' can only be used to partially consume storage`
//              `note: non-storage produced by this computed property`
//              Computed accessor results are NOT storage in Swift's ownership
//              model. `_modify` yields an inout reference, but `consume`
//              cannot be applied to accessor-yielded values regardless of
//              which accessor pair is in use. The pre-rename `let rawValue: U`
//              worked because it was direct storage; the post-rename computed
//              accessor cannot recover that capability via additional accessor
//              variants.
//
// CONCLUSION
// ----------
// The regression has a clear structural cause and a clean structural fix.
//
// CAUSE: Pre-rename Tagged had `public var rawValue: RawValue` as a STORED
// property (commit 0634a1b). `tagged.rawValue` was direct stored field
// access, supporting both borrow (when host borrowed) and consume-extract
// (partial-consume of storage when host consumed). The rename commit
// (96f2a76 — "Rename rawValue → underlying") explicitly converted this
// to a COMPUTED `_read` accessor, with the stated motivation:
//   "Public mutation removed: `tagged.underlying += 5` no longer compiles"
// The rename achieved its goal (read-only public surface) but overshot —
// the conversion from stored to computed accessor was not necessary to
// achieve read-only access. The lost consume-extract was collateral damage.
//
// EVIDENCE (this experiment):
//   V1 _read + consuming get          REFUTED — read + getter forbidden
//   V2 borrowing get + consuming get  REFUTED — duplicate getter
//   V3 consuming get alone            REFUTED — body sees self as borrowed
//   V4 _read + consuming func take()  CONFIRMED — workaround (separate names)
//   V5 _read + _modify                Conformance OK; consume REFUTED on
//                                     accessor result (not storage)
//   V6 public private(set) var       CONFIRMED — STRUCTURAL FIX. Stored
//                                     property gives borrow + consume-extract,
//                                     read-only externally, and satisfies
//                                     `var underlying { borrowing get }`.
//
// FIX: Revert Tagged.swift to use a stored property:
//   public private(set) var underlying: Underlying
// instead of:
//   package var _storage: Underlying
//   extension Tagged: Carrier.`Protocol` {
//       public var underlying: Underlying { _read { yield _storage } }
//   }
//
// This preserves:
//   - Read-only public surface (`tagged.underlying += 5` still rejected)
//   - Carrier protocol conformance (`var { borrowing get }` satisfied by stored)
//   - Internal/package mutability (private(set) allows package-internal mutation)
// And RESTORES:
//   - Consume-extract via direct stored field access on consumed host
//
// The previously-proposed `consuming func take() -> Underlying` is no longer
// needed — the stored-property fix is the principled correction.
//
// Toolchain: Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
//
// Date: 2026-05-04

// MARK: - Test Setup

struct NC: ~Copyable {
    let id: Int
}

// V1: Property with both _read (borrow) and consuming get (consume)
struct Box: ~Copyable {
    var _storage: NC

    init(_ value: consuming NC) {
        self._storage = value
    }

    var contents: NC {
        _read {
            yield _storage
        }
        _modify {
            yield &_storage
        }
    }

    consuming func take() -> NC {
        _storage
    }
}

// V6: Direct stored property `public private(set) var` shape
struct StoredBox: ~Copyable {
    public private(set) var underlying: NC

    init(_ value: consuming NC) {
        self.underlying = value
    }
}

// V6 borrow path
func storedBorrowID(_ b: borrowing StoredBox) -> Int {
    b.underlying.id
}

// V6 consume-extract path: direct stored field, on consumed host
func storedExtract(_ b: consuming StoredBox) -> NC {
    b.underlying  // direct field access — should partial-consume storage
}

// V6 alternate consume-extract: explicit `consume`
func storedExtractExplicit(_ b: consuming StoredBox) -> NC {
    consume b.underlying
}

// V5: With both `_read + _modify` accessors on `contents`, can the caller
//     extract owned NC via `consume` on the accessor result?
//
// CONFIRMED REJECTED: `consume b.contents` produces error:
//   error: 'consume' can only be used to partially consume storage
//   note: non-storage produced by this computed property
//
// `consume` only works on direct storage (stored fields), NOT on results
// produced by computed accessors. Adding `_modify` does not change this —
// `_modify` yields an inout reference, but `consume` rejects the accessor
// result regardless of which accessor pair is provided.
//
// (Box also satisfies `var underlying { borrowing get }` via `_read` —
// the swift-carrier-primitives Tagged.swift demonstrates this empirically:
// it conforms to Carrier.`Protocol` with exactly `_read { yield _storage }`.)
func extractViaModify(_ box: consuming Box) -> NC {
    let b = box
    // return consume b.contents  // ← REJECTED at compile time, see V5 result above
    return b.take()
}

// MARK: - Use Sites

// Borrow path: should use `_read` accessor on `contents`
func borrowID(_ box: borrowing Box) -> Int {
    box.contents.id
}

// Consume path: takes via `take()` method
func extractNC(_ box: consuming Box) -> NC {
    box.take()
}

// MARK: - Drive

func main() {
    var box: Box? = Box(NC(id: 42))
    print("borrow 1: id=\(borrowID(box!))")
    print("borrow 2: id=\(borrowID(box!))")
    let owned = extractNC(box.take()!)
    print("extracted: id=\(owned.id)")

    // V6 drive
    var sbox: StoredBox? = StoredBox(NC(id: 100))
    print("V6 borrow: id=\(storedBorrowID(sbox!))")
    let sOwned = storedExtract(sbox.take()!)
    print("V6 extracted: id=\(sOwned.id)")

    var sbox2: StoredBox? = StoredBox(NC(id: 200))
    let sOwned2 = storedExtractExplicit(sbox2.take()!)
    print("V6 extracted explicit: id=\(sOwned2.id)")
}

main()
