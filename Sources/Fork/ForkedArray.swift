/// Using a single array and a single async function, parallelize the work for each value of the array
public struct ForkedArray<Value: Sendable, Output: Sendable>: Sendable {
    enum ForkType: Sendable{
        case none
        case single(Value)
        case fork(Fork<ForkType, ForkType>)
    }
    
    private let filter: @Sendable (Value) async throws -> Bool
    private let map: @Sendable (Value) async throws -> Output
    private let fork: Fork<ForkType, ForkType>
    
    /// The input array used to get the output
    public let array: [Value]
    
    /// Create a ``ForkedArray`` using a single `Array`
    /// - Parameters:
    ///   - array: The `Array` to be used in creating the output
    ///   - filter: An `async` closure that determines if the value should be used or not
    ///   - map: An `async` closure that uses the `Array.Element` as its input
    public init(
        _ array: [Value],
        filter: @Sendable @escaping (Value) async throws -> Bool,
        map: @Sendable @escaping (Value) async throws -> Output
    ) {
        self.array = array
        self.filter = filter
        self.map = map
        
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
                leftOutput: { ForkType.single($0) },
                rightOutput: { _ in .none }
            )
        case .fork(let fork):
            self.fork = fork
        }
    }
    
    /// Asynchronously resolve the forked array
    public func output() async throws -> [Output] {
        try await fork.merged { leftForkType, rightForkType in
            async let leftOutput = try leftForkType.output(isIncluded: filter, transform: map)
            async let rightOutput = try rightForkType.output(isIncluded: filter, transform: map)
            
            return try await leftOutput + rightOutput
        }
    }
}

extension ForkedArray {
    /// Create a ``ForkedArray`` using a single `Array`
    /// - Parameters:
    ///   - array: The `Array` to be used in creating the output
    ///   - map: An `async` closure that uses the `Array.Element` as its input
    public init(
        _ array: [Value],
        map: @Sendable @escaping (Value) async throws -> Output
    ) {
        self.init(array, filter: { _ in true }, map: map)
    }
}

extension ForkedArray {
    @Sendable
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
                    leftOutput: { ForkType.single($0) },
                    rightOutput: { ForkType.single($0) }
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
}

extension ForkedArray.ForkType {
    func output(
        isIncluded: @Sendable @escaping (Value) async throws -> Bool,
        transform: @Sendable @escaping (Value) async throws -> Output
    ) async throws -> [Output] {
        switch self {
        case .none:
            return []
        case let .single(value):
            return try await Task.withCheckedCancellation {
                guard try await isIncluded(value) else { return [] }
                
                return [try await transform(value)]
            }
        case let .fork(fork):
            return try await fork.merged(
                using: { leftType, rightType in
                    try await Task.withCheckedCancellation {
                        async let leftOutput = try leftType.output(isIncluded: isIncluded, transform: transform)
                        async let rightOutput = try rightType.output(isIncluded: isIncluded, transform: transform)
                        
                        return try await leftOutput + rightOutput
                    }
                }
            )
        }
    }
}
