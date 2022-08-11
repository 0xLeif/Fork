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
    
    func testForkedActor() async throws {
        actor TestActor {
            var value: String
            
            init(value: String) { self.value = value }
            
            func update(value: String) {
                self.value = value
            }
        }
        
        let initValue = "init"
        
        let forkedActor = ForkedActor(
            actor: TestActor(value: initValue),
            leftOutput: { actor in
                print("Left: \(await actor.value)")
                
                await actor.update(value: "Left")
            },
            rightOutput: { actor in
                print("Right: \(await actor.value)")
                
                await actor.update(value: "Right")
            }
        )
        
        try await forkedActor.act()
        
        let actorValue = await forkedActor.actor.value
        print(actorValue)
        
        XCTAssertNotEqual(actorValue, initValue)
    }
    
    func testHigherOrderForkedActor() async throws {
        actor TestActor {
            var value: Int = 0
            
            func increment() {
                value += 1
            }
        }
        
        let forkedActor = ForkedActor(
            actor: TestActor(),
            leftOutput: { actor in
                await actor.increment()
            },
            rightOutput: { actor in
                try await actor.fork(
                    leftOutput: { await $0.increment() },
                    rightOutput: { await $0.increment() }
                )
                .act()
            }
        )
        
        try await forkedActor.act()
        
        let actorValue = await forkedActor.actor.value
        
        XCTAssertEqual(actorValue, 3)
    }
}
