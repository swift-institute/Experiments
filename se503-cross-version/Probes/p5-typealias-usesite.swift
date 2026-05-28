typealias NC = ~Copyable
protocol Mailbox<Items> { associatedtype Items: ~Copyable }
extension Mailbox where Items: NC { func ping() {} }
