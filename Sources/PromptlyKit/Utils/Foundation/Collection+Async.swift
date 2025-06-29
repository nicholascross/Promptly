import Foundation

extension Collection where Element: Sendable {

    func asyncFlatMap<T: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> [T]
    ) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: (Int, [T]).self) { group in
            let count = self.count
            for (index, element) in self.enumerated() {
                group.addTask {
                    (index, try await transform(element))
                }
            }
            var results = Array<[T]>(repeating: [], count: count)
            for try await (index, elementResults) in group {
                results[index] = elementResults
            }
            return results.flatMap { $0 }
        }
    }

    func asyncMap<T: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> T
    ) async rethrows -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            let count = self.count
            for (index, element) in self.enumerated() {
                group.addTask {
                    (index, try await transform(element))
                }
            }
            var results = Array<T?>(repeating: nil, count: count)
            for try await (index, elementResult) in group {
                results[index] = elementResult
            }
            return results.compactMap { $0 }
        }
    }
}
