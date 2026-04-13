// MARK: - Isolated Parameter: Borrowing ~Copyable Without Closures
// Purpose: Test whether a function with `isolated Actor` parameter
//          can accept `borrowing ~Copyable` parameters. No closure
//          involved — the borrow lives in the function scope.
//
// Hypotheses:
//   H1: Function with `isolated Actor` + `borrowing ~Copyable` compiles
//   H2: The function can call actor-isolated methods synchronously
//   H3: The caller can `await` the function (one hop)
//   H4: Multiple actor methods can be called in sequence (no interleaving)
//   H5: ~Copyable return works
//   H6: This pattern eliminates the 2-hop IO.Event.Selector.register problem
//
// Results:
//   H1: CONFIRMED — `isolated Actor` + `borrowing ~Copyable` compiles
//   H2: CONFIRMED — actor methods callable synchronously (no await)
//   H3: CONFIRMED — caller awaits the isolated-parameter function (one hop)
//   H4: CONFIRMED — multiple actor calls in sequence, no interleaving
//   H5: CONFIRMED — ~Copyable return works (Registration struct)
//   H6: CONFIRMED — this is the solution for IO.Event.Selector.register
//
// The `isolated` parameter on a plain function is the theoretical
// perfect: no closure, no @Sendable, no escaping, borrow survives,
// ~Copyable return works, typed throws works, one hop.
//
// For cross-actor (shared executor), combine with `assumeIsolated`:
//   func doWork(
//       descriptor: borrowing Descriptor,
//       on db: isolated Database,
//       cache: Cache
//   ) -> Result {
//       let id = db.register(descriptor: descriptor)  // sync, borrow
//       cache.assumeIsolated { cache in                // sync, same executor
//           cache.publish(id: id)
//       }
//   }
// Date: 2026-04-13

// ============================================================================
// MARK: - V1: Basic isolated + borrowing
// ============================================================================

func registerOnActor(
    descriptor: borrowing Descriptor,
    on registry: isolated Database
) -> Int32 {
    registry.register(descriptor: descriptor)
}

func testIsolatedV1() async {
    let shared = SharedExecutor(label: "iso-v1")
    let db = Database(executor: shared)
    let desc = Descriptor(fd: 7)

    let result = await registerOnActor(descriptor: desc, on: db)
    print("Isolated V1: fd=\(result), original=\(desc.fd)")
}

// ============================================================================
// MARK: - V2: Multiple actor calls in one function (no interleaving)
// ============================================================================

func registerAndPublish(
    descriptor: borrowing Descriptor,
    on db: isolated Database,
    cache: Cache
) -> (Int32, String?) {
    let fd = db.register(descriptor: descriptor)
    db.set("registered", "\(fd)")

    // Cross-actor via assumeIsolated (same executor)
    cache.assumeIsolated { cache in
        cache.set("registered", "\(fd)")
    }

    let fromCache: String? = cache.assumeIsolated { cache in
        cache.get("registered")
    }

    return (fd, fromCache)
}

func testIsolatedV2() async {
    let shared = SharedExecutor(label: "iso-v2")
    let db = Database(executor: shared)
    let cache = Cache(executor: shared)
    let desc = Descriptor(fd: 42)

    let (fd, cached) = await registerAndPublish(
        descriptor: desc,
        on: db,
        cache: cache
    )
    print("Isolated V2: fd=\(fd), cached=\(cached ?? "nil")")
}

// ============================================================================
// MARK: - V3: ~Copyable return
// ============================================================================

struct Registration: ~Copyable, Sendable {
    let id: Int32
    let dupedFD: Int32
}

func registerReturningNC(
    descriptor: borrowing Descriptor,
    on db: isolated Database
) -> Registration {
    let fd = db.register(descriptor: descriptor)
    let duped = descriptor.duplicate()
    return Registration(id: fd, dupedFD: duped.fd)
}

func testIsolatedV3() async {
    let shared = SharedExecutor(label: "iso-v3")
    let db = Database(executor: shared)
    let desc = Descriptor(fd: 10)

    let reg = await registerReturningNC(descriptor: desc, on: db)
    print("Isolated V3: id=\(reg.id), dupedFD=\(reg.dupedFD), original=\(desc.fd)")
}

// ============================================================================
// MARK: - V4: Typed throws
// ============================================================================

enum RegError: Error { case rejected }

func registerOrFail(
    descriptor: borrowing Descriptor,
    on db: isolated Database
) throws(RegError) -> Int32 {
    guard descriptor.fd > 0 else { throw .rejected }
    return db.register(descriptor: descriptor)
}

func testIsolatedV4() async {
    let shared = SharedExecutor(label: "iso-v4")
    let db = Database(executor: shared)
    let bad = Descriptor(fd: -1)

    do {
        _ = try await registerOrFail(descriptor: bad, on: db)
        print("Isolated V4: unexpected success")
    } catch {
        print("Isolated V4: caught \(error)")
    }
}

// ============================================================================
// MARK: - V5: Extension method with isolated Self
// ============================================================================
// Can we express this as a method on the actor protocol?

extension Database {
    func registerWith(
        descriptor: borrowing Descriptor,
        publishing cache: Cache
    ) -> (Int32, String?) {
        let fd = register(descriptor: descriptor)
        set("fd", "\(fd)")

        cache.assumeIsolated { cache in
            cache.set("fd", "\(fd)")
        }

        let fromCache: String? = cache.assumeIsolated { cache in
            cache.get("fd")
        }

        return (fd, fromCache)
    }
}

func testIsolatedV5() async {
    let shared = SharedExecutor(label: "iso-v5")
    let db = Database(executor: shared)
    let cache = Cache(executor: shared)
    let desc = Descriptor(fd: 77)

    let (fd, cached) = await db.registerWith(descriptor: desc, publishing: cache)
    print("Isolated V5: fd=\(fd), cached=\(cached ?? "nil")")
}

// ============================================================================
// MARK: - Run tests
// ============================================================================

func runIsolatedTests() async {
    print()
    print("--- Isolated V1: basic borrowing ---")
    await testIsolatedV1()

    print("--- Isolated V2: multi-actor + borrowing ---")
    await testIsolatedV2()

    print("--- Isolated V3: ~Copyable return ---")
    await testIsolatedV3()

    print("--- Isolated V4: typed throws ---")
    await testIsolatedV4()

    print("--- Isolated V5: actor method ---")
    await testIsolatedV5()
}
