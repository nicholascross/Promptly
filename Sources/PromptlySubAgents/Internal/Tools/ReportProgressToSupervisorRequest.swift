struct ReportProgressToSupervisorRequest: Decodable, Sendable {
    let status: String?
    let summary: String?
    let currentStep: String?
    let percentComplete: Double?
    let blockers: [String]?
}
