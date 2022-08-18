extension Array {
    /// Create a ``ForkedArray`` from the current `Array`
    public func fork<Output>(
        filter: @escaping (Element) async throws -> Bool = { _ in true },
        output: @escaping (Element) async throws -> Output
    ) -> ForkedArray<Element, Output> {
        ForkedArray(
            self,
            filter: filter,
            output: output
        )
    }
}
