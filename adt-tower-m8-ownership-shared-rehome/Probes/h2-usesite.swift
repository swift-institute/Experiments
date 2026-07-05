// H2 use-site leg. A THIRD module that imports BOTH the box module (1-param
// `Ownership.Shared<Value>` class) AND the column module (2-param `Ownership.Shared<Element, B>`
// struct). Does `Ownership.Shared<…>` resolve by ARITY, or is it an ambiguity error?
//
// This is the window a consumer would sit in if M8(b) landed before M8(a): both `Ownership.Shared`
// declarations visible at once. References are inside a function so no top-level global-actor
// isolation noise clouds the arity finding.
import OwnershipBoxStub
import H2Probe

func probe() {
    // TYPE-NAME references (annotation + metatype): does arity select the candidate?
    let oneArg: Ownership.Shared<Int>.Type = Ownership.Shared<Int>.self       // 1 arg -> class?
    let twoArg: Ownership.Shared<Int, Int>.Type = Ownership.Shared<Int, Int>.self // 2 args -> struct?
    _ = oneArg
    _ = twoArg

    // INITIALIZER-expression references (constructor overload resolution, for contrast).
    let boxValue = Ownership.Shared(7)          // 1-arg initializer -> class
    let colValue = Ownership.Shared<Int, Int>() // 2-arg initializer -> struct
    _ = boxValue.value
    _ = colValue
}
