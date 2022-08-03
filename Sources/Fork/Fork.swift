/// Implementation of the [Identity function](https://en.wikipedia.org/wiki/Identity_function)
public func identity<Value>(_ value: Value) -> Value { value }

/// # [Fork](https://en.wikipedia.org/wiki/Fork_(software_development)#Etymology)
///
/// Using a single input create two separate async functions that return `LeftOutput` and `RightOutput`.
///
public struct Fork<LeftOutput, RightOutput> {
    
    /// The left async function of the Fork
    public let left: () async throws -> LeftOutput
    
    /// The right async function of the Fork
    public let right: () async throws -> RightOutput
    
    /// Create a ``Fork`` using a single `Value` that is mapped for the left and right output function.
    /// - Parameters:
    ///   - value: The value to be passed into the map functions
    ///   - leftInputMap: Maps the `Value` into `LeftInput`
    ///   - rightInputMap: Maps the `Value` into `RightInput`
    ///   - leftOutput: An `async` closure that uses `LeftInput` to return `LeftOutput`
    ///   - rightOutput: An `async` closure that uses `RightInput` to return `RightOutput`
    public init<Value, LeftInput, RightInput>(
        value: Value,
        leftInputMap: @escaping (Value) throws -> LeftInput,
        rightInputMap: @escaping (Value) throws -> RightInput,
        leftOutput: @escaping (LeftInput) async throws -> LeftOutput,
        rightOutput: @escaping (RightInput) async throws -> RightOutput
    ) {
        left = { try await leftOutput(try leftInputMap(value)) }
        right = { try await rightOutput(try rightInputMap(value)) }
    }
    
    /// Create a ``Fork`` using a single `Value` that is mapped for the left and right output function.
    /// - Parameters:
    ///   - value: The value to be passed into the map functions
    ///   - leftInputMap: Maps the `Value` into `LeftInput`
    ///   - rightInputMap: Maps the `Value` into `RightInput`
    ///   - leftOutput: An `async` closure that uses `LeftInput` to return `LeftOutput`
    ///   - rightOutput: An `async` closure that uses `RightInput` to return `RightOutput`
    public init<Value, LeftInput, RightInput>(
        value: @escaping () -> Value,
        leftInputMap: @escaping (Value) throws -> LeftInput,
        rightInputMap: @escaping (Value) throws -> RightInput,
        leftOutput: @escaping (LeftInput) async throws -> LeftOutput,
        rightOutput: @escaping (RightInput) async throws -> RightOutput
    ) {
        left = { try await leftOutput(try leftInputMap(value())) }
        right = { try await rightOutput(try rightInputMap(value())) }
    }
    
    /// Create a ``Fork`` using a single `Value` that is passed into the left and right output function.
    /// - Parameters:
    ///   - value: The value to be passed into the map functions
    ///   - leftOutput: An `async` closure that uses `LeftInput` to return `LeftOutput`
    ///   - rightOutput: An `async` closure that uses `RightInput` to return `RightOutput`
    public init<Value>(
        value: Value,
        leftOutput: @escaping (Value) async throws -> LeftOutput,
        rightOutput: @escaping (Value) async throws -> RightOutput
    ) {
        self.init(
            value: value,
            leftInputMap: identity,
            rightInputMap: identity,
            leftOutput: leftOutput,
            rightOutput: rightOutput
        )
    }
    
    /// Create a ``Fork`` using a single `Value` that is passed into the left and right output function.
    /// - Parameters:
    ///   - value: The value to be passed into the map functions
    ///   - leftOutput: An `async` closure that uses `LeftInput` to return `LeftOutput`
    ///   - rightOutput: An `async` closure that uses `RightInput` to return `RightOutput`
    public init<Value>(
        value: @escaping () -> Value,
        leftOutput: @escaping (Value) async throws -> LeftOutput,
        rightOutput: @escaping (Value) async throws -> RightOutput
    ) {
        self.init(
            value: value,
            leftInputMap: identity,
            rightInputMap: identity,
            leftOutput: leftOutput,
            rightOutput: rightOutput
        )
    }
    
    /// Combine the `LeftOutput` and `RightOutput` into a single `Output`
    ///
    /// - Returns: An `async` closure that returns the `Output` of the Fork's left and right paths
    public func merge<Output>(
        using: @escaping (LeftOutput, RightOutput) -> Output
    ) -> () async throws -> Output {
        { using(try await left(), try await right()) }
    }
    
    /// Combine the `LeftOutput` and `RightOutput` into a single `Output`
    ///
    /// - Returns: The `Output` of the Fork's left and right paths
    public func merged<Output>(
        using: @escaping (LeftOutput, RightOutput) -> Output
    ) async throws -> Output {
        using(try await left(), try await right())
    }
}
