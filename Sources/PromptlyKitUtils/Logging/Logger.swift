import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct Logger {
    public enum Level {
        case info, success, warning, error
    }

    private static let enableColors: Bool = {
        guard isatty(fileno(stdout)) != 0 else { return false }
        return ProcessInfo.processInfo.environment["NO_COLOR"] == nil
    }()

    public static func log(_ message: String, level: Level = .info) {
        let (symbol, colorCode): (String, String) = {
            switch level {
            case .info:    return (">", "\u{001B}[36m")
            case .success: return ("", "\u{001B}[32m")
            case .warning: return ("", "\u{001B}[33m")
            case .error:   return ("", "\u{001B}[31m")
            }
        }()

        if enableColors {
            let reset = "\u{001B}[0m"
            Swift.print("\n\(colorCode)\(symbol) \(message)\(reset)")
        } else {
            Swift.print("\n\(message)")
        }
    }

    public static func prompt(_ message: String) {
        let colorCode = "\u{001B}[1;36m"
        if enableColors {
            Swift.print("\(colorCode)\(message)\u{001B}[0m", terminator: "")
        } else {
            Swift.print(message, terminator: "")
        }
    }
}
