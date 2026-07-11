import SwiftSyntax

// MARK: - Enum analysis (reproduced from swift-dual's EnumExpansion/Utilities patterns)
//
// These mirror swift-dual's `extractCases` / `isPublicDecl` so the spike exercises
// the same generated-name conventions the production @Cases would use in swift-dual —
// without editing swift-dual or importing it.

struct CaseInfo {
    let name: String
    let params: [(label: String?, type: String)]
}

/// Flatten `case a, b(Int)` element lists into one `CaseInfo` per case element.
/// `.text` preserves backtick escaping — used directly, never re-escaped.
func extractCases(from enumDecl: EnumDeclSyntax) -> [CaseInfo] {
    enumDecl.memberBlock.members.flatMap { member -> [CaseInfo] in
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { return [] }
        return caseDecl.elements.map { element in
            CaseInfo(
                name: element.name.text,
                params: element.parameterClause?.parameters.map { param in
                    (label: param.firstName?.text, type: param.type.trimmedDescription)
                } ?? []
            )
        }
    }
}

func isPublicDecl(_ declaration: some DeclGroupSyntax) -> Bool {
    declaration.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
}

// MARK: - Per-case codegen fragments

/// The `Value` type carried by a case's `Case.Path<Root, Value>`.
func valueType(_ c: CaseInfo) -> String {
    if c.params.isEmpty { return "Void" }
    if c.params.count == 1 { return c.params[0].type }
    let tuple = c.params.map { p in
        p.label.map { "\($0): \(p.type)" } ?? p.type
    }.joined(separator: ", ")
    return "(\(tuple))"
}

func embedClosure(_ c: CaseInfo) -> String {
    if c.params.isEmpty { return "{ _ in .\(c.name) }" }
    if c.params.count == 1 {
        let label = c.params[0].label.map { "\($0): " } ?? ""
        return "{ .\(c.name)(\(label)$0) }"
    }
    let args = c.params.enumerated().map { i, p in
        (p.label.map { "\($0): " } ?? "") + "$0.\(i)"
    }.joined(separator: ", ")
    return "{ .\(c.name)(\(args)) }"
}

func extractClosure(_ c: CaseInfo) -> String {
    if c.params.isEmpty {
        return "{ if case .\(c.name) = $0 { return () } else { return nil } }"
    }
    if c.params.count == 1 {
        let label = c.params[0].label.map { "\($0): " } ?? ""
        return "{ if case .\(c.name)(\(label)let v) = $0 { return v } else { return nil } }"
    }
    let patterns = c.params.enumerated().map { i, p in
        (p.label.map { "\($0): " } ?? "") + "let v\(i)"
    }.joined(separator: ", ")
    let tuple = c.params.enumerated().map { i, p in
        (p.label.map { "\($0): " } ?? "") + "v\(i)"
    }.joined(separator: ", ")
    return "{ if case .\(c.name)(\(patterns)) = $0 { return (\(tuple)) } else { return nil } }"
}

// MARK: - Witness struct + accessor + `is` predicate

/// Generates the members installed inside the enum: the witness struct (one
/// `Case.Path` property per case), a `static var` accessor, and an `is(_:)`
/// predicate keyed by `KeyPath<Witness, Case.Path<Root, Value>>`.
///
/// `witness` / `staticName` differ per macro (`Cases`/`cases` vs `Prisms`/`prisms`)
/// which is precisely what keeps two co-attached macros from colliding.
func witnessMembers(
    cases: [CaseInfo],
    root: String,
    isPublic: Bool,
    witness: String,
    staticName: String
) -> [DeclSyntax] {
    let acc = isPublic ? "public " : ""

    let properties = cases.map { c in
        "\(acc)var \(c.name): CasesRuntime.Case.Path<\(root), \(valueType(c))> { CasesRuntime.Case.Path(embed: \(embedClosure(c)), extract: \(extractClosure(c))) }"
    }.joined(separator: "\n        ")

    let witnessStruct: DeclSyntax = """
        \(raw: acc)struct \(raw: witness) {
            \(raw: acc)init() {}
            \(raw: properties)
        }
        """

    let accessor: DeclSyntax = "\(raw: acc)static var \(raw: staticName): \(raw: witness) { \(raw: witness)() }"

    let isPredicate: DeclSyntax = """
        \(raw: acc)func `is`<Value>(_ keyPath: KeyPath<\(raw: witness), CasesRuntime.Case.Path<\(raw: root), Value>>) -> Bool {
            Self.\(raw: staticName)[keyPath: keyPath].extract(self) != nil
        }
        """

    return [witnessStruct, accessor, isPredicate]
}
