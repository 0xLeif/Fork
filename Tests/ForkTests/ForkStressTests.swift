import XCTest
@testable import Fork

/// Stress tests for Fork operations - testing with large data sets and high concurrency
final class ForkStressTests: XCTestCase, @unchecked Sendable {

    // MARK: - Large Array Tests

    func testForkedArray_largeArray_1000() async throws {
        let array = Array(0..<1_000)
        let result = try await array.asyncMap { $0 * 2 }

        XCTAssertEqual(result.count, 1_000)
        XCTAssertEqual(result[0], 0)
        XCTAssertEqual(result[999], 1998)

        // Verify all elements processed correctly
        for (index, value) in result.enumerated() {
            XCTAssertEqual(value, index * 2, "Element at index \(index) should be \(index * 2)")
        }
    }

    func testForkedArray_largeArray_10000() async throws {
        let array = Array(0..<10_000)
        let result = try await array.asyncMap { $0 * 2 }

        XCTAssertEqual(result.count, 10_000)
        XCTAssertEqual(result[0], 0)
        XCTAssertEqual(result[9999], 19998)

        // Spot check some values
        XCTAssertEqual(result[5000], 10000)
        XCTAssertEqual(result[2500], 5000)
        XCTAssertEqual(result[7500], 15000)
    }

    func testForkedArray_veryLargeArray_100000() async throws {
        try await withTestTimeout(seconds: 60) {
            let array = Array(0..<100_000)
            let result = try await array.asyncMap { $0 * 2 }

            XCTAssertEqual(result.count, 100_000)
            XCTAssertEqual(result[0], 0)
            XCTAssertEqual(result[99999], 199998)

            // Spot check some values across the array
            XCTAssertEqual(result[25000], 50000)
            XCTAssertEqual(result[50000], 100000)
            XCTAssertEqual(result[75000], 150000)
        }
    }

    // MARK: - Batched Array Stress Tests

    func testBatchedForkedArray_manyBatches() async throws {
        try await withTestTimeout(seconds: 60) {
            // 10,000 elements with batch size 1 = sequential processing (one batch per element)
            let array = Array(0..<10_000)
            let result = try await array.asyncMap(batch: 1) { $0 * 2 }

            XCTAssertEqual(result.count, 10_000)
            XCTAssertEqual(result[0], 0)
            XCTAssertEqual(result[9999], 19998)
        }
    }

    func testBatchedForkedArray_largeBatches() async throws {
        // 1,000 elements with batch size 1000 = single batch
        let array = Array(0..<1_000)
        let result = try await array.asyncMap(batch: 1000) { $0 * 2 }

        XCTAssertEqual(result.count, 1_000)
        for (index, value) in result.enumerated() {
            XCTAssertEqual(value, index * 2)
        }
    }

    // MARK: - Deep Nesting Tests

    func testFork_deepNesting() async throws {
        // Test 10 levels of nested forks using a non-recursive approach
        @Sendable func computeAtDepth(_ depth: Int, _ value: Int) async throws -> Int {
            if depth == 0 {
                return value
            }

            let fork = Fork(
                value: value,
                leftOutput: { @Sendable val -> Int in val + 1 },
                rightOutput: { @Sendable val -> Int in val + 2 }
            )

            let combined = try await fork.merged { $0 + $1 }
            // Recursively process with reduced depth
            return try await computeAtDepth(depth - 1, combined)
        }

        let result = try await computeAtDepth(10, 0)
        // Each level adds (value+1) + (value+2) = 2*value + 3, starting from 0
        XCTAssertGreaterThan(result, 0)
    }

    // MARK: - Concurrent Operations Tests

    func testFork_manyConcurrentForks() async throws {
        try await withTestTimeout(seconds: 30) {
            // Launch 1,000 concurrent fork operations
            let results = try await withThrowingTaskGroup(of: Int.self) { group in
                for i in 0..<1_000 {
                    group.addTask {
                        let fork = Fork(
                            value: i,
                            leftOutput: { $0 * 2 },
                            rightOutput: { $0 + 1 }
                        )
                        return try await fork.merged { $0 + $1 }
                    }
                }

                var results: [Int] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }

            XCTAssertEqual(results.count, 1_000)
        }
    }

    func testForkedActor_rapidMutations() async throws {
        try await withTestTimeout(seconds: 30) {
            actor Counter {
                var value = 0
                func increment() { value += 1 }
                func getValue() -> Int { value }
            }

            let counter = Counter()

            // Perform 1,000 rapid mutations through forked actors
            for _ in 0..<100 {
                let forkedActor = ForkedActor(
                    actor: counter,
                    leftOutput: { actor in
                        for _ in 0..<5 { await actor.increment() }
                    },
                    rightOutput: { actor in
                        for _ in 0..<5 { await actor.increment() }
                    }
                )
                _ = try await forkedActor.act()
            }

            let finalValue = await counter.getValue()
            XCTAssertEqual(finalValue, 1_000, "All 1,000 increments should complete")
        }
    }

    func testForkedArray_concurrentOutput() async throws {
        try await withTestTimeout(seconds: 30) {
            // Multiple tasks calling output() on the same ForkedArray simultaneously
            let array = Array(0..<100)
            let forkedArray = array.fork { $0 * 2 }

            let results = try await withThrowingTaskGroup(of: [Int].self) { group in
                // Launch 10 concurrent output() calls
                for _ in 0..<10 {
                    group.addTask {
                        try await forkedArray.output()
                    }
                }

                var allResults: [[Int]] = []
                for try await result in group {
                    allResults.append(result)
                }
                return allResults
            }

            // All results should be identical
            XCTAssertEqual(results.count, 10)
            let expected = Array(0..<100).map { $0 * 2 }
            for result in results {
                XCTAssertEqual(result, expected)
            }
        }
    }

    // MARK: - Order Preservation Under Stress

    func testForkedArray_orderPreservationLargeArray() async throws {
        try await withTestTimeout(seconds: 30) {
            let array = Array(0..<10_000)
            let result = try await array.asyncMap { $0 }

            // Verify strict order preservation
            for (index, value) in result.enumerated() {
                XCTAssertEqual(value, index, "Order must be preserved at index \(index)")
            }
        }
    }

    func testBatchedForkedArray_orderPreservationLargeArray() async throws {
        try await withTestTimeout(seconds: 30) {
            let array = Array(0..<10_000)
            let result = try await array.asyncMap(batch: 100) { $0 }

            // Verify strict order preservation
            for (index, value) in result.enumerated() {
                XCTAssertEqual(value, index, "Order must be preserved at index \(index)")
            }
        }
    }
}
