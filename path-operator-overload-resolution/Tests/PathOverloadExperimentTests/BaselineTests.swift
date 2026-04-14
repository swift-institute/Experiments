import Testing
import PathOverloadExperiment

// MARK: - Baseline: Both overloads, both literal conformances

@Suite("Baseline — both overloads present")
struct BaselineTests {

    @Test("2 chained /")
    func chain2() {
        let p = Path("/base")
        let r = p / "a" / "b"
        #expect(r.string == "/base/a/b")
    }

    @Test("3 chained /")
    func chain3() {
        let p = Path("/base")
        let r = p / "a" / "b" / "c"
        #expect(r.string == "/base/a/b/c")
    }

    @Test("4 chained /")
    func chain4() {
        let p = Path("/base")
        let r = p / "a" / "b" / "c" / "d"
        #expect(r.string == "/base/a/b/c/d")
    }

    @Test("5 chained /")
    func chain5() {
        let p = Path("/base")
        let r = p / "a" / "b" / "c" / "d" / "e"
        #expect(r.string == "/base/a/b/c/d/e")
    }

    @Test("6 chained /")
    func chain6() {
        let p = Path("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f"
        #expect(r.string == "/base/a/b/c/d/e/f")
    }

    @Test("7 chained /")
    func chain7() {
        let p = Path("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g"
        #expect(r.string == "/base/a/b/c/d/e/f/g")
    }

    @Test("8 chained /")
    func chain8() {
        let p = Path("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h")
    }

    @Test("10 chained /")
    func chain10() {
        let p = Path("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j")
    }

    @Test("12 chained /")
    func chain12() {
        let p = Path("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" / "k" / "l"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j/k/l")
    }

    @Test("15 chained /")
    func chain15() {
        let p = Path("/base")
        let r = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" / "k" / "l" / "m" / "n" / "o"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o")
    }

    // MARK: - String interpolation

    @Test("4 chained / with interpolation")
    func chainInterpolation4() {
        let p = Path("/base")
        let i = 1
        let r = p / "\(i)" / "\(i+1)" / "\(i+2)" / "\(i+3)"
        #expect(r.string == "/base/1/2/3/4")
    }

    @Test("6 chained / with interpolation")
    func chainInterpolation6() {
        let p = Path("/base")
        let i = 1
        let r = p / "\(i)" / "\(i+1)" / "\(i+2)" / "\(i+3)" / "\(i+4)" / "\(i+5)"
        #expect(r.string == "/base/1/2/3/4/5/6")
    }

    // MARK: - Type-annotated result

    @Test("6 chained / with result type annotation")
    func chain6Annotated() {
        let p = Path("/base")
        let r: Path = p / "a" / "b" / "c" / "d" / "e" / "f"
        #expect(r.string == "/base/a/b/c/d/e/f")
    }

    @Test("10 chained / with result type annotation")
    func chain10Annotated() {
        let p = Path("/base")
        let r: Path = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j")
    }

    @Test("15 chained / with result type annotation")
    func chain15Annotated() {
        let p = Path("/base")
        let r: Path = p / "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" / "k" / "l" / "m" / "n" / "o"
        #expect(r.string == "/base/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o")
    }

    // MARK: - Path / Path with variable

    @Test("Path / Path variable")
    func pathSlashPathVar() {
        let base = Path("/Users")
        let rel = Path("coen/Documents")
        let full = base / rel
        #expect(full.string == "/Users/testuser/Documents")
    }
}
