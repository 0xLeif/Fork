import XCTest
@testable import Fork

final class BatchedForkedArrayTests: XCTestCase {
    func testBatchedForkedArrayOutput_x() async throws {
        let photoNames = [Int](0 ..< 100)

        let batchedForkedArray = BatchedForkedArray(
            photoNames,
            batch: 5,
            map: { "\($0)" }
        )

        let batchedArray = try await batchedForkedArray.output()

        XCTAssertEqual(batchedArray.count, photoNames.count)
    }

    func testBatchedForkedArrayStream_x() async throws {
        let photoNames = [Int](0 ..< 100)

        let batchedForkedArray = photoNames.fork(
            batch: 5,
            map: { "\($0)" }
        )

        for try await batch in batchedForkedArray.stream() {
            XCTAssertEqual(batch.count, 5)
        }
    }

    func testBatchedForkedArray() async throws {
        let photoNames: [String] = (0 ... Int.random(in: 1 ..< 10)).map(\.description)
        @Sendable func downloadPhoto(named: String) async -> String { named }
        func show(_ photos: [String]) { }

        let forkedArray = BatchedForkedArray(
            photoNames,
            batch: 5,
            map: downloadPhoto(named:)
        )
        let photos = try await forkedArray.output()

        XCTAssertEqual(photos, photoNames)
    }

    func testBatchedForkedArray_ForEach() async throws {
        try await [
            "Hello", " ", // First batch
            "World", "!"  // Second batch
        ]
            .asyncForEach(batch: 2) { print($0) }
    }

    func testBatchedForkedArray_none() async throws {
        let photoNames: [String] = []
        @Sendable func downloadPhoto(named: String) async -> String { named }
        func show(_ photos: [String]) { }

        let forkedArray = BatchedForkedArray(photoNames, batch: 5, map: downloadPhoto(named:))
        let photos = try await forkedArray.output()

        XCTAssertEqual(photos, photoNames)
    }

    func testBatchedForkedArray_one() async throws {
        let photoNames = ["one"]
        @Sendable func isValidPhoto(named: String) async -> Bool { true }

        let photos = try await photoNames.asyncFilter(batch: 0, isValidPhoto(named:))

        XCTAssertEqual(photos, photoNames)
    }

    func testBatchedForkedArray_two() async throws {
        let photoNames = ["one", "two"]
        @Sendable func downloadPhoto(named: String) async -> String { named }

        let photos = try await photoNames.forked(
            batch: 2,
            map: downloadPhoto(named:)
        )

        XCTAssertEqual(photos, photoNames)
    }

    func testBatchedForkedArray_three() async throws {
        let photoNames = ["one", "two", "three"]
        @Sendable func downloadPhoto(named: String) async -> String { named }

        let photos = try await photoNames.asyncMap(batch: 2, downloadPhoto(named:))
        XCTAssertEqual(photos, photoNames)
    }

    func testBatchedForkedArray_x() async throws {
        let photoNames = (0 ... Int.random(in: 3 ..< 100)).map(\.description)
        @Sendable func downloadPhoto(named: String) async -> String { named }

        let forkedArray = photoNames.fork(batch: 10, map: downloadPhoto(named:))
        let photos = try await forkedArray.output()

        XCTAssertEqual(photos, photoNames)
    }

    func testBatchedForkedArrayCompactMap_x() async throws {
        let photoNames = [Int](0 ..< 100)
        @Sendable func asyncFilter(number: Int) async -> String? {
            guard number.isMultiple(of: 2) else { return nil }

            return number.description
        }

        let compactedArray = try await photoNames.asyncCompactMap(batch: 10, asyncFilter(number:))

        XCTAssertEqual(compactedArray.count, photoNames.count / 2)
    }

    func testBatchedForkedArray_order() async throws {
        let photoNames = ["Hello", " ", "World", "!"]
        @Sendable func downloadPhoto(named: String) async -> String { named }

        let forkedArray = photoNames.fork(batch: 2, map: downloadPhoto(named:))
        let photos = try await forkedArray.output()

        XCTAssertEqual(photos, photoNames)
    }

    func testBatchedForkedArraySet() async throws {
        let set = Set(0 ..< 9)

        let outputArray = try await set.asyncMap(batch: 3, identity)

        XCTAssertEqual(outputArray, Array(set))
    }

    func testBatchedForkedArrayDictionary() async throws {
        let dictionary: [String: String] = [:]

        let outputArray = try await dictionary.forked(
            batch: 1,
            filter: { (key: String, value: String) in
                return true
            },
            map: identity
        )

        XCTAssert(type(of: outputArray) == [Dictionary<String, String>.Element].self)
    }
}
