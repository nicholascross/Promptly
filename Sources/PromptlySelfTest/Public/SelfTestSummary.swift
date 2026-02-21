import Foundation

public struct SelfTestSummary: Codable, Sendable {
    public let level: SelfTestLevel
    public let status: SelfTestStatus
    public let passedCount: Int
    public let failedCount: Int
    public let results: [SelfTestResult]

    public init(level: SelfTestLevel, results: [SelfTestResult]) {
        self.level = level
        self.results = results
        let passedCount = results.filter { $0.status == .passed }.count
        let failedCount = results.filter { $0.status == .failed }.count
        self.passedCount = passedCount
        self.failedCount = failedCount
        self.status = failedCount == 0 ? .passed : .failed
    }
}
