// Consumer A wants literal conformance for Tagged<UserTag, UInt32>.

public import TaggedLib

public enum UserTag {}
public typealias UserID = Tagged<UserTag, UInt32>

// Conformance for the specific Tagged specialization.
extension Tagged: ExpressibleByIntegerLiteral
where Tag == UserTag, RawValue == UInt32 {
    public init(integerLiteral value: UInt32) {
        self.init(__unchecked: (), value)
    }
}
