extension Array {
    /// Create a ``ForkedArray`` from the current `Array`
    public func fork<Output>(
        filter: @escaping (Element) async throws -> Bool,
        map: @escaping (Element) async throws -> Output
    ) -> ForkedArray<Element, Output> {
        ForkedArray(
            self,
            filter: filter,
            map: map
        )
    }
    
    /// Create a ``ForkedArray`` from the current `Array`
    public func fork<Output>(
        map: @escaping (Element) async throws -> Output
    ) -> ForkedArray<Element, Output> {
        fork(filter: { _ in true }, map: map)
    }
    
    /// Create a ``ForkedArray`` from the current `Array` and get the Output Array
    public func forked<Output>(
        filter: @escaping (Element) async throws -> Bool,
        map: @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await ForkedArray(
            self,
            filter: filter,
            map: map
        )
        .output()
    }
    
    /// Create a ``ForkedArray`` from the current `Array` and get the Output Array
    public func forked<Output>(
        map: @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await forked(filter: { _ in true }, map: map)
    }
    
    /// Returns an array containing the results of mapping the given closure over the sequence’s elements.
    public func asyncMap<Output>(
        _ transform: @escaping (Element) async throws -> Output
    ) async throws -> [Output] {
        try await fork(map: transform).output()
    }
    
    /// Returns an array containing only the true results from the given closure over the sequence’s elements.
    public func asyncFilter(
        _ isIncluded: @escaping (Element) async throws -> Bool
    ) async throws -> [Element] {
        try await fork(filter: isIncluded, map: identity).output()
    }
    
    /// Calls the given closure for each of the elements in the Array. This function uses ``ForkedArray`` and will be parallelized when possible.
    public func asyncForEach(
        _ transform: @escaping (Element) async throws -> Void
    ) async throws {
        _ = try await asyncMap(transform)
    }
}
