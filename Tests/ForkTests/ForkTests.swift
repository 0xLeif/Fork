import XCTest
@testable import Fork

final class ForkTests: XCTestCase {
    func testExample() async throws {
        let fork = Fork(
            value: 10,
            leftOutput: { $0.isMultiple(of: 2) },
            rightOutput: { "\($0)" }
        )
        
        let leftOutput = await fork.left()
        let rightOutput = await fork.right()
        
        XCTAssertEqual(leftOutput, true)
        XCTAssertEqual(rightOutput, "10")
        
        let mergedFork: () async -> String = fork.merge(
            using: { bool, string in
                if bool {
                    return string + string
                }
                    
                return string
            }
        )
        
        let output = await mergedFork()
        
        XCTAssertEqual(output, "1010")
    }
}
