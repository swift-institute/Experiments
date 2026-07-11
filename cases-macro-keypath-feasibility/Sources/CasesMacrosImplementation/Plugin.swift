import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct CasesMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        CasesMacro.self,
        DualLikeMacro.self,
    ]
}
