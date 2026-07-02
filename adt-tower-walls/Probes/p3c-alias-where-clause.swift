// p3c: where-clause on a generic typealias. Expect: probe grammar.
// Result (Apple Swift 6.3.3, 2026-07-02): PASSES and the where clause IS ENFORCED for conformance constraints (AliC<NotEq> errors "does not conform to Equatable"). Initial NOT-ENFORCED read was a Sendable-leniency artifact (Sendable checked leniently outside strict-concurrency).
public struct Impl6<S>: ~Copyable { public init() {} }
public typealias AliC<E> = Impl6<E> where E: Sendable
print("p3c ok")
