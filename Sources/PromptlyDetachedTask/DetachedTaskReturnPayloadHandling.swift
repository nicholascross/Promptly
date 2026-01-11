import PromptlyKit

public struct DetachedTaskReturnPayloadResolution: Sendable {
    public let payload: DetachedTaskReturnPayload
    public let didUseFallback: Bool

    public init(
        payload: DetachedTaskReturnPayload,
        didUseFallback: Bool
    ) {
        self.payload = payload
        self.didUseFallback = didUseFallback
    }
}

public protocol DetachedTaskReturnPayloadResolving: Sendable {
    func extractReturnPayload(
        from conversationEntries: [PromptMessage]
    ) -> DetachedTaskReturnPayload?

    func resolvePayload(
        candidate: DetachedTaskReturnPayload?,
        conversationEntries: [PromptMessage]
    ) -> DetachedTaskReturnPayloadResolution

    func needsFollowUp(
        in payload: DetachedTaskReturnPayload
    ) -> Bool
}
