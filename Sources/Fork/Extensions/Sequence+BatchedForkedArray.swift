extension Sequence {
    /// Create a ``BatchedForkedArray`` from the current `Sequence`
    public func batchedFork<Output>(
        batch: UInt,
        filter: @escaping (Element) async throws -> Bool,
        map: @escaping (Element) async throws -> Output
    ) -> BatchedForkedArray<Element, Output> {
        BatchedForkedArray(
            Array(self),
            batch: batch,
            filter: filter,
            map: map
        )
    }

    /// Create a ``BatchedForkedArray`` from the current `Sequence`
    public func batchedFork<Output>(
        batch: UInt,
        map: @escaping (Element) async throws -> Output
    ) -> BatchedForkedArray<Element, Output> {
        batchedFork(batch: batch, filter: { _ in true }, map: map)
    }

    /// Create a ``BatchedForkedArray`` from the current `Sequence` and get the Output Array
    public func batchedForked<Output>(
        batch: UInt,
        filter: @escaping (Element) async throws -> Bool,
        map: @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await fork(filter: filter, map: map).output()
    }

    /// Create a ``BatchedForkedArray`` from the current `Sequence` and get the Output Array
    public func batchedForked<Output>(
        batch: UInt,
        map: @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await batchedForked(batch: batch, filter: { _ in true }, map: map)
    }

    /// Returns an array containing the results of mapping the given closure over the sequence’s elements.
    public func asyncBatchedMap<Output>(
        batch: UInt,
        _ transform: @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await batchedFork(batch: batch, map: transform).output()
    }

    /// Returns an array containing the results, that aren't nil, of mapping the given closure over the sequence’s elements.
    public func asyncBatchedCompactMap<Output>(
        batch: UInt,
        _ transform: @escaping (Element) async throws -> Output?
    ) async throws -> [Output] {
        try await batchedFork(batch: batch, map: transform).output().compactMap { $0 }
    }

    /// Returns an array containing only the true results from the given closure over the sequence’s elements.
    public func asyncBatchedFilter(
        batch: UInt,
        _ isIncluded: @escaping (Element) async throws -> Bool
    ) async throws -> [Element] {
        try await batchedFork(batch: batch, filter: isIncluded, map: identity).output()
    }

    /// Calls the given closure for each of the elements in the Sequence. This function uses ``BatchedForkedArray`` and will be parallelized when possible.
    public func asyncBatchedForEach(
        batch: UInt,
        _ transform: @escaping (Element) async throws -> Void
    ) async throws {
        _ = try await asyncBatchedMap(batch: batch, transform)
    }
}
