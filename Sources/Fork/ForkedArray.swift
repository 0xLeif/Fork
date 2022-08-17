public struct ForkedArray<Value, Output> {
    enum ForkType {
        case none
        case single(Value)
        case fork(Fork<ForkType, ForkType>)
    }
    
    private let output: (Value) async throws -> Output
    
    public let array: [Value]
    let fork: Fork<ForkType, ForkType>
    
    public init(
        _ array: [Value],
        output: @escaping (Value) async throws -> Output
    ) {
        self.array = array
        self.output = output
        
        let forkType = ForkedArray.split(array: array)
        
        switch forkType {
        case .none:
            self.fork = Fork(value: array, leftOutput: { _ in .none}, rightOutput: { _ in .none })
        case .single(let value):
            self.fork = Fork(
                value: value,
                leftOutput: ForkType.single,
                rightOutput: { _ in .none }
            )
        case .fork(let fork):
            self.fork = fork
        }
    }
    
    /// Asynchronously resolve the forked array
    public func output() async throws -> [Output] {
        try await fork.merged(
            using: { leftForkType, rightForkType in
                async let leftOutput = try await ForkedArray.output(for: leftForkType, using: output)
                async let rightOutput = try await ForkedArray.output(for: rightForkType, using: output)
                
                return try await leftOutput + rightOutput
            }
        )
    }
    
    private static func split(
        array: [Value]
    ) -> ForkType {
        let count = array.count
        
        guard count > 0 else { return .none }
        guard count > 1 else { return .single(array[0]) }
        
        if count == 2 {
            return .fork(
                Fork(
                    value: array,
                    leftInputMap: { $0[0] },
                    rightInputMap: { $0[1] },
                    leftOutput: ForkType.single,
                    rightOutput: ForkType.single
                )
            )
        }
        
        let midPoint = count / 2
        
        return .fork(
            Fork(
                value: array,
                leftInputMap: { Array($0[0 ..< midPoint]) },
                rightInputMap: { Array($0[midPoint ... count - 1]) },
                leftOutput: split(array:),
                rightOutput: split(array:)
            )
        )
    }
    
    private static func output(
        for type: ForkType,
        using: @escaping (Value) async throws -> Output
    ) async throws -> [Output] {
        switch type {
        case .none:
            return []
        case let .single(value):
            return [try await using(value)]
        case let .fork(fork):
            return try await fork.merged(
                using: { leftType, rightType in
                    async let leftOutput = try output(for: leftType, using: using)
                    async let rightOutput = try output(for: rightType, using: using)
                    
                    return try await leftOutput + rightOutput
                }
            )
        }
    }
}
