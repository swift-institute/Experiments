// Status: SUPERSEDED -- ~Copyable element support shipped via Set_Primitives + Hash_Primitives; see [MEM-COPY-*]. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// Experiment: ~Copyable Set with Hash.Protocol elements
// Tests: Can we build a set that stores ~Copyable elements using Hash.Protocol?

import Hash_Primitives

// MARK: - Test Element: A ~Copyable type conforming to Hash.Protocol

struct Token: ~Copyable, Hash.`Protocol` {
    let id: Int

    init(_ id: Int) {
        self.id = id
    }

    static func == (lhs: borrowing Token, rhs: borrowing Token) -> Bool {
        lhs.id == rhs.id
    }

    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    deinit {
        print("Token \(id) deinitialized")
    }
}

// MARK: - Minimal Set Implementation

/// A minimal ordered set supporting ~Copyable elements.
struct NCSet<Element: Hash.`Protocol` & ~Copyable>: ~Copyable {
    private var storage: UnsafeMutablePointer<Element>
    private var capacity: Int
    private var _count: Int

    var count: Int { _count }
    var isEmpty: Bool { _count == 0 }

    init(capacity: Int = 8) {
        self.capacity = capacity
        self._count = 0
        self.storage = .allocate(capacity: capacity)
    }

    deinit {
        // Deinitialize all stored elements
        for i in 0..<_count {
            storage.advanced(by: i).deinitialize(count: 1)
        }
        storage.deallocate()
    }

    /// Check if set contains element (borrows the element for hash/equality check)
    borrowing func contains(_ element: borrowing Element) -> Bool {
        let targetHash = element.hashValue
        for i in 0..<_count {
            // Compare hash first (cheap), then equality
            if storage[i].hashValue == targetHash && storage[i] == element {
                return true
            }
        }
        return false
    }

    /// Insert element (consumes the element, takes ownership)
    mutating func insert(_ element: consuming Element) -> Bool {
        // Check if already present (borrow for comparison)
        // Note: We need to be careful here - we own `element` but need to borrow for contains check
        // This is tricky with ~Copyable... we'll do a linear scan
        let targetHash = element.hashValue
        for i in 0..<_count {
            if storage[i].hashValue == targetHash && storage[i] == element {
                // Already present, don't insert
                // We need to consume the element somehow - this is the tricky part
                _ = consume element
                return false
            }
        }

        // Not present, insert
        precondition(_count < capacity, "Set is full")
        storage.advanced(by: _count).initialize(to: element)
        _count += 1
        return true
    }

    /// Iterate over elements (borrowing)
    borrowing func forEach(_ body: (borrowing Element) -> Void) {
        for i in 0..<_count {
            body(storage[i])
        }
    }
}

// MARK: - Test

print("=== NCSet with ~Copyable Elements Test ===\n")

do {
    var set = NCSet<Token>(capacity: 10)

    print("Inserting tokens...")
    let inserted1 = set.insert(Token(1))
    print("Inserted Token(1): \(inserted1)")

    let inserted2 = set.insert(Token(2))
    print("Inserted Token(2): \(inserted2)")

    let inserted3 = set.insert(Token(3))
    print("Inserted Token(3): \(inserted3)")

    // Try to insert duplicate
    let insertedDup = set.insert(Token(2))
    print("Inserted Token(2) again: \(insertedDup)")

    print("\nSet count: \(set.count)")

    // Test contains with borrowing
    print("\nTesting contains (borrowing)...")
    let probe = Token(2)
    let containsProbe = set.contains(probe)
    print("Contains Token(2): \(containsProbe)")
    _ = consume probe

    // Test forEach (borrowing iteration)
    print("\nIterating with forEach:")
    set.forEach { token in
        print("  - Token(\(token.id))")
    }

    print("\nSet going out of scope...")
}

print("\n=== Test Complete ===")
