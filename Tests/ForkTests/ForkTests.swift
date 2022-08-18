import XCTest
@testable import Fork

final class ForkTests: XCTestCase {
    func testFork() async throws {
        let fork = Fork(
            value: 10,
            leftOutput: { $0.isMultiple(of: 2) },
            rightOutput: { "\($0)" }
        )
        
        let leftOutput = try await fork.left()
        let rightOutput = try await fork.right()
        
        XCTAssertEqual(leftOutput, true)
        XCTAssertEqual(rightOutput, "10")
        
        let mergedFork: () async throws -> String = fork.merge(
            using: { bool, string in
                if bool {
                    return string + string
                }
                
                return string
            }
        )
        
        let output = try await mergedFork()
        
        XCTAssertEqual(output, "1010")
    }
}
