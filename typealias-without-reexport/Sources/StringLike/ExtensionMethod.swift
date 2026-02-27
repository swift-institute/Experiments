// Extension method defined in StringLike module on String.
// Tests whether MemberImportVisibility allows access through typealias.

extension String {
    public var isEmpty: Bool { count == 0 }
}
