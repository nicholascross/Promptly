import Foundation

extension Collection where Element: Sendable {
    func asyncFlatMap<T: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> [T]
    ) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: [T].self) { group in
            for element in self {
                group.addTask {
                    try await transform(element)
                }
            }
            var results: [T] = []
            for try await result in group {
                results.append(contentsOf: result)
            }
            return results
        }
    }

    func asyncMap<T: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> T
    ) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: T.self) { group in
            for element in self {
                group.addTask {
                    try await transform(element)
                }
            }
            var results: [T] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
}
