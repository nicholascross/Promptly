public enum SubAgentRoutingGuidance {
    public static let delegationCriteria =
        "multi step execution, multi file changes, command execution, or specialized analysis"

    public static let directHandlingCriteria =
        "simple lookups, short explanations, greetings, or one command tasks"

    public static var subAgentHintDelegationReminder: String {
        "Route to a sub agent when the request requires \(delegationCriteria)."
    }

    public static var subAgentHintDirectHandlingReminder: String {
        "For \(directHandlingCriteria), answer directly or use the matching shell tool instead."
    }

    public static var ambiguousRoutingReminder: String {
        "If routing is unclear, ask one focused clarifying question before deciding."
    }

    public static func delegatedToolRoutingReminder(toolName: String) -> String {
        "Route requests to \(toolName) when they require \(delegationCriteria)."
    }
}
