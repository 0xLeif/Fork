import XCTest
@testable import Fork

class ForkedArrayTests: XCTestCase {
    func testForkedArray() async throws {
        let photoNames: [String] = (0 ... Int.random(in: 1 ..< 10)).map(\.description)
        @Sendable func downloadPhoto(named: String) async -> String { named }
        func show(_ photos: [String]) { }
        
        let forkedArray = ForkedArray(
            photoNames,
            map: downloadPhoto(named:)
        )
        let photos = try await forkedArray.output()
        
        XCTAssertEqual(photos, photoNames)
    }
    
    func testForkedArray_ForEach() async throws {
        try await ["Hello", " ", "World", "!"].asyncForEach { print($0) }
    }
    
    func testForkedArray_none() async throws {
        let photoNames: [String] = []
        @Sendable func downloadPhoto(named: String) async -> String { named }
        func show(_ photos: [String]) { }
        
        let forkedArray = ForkedArray(photoNames, map: downloadPhoto(named:))
        let photos = try await forkedArray.output()
        
        XCTAssertEqual(photos, photoNames)
    }
    
    func testForkedArray_one() async throws {
        let photoNames = ["one"]
        @Sendable func isValidPhoto(named: String) async -> Bool { true }
        
        let photos = try await photoNames.asyncFilter(isValidPhoto(named:))
        
        XCTAssertEqual(photos, photoNames)
    }
    
    func testForkedArray_two() async throws {
        let photoNames = ["one", "two"]
        @Sendable func downloadPhoto(named: String) async -> String { named }
        
        let photos = try await photoNames.forked(
            map: downloadPhoto(named:)
        )
        
        XCTAssertEqual(photos, photoNames)
    }
    
    func testForkedArray_three() async throws {
        let photoNames = ["one", "two", "three"]
        @Sendable func downloadPhoto(named: String) async -> String { named }
        
        let photos = try await photoNames.asyncMap(downloadPhoto(named:))
        
        XCTAssertEqual(photos, photoNames)
    }
    
    func testForkedArray_x() async throws {
        let photoNames = (0 ... Int.random(in: 3 ..< 100)).map(\.description)
        @Sendable func downloadPhoto(named: String) async -> String { named }
        
        let forkedArray = photoNames.fork(map: downloadPhoto(named:))
        let photos = try await forkedArray.output()
        
        XCTAssertEqual(photos, photoNames)
    }
    
    func testForkedArray_order() async throws {
        let photoNames = ["Hello", " ", "World", "!"]
        @Sendable func downloadPhoto(named: String) async -> String { named }
        
        let forkedArray = photoNames.fork(map: downloadPhoto(named:))
        let photos = try await forkedArray.output()
        
        XCTAssertEqual(photos, photoNames)
    }
}
