protocol Mailbox<Items> { associatedtype Items: ~Copyable }
extension Mailbox { func ping() {} }
struct MoveOnly: ~Copyable {}
struct MB: Mailbox { typealias Items = MoveOnly }
func check(_ m: borrowing MB) { m.ping() }       // available on prototype; narrowed away by SE-503?
