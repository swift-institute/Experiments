//
// Demo: pure algebra. IO is Copyable, non-Sendable by default. No
// @Sendable, no sending, no Sendable constraints.
//

struct ServerEnvironment {
    let greeting: String
    let multiplier: Int
}

enum ServerError: Swift.Error {
    case tooShort
}

enum HTTPError: Swift.Error {
    case server(ServerError)
}

let fetchLength: IO<ServerEnvironment, ServerError, Int> = IO {
    (env: borrowing ServerEnvironment) async throws(ServerError) -> Int in
    guard env.greeting.count >= 3 else { throw .tooShort }
    return env.greeting.count * env.multiplier
}

let pipeline = fetchLength
    .map { n in "length×multiplier = \(n)" }
    .flatMap { s in IO<ServerEnvironment, ServerError, String>.pure(s + " !") }

let wrapped = pipeline.mapError { e in HTTPError.server(e) }

let env = ServerEnvironment(greeting: "Hello", multiplier: 7)
do throws(HTTPError) {
    let output = try await wrapped.provide(env).run(())
    print("output: \(output)")
} catch {
    print("failed: \(error)")
}

// local
struct WiderEnvironment {
    let server: ServerEnvironment
    let traceID: UInt64
}

let widened = fetchLength
    .local { (wider: borrowing WiderEnvironment) -> ServerEnvironment in wider.server }

let wider = WiderEnvironment(
    server: ServerEnvironment(greeting: "World", multiplier: 3),
    traceID: 0xABCD
)
do throws(ServerError) {
    let value = try await widened.run(wider)
    print("widened: \(value)")
} catch {
    print("widened failed: \(error)")
}

// orElse / recover
let flakey: IO<ServerEnvironment, ServerError, Int> = IO {
    (_: borrowing ServerEnvironment) async throws(ServerError) -> Int in
    throw .tooShort
}

let resilient = flakey.orElse(IO.pure(0))

let envForResilience = ServerEnvironment(greeting: "x", multiplier: 100)
do throws(ServerError) {
    let value = try await resilient.provide(envForResilience).run(())
    print("resilient: \(value)")
} catch {
    print("still failed: \(error)")
}

let neverFailing = flakey.recover { _ in -1 }
let value = await neverFailing.provide(envForResilience).run(())
print("recovered: \(value)")

// sequence — IO is Copyable, arrays of IO work
let computations: [IO<ServerEnvironment, ServerError, Int>] = [
    IO.pure(1),
    IO.pure(2),
    IO.pure(3),
]
let combined = IO.sequence(computations)
do throws(ServerError) {
    let values = try await combined.provide(envForResilience).run(())
    print("sequence: \(values)")
} catch {
    print("sequence failed: \(error)")
}
