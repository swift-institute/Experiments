// Either+Consuming.swift
// Library declarations of `consuming` method variants for ~Copyable Either arms.
// Sibling executable target consumes these to validate cross-module per [EXP-017].

public import Either_Primitives

// MARK: - V1: consuming map(right:)

extension Either where Left: ~Copyable, Right: ~Copyable {

    /// Consuming variant of `map(right:)` for `~Copyable` arms.
    ///
    /// Consumes self, applies `transform` if `.right`, and returns a new
    /// `Either<Left, NewRight>` carrying the moved Left payload or the
    /// transformed Right payload.
    @inlinable
    public consuming func consumingMap<NewRight: ~Copyable, E: Swift.Error>(
        right transform: (consuming Right) throws(E) -> NewRight
    ) throws(E) -> Either<Left, NewRight> {
        switch consume self {
        case .left(let left):
            .left(consume left)
        case .right(let right):
            try .right(transform(consume right))
        }
    }
}

// MARK: - V2: consuming map(left:)

extension Either where Left: ~Copyable, Right: ~Copyable {

    @inlinable
    public consuming func consumingMap<NewLeft: ~Copyable, E: Swift.Error>(
        left transform: (consuming Left) throws(E) -> NewLeft
    ) throws(E) -> Either<NewLeft, Right> {
        switch consume self {
        case .left(let left):
            try .left(transform(consume left))
        case .right(let right):
            .right(consume right)
        }
    }
}

// MARK: - V3: consuming map(left:right:)

extension Either where Left: ~Copyable, Right: ~Copyable {

    @inlinable
    public consuming func consumingMap<
        NewLeft: ~Copyable,
        NewRight: ~Copyable,
        E: Swift.Error
    >(
        left  leftTransform:  (consuming Left)  throws(E) -> NewLeft,
        right rightTransform: (consuming Right) throws(E) -> NewRight
    ) throws(E) -> Either<NewLeft, NewRight> {
        switch consume self {
        case .left(let left):
            try .left(leftTransform(consume left))
        case .right(let right):
            try .right(rightTransform(consume right))
        }
    }
}

// MARK: - V4: consuming swapped()

extension Either where Left: ~Copyable, Right: ~Copyable {

    @inlinable
    public consuming func consumingSwapped() -> Either<Right, Left> {
        switch consume self {
        case .left(let left):
            .right(consume left)
        case .right(let right):
            .left(consume right)
        }
    }
}

// MARK: - V5: consuming fold(left:right:)

extension Either where Left: ~Copyable, Right: ~Copyable {

    @inlinable
    public consuming func consumingFold<Result: ~Copyable, E: Swift.Error>(
        left  leftHandler:  (consuming Left)  throws(E) -> Result,
        right rightHandler: (consuming Right) throws(E) -> Result
    ) throws(E) -> Result {
        switch consume self {
        case .left(let left):
            try leftHandler(consume left)
        case .right(let right):
            try rightHandler(consume right)
        }
    }
}

// MARK: - V6: consuming flatMap(right:)

extension Either where Left: ~Copyable, Right: ~Copyable {

    @inlinable
    public consuming func consumingFlatMap<NewRight: ~Copyable, E: Swift.Error>(
        right transform: (consuming Right) throws(E) -> Either<Left, NewRight>
    ) throws(E) -> Either<Left, NewRight> {
        switch consume self {
        case .left(let left):
            .left(consume left)
        case .right(let right):
            try transform(consume right)
        }
    }
}

// MARK: - V7: consuming flatMap(left:)

extension Either where Left: ~Copyable, Right: ~Copyable {

    @inlinable
    public consuming func consumingFlatMap<NewLeft: ~Copyable, E: Swift.Error>(
        left transform: (consuming Left) throws(E) -> Either<NewLeft, Right>
    ) throws(E) -> Either<NewLeft, Right> {
        switch consume self {
        case .left(let left):
            try transform(consume left)
        case .right(let right):
            .right(consume right)
        }
    }
}
