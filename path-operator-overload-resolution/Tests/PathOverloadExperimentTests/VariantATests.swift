import Testing
import PathOverloadExperiment

// Variant A: Three overloads (original scenario with Path / String)

@Suite("Variant A — 3 overloads (Component, Path, String)")
struct VariantATests {

    @Test("A: 2 chained /")
    func chain2() {
        let p = PathA("/base")
        let r = p / "a" / "b"
        #expect(r.string == "/base/a/b")
    }

    @Test("A: 3 chained /")
    func chain3() {
        let p = PathA("/base")
        let r = p / "a" / "b" / "c"
        #expect(r.string == "/base/a/b/c")
    }

    @Test("A: 4 chained /")
    func chain4() {
        let p = PathA("/base")
        let r = p / "a" / "b" / "c" / "d"
        #expect(r.string == "/base/a/b/c/d")
    }

    @Test("A: 5 chained /")
    func chain5() {
        let p = PathA("/base")
        let r = p / "a" / "b" / "c" / "d" / "e"
        #expect(r.string == "/base/a/b/c/d/e")
    }

    @Test("A: 6 chained /")
    func chain6() {
        let p = PathA("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f"
        #expect(r.string == "/base/a/b/c/d/e/f")
    }

    @Test("A: 7 chained /")
    func chain7() {
        let p = PathA("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g"
        #expect(r.string == "/base/a/b/c/d/e/f/g")
    }

    @Test("A: 8 chained /")
    func chain8() {
        let p = PathA("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h")
    }

    @Test("A: 10 chained /")
    func chain10() {
        let p = PathA("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j")
    }

    @Test("A: 12 chained /")
    func chain12() {
        let p = PathA("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" / "k" / "l"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j/k/l")
    }

    @Test("A: 15 chained /")
    func chain15() {
        let p = PathA("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" / "k" / "l" / "m" / "n" / "o"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o")
    }
}
