//
//  HelpVisitor.swift
//  argv-parser-protocol-spike
//
//  Visitor over an `Argument.Schema` (via `Argument.Command`) that
//  produces formatted help text.
//
//  This is one half of the P2 verification: a visitor walks a data-only
//  Schema and emits a human-readable artifact (help text) without any
//  ad-hoc reflection or string-tag dispatch. Every `visit(...)` method
//  is statically dispatched on the schema-node type the visitor sees.
//

/// A visitor that accumulates a help-text rendering of a command schema.
///
/// Usage:
/// ```swift
/// var visitor = HelpVisitor()
/// try command.accept(&visitor)
/// let helpText = visitor.render(for: command)
/// ```
public struct HelpVisitor: Argument.Schema.Visitor {
    public typealias Failure = Never

    /// Per-row entries collected while walking the schema. Rendering
    /// happens later (in `render(for:)`) so that the USAGE line can be
    /// composed from the same information.
    @usableFromInline
    internal enum Row: Sendable, Equatable {
        case positional(name: String, valueName: String, help: String)
        case option(name: String, valueName: String, help: String, defaultRepr: String?)
        case flag(name: String, help: String)
    }

    @usableFromInline
    internal var rows: [Row] = []

    public init() {}

    public mutating func visit<V: Sendable & Equatable>(
        positional: Argument.Positional<V>
    ) throws(Never) {
        rows.append(
            .positional(
                name: positional.name,
                valueName: positional.valueName,
                help: positional.help
            )
        )
    }

    public mutating func visit<V: Sendable & Equatable>(
        option: Argument.Option<V>
    ) throws(Never) {
        let repr: String? = option.defaultValue.map { "\($0)" }
        rows.append(
            .option(
                name: option.name,
                valueName: option.valueName,
                help: option.help,
                defaultRepr: repr
            )
        )
    }

    public mutating func visit(flag: Argument.Flag) throws(Never) {
        rows.append(.flag(name: flag.name, help: flag.help))
    }

    /// Render the accumulated rows into the canonical help-text format.
    public func render(for command: Argument.Command) -> String {
        var output = ""
        output += renderUsage(commandName: command.name) + "\n\n"

        let positionalRows = rows.compactMap { row -> Row? in
            if case .positional = row { return row }
            return nil
        }

        if !positionalRows.isEmpty {
            output += "ARGUMENTS:\n"
            for row in positionalRows {
                guard case let .positional(_, valueName, help) = row else { continue }
                let left = "<\(valueName)>"
                output += "  " + pad(left, to: 24) + "  " + help + "\n"
            }
            output += "\n"
        }

        output += "OPTIONS:\n"
        for row in rows {
            switch row {
            case .positional:
                continue
            case let .option(name, valueName, help, defaultRepr):
                let left = "\(name) <\(valueName)>"
                var right = help
                if let d = defaultRepr {
                    right += " (default: \(d))"
                }
                output += "  " + pad(left, to: 24) + "  " + right + "\n"
            case let .flag(name, help):
                output += "  " + pad(name, to: 24) + "  " + help + "\n"
            }
        }
        // The built-in --help row is appended unconditionally.
        output += "  " + pad("-h, --help", to: 24) + "  Show help information.\n"
        return output
    }

    // MARK: - Helpers

    private func renderUsage(commandName: String) -> String {
        var parts: [String] = ["USAGE:", commandName]
        for row in rows {
            switch row {
            case .positional:
                continue // positionals appended last
            case let .option(name, valueName, _, _):
                parts.append("[\(name) <\(valueName)>]")
            case let .flag(name, _):
                parts.append("[\(name)]")
            }
        }
        for row in rows {
            guard case let .positional(_, valueName, _) = row else { continue }
            parts.append("<\(valueName)>")
        }
        return parts.joined(separator: " ")
    }

    private func pad(_ string: String, to width: Int) -> String {
        if string.count >= width { return string }
        return string + String(repeating: " ", count: width - string.count)
    }
}
