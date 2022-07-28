/// Implementation of the [Identity function](https://en.wikipedia.org/wiki/Identity_function)
public func identity<Value>(_ value: Value) -> Value { value }

///
public struct Fork<LeftOutput, RightOutput> {
    
    ///
    public let left: () async -> LeftOutput
    
    ///
    public let right: () async -> RightOutput
    
    ///
    public init<Value, LeftInput, RightInput>(
        value: Value,
        leftInputMap: @escaping (Value) -> LeftInput,
        rightInputMap: @escaping (Value) -> RightInput,
        leftOutput: @escaping (LeftInput) async -> LeftOutput,
        rightOutput: @escaping (RightInput) async -> RightOutput
    ) {
        left = { await leftOutput(leftInputMap(value)) }
        right = { await rightOutput(rightInputMap(value)) }
    }
    
    ///
    public init<Value>(
        value: Value,
        leftOutput: @escaping (Value) async -> LeftOutput,
        rightOutput: @escaping (Value) async -> RightOutput
    ) {
        self.init(
            value: value,
            leftInputMap: identity,
            rightInputMap: identity,
            leftOutput: leftOutput,
            rightOutput: rightOutput
        )
    }
    
    ///
    public func merge<Output>(
        using: @escaping (LeftOutput, RightOutput) -> Output
    ) -> () async -> Output {
        { using(await left(), await right()) }
    }
}
