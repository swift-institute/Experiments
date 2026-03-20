import Testing
import PathOverloadExperiment

// Variant D: Three overloads WITHOUT @_disfavoredOverload (worst case)

@Suite("Variant D — 3 overloads, NO @_disfavoredOverload")
struct VariantDTests {

    @Test("D: 2 chained /")
    func chain2() {
        let p = PathD("/base")
        let r = p / "a" / "b"
        #expect(r.string == "/base/a/b")
    }

    @Test("D: 3 chained /")
    func chain3() {
        let p = PathD("/base")
        let r = p / "a" / "b" / "c"
        #expect(r.string == "/base/a/b/c")
    }

    @Test("D: 4 chained /")
    func chain4() {
        let p = PathD("/base")
        let r = p / "a" / "b" / "c" / "d"
        #expect(r.string == "/base/a/b/c/d")
    }

    @Test("D: 5 chained /")
    func chain5() {
        let p = PathD("/base")
        let r = p / "a" / "b" / "c" / "d" / "e"
        #expect(r.string == "/base/a/b/c/d/e")
    }

    @Test("D: 6 chained /")
    func chain6() {
        let p = PathD("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f"
        #expect(r.string == "/base/a/b/c/d/e/f")
    }

    @Test("D: 7 chained /")
    func chain7() {
        let p = PathD("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g"
        #expect(r.string == "/base/a/b/c/d/e/f/g")
    }

    @Test("D: 8 chained /")
    func chain8() {
        let p = PathD("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h")
    }

    @Test("D: 10 chained /")
    func chain10() {
        let p = PathD("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j")
    }

    @Test("D: 12 chained /")
    func chain12() {
        let p = PathD("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" / "k" / "l"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j/k/l")
    }

    @Test("D: 15 chained /")
    func chain15() {
        let p = PathD("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" / "k" / "l" / "m" / "n" / "o"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o")
    }
}
