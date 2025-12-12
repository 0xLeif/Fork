import Foundation

// MARK: - Test Timeout Helper

struct TestTimeoutError: Error, CustomStringConvertible {
    let seconds: TimeInterval
    var description: String { "Test timed out after \(seconds) seconds" }
}

func withTestTimeout<T: Sendable>(
    seconds: TimeInterval = 30,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TestTimeoutError(seconds: seconds)
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
