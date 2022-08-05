/// Using a single actor create two separate async functions that are passed the actor.
public struct ForkedActor<Value: Actor> {
    
    /// The `Actor` used for the fork
    public var actor: Value
    
    /// A ``Fork`` that only uses the actor `Value`
    public var fork: Fork<Value, Value>
    
    /// Create a ``ForkedActor`` using a single `actor` that is passed into the left and right async functions.
    /// - Parameters:
    ///   - actor: The `actor` to be passed into the map functions
    ///   - leftOutput: An `async` closure that uses the `actor` as its input
    ///   - rightOutput: An `async` closure that uses the `actor` as its input
    public init(
        actor: Value,
        leftOutput: @escaping (_ actor: Value) async throws -> Void,
        rightOutput: @escaping (_ actor: Value) async throws -> Void
    ) {
        self.actor = actor
        self.fork = Fork(
            value: actor,
            leftOutput: { actor in
                try await leftOutput(actor)
                
                return actor
            },
            rightOutput: { actor in
                try await rightOutput(actor)
                
                return actor
            }
        )
    }
    
    /// Asynchronously resolve the fork using the actor
    public func act() async throws {
        try Task.checkCancellation()
        
        async let leftForkedTask = fork.left()
        async let rightForkedTask = fork.right()
        
        try Task.checkCancellation()
        
        _ = try await [leftForkedTask, rightForkedTask]
        
        try Task.checkCancellation()
    }
}

public extension Actor {
    /// Create a ``ForkedActor`` from the current `Actor`
    func fork(
        leftOutput: @escaping (_ actor: Self) async throws -> Void,
        rightOutput: @escaping (_ actor: Self) async throws -> Void
    ) -> ForkedActor<Self> {
        ForkedActor(
            actor: self,
            leftOutput: leftOutput,
            rightOutput: rightOutput
        )
    }
}
