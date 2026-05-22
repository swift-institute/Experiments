//
//  __WitnessBuilder.swift
//  Witness Core target
//
//  STEP 4: Builder hoist — mirrors production Builder<B> hoist.
//

@resultBuilder
public struct __WitnessBuilder<B> {}

extension Witness {
    public typealias Builder = __WitnessBuilder
}

extension Witness.`Builder` {
    @inlinable
    public static func buildExpression<S: Witness.`Protocol`>(
        _ witness: S
    ) -> S where S.Buffer == B {
        witness
    }

    @inlinable
    public static func buildBlock<S: Witness.`Protocol`>(
        _ witness: S
    ) -> S where S.Buffer == B {
        witness
    }

    @inlinable
    public static func buildPartialBlock<S: Witness.`Protocol`>(
        first: S
    ) -> S where S.Buffer == B {
        first
    }

    @inlinable
    public static func buildPartialBlock<
        Accumulated: Witness.`Protocol`,
        Next: Witness.`Protocol`
    >(
        accumulated: Accumulated,
        next: Next
    ) -> Witness.Sequence.Two<Accumulated, Next>
    where
        Accumulated.Buffer == B,
        Next.Buffer == B,
        Accumulated.Output == Next.Output
    {
        // PROBE: try Witnesses.Sequence.Two as expression instead of __ leak
        Witnesses.Sequence.Two(accumulated, next)
    }
}
