import XCTest
@testable import Fork

/// Tests for edge cases and boundary conditions in Fork operations
final class ForkEdgeCaseTests: XCTestCase, @unchecked Sendable {

    // MARK: - Single Element Tests

    func testForkedArray_singleElementBatched() async throws {
        let array = [42]

        // Test with various batch sizes
        let result1 = try await array.concurrentMap(batch: 0) { $0 * 2 }
        XCTAssertEqual(result1, [84])

        let result2 = try await array.concurrentMap(batch: 1) { $0 * 2 }
        XCTAssertEqual(result2, [84])

        let result3 = try await array.concurrentMap(batch: 10) { $0 * 2 }
        XCTAssertEqual(result3, [84])

        let result4 = try await array.concurrentMap(batch: 1000) { $0 * 2 }
        XCTAssertEqual(result4, [84])
    }

    // MARK: - Batch Size Edge Cases

    func testBatchedForkedArray_batchLargerThanArray() async throws {
        let array = [1, 2, 3, 4, 5]

        // Batch size larger than array
        let result = try await array.concurrentMap(batch: 100) { $0 * 2 }
        XCTAssertEqual(result, [2, 4, 6, 8, 10])
    }

    func testBatchedForkedArray_batchZero() async throws {
        let array = [1, 2, 3, 4, 5]

        // Batch size 0 should still work (implementation-dependent behavior)
        let result = try await array.concurrentMap(batch: 0) { $0 * 2 }
        XCTAssertEqual(result, [2, 4, 6, 8, 10])
    }

    // MARK: - Empty Collection Tests

    func testForkedArray_emptyWithFilter() async throws {
        let array: [Int] = []

        // Empty array through filter
        let filtered = try await array.concurrentFilter { $0 > 5 }
        XCTAssertEqual(filtered, [])

        // Empty array through map
        let mapped = try await array.concurrentMap { $0 * 2 }
        XCTAssertEqual(mapped, [])

        // Empty array through compactMap
        let compacted: [Int] = try await array.concurrentCompactMap { $0 > 5 ? $0 : nil }
        XCTAssertEqual(compacted, [])
    }

    // MARK: - Void Output Tests

    func testFork_voidBothBranches() async throws {
        actor Tracker {
            var leftCalled = false
            var rightCalled = false
            func markLeft() { leftCalled = true }
            func markRight() { rightCalled = true }
            func getState() -> (left: Bool, right: Bool) { (leftCalled, rightCalled) }
        }

        let tracker = Tracker()

        let fork = Fork<Void, Void>(
            leftOutput: { await tracker.markLeft() },
            rightOutput: { await tracker.markRight() }
        )

        try await fork.merged()

        let state = await tracker.getState()
        XCTAssertTrue(state.left)
        XCTAssertTrue(state.right)
    }

    // MARK: - Same Output Type Tests

    func testFork_sameOutputType() async throws {
        let fork = Fork<Int, Int>(
            value: 10,
            leftOutput: { $0 * 2 },
            rightOutput: { $0 + 5 }
        )

        let result = try await fork.merged { left, right in
            left + right
        }

        XCTAssertEqual(result, 35) // 20 + 15
    }

    func testFork_sameOutputTypeWithVoidLeft() async throws {
        actor SideEffectTracker {
            var value = 0
            func set(_ newValue: Int) { value = newValue }
            func get() -> Int { value }
        }

        let tracker = SideEffectTracker()

        let fork = Fork<Void, Int>(
            leftOutput: { await tracker.set(42) },
            rightOutput: { 100 }
        )

        let result = try await fork.merged()

        let sideEffect = await tracker.get()
        XCTAssertEqual(sideEffect, 42)
        XCTAssertEqual(result, 100)
    }

    func testFork_sameOutputTypeWithVoidRight() async throws {
        actor SideEffectTracker {
            var value = 0
            func set(_ newValue: Int) { value = newValue }
            func get() -> Int { value }
        }

        let tracker = SideEffectTracker()

        let fork = Fork<Int, Void>(
            leftOutput: { 100 },
            rightOutput: { await tracker.set(42) }
        )

        let result = try await fork.merged()

        let sideEffect = await tracker.get()
        XCTAssertEqual(sideEffect, 42)
        XCTAssertEqual(result, 100)
    }

    // MARK: - Filter Edge Cases

    func testForkedArray_allFilteredOut() async throws {
        let array = [1, 2, 3, 4, 5]

        // Filter that removes all elements
        let result = try await array.concurrentFilter { _ in false }
        XCTAssertEqual(result, [])
    }

    func testForkedArray_noneFilteredOut() async throws {
        let array = [1, 2, 3, 4, 5]

        // Filter that keeps all elements
        let result = try await array.concurrentFilter { _ in true }
        XCTAssertEqual(result, [1, 2, 3, 4, 5])
    }

    // MARK: - CompactMap Edge Cases

    func testForkedArray_compactMapAllNil() async throws {
        let array = [1, 2, 3, 4, 5]

        // CompactMap that returns nil for all elements
        let result: [Int] = try await array.concurrentCompactMap { _ in nil }
        XCTAssertEqual(result, [])
    }

    func testForkedArray_compactMapAllSome() async throws {
        let array = [1, 2, 3, 4, 5]

        // CompactMap that returns values for all elements
        let result: [Int] = try await array.concurrentCompactMap { $0 * 2 }
        XCTAssertEqual(result, [2, 4, 6, 8, 10])
    }

    func testForkedArray_compactMapMixed() async throws {
        let array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

        // CompactMap that returns values for even elements only
        let result: [Int] = try await array.concurrentCompactMap { $0 % 2 == 0 ? $0 * 2 : nil }
        XCTAssertEqual(result, [4, 8, 12, 16, 20])
    }

    // MARK: - Identity Function Tests

    func testFork_withIdentityFunction() async throws {
        // Test using the identity function
        let fork = Fork(
            value: "test",
            leftOutput: identity,
            rightOutput: identity
        )

        let result = try await fork.merged { $0 + $1 }
        XCTAssertEqual(result, "testtest")
    }

    // MARK: - Nested Collection Tests

    func testForkedArray_nestedArrays() async throws {
        let arrays = [[1, 2], [3, 4], [5, 6]]

        let result = try await arrays.concurrentMap { innerArray in
            innerArray.map { $0 * 2 }
        }

        XCTAssertEqual(result, [[2, 4], [6, 8], [10, 12]])
    }

    func testForkedArray_dictionaryValues() async throws {
        let dict = ["a": 1, "b": 2, "c": 3]

        let result = try await dict.concurrentMap { (key, value) in
            "\(key):\(value * 2)"
        }

        // Dictionary order is not guaranteed, so check set equality
        XCTAssertEqual(Set(result), Set(["a:2", "b:4", "c:6"]))
    }

    // MARK: - Stream Edge Cases

    func testBatchedForkedArray_streamEmptyArray() async throws {
        let array: [Int] = []
        let batched = array.fork(batch: 10) { $0 * 2 }

        var results: [Int] = []
        for try await batch in batched.stream() {
            results.append(contentsOf: batch)
        }

        XCTAssertEqual(results, [])
    }

    func testBatchedForkedArray_streamSingleBatch() async throws {
        let array = [1, 2, 3]
        let batched = array.fork(batch: 10) { $0 * 2 }

        var batchCount = 0
        var results: [Int] = []
        for try await batch in batched.stream() {
            batchCount += 1
            results.append(contentsOf: batch)
        }

        XCTAssertEqual(batchCount, 1)
        XCTAssertEqual(results, [2, 4, 6])
    }
}
