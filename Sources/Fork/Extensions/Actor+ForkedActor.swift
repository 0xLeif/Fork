extension Actor {
    /// Create a ``ForkedActor`` from the current `Actor`
    public func fork(
        leftOutput: @Sendable @escaping (_ actor: Self) async throws -> Void,
        rightOutput: @Sendable @escaping (_ actor: Self) async throws -> Void
    ) -> ForkedActor<Self> {
        ForkedActor(
            actor: self,
            leftOutput: leftOutput,
            rightOutput: rightOutput
        )
    }
}
