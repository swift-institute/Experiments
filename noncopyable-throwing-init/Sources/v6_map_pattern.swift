// MARK: - Variant 6: Memory.Map-like pattern
// Purpose: Reproduce the exact structure that fails in Memory.Map
// Hypothesis: The combination of multiple let + var Optional<~Copyable with deinit>
//             triggers "conditional initialization" error

struct Token: ~Copyable {
    let value: Int
    deinit { print("  Token(\(value)) deinit") }
}

enum MapError: Error { case stat, mapping, lock }

struct FakeMap: ~Copyable {
    var region: Int?
    let delta: Int
    let userLen: Int
    let access: String
    var lockToken: Token?

    init(fd: Int, shouldFailValidation: Bool, shouldFailMap: Bool, needsLock: Bool) throws(MapError) {
        // Phase 1: validation (self untouched)
        if shouldFailValidation { throw .stat }

        let computedDelta = fd * 2
        let computedLen = fd * 3

        // Phase 2: resource acquisition (self untouched)
        if shouldFailMap { throw .mapping }
        let mappedRegion = fd * 100

        // Phase 3: initialize ALL stored properties
        self.region = mappedRegion
        self.delta = computedDelta
        self.userLen = computedLen
        self.access = "read"
        self.lockToken = nil

        // Phase 4: optional lock (self initialized, deinit handles cleanup)
        if needsLock {
            self.lockToken = Token(value: fd)
        }
    }

    deinit {
        print("  FakeMap deinit (region: \(region != nil ? "set" : "nil"), token: \(lockToken != nil ? "set" : "nil"))")
    }
}

func testV6() {
    print("\nV6 (Map pattern):")
    test("  validation fail") { try FakeMap(fd: 1, shouldFailValidation: true, shouldFailMap: false, needsLock: false) }
    test("  map fail") { try FakeMap(fd: 2, shouldFailValidation: false, shouldFailMap: true, needsLock: false) }
    test("  success no lock") { try FakeMap(fd: 3, shouldFailValidation: false, shouldFailMap: false, needsLock: false) }
    test("  success with lock") { try FakeMap(fd: 4, shouldFailValidation: false, shouldFailMap: false, needsLock: true) }
}
