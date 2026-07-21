import Foundation

/// Two-step confirm state machine for assistive-technology users who
/// cannot perform a timed press-and-hold (Switch Control in particular).
///
/// First activation arms; a second activation within `windowSeconds`
/// confirms. Letting the window lapse means the next activation re-arms
/// instead of confirming — there is deliberately no single-activation
/// instant-confirm path anywhere in this machine. The deliberate
/// friction of the typed-confirm gate must survive in every input mode.
@available(iOS 17, *)
public struct TwoStepConfirmArming {

    public enum Outcome: Equatable {
        /// This activation armed (or re-armed) the machine. The caller
        /// should announce "activate again within N seconds to confirm".
        case armed
        /// This activation landed inside the open window — confirmed.
        /// The machine disarms itself; the caller performs the action.
        case confirmed
    }

    /// Seconds the arm window stays open after an arming activation.
    public let windowSeconds: TimeInterval

    /// When the machine was last armed; nil when disarmed.
    public private(set) var armedAt: Date?

    public init(windowSeconds: TimeInterval = 10) {
        self.windowSeconds = windowSeconds
    }

    /// True while the arm window is open.
    public func isArmed(now: Date = Date()) -> Bool {
        guard let armedAt else { return false }
        return now.timeIntervalSince(armedAt) <= windowSeconds
    }

    /// Drive the machine with one activation. Injectable `now` keeps
    /// the window logic testable without wall-clock sleeps.
    @discardableResult
    public mutating func activate(now: Date = Date()) -> Outcome {
        if isArmed(now: now) {
            armedAt = nil
            return .confirmed
        }
        armedAt = now
        return .armed
    }

    /// Disarm without confirming (cancel, sheet dismissal, timeout).
    public mutating func reset() {
        armedAt = nil
    }
}
