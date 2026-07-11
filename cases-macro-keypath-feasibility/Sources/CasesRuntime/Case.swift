// MARK: - Case.Path<Root, Value>
//
// Minimal case-path value type carrying an embed/extract pair. This is the value
// held at each keypath position: `KeyPath<Enum.Cases, Case.Path<Enum, Value>>`.
//
// `@dynamicMemberLookup` with a KeyPath-based subscript (SE-0252) is what makes
// depth-3 composition `\.authenticate.api.credentials` type-check: each hop past
// the first is a dynamic-member lookup that composes embed/extract, requiring the
// hop's `Value` to itself be `CaseAnalyzable` (so its `Cases` witness is reachable).
//
// `Case.Path` is the `Nest.Name` shape the routing arc's R3 plan names literally.

public enum Case {}

extension Case {
    @dynamicMemberLookup
    public struct Path<Root, Value> {
        public let embed: (Value) -> Root
        public let extract: (Root) -> Value?

        public init(embed: @escaping (Value) -> Root, extract: @escaping (Root) -> Value?) {
            self.embed = embed
            self.extract = extract
        }

        /// Depth composition: appending `.child` to a `Case.Path<Root, Value>` where
        /// `Value: CaseAnalyzable` yields `Case.Path<Root, Sub>` by threading embed/extract.
        public subscript<Sub>(
            dynamicMember keyPath: KeyPath<Value.Cases, Case.Path<Value, Sub>>
        ) -> Case.Path<Root, Sub> where Value: CaseAnalyzable {
            let inner = Value.cases[keyPath: keyPath]
            return Case.Path<Root, Sub>(
                embed: { sub in self.embed(inner.embed(sub)) },
                extract: { root in self.extract(root).flatMap(inner.extract) }
            )
        }
    }
}
