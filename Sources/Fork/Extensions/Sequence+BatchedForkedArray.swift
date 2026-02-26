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

    /// Concurrently returns an array containing the results of mapping the given closure over the sequence's elements in batches. Each batch is processed in parallel using a ``BatchedForkedArray``.
    public func concurrentMap<Output: Sendable>(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await fork(batch: batch, map: transform).output()
    }

    /// Concurrently returns an array containing the non-nil results of mapping the given closure over the sequence's elements in batches. Each batch is processed in parallel using a ``BatchedForkedArray``.
    public func concurrentCompactMap<Output: Sendable>(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Output?
    ) async throws -> [Output] {
        try await fork(batch: batch, map: transform).output().compactMap { $0 }
    }

    /// Concurrently filters the sequence's elements in batches using the given closure. Each batch is evaluated in parallel using a ``BatchedForkedArray``.
    public func concurrentFilter(
        batch: UInt,
        _ isIncluded: @Sendable @escaping (Element) async throws -> Bool
    ) async throws -> [Element] {
        try await fork(batch: batch, filter: isIncluded, map: identity).output()
    }

    /// Concurrently calls the given closure for each element in the sequence in batches. Each batch is processed in parallel using a ``BatchedForkedArray``.
    public func concurrentForEach(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Void
    ) async throws {
        _ = try await concurrentMap(batch: batch, transform)
    }
}

// MARK: - Deprecated Aliases

extension Sequence where Element: Sendable {
    @available(*, deprecated, renamed: "concurrentMap")
    public func asyncMap<Output: Sendable>(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await concurrentMap(batch: batch, transform)
    }

    @available(*, deprecated, renamed: "concurrentCompactMap")
    public func asyncCompactMap<Output: Sendable>(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Output?
    ) async throws -> [Output] {
        try await concurrentCompactMap(batch: batch, transform)
    }

    @available(*, deprecated, renamed: "concurrentFilter")
    public func asyncFilter(
        batch: UInt,
        _ isIncluded: @Sendable @escaping (Element) async throws -> Bool
    ) async throws -> [Element] {
        try await concurrentFilter(batch: batch, isIncluded)
    }

    @available(*, deprecated, renamed: "concurrentForEach")
    public func asyncForEach(
        batch: UInt,
        _ transform: @Sendable @escaping (Element) async throws -> Void
    ) async throws {
        try await concurrentForEach(batch: batch, transform)
    }
}
