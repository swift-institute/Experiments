import Synchronization
import Tagged_Primitives
import Ordinal_Primitives
import Cardinal_Primitives
import Foundation

public enum SimpleTag: Sendable {}

func say(_ msg: String) {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
}

@main
struct Main {
    static func main() async {
        // Bisection oracle: this body MUST run to completion (exit 0) for a
        // candidate Tagged.swift edit to count as "PASSED". With unfixed
        // Tagged_Primitives.Tagged on Swift 6.3.2, the runtime fails to
        // instantiate Atomic<Tagged<…>> metadata; init/advance/deinit
        // dereference null and SIGSEGV (exit 139).
        say("Atomic<Tagged<SimpleTag, Ordinal>>.advance(within: Tagged<SimpleTag, Cardinal>)")
        let cursor = Atomic<Tagged<SimpleTag, Ordinal>>(.zero)
        let count: Tagged<SimpleTag, Cardinal> = try! .init(2)
        let result = cursor.advance(within: count)
        say("  result = \(result)")
        say("PASSED")
    }
}
