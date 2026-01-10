import ArgumentParser
import PromptlySelfTest

enum SelfTestHandoffStrategySelection: ExpressibleByArgument {
    case automatic
    case contextPack
    case forkedContext

    init?(argument: String) {
        switch argument.lowercased() {
        case "automatic":
            self = .automatic
        case "contextpack", "context-pack":
            self = .contextPack
        case "forkedcontext", "forked-context":
            self = .forkedContext
        default:
            return nil
        }
    }

    var selfTestValue: SelfTestHandoffStrategy {
        switch self {
        case .automatic:
            return .automatic
        case .contextPack:
            return .contextPack
        case .forkedContext:
            return .forkedContext
        }
    }
}
