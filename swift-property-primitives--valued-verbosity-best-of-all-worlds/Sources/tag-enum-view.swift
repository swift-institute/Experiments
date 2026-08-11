// MARK: - Variant 10: Tag enum carries its own View typealias
// Purpose: Eliminate separate typealiases by putting View on the tag enum itself
// Hypothesis: Tag enums can carry typealiases that reference parent generic params,
//             and the accessor `Insert.View` reads cleanly without indirection.
//
// Result: CONFIRMED — all 4 sub-variants compile and run; applied to buffer-primitives (333 tests pass)

// ===----------------------------------------------------------------------===//
// MARK: - Container with 1 value generic — tag enum carries View
// ===----------------------------------------------------------------------===//

struct TagContainer<Element: ~Copyable, let N: Int>: ~Copyable {
    enum Insert {
        typealias View = Property<Insert, TagContainer>.View.Typed<Element>.Valued<N>
    }
    enum Remove {
        typealias View = Property<Remove, TagContainer>.View.Typed<Element>.Valued<N>
    }

    @usableFromInline var _storage: [Int] = []
    @usableFromInline var _count: Int = 0
}

// Accessor — clean, no typealiases needed
extension TagContainer where Element: ~Copyable {
    var insert: Insert.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Insert.View = unsafe .init(&self)
            yield &view
        }
    }

    var remove: Remove.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Remove.View = unsafe .init(&self)
            yield &view
        }
    }
}

// Extension methods — same as before (these can't be shortened)
extension Property.View.Typed.Valued
where Tag == TagContainer<Element, n>.Insert,
      Base == TagContainer<Element, n>,
      Element: ~Copyable
{
    @_lifetime(&self)
    mutating func front(_ element: Int) {
        unsafe base.pointee._storage.append(element)
        unsafe base.pointee._count += 1
    }

    @_lifetime(&self)
    mutating func back(_ element: Int) {
        unsafe base.pointee._storage.append(element)
        unsafe base.pointee._count += 1
    }
}

extension Property.View.Typed.Valued
where Tag == TagContainer<Element, n>.Remove,
      Base == TagContainer<Element, n>,
      Element: ~Copyable
{
    @_lifetime(&self)
    mutating func front() -> Int? {
        guard unsafe !base.pointee._storage.isEmpty else { return nil }
        unsafe base.pointee._count -= 1
        return unsafe base.pointee._storage.removeFirst()
    }
}

// Copyable overload — same Insert.View type
extension Property.View.Typed.Valued
where Tag == TagContainer<Element, n>.Insert,
      Base == TagContainer<Element, n>,
      Element: Copyable
{
    @_lifetime(&self)
    mutating func front_cow(_ element: Int) {
        // In real code: ensureUnique() + grow()
        unsafe base.pointee._storage.append(element)
        unsafe base.pointee._count += 1
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Container with 2 value generics — same pattern
// ===----------------------------------------------------------------------===//

struct TagContainer2<Element: ~Copyable, let N: Int, let capacity: Int>: ~Copyable {
    enum Insert {
        typealias View = Property<Insert, TagContainer2>.View.Typed<Element>.Valued<N>.Valued<capacity>
    }

    @usableFromInline var _storage: [Int] = []
    @usableFromInline var _count: Int = 0
}

extension TagContainer2 where Element: ~Copyable {
    var insert: Insert.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Insert.View = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property.View.Typed.Valued.Valued
where Tag == TagContainer2<Element, n, m>.Insert,
      Base == TagContainer2<Element, n, m>,
      Element: ~Copyable
{
    @_lifetime(&self)
    mutating func front(_ element: Int) {
        unsafe base.pointee._storage.append(element)
        unsafe base.pointee._count += 1
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Runtime Verification
// ===----------------------------------------------------------------------===//

func testVariant10_insert() {
    var c = TagContainer<Int, 8>()
    c.insert.front(42)
    c.insert.back(99)
    assert(c._count == 2, "V10 insert failed")
    print("V10a (tag Insert.View):  PASS — count=\(c._count)")
}

func testVariant10_remove() {
    var c = TagContainer<Int, 8>()
    c.insert.front(42)
    let removed = c.remove.front()
    assert(removed == 42, "V10 remove failed")
    assert(c._count == 0, "V10 remove count failed")
    print("V10b (tag Remove.View):  PASS — removed=\(removed!)")
}

func testVariant10_copyable() {
    var c = TagContainer<Int, 8>()
    c.insert.front_cow(42)
    assert(c._count == 1, "V10 copyable failed")
    print("V10c (Copyable overload): PASS — count=\(c._count)")
}

func testVariant10_two_values() {
    var c = TagContainer2<Int, 2, 16>()
    c.insert.front(42)
    assert(c._count == 1, "V10 two-values failed")
    print("V10d (2 value generics): PASS — count=\(c._count)")
}
