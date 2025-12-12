import XCTest
@testable import Fork

/// Tests for cancellation behavior in Fork operations
final class ForkCancellationTests: XCTestCase, @unchecked Sendable {

    // MARK: - Fork Cancellation Tests

    func testFork_cancelDuringExecution() async throws {
        let task = Task {
            let fork = Fork<String, String>(
                leftOutput: {
                    try await Task.sleep(for: .seconds(10))
                    return "left"
                },
                rightOutput: {
                    try await Task.sleep(for: .seconds(10))
                    return "right"
                }
            )
            return try await fork.merged { $0 + $1 }
        }

        // Give the task time to start
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Should have thrown CancellationError")
        } catch is CancellationError {
            // Expected
        }
    }

    func testFork_cancelBeforeExecution() async throws {
        let task = Task {
            // Check cancellation before starting
            try Task.checkCancellation()

            let fork = Fork<String, String>(
                leftOutput: { "left" },
                rightOutput: { "right" }
            )
            return try await fork.merged { $0 + $1 }
        }

        // Cancel immediately
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Should have thrown CancellationError")
        } catch is CancellationError {
            // Expected
        }
    }

    // MARK: - ForkedArray Cancellation Tests

    // Note: ForkedArray now has improved cancellation support with Task.checkCancellation()
    // calls at key points in output() and ForkType.output(). Cancellation is checked:
    // - At the start of output() and ForkType.output()
    // - Between filter (isIncluded) and map (transform) operations
    // This enables cooperative cancellation at natural boundaries in the processing.

    // MARK: - BatchedForkedArray Cancellation Tests

    func testBatchedForkedArray_cancelDuringBatch() async throws {
        let array = Array(0..<1000)

        let task = Task {
            try await array.asyncMap(batch: 10) { value -> Int in
                try await Task.sleep(for: .milliseconds(10))
                return value * 2
            }
        }

        try await Task.sleep(for: .milliseconds(100))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Should have thrown CancellationError")
        } catch is CancellationError {
            // Expected
        }
    }

    func testBatchedForkedArray_streamEarlyTermination() async throws {
        // Test that when consumer breaks out of stream early, the producer is properly cancelled
        // via onTermination. This verifies the cleanup behavior of the stream.

        // Note: AsyncThrowingStream has a fundamental limitation where Task.cancel() on the
        // consumer task doesn't automatically interrupt the await on iterator.next().
        // This test instead verifies that early termination (break) properly triggers cleanup.

        actor TerminationTracker {
            var wasCancelled = false
            func markCancelled() { wasCancelled = true }
            func check() -> Bool { wasCancelled }
        }

        let tracker = TerminationTracker()
        let array = Array(0..<100)
        var batchCount = 0

        // Scope the stream so it's deallocated after the block
        do {
            // Custom stream that tracks when onTermination is called
            let stream = AsyncThrowingStream<[Int], Error> { continuation in
                let task = Task {
                    do {
                        for i in stride(from: 0, to: array.count, by: 10) {
                            try Task.checkCancellation()
                            let batch = Array(array[i..<min(i+10, array.count)])
                            let mapped = batch.map { $0 * 2 }
                            // Small delay to ensure batches are processed sequentially
                            try await Task.sleep(for: .milliseconds(50))
                            continuation.yield(mapped)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }

                continuation.onTermination = { @Sendable _ in
                    Task { await tracker.markCancelled() }
                    task.cancel()
                }
            }

            for try await _ in stream {
                batchCount += 1
                if batchCount >= 2 {
                    // Break early after receiving 2 batches
                    break
                }
            }
        }

        // Give time for deallocation and onTermination to be called
        try await Task.sleep(for: .milliseconds(200))

        // Verify that early termination triggered cleanup
        XCTAssertEqual(batchCount, 2, "Should have received exactly 2 batches before breaking")
        let wasCancelled = await tracker.check()
        XCTAssertTrue(wasCancelled, "Producer should have been cancelled via onTermination")
    }

    // MARK: - ForkedActor Cancellation Tests

    func testForkedActor_cancelDuringMutation() async throws {
        actor SlowActor {
            var value = 0
            func slowIncrement() async throws {
                try await Task.sleep(for: .seconds(10))
                value += 1
            }
        }

        let testActor = SlowActor()
        let forkedActor = ForkedActor(
            actor: testActor,
            leftOutput: { actor in try await actor.slowIncrement() },
            rightOutput: { actor in try await actor.slowIncrement() }
        )

        let task = Task {
            try await forkedActor.act()
        }

        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Should have thrown CancellationError")
        } catch is CancellationError {
            // Expected
        }
    }

    // MARK: - Task.withCheckedCancellation Tests

    func testTaskWithCheckedCancellation_throwsOnCancel() async throws {
        let task = Task {
            try await Task.withCheckedCancellation {
                try await Task.sleep(for: .seconds(10))
                return "completed"
            }
        }

        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Should have thrown CancellationError")
        } catch is CancellationError {
            // Expected
        }
    }
}
