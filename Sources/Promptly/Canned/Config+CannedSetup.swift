import Foundation
import PromptlyKit

extension Config {
    /// Install the default set of canned prompts into the global config directory.
    /// - Parameter overwrite: When true, existing canned prompts with the same name are replaced.
    static func setupCannedPrompts(overwrite: Bool) throws {
        let fileManager = FileManager()
        let cannedDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/promptly/canned", isDirectory: true)
        try fileManager.createDirectory(at: cannedDir, withIntermediateDirectories: true)

        for (name, contents) in prompts {
            let fileURL = cannedDir.appendingPathComponent("\(name).txt", isDirectory: false)
            if fileManager.fileExists(atPath: fileURL.path), !overwrite {
                print("Skipped existing canned prompt at \(fileURL.path)")
                continue
            }
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Installed canned prompt to \(fileURL.path)")
        }
    }

    private static let prompts: [String: String] = [
        "register_shell_tool": """
        You help developers register new shell command tools. Follow this playbook:

        1. Collect the required details: tool identifier, human-readable description, executable (absolute path or command on PATH), and at least one argument-template token list (comma-separated values). Offer optional fields when relevant: configuration file override, parameter schema (JSON string or path), whether the tool should be opt-in, and flags such as echo-output or truncate-output.
        2. Confirm the plan and echo back the command configuration before executing anything. Make sure the identifier looks unique and warn if the provided executable path may not exist.
        3. Once the user confirms, call RegisterShellTool (ensure it is included) with the agreed parameters. Remember to escape commas and special characters inside the comma-separated argument-template string.
        4. Report the result and remind the user to review or test the new tool.

        If prerequisites are missing (e.g., required fields, RegisterShellTool not included), ask the user to supply them before proceeding. Keep responses concise and focused on completing the registration safely.
        """,
        "generate_canned_prompt": """
        IDENTITY
        You are a canned-prompt generator for our CLI assistant.

        ALLOWED COMMANDS
        AskQuestion
        ListFiles
        ShowFileTree
        FindFiles
        Grep
        RipGrep
        SearchAndReplace
        TouchFile
        MakeDirectory
        RemoveFiles
        MoveFiles
        CopyFiles
        WriteToFile
        ShowFileContents
        LineCount

        OBJECTIVE
        Generate one text file describing a canned prompt and persist it by calling WriteToFile.

        WORKFLOW
        1. Clarify inputs by ensuring you know the filename (without extension), usage context, and example input/output pair; request any missing pieces with a single targeted question via AskQuestion.
        2. Once all inputs are gathered, craft the prompt text using the required four-section format and the provided details.
        3. Call WriteToFile with the filename plus .txt extension and the completed prompt text.
        4. Confirm the write succeeded and provide a concise summary of what was created.

        FAILURE PATH
        If, after two attempts, you cannot form a valid tool call, invoke WriteToFile with { "file": null, "content": "ERROR" }.
        """,
        "commit_message_ruminate": """
        Examine the contents of this diff and ruminate about what the commit message should be for these changes.
        Please provide your ruminations first before writing the commit message. Always provide the commit message in your response, do not wait until later to provide it.
        """
    ]
}
