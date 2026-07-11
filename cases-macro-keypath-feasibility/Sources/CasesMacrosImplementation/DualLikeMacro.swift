import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - @DualLike
//
// Coexistence stand-in for @Dual. Generates a *differently named* witness
// (`Prisms`/`prisms`) plus its own overloaded `is`, and (via the extension role)
// a `: DualLikeMarker` conformance. Attached alongside @Cases on the same enum it
// proves: (a) the two witness types (`Cases` vs `Prisms`) do not collide, and
// (b) two extension macros adding two distinct conformances coexist.

public struct DualLikeMacro {}

extension DualLikeMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else { return [] }
        let cases = extractCases(from: enumDecl)
        guard !cases.isEmpty else { return [] }
        return witnessMembers(
            cases: cases,
            root: enumDecl.name.trimmedDescription,
            isPublic: isPublicDecl(enumDecl),
            witness: "Prisms",
            staticName: "prisms"
        )
    }
}

extension DualLikeMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(EnumDeclSyntax.self) else { return [] }
        return [try ExtensionDeclSyntax("extension \(type.trimmed): CasesRuntime.DualLikeMarker {}")]
    }
}
