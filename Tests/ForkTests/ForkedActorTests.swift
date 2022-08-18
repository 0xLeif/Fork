import XCTest
@testable import Fork

class ForkedActorTests: XCTestCase {
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
        let forkedActor = ForkedActor(
            value: 0,
            leftOutput: { actor in
                await actor.update(to: { $0 + 1 })
            },
            rightOutput: { actor in
                try await actor.fork(
                    leftOutput: { actor in
                        await actor.update(to: { $0 + 1 })
                    },
                    rightOutput: { actor in
                        await actor.update(\.self, to: { $0 + 1 })
                    }
                )
                .act()
            }
        )
        
        let actorValue = try await forkedActor.act().value
        
        XCTAssertEqual(actorValue, 3)
    }
}
