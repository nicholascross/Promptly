import Foundation

enum DefaultAgentConfigurations {
    static let configurations: [DefaultAgentConfiguration] = [
        DefaultAgentConfiguration(
            fileName: "refactor",
            configuration: AgentConfigurationDocument(
                model: nil,
                provider: nil,
                api: nil,
                agent: AgentDefinitionDocument(
                    name: "Refactor Agent",
                    description: "Refactor code while preserving behavior and clarity.",
                    supervisorHint: nil,
                    systemPrompt: """
                    You are a refactoring specialist. Preserve behavior, keep changes minimal, and improve clarity.
                    Focus on readability, structure, and maintainability without altering public interfaces unless needed.
                    """,
                    tools: nil
                )
            )
        )
    ]
}
