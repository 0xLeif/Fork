extension Sequence where Element: Sendable {
    /// Create a ``BatchedForkedArray`` from the current `Sequence`
    public func fork<Output: Sendable>(
        batch: UInt,
        filter: @Sendable @escaping (Element) async throws -> Bool,
        map: @Sendable @escaping (Element) async throws -> Output
    ) -> BatchedForkedArray<Element, Output> {
        BatchedForkedArray(
            Array(self),
            batch: batch,
            filter: filter,
            map: map
        )
    }

    /// Create a ``BatchedForkedArray`` from the current `Sequence`
    public func fork<Output: Sendable>(
        batch: UInt,
        map: @Sendable @escaping (Element) async throws -> Output
    ) -> BatchedForkedArray<Element, Output> {
        fork(batch: batch, filter: { _ in true }, map: map)
    }

    /// Create a ``BatchedForkedArray`` from the current `Sequence` and get the Output Array
    public func forked<Output: Sendable>(
        batch: UInt,
        filter: @Sendable @escaping (Element) async throws -> Bool,
        map: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await fork(batch: batch, filter: filter, map: map).output()
    }

    /// Create a ``BatchedForkedArray`` from the current `Sequence` and get the Output Array
    public func forked<Output: Sendable>(
        batch: UInt,
        map: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await forked(batch: batch, filter: { _ in true }, map: map)
    }

    /// Concurrently maps the given closure over the sequence's elements in batches, returning an array of results.
    public func concurrentMap<Output: Sendable>(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await fork(batch: batch, map: transform).output()
    }

    /// Concurrently maps the given closure over the sequence's elements in batches, returning an array of non-nil results.
    public func concurrentCompactMap<Output: Sendable>(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Output?
    ) async throws -> [Output] {
        try await fork(batch: batch, map: transform).output().compactMap { $0 }
    }

    /// Concurrently filters the sequence's elements in batches using the given closure.
    public func concurrentFilter(
        batch: UInt,
        _ isIncluded: @Sendable @escaping (Element) async throws -> Bool
    ) async throws -> [Element] {
        try await fork(batch: batch, filter: isIncluded, map: identity).output()
    }

    /// Concurrently calls the given closure for each element in the sequence, processing in batches.
    public func concurrentForEach(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Void
    ) async throws {
        _ = try await concurrentMap(batch: batch, transform)
    }

    // MARK: - Deprecated

    /// Returns an array containing the results of mapping the given closure over the sequence's elements.
    @available(*, deprecated, renamed: "concurrentMap(batch:_:)")
    public func asyncMap<Output: Sendable>(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await concurrentMap(batch: batch, transform)
    }

    /// Returns an array containing the results, that aren't nil, of mapping the given closure over the sequence's elements.
    @available(*, deprecated, renamed: "concurrentCompactMap(batch:_:)")
    public func asyncCompactMap<Output: Sendable>(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Output?
    ) async throws -> [Output] {
        try await concurrentCompactMap(batch: batch, transform)
    }

    /// Returns an array containing only the true results from the given closure over the sequence's elements.
    @available(*, deprecated, renamed: "concurrentFilter(batch:_:)")
    public func asyncFilter(
        batch: UInt,
        _ isIncluded: @Sendable @escaping (Element) async throws -> Bool
    ) async throws -> [Element] {
        try await concurrentFilter(batch: batch, isIncluded)
    }

    /// Calls the given closure for each of the elements in the Sequence. This function uses ``BatchedForkedArray`` and will be parallelized when possible.
    @available(*, deprecated, renamed: "concurrentForEach(batch:_:)")
    public func asyncForEach(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Void
    ) async throws {
        try await concurrentForEach(batch: batch, transform)
    }
}
