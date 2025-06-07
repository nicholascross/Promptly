import Foundation

public enum ToolFactory {
    public static func makeTools() -> [any ExecutableTool] {
        [RandomNumberTool()]
    }
}

private struct RandomNumberTool: ExecutableTool {
    public let name = "randomNumber"
    public let description = "Generates a random integer between a minimum and maximum value."

    public let parameters: JSONSchema = .object(
        requiredProperties: [
            "min": .integer(minimum: nil, maximum: nil, description: "Minimum value (inclusive)"),
            "max": .integer(minimum: nil, maximum: nil, description: "Maximum value (inclusive)")
        ],
        optionalProperties: [:],
        description: "Parameters for generating a random number."
    )

    public func execute(arguments: JSONValue) async throws -> JSONValue {
        let args = try arguments.decoded([String: Int].self)
        let min = args["min"]!
        let max = args["max"]!
        let number = Int.random(in: min ... max)
        return .object(["number": .number(Double(number))])
    }
}
