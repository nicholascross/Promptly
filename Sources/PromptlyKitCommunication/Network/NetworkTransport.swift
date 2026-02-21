import Foundation

public protocol NetworkTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func lineStream(for request: URLRequest) async throws -> (AsyncThrowingStream<String, Error>, URLResponse)
}
