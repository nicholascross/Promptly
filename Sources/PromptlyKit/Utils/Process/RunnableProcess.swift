import Foundation

protocol RunnableProcess {
    func run(
        executable: String,
        arguments: [String],
        currentDirectoryURL: URL?,
        streamOutput: Bool
    ) throws -> (exitCode: Int32, output: String)
}
