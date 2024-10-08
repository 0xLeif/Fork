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
    
    /// Returns an array containing the results of mapping the given closure over the sequence’s elements.
    public func asyncMap<Output: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await fork(map: transform).output()
    }
    
    /// Returns an array containing the results, that aren't nil, of mapping the given closure over the sequence’s elements.
    public func asyncCompactMap<Output: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> Output?
    ) async throws -> [Output] {
        try await fork(map: transform).output().compactMap { $0 }
    }
    
    /// Returns an array containing only the true results from the given closure over the sequence’s elements.
    public func asyncFilter(
        _ isIncluded: @Sendable @escaping (Element) async throws -> Bool
    ) async throws -> [Element] {
        try await fork(filter: isIncluded, map: identity).output()
    }
    
    /// Calls the given closure for each of the elements in the Sequence. This function uses ``ForkedArray`` and will be parallelized when possible.
    public func asyncForEach(
        _ transform: @Sendable @escaping (Element) async throws -> Void
    ) async throws {
        _ = try await asyncMap(transform)
    }
}
