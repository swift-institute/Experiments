import Testing
import PathOverloadExperiment

// Variant C: Both operators, no Path: ExpressibleByStringLiteral

@Suite("Variant C — 2 overloads, no Path literal")
struct VariantCTests {

    @Test("C: 2 chained /")
    func chain2() {
        let p = PathC("/base")
        let r = p / "a" / "b"
        #expect(r.string == "/base/a/b")
    }

    @Test("C: 4 chained /")
    func chain4() {
        let p = PathC("/base")
        let r = p / "a" / "b" / "c" / "d"
        #expect(r.string == "/base/a/b/c/d")
    }

    @Test("C: 6 chained /")
    func chain6() {
        let p = PathC("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f"
        #expect(r.string == "/base/a/b/c/d/e/f")
    }

    @Test("C: 8 chained /")
    func chain8() {
        let p = PathC("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h")
    }

    @Test("C: 10 chained /")
    func chain10() {
        let p = PathC("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j")
    }

    @Test("C: 15 chained /")
    func chain15() {
        let p = PathC("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" / "k" / "l" / "m" / "n" / "o"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o")
    }
}
