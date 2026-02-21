public struct DetachedTaskRunResult: Sendable {
    public let payload: DetachedTaskReturnPayload
    public let didUseFallbackPayload: Bool
    public let didSendReminder: Bool
    public let needsFollowUp: Bool

    public init(
        payload: DetachedTaskReturnPayload,
        didUseFallbackPayload: Bool,
        didSendReminder: Bool,
        needsFollowUp: Bool
    ) {
        self.payload = payload
        self.didUseFallbackPayload = didUseFallbackPayload
        self.didSendReminder = didSendReminder
        self.needsFollowUp = needsFollowUp
    }
}
