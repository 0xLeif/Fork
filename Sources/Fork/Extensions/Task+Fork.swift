extension Task where Success == Never, Failure == Never {
    /// Run the async throwing task while checking for cancellation before and after.
    @discardableResult
    public static func withCheckedCancellation<Output>(
        task: () async throws -> Output
    ) async throws -> Output {
        try checkCancellation()
        let output = try await task()
        try checkCancellation()
        
        return output
    }
}
