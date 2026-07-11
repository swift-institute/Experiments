import XCTest

import CasesMacros
import CasesRuntime
import CasesSubject

// Cross-module behavioral proof: enums live in CasesSubject; every call site below
// is written in this separate test module, so passing means the keypath-literal
// shapes resolve across a module boundary, not just intra-module.

final class CasesTests: XCTestCase {

    // MARK: Part 1 — `.is(\.case)` keypath-literal shape (depth-1)

    func testDepth1IsPredicate() {
        XCTAssertTrue((Route.list).is(\.list))
        XCTAssertFalse((Route.list).is(\.home))
        XCTAssertFalse((Route.list).is(\.detail))
        XCTAssertTrue((Route.detail(3)).is(\.detail))
        XCTAssertTrue((Route.edit(id: 1, draft: "d")).is(\.edit))
    }

    func testDepth1EmbedExtractRoundTrip() {
        // No-payload case.
        let home = Route.cases[keyPath: \.home]
        XCTAssertEqual(home.embed(()), .home)
        XCTAssertNotNil(home.extract(.home))
        XCTAssertNil(home.extract(.list))

        // Single-payload case.
        let detail = Route.cases[keyPath: \.detail]
        XCTAssertEqual(detail.embed(42), .detail(42))
        XCTAssertEqual(detail.extract(.detail(42)), 42)
        XCTAssertNil(detail.extract(.home))

        // Multi-payload (tuple) case.
        let edit = Route.cases[keyPath: \.edit]
        XCTAssertEqual(edit.embed((id: 9, draft: "x")), .edit(id: 9, draft: "x"))
        let extracted = edit.extract(.edit(id: 9, draft: "x"))
        XCTAssertEqual(extracted?.id, 9)
        XCTAssertEqual(extracted?.draft, "x")
        XCTAssertNil(edit.extract(.home))
    }

    // MARK: Part 2 — depth-3 @dynamicMemberLookup composition

    func testDepth3CompositionRoundTrip() {
        let creds = Credentials(token: "abc")
        // Composed keypath literal: KeyPath<AppRoute.Cases, Case.Path<AppRoute, Credentials>>
        let path = AppRoute.cases[keyPath: \.authenticate.api.credentials]

        let whole: AppRoute = path.embed(creds)
        XCTAssertEqual(whole, .authenticate(.api(.credentials(creds))))

        XCTAssertEqual(path.extract(whole), creds)
        XCTAssertNil(path.extract(.home))
        XCTAssertNil(path.extract(.authenticate(.login)))
        XCTAssertNil(path.extract(.authenticate(.api(.status))))
    }

    func testDepth3IsPredicate() {
        let whole: AppRoute = .authenticate(.api(.credentials(Credentials(token: "x"))))
        XCTAssertTrue(whole.is(\.authenticate.api.credentials))
        XCTAssertFalse(whole.is(\.authenticate.api.status))
        XCTAssertFalse(whole.is(\.home))

        // Intermediate depth-2 hop composes too.
        XCTAssertTrue(whole.is(\.authenticate.api))
        XCTAssertTrue(whole.is(\.authenticate))
        XCTAssertFalse((AppRoute.authenticate(.login)).is(\.authenticate.api))
    }

    // MARK: Part 1 (cont.) — `.case(\.case)` combinator shape

    func testCaseCombinatorRootPinnedByNamespace() {
        // Leading-dot keypath literal; Root pinned by `Routes<...>`.
        let listPath = Routes<Route>.case(\.list)
        XCTAssertNotNil(listPath.extract(.list))
        XCTAssertNil(listPath.extract(.home))

        // Composed literal through the same combinator.
        let credsPath = Routes<AppRoute>.case(\.authenticate.api.credentials)
        let c = Credentials(token: "z")
        XCTAssertEqual(credsPath.extract(.authenticate(.api(.credentials(c)))), c)
    }

    func testCaseCombinatorRootPinnedByAnnotation() {
        // Free-function form; Root pinned by the result-type annotation.
        let detail: Case.Path<Route, Int> = makeCase(\.detail)
        XCTAssertEqual(detail.embed(7), .detail(7))
        XCTAssertEqual(detail.extract(.detail(7)), 7)
    }

    // MARK: Part 3 — coexistence with @DualLike

    func testCoexistenceWitnessTypesDistinct() {
        let c: CoexistRoute = .beta(3)

        // Both witnesses exist and are reachable — no name collision (Cases vs Prisms).
        _ = CoexistRoute.cases    // @Cases witness
        _ = CoexistRoute.prisms   // @DualLike witness

        // Both `is` overloads resolve when the witness root is stated explicitly.
        XCTAssertTrue(c.is(\CoexistRoute.Cases.beta))
        XCTAssertTrue(c.is(\CoexistRoute.Prisms.beta))
        XCTAssertFalse(c.is(\CoexistRoute.Cases.alpha))
        XCTAssertFalse(c.is(\CoexistRoute.Prisms.gamma))
    }

    func testCoexistenceConformancesBothPresent() {
        // @Cases added `: CaseAnalyzable`; @DualLike added `: DualLikeMarker`.
        func requiresCaseAnalyzable<T: CaseAnalyzable>(_: T.Type) {}
        func requiresDualLikeMarker<T: DualLikeMarker>(_: T.Type) {}
        requiresCaseAnalyzable(CoexistRoute.self)
        requiresDualLikeMarker(CoexistRoute.self)
    }

    // Reference the same-module proof so it is compiled and linked.
    func testSameModuleTypecheckCompiles() {
        casesSubjectSameModuleTypecheck()
    }
}
