/// Using a single array and a single async function, batch the parallelized work for each value of the array
public struct BatchedForkedArray<Value, Output> {
    private let batchedArray: [[Value]]
    private let filter: (Value) async throws -> Bool
    private let map: (Value) async throws -> Output

    /// Create a ``BatchedForkedArray`` using a single `Array`
    /// - Parameters:
    ///   - array: The `Array` to be used in creating the output
    ///   - batch: The number of elements to batch together. (The minimum value is 1)
    ///   - filter: An `async` closure that determines if the value should be used or not
    ///   - map: An `async` closure that uses the `Array.Element` as its input
    public init(
        _ array: [Value],
        batch: UInt,
        filter: @escaping (Value) async throws -> Bool,
        map: @escaping (Value) async throws -> Output
    ) {
        var index: Int = 0
        let batchLimit: UInt = max(batch, 1)
        let batchedArray: [[Value]]

        batchedArray = array.reduce(into: []) { partialResult, value in
            guard partialResult.isEmpty == false else {
                partialResult.append([value])
                return
            }

            guard partialResult[index].count < batchLimit else {
                partialResult.append([value])
                return index += 1
            }

            partialResult[index].append(value)
        }

        self.batchedArray = batchedArray
        self.filter = filter
        self.map = map
    }

    /// Asynchronously resolve the forked array
    ///
    /// - Returns: The resolved array after performing the batched operations
    public func output() async throws -> [Output] {
        var batchedOutput: [[Output]] = []

        for batch in batchedArray {
            let batchedValues = try await batch.asyncFilter(filter).asyncMap(map)

            batchedOutput.append(batchedValues)
        }

        return batchedOutput.flatMap(identity)
    }

    /// Stream the forked array asynchronously
    ///
    /// - Returns: An AsyncThrowingStream object that yields batches of the resolved array
    public func stream() -> AsyncThrowingStream<[Output], Error> {
        AsyncThrowingStream { continuation in
            Task {
                for batch in batchedArray {
                    let batchedValues = try await batch.asyncFilter(filter).asyncMap(map)

                    continuation.yield(batchedValues)
                }

                continuation.finish()
            }
        }
    }
}

extension BatchedForkedArray {
    /// Create a ``BatchedForkedArray`` using a single `Array`
    /// - Parameters:
    ///   - array: The `Array` to be used in creating the output
    ///   - batch: The number of elements to batch together. (The minimum value is 1)
    ///   - map: An `async` closure that uses the `Array.Element` as its input
    public init(
        _ array: [Value],
        batch: UInt,
        map: @escaping (Value) async throws -> Output
    ) {
        self.init(array, batch: batch, filter: { _ in true }, map: map)
    }
}
