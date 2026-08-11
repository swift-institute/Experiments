//
// Kernel.Event.Interest — readiness-interest stand-in. Production type
// is an OptionSet; this experiment uses an enum for the three
// commonly-paired states.
//

extension Kernel.Event {

    public enum Interest: Sendable, Equatable {
        case read
        case write
        case both
    }
}
