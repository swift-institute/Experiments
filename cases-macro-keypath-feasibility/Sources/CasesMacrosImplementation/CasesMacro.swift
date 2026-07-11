import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - @Cases
//
// Generates, inside the enum:
//   - `struct Cases { ... one Case.Path property per case ... }`
//   - `static var cases: Cases`
//   - `func is<Value>(_ keyPath: KeyPath<Cases, Case.Path<Root, Value>>) -> Bool`
// and, via the extension role: `extension Enum: CaseAnalyzable {}`.

public struct CasesMacro {}

extension CasesMacro {
    enum Message: String, DiagnosticMessage {
        case requiresEnum
        case noEnumCases

        var message: String {
            switch self {
            case .requiresEnum: "@Cases can only be applied to an enum"
            case .noEnumCases: "@Cases requires an enum with at least one case"
            }
        }
        var diagnosticID: MessageID { MessageID(domain: "CasesMacro", id: rawValue) }
        var severity: DiagnosticSeverity { .error }
    }
}

extension CasesMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            context.diagnose(SwiftDiagnostics.Diagnostic(node: node, message: Message.requiresEnum))
            return []
        }
        let cases = extractCases(from: enumDecl)
        guard !cases.isEmpty else {
            context.diagnose(SwiftDiagnostics.Diagnostic(node: node, message: Message.noEnumCases))
            return []
        }
        return witnessMembers(
            cases: cases,
            root: enumDecl.name.trimmedDescription,
            isPublic: isPublicDecl(enumDecl),
            witness: "Cases",
            staticName: "cases"
        )
    }
}

extension CasesMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(EnumDeclSyntax.self) else { return [] }
        return [try ExtensionDeclSyntax("extension \(type.trimmed): CasesRuntime.CaseAnalyzable {}")]
    }
}
