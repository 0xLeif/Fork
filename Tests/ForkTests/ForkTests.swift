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
    
    func testForkLeftVoid() async throws {
        let expectedValue = "RIGHT"
        let value = try await Fork(
            leftOutput: { () },
            rightOutput: { expectedValue }
        )
            .merged()
        
        XCTAssertEqual(value, expectedValue)
    }
    
    func testForkRightVoid() async throws {
        let expectedValue = "LEFT"
        let value = try await Fork(
            leftOutput: { expectedValue },
            rightOutput: { () }
        )
            .merged()
        
        XCTAssertEqual(value, expectedValue)
    }
    
    func testForkCancel() async throws {
        let fork = Fork(
            leftOutput: {
                try await Task.sleep(nanoseconds: 100_000_000)
            },
            rightOutput: {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        )
        
        let forkedTask = Task {
            do {
                try await fork.merged { _, _ in
                    XCTFail()
                }
            } catch is CancellationError {
                XCTAssert(true)
            } catch {
                XCTFail()
            }
        }
        
        forkedTask.cancel()
        
        await forkedTask.value
    }
}
