import XCTest
@testable import Fork

class ForkedArrayTests: XCTestCase {
    func testForkedArray_none() async throws {
        let photoNames: [String] = []
        @Sendable func downloadPhoto(named: String) async -> String { named }
        func show(_ photos: [String]) { }
        
        let forkedArray = ForkedArray(photoNames, output: downloadPhoto(named:))
        let photos = try await forkedArray.output()
        
        XCTAssertEqual(photos, photoNames)
    }
    
    func testForkedArray_one() async throws {
        let photoNames = ["one"]
        @Sendable func downloadPhoto(named: String) async -> String { named }
        func show(_ photos: [String]) { }
        
        let forkedArray = ForkedArray(photoNames, output: downloadPhoto(named:))
        let photos = try await forkedArray.output()
        
        XCTAssertEqual(photos, photoNames)
    }
    
    func testForkedArray_two() async throws {
        let photoNames = ["one", "two"]
        @Sendable func downloadPhoto(named: String) async -> String { named }
        func show(_ photos: [String]) { }
        
        let forkedArray = ForkedArray(photoNames, output: downloadPhoto(named:))
        let photos = try await forkedArray.output()
        
        XCTAssertEqual(photos, photoNames)
    }
    
    func testForkedArray_three() async throws {
        let photoNames = ["one", "two", "three"]
        @Sendable func downloadPhoto(named: String) async -> String { named }
        func show(_ photos: [String]) { }
        
        let forkedArray = ForkedArray(photoNames, output: downloadPhoto(named:))
        let photos = try await forkedArray.output()
        
        XCTAssertEqual(photos, photoNames)
    }
    
    func testForkedArray_x() async throws {
        let photoNames = (0 ... Int.random(in: 3 ..< 100)).map(\.description)
        @Sendable func downloadPhoto(named: String) async -> String { named }
        func show(_ photos: [String]) { }
        
        let forkedArray = photoNames.fork(output: downloadPhoto(named:))
        let photos = try await forkedArray.output()
        
        XCTAssertEqual(photos, photoNames)
    }
}
