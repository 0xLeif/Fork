import XCTest
@testable import Fork

// MARK: - Test Timeout Helper

private struct RaceTestTimeoutError: Error, CustomStringConvertible {
    let seconds: TimeInterval
    var description: String { "Test timed out after \(seconds) seconds" }
}

private func withRaceTestTimeout<T: Sendable>(
    seconds: TimeInterval = 30,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw RaceTestTimeoutError(seconds: seconds)
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

/// Tests to verify race condition safety in Fork operations
final class ForkRaceConditionTests: XCTestCase, @unchecked Sendable {

    // MARK: - Fork Execution Order Tests

    func testFork_executionOrderIndependence() async throws {
        // Run multiple times to catch timing-dependent issues
        for _ in 0..<100 {
            let fork = Fork(
                value: 10,
                leftOutput: { value -> Int in
                    // Random delay to vary execution order
                    try await Task.sleep(for: .microseconds(.random(in: 1...100)))
                    return value * 2
                },
                rightOutput: { value -> Int in
                    try await Task.sleep(for: .microseconds(.random(in: 1...100)))
                    return value + 5
                }
            )

            let result = try await fork.merged { left, right in
                (left: left, right: right)
            }

            // Results should be correct regardless of which branch completes first
            XCTAssertEqual(result.left, 20)
            XCTAssertEqual(result.right, 15)
        }
    }

    // MARK: - ForkedActor Race Condition Tests

    func testForkedActor_concurrentMutations() async throws {
        actor Counter {
            var value = 0
            func increment() { value += 1 }
            func getValue() -> Int { value }
        }

        // Run multiple times to catch race conditions
        for iteration in 0..<10 {
            let counter = Counter()

            let forkedActor = ForkedActor(
                actor: counter,
                leftOutput: { actor in
                    for _ in 0..<100 {
                        await actor.increment()
                    }
                },
                rightOutput: { actor in
                    for _ in 0..<100 {
                        await actor.increment()
                    }
                }
            )

            _ = try await forkedActor.act()
            let finalValue = await counter.getValue()

            // Actor isolation ensures all 200 increments complete without races
            XCTAssertEqual(finalValue, 200, "Iteration \(iteration): All increments should complete safely")
        }
    }

    func testForkedActor_mutationVisibility() async throws {
        actor StateHolder {
            var values: [Int] = []
            func append(_ value: Int) { values.append(value) }
            func getValues() -> [Int] { values }
        }

        let stateHolder = StateHolder()

        let forkedActor = ForkedActor(
            actor: stateHolder,
            leftOutput: { actor in
                for i in 0..<50 {
                    await actor.append(i)
                }
            },
            rightOutput: { actor in
                for i in 50..<100 {
                    await actor.append(i)
                }
            }
        )

        _ = try await forkedActor.act()
        let values = await stateHolder.getValues()

        // All values should be present (order may vary due to concurrent access)
        XCTAssertEqual(values.count, 100, "All 100 values should be appended")
        XCTAssertEqual(Set(values), Set(0..<100), "All values 0-99 should be present")
    }

    // MARK: - KeyPathActor Race Condition Tests

    func testKeyPathActor_concurrentUpdates() async throws {
        try await withRaceTestTimeout(seconds: 30) {
            struct State: Sendable {
                var counter: Int = 0
                var name: String = ""
            }

            let keyPathActor = KeyPathActor(value: State())

            // Concurrent updates to different properties
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Update counter 100 times
                for _ in 0..<100 {
                    group.addTask {
                        await keyPathActor.update(\State.counter) { $0 + 1 }
                    }
                }

                // Update name concurrently
                for i in 0..<100 {
                    group.addTask {
                        await keyPathActor.set(\State.name, to: "name\(i)")
                    }
                }

                try await group.waitForAll()
            }

            let finalState = await keyPathActor.value
            XCTAssertEqual(finalState.counter, 100, "Counter should be incremented 100 times")
            XCTAssertTrue(finalState.name.hasPrefix("name"), "Name should be set")
        }
    }

    // MARK: - BatchedForkedArray Concurrent Access Tests

    func testBatchedForkedArray_concurrentStreamAndOutput() async throws {
        try await withRaceTestTimeout(seconds: 30) {
            let array = Array(0..<100)
            let batchedArray = array.fork(batch: 10) { $0 * 2 }

            // Launch concurrent stream and output operations
            async let streamResult: [Int] = {
                var results: [Int] = []
                for try await batch in batchedArray.stream() {
                    results.append(contentsOf: batch)
                }
                return results
            }()

            async let outputResult = batchedArray.output()

            let (stream, output) = try await (streamResult, outputResult)

            // Both should produce the same results
            XCTAssertEqual(stream.sorted(), output.sorted())
            XCTAssertEqual(stream.count, 100)
        }
    }

    // MARK: - Shared State Isolation Tests

    func testForkedArray_sharedStateIsolation() async throws {
        // This test verifies that closures don't accidentally share mutable state
        // Due to Sendable requirements, this should be enforced at compile time

        actor ResultCollector {
            var results: [Int] = []
            func append(_ value: Int) { results.append(value) }
            func getResults() -> [Int] { results }
        }

        let collector = ResultCollector()
        let array = Array(0..<100)

        // Each element should be processed independently
        try await array.asyncForEach { value in
            await collector.append(value * 2)
        }

        let results = await collector.getResults()
        XCTAssertEqual(results.count, 100)
        XCTAssertEqual(Set(results), Set((0..<100).map { $0 * 2 }))
    }

    // MARK: - High Contention Tests

    func testFork_highContentionScenario() async throws {
        try await withRaceTestTimeout(seconds: 30) {
            actor SharedResource {
                var accessCount = 0
                var maxConcurrent = 0
                var currentConcurrent = 0

                func beginAccess() {
                    currentConcurrent += 1
                    accessCount += 1
                    if currentConcurrent > maxConcurrent {
                        maxConcurrent = currentConcurrent
                    }
                }

                func endAccess() {
                    currentConcurrent -= 1
                }

                func getStats() -> (total: Int, maxConcurrent: Int) {
                    (accessCount, maxConcurrent)
                }
            }

            let resource = SharedResource()

            // Many concurrent forks accessing the same resource
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<100 {
                    group.addTask {
                        let fork = Fork<Void, Void>(
                            leftOutput: {
                                await resource.beginAccess()
                                try await Task.sleep(for: .microseconds(100))
                                await resource.endAccess()
                            },
                            rightOutput: {
                                await resource.beginAccess()
                                try await Task.sleep(for: .microseconds(100))
                                await resource.endAccess()
                            }
                        )
                        try await fork.merged()
                    }
                }

                try await group.waitForAll()
            }

            let stats = await resource.getStats()
            XCTAssertEqual(stats.total, 200, "All 200 accesses should complete")
            XCTAssertGreaterThan(stats.maxConcurrent, 1, "Should have concurrent access")
        }
    }
}
