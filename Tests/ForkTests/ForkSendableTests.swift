import XCTest
@testable import Fork

/// Tests for Sendable compliance in Fork operations
final class ForkSendableTests: XCTestCase, @unchecked Sendable {

    // MARK: - Sendable Type Tests

    func testFork_sendableTypes() async throws {
        // Test with various Sendable types

        // Int
        let intFork = Fork(
            value: 42,
            leftOutput: { $0 * 2 },
            rightOutput: { $0 + 10 }
        )
        let intResult = try await intFork.merged { $0 + $1 }
        XCTAssertEqual(intResult, 136) // 84 + 52

        // String
        let stringFork = Fork(
            value: "hello",
            leftOutput: { $0.uppercased() },
            rightOutput: { $0 + " world" }
        )
        let stringResult = try await stringFork.merged { $0 + " | " + $1 }
        XCTAssertEqual(stringResult, "HELLO | hello world")

        // Bool
        let boolFork = Fork(
            value: true,
            leftOutput: { !$0 },
            rightOutput: { $0 }
        )
        let boolResult = try await boolFork.merged { ($0, $1) }
        XCTAssertEqual(boolResult.0, false)
        XCTAssertEqual(boolResult.1, true)

        // Optional
        let optionalFork = Fork<Int?, Int?>(
            value: 42 as Int?,
            leftOutput: { $0.map { $0 * 2 } },
            rightOutput: { $0.map { $0 + 10 } }
        )
        let optionalResult = try await optionalFork.merged { ($0, $1) }
        XCTAssertEqual(optionalResult.0, 84)
        XCTAssertEqual(optionalResult.1, 52)

        // Array
        let arrayFork = Fork(
            value: [1, 2, 3],
            leftOutput: { $0.map { $0 * 2 } },
            rightOutput: { Array($0.reversed()) }
        )
        let arrayResult = try await arrayFork.merged { ($0, $1) }
        XCTAssertEqual(arrayResult.0, [2, 4, 6])
        XCTAssertEqual(arrayResult.1, [3, 2, 1])

        // Dictionary
        let dictFork = Fork(
            value: ["a": 1, "b": 2],
            leftOutput: { dict in dict.mapValues { $0 * 2 } },
            rightOutput: { dict in dict.count }
        )
        let dictResult = try await dictFork.merged { ($0, $1) }
        XCTAssertEqual(dictResult.0, ["a": 2, "b": 4])
        XCTAssertEqual(dictResult.1, 2)

        // Set
        let setFork = Fork(
            value: Set([1, 2, 3]),
            leftOutput: { Set($0.map { $0 * 2 }) },
            rightOutput: { $0.count }
        )
        let setResult = try await setFork.merged { ($0, $1) }
        XCTAssertEqual(setResult.0, Set([2, 4, 6]))
        XCTAssertEqual(setResult.1, 3)
    }

    func testFork_sendableClosures() async throws {
        // Verify that @Sendable closures work correctly

        // Closures that capture nothing
        let fork1 = Fork<Int, Int>(
            leftOutput: { 42 },
            rightOutput: { 100 }
        )
        let result1 = try await fork1.merged { $0 + $1 }
        XCTAssertEqual(result1, 142)

        // Closures that capture Sendable values
        let multiplier = 2
        let offset = 10
        let fork2 = Fork(
            value: 5,
            leftOutput: { $0 * multiplier },
            rightOutput: { $0 + offset }
        )
        let result2 = try await fork2.merged { $0 + $1 }
        XCTAssertEqual(result2, 25) // 10 + 15
    }

    func testForkedArray_sendableConstraints() async throws {
        // Test that ForkedArray works with Sendable types

        // Struct that is Sendable
        struct Point: Sendable, Equatable {
            let x: Int
            let y: Int
        }

        let points = [Point(x: 1, y: 2), Point(x: 3, y: 4), Point(x: 5, y: 6)]

        let result = try await points.concurrentMap { point in
            Point(x: point.x * 2, y: point.y * 2)
        }

        XCTAssertEqual(result, [
            Point(x: 2, y: 4),
            Point(x: 6, y: 8),
            Point(x: 10, y: 12)
        ])
    }

    func testKeyPathActor_sendableValue() async throws {
        // Test KeyPathActor with various Sendable types

        struct Config: Sendable {
            var timeout: Int
            var retryCount: Int
            var enabled: Bool
        }

        let keyPathActor = KeyPathActor(value: Config(timeout: 30, retryCount: 3, enabled: true))

        // Verify initial state
        var config = await keyPathActor.value
        XCTAssertEqual(config.timeout, 30)
        XCTAssertEqual(config.retryCount, 3)
        XCTAssertTrue(config.enabled)

        // Update via keypath
        await keyPathActor.set(\Config.timeout, to: 60)
        config = await keyPathActor.value
        XCTAssertEqual(config.timeout, 60)

        // Update via transform
        await keyPathActor.update(\Config.retryCount) { $0 + 2 }
        config = await keyPathActor.value
        XCTAssertEqual(config.retryCount, 5)

        // Full replacement
        await keyPathActor.set(to: Config(timeout: 10, retryCount: 1, enabled: false))
        config = await keyPathActor.value
        XCTAssertEqual(config.timeout, 10)
        XCTAssertEqual(config.retryCount, 1)
        XCTAssertFalse(config.enabled)
    }

    // MARK: - Complex Sendable Types

    func testFork_complexSendableTypes() async throws {
        // Enum with associated values
        enum Result: Sendable, Equatable {
            case success(Int)
            case failure(String)
        }

        let fork = Fork<Result, Result>(
            leftOutput: { .success(42) },
            rightOutput: { .failure("error") }
        )

        let result = try await fork.merged { ($0, $1) }
        XCTAssertEqual(result.0, .success(42))
        XCTAssertEqual(result.1, .failure("error"))
    }

    func testForkedArray_nestedSendableTypes() async throws {
        // Nested Sendable structure
        struct Inner: Sendable, Equatable {
            let value: Int
        }

        struct Outer: Sendable, Equatable {
            let inner: Inner
            let name: String
        }

        let items = [
            Outer(inner: Inner(value: 1), name: "first"),
            Outer(inner: Inner(value: 2), name: "second"),
            Outer(inner: Inner(value: 3), name: "third")
        ]

        let result = try await items.concurrentMap { outer in
            Outer(inner: Inner(value: outer.inner.value * 2), name: outer.name.uppercased())
        }

        XCTAssertEqual(result, [
            Outer(inner: Inner(value: 2), name: "FIRST"),
            Outer(inner: Inner(value: 4), name: "SECOND"),
            Outer(inner: Inner(value: 6), name: "THIRD")
        ])
    }
}
