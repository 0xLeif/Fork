extension Sequence where Element: Sendable {
    /// Create a ``ForkedArray`` from the current `Sequence`
    public func fork<Output: Sendable>(
        filter: @Sendable @escaping (Element) async throws -> Bool,
        map: @Sendable @escaping (Element) async throws -> Output
    ) -> ForkedArray<Element, Output> {
        ForkedArray(
            Array(self),
            filter: filter,
            map: map
        )
    }
    
    /// Create a ``ForkedArray`` from the current `Sequence`
    public func fork<Output: Sendable>(
        map: @Sendable @escaping (Element) async throws -> Output
    ) -> ForkedArray<Element, Output> {
        fork(filter: { _ in true }, map: map)
    }
    
    /// Create a ``ForkedArray`` from the current `Sequence` and get the Output Array
    public func forked<Output: Sendable>(
        filter: @Sendable @escaping (Element) async throws -> Bool,
        map: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await fork(filter: filter, map: map).output()
    }
    
    /// Create a ``ForkedArray`` from the current `Sequence` and get the Output Array
    public func forked<Output: Sendable>(
        map: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await forked(filter: { _ in true }, map: map)
    }
    
    /// Concurrently returns an array containing the results of mapping the given closure over the sequence's elements. Each element is processed in parallel using a ``ForkedArray``.
    public func concurrentMap<Output: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await fork(map: transform).output()
    }
    
    /// Concurrently returns an array containing the non-nil results of mapping the given closure over the sequence's elements. Each element is processed in parallel using a ``ForkedArray``.
    public func concurrentCompactMap<Output: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> Output?
    ) async throws -> [Output] {
        try await fork(map: transform).output().compactMap { $0 }
    }
    
    /// Concurrently filters the sequence's elements using the given closure. Each element is evaluated in parallel using a ``ForkedArray``.
    public func concurrentFilter(
        _ isIncluded: @Sendable @escaping (Element) async throws -> Bool
    ) async throws -> [Element] {
        try await fork(filter: isIncluded, map: identity).output()
    }
    
    /// Concurrently calls the given closure for each element in the sequence. Each element is processed in parallel using a task group.
    public func concurrentForEach(
        _ transform: @Sendable @escaping (Element) async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask { try await transform(element) }
            }
            try await group.waitForAll()
        }
    }

    // MARK: - Deprecated Aliases

    @available(*, deprecated, renamed: "concurrentMap")
    public func asyncMap<Output: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await concurrentMap(transform)
    }

    @available(*, deprecated, renamed: "concurrentCompactMap")
    public func asyncCompactMap<Output: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> Output?
    ) async throws -> [Output] {
        try await concurrentCompactMap(transform)
    }

    @available(*, deprecated, renamed: "concurrentFilter")
    public func asyncFilter(
        _ isIncluded: @Sendable @escaping (Element) async throws -> Bool
    ) async throws -> [Element] {
        try await concurrentFilter(isIncluded)
    }

    @available(*, deprecated, renamed: "concurrentForEach")
    public func asyncForEach(
        _ transform: @Sendable @escaping (Element) async throws -> Void
    ) async throws {
        try await concurrentForEach(transform)
    }
}
