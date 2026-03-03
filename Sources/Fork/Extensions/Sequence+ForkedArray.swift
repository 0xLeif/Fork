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

    /// Concurrently maps the given closure over the sequence's elements, returning an array of results.
    public func concurrentMap<Output: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await fork(map: transform).output()
    }

    /// Concurrently maps the given closure over the sequence's elements, returning an array of non-nil results.
    public func concurrentCompactMap<Output: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> Output?
    ) async throws -> [Output] {
        try await fork(map: transform).output().compactMap { $0 }
    }

    /// Concurrently filters the sequence's elements using the given closure.
    public func concurrentFilter(
        _ isIncluded: @Sendable @escaping (Element) async throws -> Bool
    ) async throws -> [Element] {
        try await fork(filter: isIncluded, map: identity).output()
    }

    /// Concurrently calls the given closure for each element in the sequence.
    public func concurrentForEach(
        _ transform: @Sendable @escaping (Element) async throws -> Void
    ) async throws {
        _ = try await concurrentMap(transform)
    }

    // MARK: - Deprecated

    /// Returns an array containing the results of mapping the given closure over the sequence's elements.
    @available(*, deprecated, renamed: "concurrentMap")
    public func asyncMap<Output: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await concurrentMap(transform)
    }

    /// Returns an array containing the results, that aren't nil, of mapping the given closure over the sequence's elements.
    @available(*, deprecated, renamed: "concurrentCompactMap")
    public func asyncCompactMap<Output: Sendable>(
        _ transform: @Sendable @escaping (Element) async throws -> Output?
    ) async throws -> [Output] {
        try await concurrentCompactMap(transform)
    }

    /// Returns an array containing only the true results from the given closure over the sequence's elements.
    @available(*, deprecated, renamed: "concurrentFilter")
    public func asyncFilter(
        _ isIncluded: @Sendable @escaping (Element) async throws -> Bool
    ) async throws -> [Element] {
        try await concurrentFilter(isIncluded)
    }

    /// Calls the given closure for each of the elements in the Sequence. This function uses ``ForkedArray`` and will be parallelized when possible.
    @available(*, deprecated, renamed: "concurrentForEach")
    public func asyncForEach(
        _ transform: @Sendable @escaping (Element) async throws -> Void
    ) async throws {
        try await concurrentForEach(transform)
    }
}
