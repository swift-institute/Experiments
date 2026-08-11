extension Socket {
    public enum Error: Swift.Error {
        case io(IO<Never>.Error)
        case refused
    }
}
