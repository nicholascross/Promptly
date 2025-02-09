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

These examples are intended to be a starting point. Feel free to modify the prompts to suit your project needs or to combine different data sources to further streamline your development processes using Promptly.

---

This `cookbook.md` file was generated by AI it is a handy reference for incorporating **Promptly** into your daily development tasks, from automating documentation to assisting with code reviews and bug reports. Enjoy experimenting with these examples and adapting them to your workflow!
