import XCTest
@testable import Fork

/// Tests for error propagation in Fork operations
final class ForkErrorTests: XCTestCase, @unchecked Sendable {

    // MARK: - Test Error Type

    enum TestError: Error, Equatable, Sendable {
        case leftFailed
        case rightFailed
        case mapFailed
        case filterFailed
    }

    // MARK: - Fork Error Tests

    func testFork_leftThrows() async {
        let fork = Fork<String, String>(
            leftOutput: { throw TestError.leftFailed },
            rightOutput: { "right" }
        )

        do {
            _ = try await fork.merged { $0 + $1 }
            XCTFail("Should have thrown an error")
        } catch let error as TestError {
            XCTAssertEqual(error, .leftFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFork_rightThrows() async {
        let fork = Fork<String, String>(
            leftOutput: { "left" },
            rightOutput: { throw TestError.rightFailed }
        )

        do {
            _ = try await fork.merged { $0 + $1 }
            XCTFail("Should have thrown an error")
        } catch let error as TestError {
            XCTAssertEqual(error, .rightFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFork_bothThrow() async {
        let fork = Fork<String, String>(
            leftOutput: { throw TestError.leftFailed },
            rightOutput: { throw TestError.rightFailed }
        )

        do {
            _ = try await fork.merged { $0 + $1 }
            XCTFail("Should have thrown an error")
        } catch is TestError {
            // Either error is acceptable - both branches throw
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - ForkedArray Error Tests

    func testForkedArray_mapThrows() async {
        let array = Array(0..<100)

        do {
            _ = try await array.asyncMap { value -> Int in
                if value == 50 {
                    throw TestError.mapFailed
                }
                return value * 2
            }
            XCTFail("Should have thrown an error")
        } catch let error as TestError {
            XCTAssertEqual(error, .mapFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testForkedArray_filterThrows() async {
        let array = Array(0..<100)

        do {
            _ = try await array.asyncFilter { value -> Bool in
                if value == 50 {
                    throw TestError.filterFailed
                }
                return value % 2 == 0
            }
            XCTFail("Should have thrown an error")
        } catch let error as TestError {
            XCTAssertEqual(error, .filterFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - BatchedForkedArray Error Tests

    func testBatchedForkedArray_mapThrows() async {
        let array = Array(0..<100)

        do {
            _ = try await array.asyncMap(batch: 10) { value -> Int in
                if value == 50 {
                    throw TestError.mapFailed
                }
                return value * 2
            }
            XCTFail("Should have thrown an error")
        } catch let error as TestError {
            XCTAssertEqual(error, .mapFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testBatchedForkedArray_streamThrows() async {
        let array = Array(0..<100)
        let batchedArray = array.fork(batch: 10) { value -> Int in
            if value == 50 {
                throw TestError.mapFailed
            }
            return value * 2
        }

        do {
            var results: [Int] = []
            for try await batch in batchedArray.stream() {
                results.append(contentsOf: batch)
            }
            XCTFail("Should have thrown an error")
        } catch let error as TestError {
            XCTAssertEqual(error, .mapFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - ForkedActor Error Tests

    func testForkedActor_leftThrows() async {
        actor TestActor {
            var value = 0
            func increment() { value += 1 }
        }

        let testActor = TestActor()
        let forkedActor = ForkedActor(
            actor: testActor,
            leftOutput: { _ in throw TestError.leftFailed },
            rightOutput: { actor in await actor.increment() }
        )

        do {
            _ = try await forkedActor.act()
            XCTFail("Should have thrown an error")
        } catch let error as TestError {
            XCTAssertEqual(error, .leftFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testForkedActor_rightThrows() async {
        actor TestActor {
            var value = 0
            func increment() { value += 1 }
        }

        let testActor = TestActor()
        let forkedActor = ForkedActor(
            actor: testActor,
            leftOutput: { actor in await actor.increment() },
            rightOutput: { _ in throw TestError.rightFailed }
        )

        do {
            _ = try await forkedActor.act()
            XCTFail("Should have thrown an error")
        } catch let error as TestError {
            XCTAssertEqual(error, .rightFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
