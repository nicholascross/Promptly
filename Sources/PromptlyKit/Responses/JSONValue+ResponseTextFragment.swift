import Foundation

extension JSONValue {
    var textFragment: String? {
        switch self {
        case .string(let text):
            return text
        case .object(let object):
            if let value = object["text"], let fragment = value.textFragment {
                return fragment
            }
            if let value = object["delta"], let fragment = value.textFragment {
                return fragment
            }
            if let value = object["content"], let fragment = value.textFragment {
                return fragment
            }
            return nil
        case .array(let values):
            let fragments = values.compactMap { $0.textFragment }
            guard !fragments.isEmpty else { return nil }
            return fragments.joined()
        default:
            return nil
        }
    }
}
