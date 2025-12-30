import ArgumentParser

struct SelfTestOptions: ParsableArguments {
    @Option(
        name: [.customShort("c"), .customLong("config-file")],
        help: "Override the default configuration file path of ~/.config/promptly/config.json."
    )
    var configurationFile: String = "~/.config/promptly/config.json"

    @Option(
        name: .customLong("tools"),
        help: "Override the default shell command tools configuration basename (without .json)."
    )
    var toolsFileName: String = "tools"

    @Option(
        name: .customLong("api"),
        help: "Select backend API (responses or chat). Overrides configuration."
    )
    var apiSelection: APISelection?
}
