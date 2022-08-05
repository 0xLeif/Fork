public struct ForkedActor<Value: Actor> {
    public var actor: Value
    public var fork: Fork<Value, Value>
    
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
