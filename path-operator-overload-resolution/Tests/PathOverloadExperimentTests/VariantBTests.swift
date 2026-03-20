import Testing
import PathOverloadExperiment

// Variant B: Only Path / Component (no Path / Path operator)

@Suite("Variant B — single overload (Component only)")
struct VariantBTests {

    @Test("B: 2 chained /")
    func chain2() {
        let p = PathB("/base")
        let r = p / "a" / "b"
        #expect(r.string == "/base/a/b")
    }

    @Test("B: 4 chained /")
    func chain4() {
        let p = PathB("/base")
        let r = p / "a" / "b" / "c" / "d"
        #expect(r.string == "/base/a/b/c/d")
    }

    @Test("B: 6 chained /")
    func chain6() {
        let p = PathB("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f"
        #expect(r.string == "/base/a/b/c/d/e/f")
    }

    @Test("B: 8 chained /")
    func chain8() {
        let p = PathB("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h")
    }

    @Test("B: 10 chained /")
    func chain10() {
        let p = PathB("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j")
    }

    @Test("B: 15 chained /")
    func chain15() {
        let p = PathB("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" / "k" / "l" / "m" / "n" / "o"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o")
    }
}
