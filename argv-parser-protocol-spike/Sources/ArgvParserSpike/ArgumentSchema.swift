//
//  ArgumentSchema.swift
//  argv-parser-protocol-spike
//
//  Data-only Schema describing the structure of a CLI command's arguments.
//
//  Per §2.2 of the swift-arguments research doc (v1.0.3), the Schema is
//  data, not opaque continuation. Visitors walk it to produce help text,
//  bash completion scripts, manpages, etc.
//
//  Design notes:
//   * Per v1.0.3, Command/Schema types are Copyable-by-default. The ~Copyable
//     opt-in is deferred to a different direction item, so the visitor
//     protocol does NOT carry `~Copyable` constraints here.
//   * `Argument.Positional<V>` and `Argument.Option<V>` are generic on the
//     parsed value type V (matching §2.2). To collect them in a single
//     ordered list (the Schema), they conform to a non-generic
//     `Argument.Schema.Node` protocol that exposes `accept(visitor:)`.
//

/// The `Argument` namespace per [API-NAME-001].
public enum Argument {}

extension Argument {

    /// A required positional argument with a parsed value type `V`.
    ///
    /// Generic over `V` per §2.2 so the visitor sees the same value-typed
    /// information the parser sees — there is no second source of truth.
    public struct Positional<V: Sendable & Equatable>: Sendable, Equatable {
        public let name: String
        public let valueName: String
        public let help: String

        public init(name: String, valueName: String, help: String) {
            self.name = name
            self.valueName = valueName
            self.help = help
        }
    }

    /// An optional named option that takes a value (e.g., `--count <int>`),
    /// generic over the parsed value type `V`.
    public struct Option<V: Sendable & Equatable>: Sendable, Equatable {
        public let name: String
        public let valueName: String
        public let help: String
        public let defaultValue: V?

        public init(
            name: String,
            valueName: String,
            help: String,
            defaultValue: V? = nil
        ) {
            self.name = name
            self.valueName = valueName
            self.help = help
            self.defaultValue = defaultValue
        }
    }

    /// A boolean flag — present means true, absent means false.
    public struct Flag: Sendable, Equatable {
        public let name: String
        public let help: String

        public init(name: String, help: String) {
            self.name = name
            self.help = help
        }
    }
}

// MARK: - Schema node + visitor protocols

extension Argument {

    /// Schema namespace.
    public enum Schema {}
}

extension Argument.Schema {

    /// A schema node — one positional, option, or flag in a command's
    /// argument surface. Each conforming type implements `accept(visitor:)`
    /// dispatching to the visitor's value-typed `visit(...)` method.
    public protocol Node: Sendable {
        func accept<Visitor: Argument.Schema.Visitor>(
            _ visitor: inout Visitor
        ) throws(Visitor.Failure)
    }

    /// Visitor over an argument schema. Mirrors §2.2 of the research doc:
    /// the visitor receives value-typed nodes (`Positional<V>`, `Option<V>`)
    /// at compile time. Help / completion / manpage generators each implement
    /// this protocol with a different `Buffer` shape.
    public protocol Visitor {
        associatedtype Failure: Swift.Error = Never
        mutating func visit<V: Sendable & Equatable>(positional: Argument.Positional<V>) throws(Failure)
        mutating func visit<V: Sendable & Equatable>(option: Argument.Option<V>) throws(Failure)
        mutating func visit(flag: Argument.Flag) throws(Failure)
    }
}

// MARK: - Node conformances

extension Argument.Positional: Argument.Schema.Node {
    public func accept<Visitor: Argument.Schema.Visitor>(
        _ visitor: inout Visitor
    ) throws(Visitor.Failure) {
        try visitor.visit(positional: self)
    }
}

extension Argument.Option: Argument.Schema.Node {
    public func accept<Visitor: Argument.Schema.Visitor>(
        _ visitor: inout Visitor
    ) throws(Visitor.Failure) {
        try visitor.visit(option: self)
    }
}

extension Argument.Flag: Argument.Schema.Node {
    public func accept<Visitor: Argument.Schema.Visitor>(
        _ visitor: inout Visitor
    ) throws(Visitor.Failure) {
        try visitor.visit(flag: self)
    }
}

// MARK: - Command Schema (top-level)

extension Argument {

    /// The full schema for one command: a name, an abstract, and the
    /// ordered list of argument-schema nodes that make up its surface.
    ///
    /// The list of nodes is the single source of truth — it drives both:
    ///   * the parser (each node dispatches to a leaf parser)
    ///   * the help / completion visitors (each node dispatches to `Visitor.visit(...)`)
    ///
    /// `nodes` is `[any Argument.Schema.Node]` because the list is
    /// heterogeneous (each `Positional<V>`/`Option<V>` has a distinct `V`).
    /// The visitor double-dispatch via `accept(_:)` recovers the static
    /// value type at the call site.
    public struct Command: Sendable {
        public let name: String
        public let abstract: String
        public let nodes: [any Argument.Schema.Node]

        public init(
            name: String,
            abstract: String,
            nodes: [any Argument.Schema.Node]
        ) {
            self.name = name
            self.abstract = abstract
            self.nodes = nodes
        }

        /// Walk every node in declaration order, invoking the appropriate
        /// `visitor.visit(...)` method on each. This is the single entry
        /// point the help and completion visitors share.
        public func accept<Visitor: Argument.Schema.Visitor>(
            _ visitor: inout Visitor
        ) throws(Visitor.Failure) {
            for node in nodes {
                try node.accept(&visitor)
            }
        }
    }
}
