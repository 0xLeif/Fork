extension Array {
    /// Create a ``ForkedArray`` from the current `Array`
    public func fork<Output>(
        filter: @escaping (Element) async throws -> Bool = { _ in true },
        map: @escaping (Element) async throws -> Output
    ) -> ForkedArray<Element, Output> {
        ForkedArray(
            self,
            filter: filter,
            map: map
        )
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
}
