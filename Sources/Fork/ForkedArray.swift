/// Using a single array and a single async function, parallelize the work for each value of the array
public struct ForkedArray<Value, Output> {
    private enum ForkType {
        case none
        case single(Value)
        case fork(Fork<ForkType, ForkType>)
    }
    
    private let filter: (Value) async throws -> Bool
    private let output: (Value) async throws -> Output
    private let fork: Fork<ForkType, ForkType>
    
    /// The input array used to get the output
    public let array: [Value]
    
    /// Create a ``ForkedArray`` using a single `Array`
    /// - Parameters:
    ///   - array: The `Array` to be used in creating the output
    ///   - filter: An `async` closure that determines if the value should be used or not
    ///   - output: An `async` closure that uses the `Array.Element` as its input
    public init(
        _ array: [Value],
        filter: @escaping (Value) async throws -> Bool = { _ in true },
        output: @escaping (Value) async throws -> Output
    ) {
        self.array = array
        self.filter = filter
        self.output = output
        
        switch ForkedArray.split(array: array) {
        case .none:
            self.fork = Fork(
                value: array,
                leftOutput: { _ in .none },
                rightOutput: { _ in .none }
            )
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
                async let leftOutput = try await ForkedArray.output(for: leftForkType, filter: filter, using: output)
                async let rightOutput = try await ForkedArray.output(for: rightForkType, filter: filter, using: output)
                
                return try await leftOutput + rightOutput
            }
        )
    }
}

extension ForkedArray {
    private static func split(
        array: [Value]
    ) -> ForkType {
        let count = array.count
        switch count {
        case 0:
            return .none
        case 1:
            return .single(array[0])
        case 2:
            return .fork(
                Fork(
                    value: array,
                    leftInputMap: { $0[0] },
                    rightInputMap: { $0[1] },
                    leftOutput: ForkType.single,
                    rightOutput: ForkType.single
                )
            )
        default:
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
    }
    
    private static func output(
        for type: ForkType,
        filter: @escaping (Value) async throws -> Bool,
        using: @escaping (Value) async throws -> Output
    ) async throws -> [Output] {
        switch type {
        case .none:
            return []
        case let .single(value):
            guard try await filter(value) else { return [] }
            
            try Task.checkCancellation()
            
            return [try await using(value)]
        case let .fork(fork):
            return try await fork.merged(
                using: { leftType, rightType in
                    async let leftOutput = try output(for: leftType, filter: filter, using: using)
                    async let rightOutput = try output(for: rightType, filter: filter, using: using)
                    
                    try Task.checkCancellation()
                    
                    return try await leftOutput + rightOutput
                }
            )
        }
    }
}
