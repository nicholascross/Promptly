import Foundation

public enum ToolFactory {
    public static func makeTools() -> [any ExecutableTool] {
        [RandomNumberTool()]
    }
}

private struct RandomNumberTool: ExecutableTool {
    public let name = "randomNumber"
    public let description = "Generates a random integer between a minimum and maximum value."
    public let parameters: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "min": .object([
                "type": .string("integer"),
                "description": .string("Minimum value (inclusive)")
            ]),
            "max": .object([
                "type": .string("integer"),
                "description": .string("Maximum value (inclusive)")
            ])
        ]),
        "required": .array([.string("min"), .string("max")])
    ])

    public func execute(arguments: JSONValue) async throws -> JSONValue {
        let args = try arguments.decoded([String: Int].self)
        let min = args["min"]!
        let max = args["max"]!
        let number = Int.random(in: min ... max)
        return .object(["number": .number(Double(number))])
    }
}
