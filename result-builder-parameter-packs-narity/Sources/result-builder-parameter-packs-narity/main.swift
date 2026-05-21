// MARK: - Result-Builder + Parameter-Packs N-Arity Spike
//
// Purpose: Validate that @resultBuilder and SE-0393 parameter packs compose
//          cleanly, so combinator-family Builders (Parser.Builder,
//          Serializer.Builder) can replace their per-arity overload tables
//          (currently 2/3/4/.../N) with a single variadic-generic block.
//
// Hypothesis: A single `buildBlock<each C: Protocol>(_ parts: repeat each C)
//          -> Tuple<repeat each C>` replaces the per-arity overload table
//          without compiler complaints, and the result is constructible AND
//          runnable inside a `@resultBuilder`-attributed body.
//
// Toolchain: swift-6.3+
// Platform:  macOS 26 (arm64)
//
// Result: CONFIRMED — all 5 validations pass (V1–V5)
//   V1 ✓ Single-arity via @Builder
//   V2 ✓ 2/3/4-arity (a/b/c) — heterogeneous Outputs preserved
//   V3 ✓ 0-arity (Empty) — empty body compiles + runs
//   V4 ✓ Heterogeneous Output types preserved through the parameter pack
//   V5 ✓ @Builder on var body in user-defined conformer
//
// Implication: Parser.Builder + Serializer.Builder MAY replace their
// per-arity overload tables (currently 2/3/.../N) with one variadic
// `buildBlock<each C: ...Protocol>(_ parts: repeat each C) -> ...Tuple<repeat each C>`.
// Per-element constraints like `(each C).Input == SharedInput` are valid
// SE-0393 where clauses; production refactor needs to encode those.
//
// Date: 2026-05-15
//
// Validation surface:
//   V1  Single-arity build (1 child) compiles + runs
//   V2  Multi-arity build (2, 3, 4 children) compiles + runs
//   V3  Zero-arity (empty body) compiles
//   V4  Heterogeneous Output types preserved through the pack
//   V5  Builder-attributed `var body` composition works at use sites

// MARK: - Minimal protocol stand-in (mirrors Serializer.Protocol shape)

public protocol RunnableProtocol<Output>: ~Copyable {
    associatedtype Output
    borrowing func run() -> Output
}

public enum Combinator {}

extension Combinator {
    // Leaf combinator (mirrors Serializer.Literal): wraps a fixed value.
    public struct Constant<Output>: RunnableProtocol {
        let value: Output
        public init(_ value: Output) { self.value = value }
        public borrowing func run() -> Output { value }
    }

    // N-arity tuple combinator using parameter packs.
    // Each child can have a different Output; the tuple's Output is the
    // type-level concatenation of each child's Output.
    public struct Tuple<each Child: RunnableProtocol>: RunnableProtocol {
        public typealias Output = (repeat (each Child).Output)

        let children: (repeat each Child)

        public init(_ children: repeat each Child) {
            self.children = (repeat each children)
        }

        public borrowing func run() -> Output {
            (repeat (each children).run())
        }
    }

    // Empty (zero-arity) combinator.
    public struct Empty: RunnableProtocol {
        public typealias Output = Void
        public init() {}
        public borrowing func run() -> Void { () }
    }

    // The result builder — one variadic `buildBlock` replaces the per-arity
    // overload table.
    @resultBuilder
    public enum Builder {
        public static func buildBlock() -> Empty {
            Empty()
        }

        public static func buildBlock<each Child: RunnableProtocol>(
            _ parts: repeat each Child
        ) -> Tuple<repeat each Child> {
            Tuple(repeat each parts)
        }
    }
}

// MARK: - Validations

print("=== Result-Builder + Parameter-Packs N-Arity Spike ===")
print("")

// V1: single child via @Builder attribute
@Combinator.Builder
func singletonBody() -> Combinator.Tuple<Combinator.Constant<Int>> {
    Combinator.Constant(42)
}
do {
    let result = singletonBody().run()
    print("V1 ✓ Single-arity via @Builder — result=\(result)")
}

// V2: multi-arity (2, 3, 4 children)
@Combinator.Builder
func pair() -> Combinator.Tuple<Combinator.Constant<Int>, Combinator.Constant<String>> {
    Combinator.Constant(1)
    Combinator.Constant("two")
}
do {
    let result = pair().run()
    print("V2a ✓ 2-arity — result=\(result)")
}

@Combinator.Builder
func triple() -> Combinator.Tuple<Combinator.Constant<Int>, Combinator.Constant<String>, Combinator.Constant<Bool>> {
    Combinator.Constant(1)
    Combinator.Constant("two")
    Combinator.Constant(true)
}
do {
    let result = triple().run()
    print("V2b ✓ 3-arity — result=\(result)")
}

@Combinator.Builder
func quad() -> Combinator.Tuple<Combinator.Constant<Int>, Combinator.Constant<Int>, Combinator.Constant<Int>, Combinator.Constant<Int>> {
    Combinator.Constant(10)
    Combinator.Constant(20)
    Combinator.Constant(30)
    Combinator.Constant(40)
}
do {
    let result = quad().run()
    print("V2c ✓ 4-arity — result=\(result)")
}

// V3: zero-arity
@Combinator.Builder
func empty() -> Combinator.Empty {
}
do {
    empty().run()
    print("V3 ✓ 0-arity (Empty) — runs without crash")
}

// V4: heterogeneous Output preserved through the pack
@Combinator.Builder
func heterogeneous() -> Combinator.Tuple<Combinator.Constant<Int>, Combinator.Constant<[String]>, Combinator.Constant<Double?>> {
    Combinator.Constant(99)
    Combinator.Constant(["a", "b"])
    Combinator.Constant(Optional<Double>.some(3.14))
}
do {
    let result = heterogeneous().run()
    print("V4 ✓ Heterogeneous Output preserved — result=\(result)")
}

// V5: builder-attributed `var body` composition at use site
struct UserSerializer {
    @Combinator.Builder
    var body: Combinator.Tuple<Combinator.Constant<String>, Combinator.Constant<Int>> {
        Combinator.Constant("hello")
        Combinator.Constant(42)
    }
}
do {
    let s = UserSerializer()
    let result = s.body.run()
    print("V5 ✓ @Builder on var body in user type — result=\(result)")
}

print("")
print("All 5 validations PASSED")
print("Result-builder + parameter packs compose cleanly.")
print("Implication: Parser.Builder + Serializer.Builder can replace their")
print("per-arity overload tables (currently 2/3/.../N) with a single")
print("variadic `buildBlock<each C: ...Protocol>(_ parts: repeat each C)`.")
