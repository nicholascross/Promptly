import PromptlyKitUtils

func objectValue(_ value: JSONValue?) -> [String: JSONValue]? {
    guard case let .object(object) = value else {
        return nil
    }
    return object
}

func stringValue(_ value: JSONValue?) -> String? {
    guard case let .string(text) = value else {
        return nil
    }
    return text
}
