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
    
    func testForkClosure() async throws {
        let fork = Fork(
            value: UUID.init,
            leftOutput: { $0.uuidString == "UUID" },
            rightOutput: { Array($0.uuidString.reversed().map(\.description)) }
        )
        
        let leftOutput = try await fork.left()
        let rightOutput = try await fork.right()
        
        XCTAssertEqual(leftOutput, false)
        XCTAssertEqual(rightOutput.count, 36)
        
        let mergedFork: () async throws -> [String] = fork.merge(
            using: { bool, string in
                if bool {
                    return string + string
                }
                
                return string
            }
        )
        
        let output = try await mergedFork()
        
        XCTAssertNotEqual(output, rightOutput)
    }
    
    func testForkVoid() async throws {
        try await Fork(
            leftOutput: { print("Hello", terminator: "") },
            rightOutput: {
                try await Fork(
                    leftOutput: { print(" ", terminator: "") },
                    rightOutput: { print("World", terminator: "") }
                )
                .merged()
            }
        )
        .merged()
        print()
    }
}
