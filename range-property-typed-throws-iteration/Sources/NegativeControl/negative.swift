// Negative control — this file SHOULD FAIL to compile.
// Demonstrates that without `.iterate`, typed-throws on stdlib Range.forEach
// is rejected because stdlib's rethrows Sequence.forEach erases throws(E)
// to any Error.

enum NegError: Swift.Error { case foo }

func negativeControl() throws(NegError) {
    do throws(NegError) {
        try (0..<3).forEach { (i: Int) throws(NegError) in
            if i == 1 { throw .foo }
        }
    } catch {
        let _: NegError = error  // expected diagnostic here
    }
}
