/// Using a single actor create two separate async functions that are passed the actor.
public struct ForkedActor<Value: Actor>: Sendable {

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
        leftOutput: @Sendable @escaping (_ actor: Value) async throws -> Void,
        rightOutput: @Sendable @escaping (_ actor: Value) async throws -> Void
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
    @discardableResult
    public func act() async throws -> Value {
        try await fork.merged { _, _ in
            actor
        }
    }
}

extension ForkedActor {
    /// Create a ``ForkedActor`` using a single value that is passed into the left and right async functions.
    /// - Parameters:
    ///   - value: Any value to be passed into the map functions. This value is wrapped into an `actor` using ``KeyPathActor``.
    ///   - leftOutput: An `async` closure that uses the `actor` as its input
    ///   - rightOutput: An `async` closure that uses the `actor` as its input
    public init<Input: Sendable>(
        value: Input,
        leftOutput: @Sendable @escaping (_ actor: Value) async throws -> Void,
        rightOutput: @Sendable @escaping (_ actor: Value) async throws -> Void
    ) where Value == KeyPathActor<Input> {
        self.init(
            actor: KeyPathActor(value: value),
            leftOutput: leftOutput,
            rightOutput: rightOutput
        )
    }
}
