protocol NonCopyable: ~Copyable {}
protocol Box {
    associatedtype Item: NonCopyable      // a protocol bound, NOT `: ~Copyable`
}
struct MoveOnly: ~Copyable, NonCopyable {} // genuine move-only type
struct UserBox: Box { typealias Item = MoveOnly }
