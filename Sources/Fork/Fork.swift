/// Implementation of the [Identity function](https://en.wikipedia.org/wiki/Identity_function)
@Sendable 
public func identity<Value: Sendable>(_ value: Value) -> Value { value }

/// # [Fork](https://en.wikipedia.org/wiki/Fork_(software_development)#Etymology)
///
/// Using a single input create two separate async functions that return `LeftOutput` and `RightOutput`.
///
public struct Fork<LeftOutput: Sendable, RightOutput: Sendable>: Sendable {

    /// The left async function of the Fork
    public let left: @Sendable () async throws -> LeftOutput

    /// The right async function of the Fork
    public let right: @Sendable () async throws -> RightOutput

    /// Create a ``Fork`` using a single `Value` that is mapped for the left and right output functions.
    /// - Parameters:
    ///   - value: The value to be passed into the map functions
    ///   - leftInputMap: Maps the `Value` into `LeftInput`
    ///   - rightInputMap: Maps the `Value` into `RightInput`
    ///   - leftOutput: An `async` closure that uses `LeftInput` to return `LeftOutput`
    ///   - rightOutput: An `async` closure that uses `RightInput` to return `RightOutput`
    public init<Value, LeftInput, RightInput>(
        value: @Sendable @escaping () async throws -> Value,
        leftInputMap: @Sendable @escaping (Value) throws -> LeftInput,
        rightInputMap: @Sendable @escaping (Value) throws -> RightInput,
        leftOutput: @Sendable @escaping (LeftInput) async throws -> LeftOutput,
        rightOutput: @Sendable @escaping (RightInput) async throws -> RightOutput
    ) {
        left = { try await leftOutput(try leftInputMap(value())) }
        right = { try await rightOutput(try rightInputMap(value())) }
    }
    
    /// Combine the `LeftOutput` and `RightOutput` into a single `Output`
    ///
    /// - Returns: An `async` closure that returns the `Output` of the Fork's left and right paths
    public func merge<Output>(
        using: @escaping (LeftOutput, RightOutput) async throws -> Output
    ) -> () async throws -> Output {
        {
            try await Task.withCheckedCancellation {
                async let leftOutput = try left()
                async let rightOutput = try right()
                
                return try await using(leftOutput, rightOutput)
            }
        }
    }
}

extension Fork {
    /// Create a ``Fork`` using a single `Value` that is mapped for the left and right output functions.
    /// - Parameters:
    ///   - value: The value to be passed into the map functions
    ///   - leftInputMap: Maps the `Value` into `LeftInput`
    ///   - rightInputMap: Maps the `Value` into `RightInput`
    ///   - leftOutput: An `async` closure that uses `LeftInput` to return `LeftOutput`
    ///   - rightOutput: An `async` closure that uses `RightInput` to return `RightOutput`
    public init<Value: Sendable, LeftInput: Sendable, RightInput: Sendable>(
        value: Value,
        leftInputMap: @Sendable @escaping (Value) throws -> LeftInput,
        rightInputMap: @Sendable @escaping (Value) throws -> RightInput,
        leftOutput: @Sendable @escaping (LeftInput) async throws -> LeftOutput,
        rightOutput: @Sendable @escaping (RightInput) async throws -> RightOutput
    ) {
        self.init(
            value: { value },
            leftInputMap: leftInputMap,
            rightInputMap: rightInputMap,
            leftOutput: leftOutput,
            rightOutput: rightOutput
        )
    }
    
    /// Create a ``Fork`` using a single `Value` that is passed into the left and right output functions.
    /// - Parameters:
    ///   - value: The value to be passed into the map functions
    ///   - leftOutput: An `async` closure that uses `LeftInput` to return `LeftOutput`
    ///   - rightOutput: An `async` closure that uses `RightInput` to return `RightOutput`
    public init<Value: Sendable>(
        value: Value,
        leftOutput: @Sendable @escaping (Value) async throws -> LeftOutput,
        rightOutput: @Sendable @escaping (Value) async throws -> RightOutput
    ) {
        self.init(
            value: value,
            leftInputMap: identity,
            rightInputMap: identity,
            leftOutput: leftOutput,
            rightOutput: rightOutput
        )
    }
    
    /// Create a ``Fork`` using two `async` functions
    /// - Parameters:
    ///   - leftOutput: An `async` closure that returns `LeftOutput`
    ///   - rightOutput: An `async` closure that returns `RightOutput`
    public init(
        leftOutput: @Sendable @escaping () async throws -> LeftOutput,
        rightOutput: @Sendable @escaping () async throws -> RightOutput
    ) {
        self.init(
            value: (),
            leftInputMap: identity,
            rightInputMap: identity,
            leftOutput: leftOutput,
            rightOutput: rightOutput
        )
    }
    
    /// Create a ``Fork`` using a single `Value` that is passed into the left and right output functions.
    /// - Parameters:
    ///   - value: The value to be passed into the map functions
    ///   - leftOutput: An `async` closure that uses `LeftInput` to return `LeftOutput`
    ///   - rightOutput: An `async` closure that uses `RightInput` to return `RightOutput`
    public init<Value: Sendable>(
        value: @Sendable @escaping () async throws -> Value,
        leftOutput: @Sendable @escaping (Value) async throws -> LeftOutput,
        rightOutput: @Sendable @escaping (Value) async throws -> RightOutput
    ) {
        self.init(
            value: value,
            leftInputMap: identity,
            rightInputMap: identity,
            leftOutput: leftOutput,
            rightOutput: rightOutput
        )
    }
    
    /// Merge the ``Fork`` and combine the `LeftOutput` and `RightOutput` into a single `Output`
    ///
    /// - Returns: The `Output` of the Fork's left and right paths
    public func merged<Output: Sendable>(
        using: @Sendable @escaping (LeftOutput, RightOutput) async throws -> Output
    ) async throws -> Output {
        try await merge(using: using)()
    }
    
    /// Merge the ``Fork`` and return Void when `LeftOutput` and `RightOutput` are both Void
    public func merged() async throws where LeftOutput == Void, RightOutput == Void {
        try await merged(using: { _, _ in () })
    }

    /// Merge the ``Fork`` and return the `RightOutput` when `LeftOutput` is Void
    public func merged() async throws -> RightOutput where LeftOutput == Void {
        try await merged(using: { _, output in output })
    }

    /// Merge the ``Fork`` and return the `LeftOutput` when `RightOutput` is Void
    public func merged() async throws -> LeftOutput where RightOutput == Void {
        try await merged(using: { output, _ in output })
    }
}
