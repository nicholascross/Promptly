import Darwin
import Foundation

public struct StandardInputHandler {
    public init() {}

    public func readPipedInput() -> String? {
        guard isatty(STDIN_FILENO) == 0 else { return nil }
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            return nil
        }
        return text
    }

    public func reopenIfNeeded() {
        if isatty(STDIN_FILENO) == 0 {
            _ = freopen("/dev/tty", "r", stdin)
        }
    }
}
