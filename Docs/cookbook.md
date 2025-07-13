# Promptly Cookbook

This document provides a collection of examples to demonstrate how you can integrate **Promptly** into your development workflow. The examples are designed to be language-agnostic and cover a range of general development tasks such as generating commit messages, pull request descriptions, release notes, and more.

## Table of Contents

- [Generate Commit Message](#generate-commit-message)
- [Update README with Changes](#update-readme-with-changes)
- [Generate Release Notes](#generate-release-notes)
- [Pull Request Description Generator](#pull-request-description-generator)
- [Bug Report Summarization](#bug-report-summarization)
- [Code Review Assistant](#code-review-assistant)
- [Test Case Suggestions](#test-case-suggestions)
- [Error Log Analysis](#error-log-analysis)
- [Refactoring Suggestions](#refactoring-suggestions)
- [Generate Technical Specification](#generate-technical-specification)
- [Auto-generate Code Comments](#auto-generate-code-comments)
- [Identify Potential Bugs](#identify-potential-bugs)

---

## Generate Commit Message

Generate a concise commit message based on your staged changes:

```bash
git diff --staged | promptly "Write a concise commit message that explains the following changes."
```

Tip: You can pipe the output directly into your clipboard (e.g., using pbcopy on macOS) to easily paste it into your commit message.

## Update README with Changes

Automatically update your README by incorporating recent changes:

```bash
(cat README.md; echo; git diff --staged) | promptly "Update the README with the above changes, ensuring all examples remain relevant and the overall document is cohesive. Output the full README and nothing else." > README.md
```

## Generate Release Notes

Summarize recent commits to create release notes:

```bash
git log --pretty=format:"%h %s" -n 10 | promptly "Generate release notes summarizing the key changes from the commit logs above."
```

Tip: Adjust the number of commits (here -n 10) to match your release cycle.

## Pull Request Description Generator

Create a detailed pull request description using commit logs and diffs:

```bash
(
  echo "Pull Request Title: [Feature] Add New Integration"
  echo ""
  echo "Recent Commits:"
  git log --oneline --no-merges -n 5
  echo ""
  echo "Changes Overview:"
  git diff --staged
) | promptly "Based on the information above, generate a comprehensive pull request description that covers the motivation behind the changes, a summary of what was modified, and instructions on how to test the updates."
```

## Bug Report Summarization

Turn verbose error logs into a clear and concise bug report:

```bash
cat error.log | promptly "Summarize the error log above into a concise bug report that includes a description of the issue, potential causes, and steps to reproduce the problem."
```

## Code Review Assistant

Receive a review summary and actionable suggestions based on code differences:

```bash
git diff --staged | promptly "Provide a detailed code review for the changes above, highlighting strengths, potential issues, and suggestions for improvement."
```

Tip: This can help catch issues early in your pull request workflow.

## Test Case Suggestions

Generate potential test cases for a given specification or module:

```bash
cat module_requirements.txt | promptly "Based on the requirements listed above, suggest a series of test cases including edge cases and error handling scenarios."
```

## Error Log Analysis

Analyze an error log to receive troubleshooting steps and potential fixes:

```bash
cat system_error.log | promptly "Analyze the error log above and propose a list of troubleshooting steps along with possible solutions."
```

## Smart Log Slicing Middleware

When using a shell-command tool configured with `truncateOutput: true` (for example, wrapping `xcodebuild`, `swift build`, or `tree`), Promptly will condense large outputs by keeping the first 250 and last 250 lines. It then asks the LLM to suggest up to five regular expressions that match important content (errors, warnings, etc.) in the omitted middle section. The matched lines are reinjected between the head and tail of the log. The JSON response from the tool includes the exit code, condensed output, number of skipped lines, and the regex patterns suggested by the LLM.

Example:

```bash
promptly --message "user:Build the swift package and Analyze the build log for failures and warnings"
```

The tool response will include:

- `exitCode`: exit code of the wrapped command
- `skippedLines`: number of lines omitted
- `regex`: array of regex patterns suggested by the LLM
- `output`: the condensed log with matched lines reinjected

## Refactoring Suggestions

Get recommendations on how to refactor a block of code for clarity and maintainability:

```bash
cat code_snippet.txt | promptly "Review the code snippet above and suggest refactoring improvements that enhance clarity, efficiency, and maintainability."
```

## Generate Technical Specification

Create an outline for a technical specification document based on provided requirements:

```bash
cat requirements.txt | promptly "Based on the requirements above, generate an outline for a technical specification document that covers the system architecture, major components, and their interactions."
```

## Auto-generate Code Comments

Automatically insert meaningful comments into code to improve documentation:

```bash
cat code_without_comments.txt | promptly "Analyze the code above and insert helpful comments that explain its functionality and logic."
```

## Identify Potential Bugs

Examine code for potential issues and provide suggestions for fixes:

```bash
cat code_snippet.txt | promptly "Examine the code above and identify any potential bugs or issues. Offer suggestions for resolving them."
```

## Automated File Edits

Perform safe, atomic file modifications via line-based edits:

```bash
promptly \
  --message "system:Apply the modifyFile tool to perform safe, atomic file modifications within the project sandbox." \
  --message "user:{\"filePath\":\"path/to/file.swift\",\"edits\":[{\"startLine\":5,\"endLine\":8,\"replacement\":\"// Updated implementation\nfunc newMethod() { /* ... */ }\n\"}]}" \
| jq .
```

The `modifyFile` tool will apply the specified edits under the project root while preventing any modifications outside the sandbox.

## Whitelisted Shell Commands

Promptly can execute a curated set of shell commands defined in your project’s configuration. Each tool runs in a sandbox, enforcing that any file or directory paths passed in parameters stay within the project root. Simply send a user message describing the action you want in natural language, and Promptly will choose the appropriate tool and parameters under the hood.

For example, to list all files under the `src/` directory:

```bash
promptly --message 'user:list all files under the src folder'
```

To find every Swift source file in your project:

```bash
promptly --message 'user:find all Swift files in the project'
```

To search for TODO comments throughout your codebase:

```bash
promptly --message 'user:search for TODO in the project files'
```

To view a visual directory tree of the repository:

```bash
promptly --message 'user:show me the directory tree'
```

To extract Swift type information with SourceCrawler:

```bash
promptly --message 'user:analyze the Swift project and extract type information'
```

To create or overwrite a `CHANGELOG.md` file with an initial header:

```bash
promptly --message 'user:create a CHANGELOG.md file with initial changelog content'
```

See [Shell Commands Configuration](configuration.md#shell-commands-configuration) for details on defining or customizing your own whitelisted commands.

---

This `cookbook.md` file was generated by AI. It is a handy reference for incorporating **Promptly** into your daily development tasks, from automating documentation to assisting with code reviews and bug reports. Enjoy experimenting with these examples and adapting them to your workflow!
