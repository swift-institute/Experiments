import Testing
@testable import Set_Primitives

func toArray<Element: Hashable>(_ set: borrowing Set<Element>.Ordered) -> [Element] {
    var result: [Element] = []
    for i in 0..<set.count {
        result.append(set[i])
    }
    return result
}

@Suite("Minimal Set.Ordered Tests")
struct MinimalTests {

    @Test
    func `Basic insert`() {
        var set = Set<Int>.Ordered()
        set.insert(1)
        let count = set.count
        #expect(count == 1)
    }

    @Test
    func `Copy and mutate`() {
        var set1 = Set<Int>.Ordered()
        set1.insert(1)
        set1.insert(2)

        var set2 = set1
        set2.insert(3)

        let count1 = set1.count
        let count2 = set2.count
        #expect(count1 == 2)
        #expect(count2 == 3)
    }

    @Test
    func `Iteration`() {
        var set = Set<Int>.Ordered()
        set.insert(10)
        set.insert(20)
        set.insert(30)

        var sum = 0
        for element in set {
            sum += element
        }
        #expect(sum == 60)
    }

    @Test
    func `toArray helper`() {
        var set = Set<Int>.Ordered()
        set.insert(1)
        set.insert(2)
        set.insert(3)

        let array = toArray(set)
        #expect(array == [1, 2, 3])
    }

    @Test
    func `Algebra union`() {
        var a = Set<Int>.Ordered()
        a.insert(1)
        a.insert(2)
        a.insert(3)

        var b = Set<Int>.Ordered()
        b.insert(3)
        b.insert(4)
        b.insert(5)

        let result = a.algebra.union(b)
        let array = toArray(result)
        #expect(array == [1, 2, 3, 4, 5])
    }

    @Test
    func `Consuming iteration`() {
        var set = Set<Int>.Ordered()
        set.insert(10)
        set.insert(20)
        set.insert(30)

        var consumed: [Int] = []
        var iter = set.makeConsumingIterator()
        while let element = iter.next() {
            consumed.append(element)
        }
        #expect(consumed == [10, 20, 30])
    }

    @Test
    func `Model test pattern - random operations`() {
        var set = Set<Int>.Ordered()
        var model = Swift.Set<Int>()

        for i in 0..<100 {
            set.insert(i)
            model.insert(i)
        }

        let setCount = set.count
        #expect(setCount == model.count)

        for i in stride(from: 0, to: 100, by: 2) {
            set.remove(i)
            model.remove(i)
        }

        let setCount2 = set.count
        #expect(setCount2 == model.count)
    }
}
