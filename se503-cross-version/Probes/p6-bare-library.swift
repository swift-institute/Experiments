protocol Mailbox<Items> { associatedtype Items: ~Copyable }
extension Mailbox { func ping() {} }            // bare — no `where Items: ~Copyable`
func use<T: Mailbox>(_ t: borrowing T) {}        // bare generic use
