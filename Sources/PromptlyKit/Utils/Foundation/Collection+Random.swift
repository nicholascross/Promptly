import Foundation

extension Collection where Index == Int {
    func randomElements(_ count: Int) -> [Element] {
        (0 ..< count)
            .map { Int.random(in: $0 ..< self.count) }
            .sorted()
            .map { self[$0] }
    }
}
