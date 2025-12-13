import XCTest
@testable import Fork

/// Tests for actor isolation guarantees in Fork operations
final class ForkActorIsolationTests: XCTestCase, @unchecked Sendable {

    // MARK: - ForkedActor Isolation Tests

    func testForkedActor_isolationPreserved() async throws {
        actor IsolatedState {
            private var internalValue = 0

            func increment() -> Int {
                internalValue += 1
                return internalValue
            }

            func getValue() -> Int {
                internalValue
            }
        }

        let state = IsolatedState()

        // Both branches access the actor - isolation should be preserved
        let forkedActor = ForkedActor(
            actor: state,
            leftOutput: { actor in
                for _ in 0..<10 {
                    _ = await actor.increment()
                }
            },
            rightOutput: { actor in
                for _ in 0..<10 {
                    _ = await actor.increment()
                }
            }
        )

        _ = try await forkedActor.act()
        let finalValue = await state.getValue()

        // Actor isolation ensures sequential access, so final value should be 20
        XCTAssertEqual(finalValue, 20)
    }

    func testForkedActor_nestedActorCalls() async throws {
        actor OuterActor {
            let inner: InnerActor

            init(inner: InnerActor) {
                self.inner = inner
            }

            func outerIncrement() async -> Int {
                await inner.increment()
            }
        }

        actor InnerActor {
            var value = 0

            func increment() -> Int {
                value += 1
                return value
            }

            func getValue() -> Int { value }
        }

        let inner = InnerActor()
        let outer = OuterActor(inner: inner)

        let forkedActor = ForkedActor(
            actor: outer,
            leftOutput: { actor in
                for _ in 0..<5 {
                    _ = await actor.outerIncrement()
                }
            },
            rightOutput: { actor in
                for _ in 0..<5 {
                    _ = await actor.outerIncrement()
                }
            }
        )

        _ = try await forkedActor.act()
        let finalValue = await inner.getValue()

        XCTAssertEqual(finalValue, 10, "Nested actor calls should work correctly")
    }

    // MARK: - KeyPathActor Tests

    func testKeyPathActor_allOperations() async throws {
        struct TestState: Sendable, Equatable {
            var count: Int = 0
            var name: String = "initial"
            var items: [Int] = []
        }

        let keyPathActor = KeyPathActor(value: TestState())

        // Test set(to:)
        await keyPathActor.set(to: TestState(count: 10, name: "updated", items: [1, 2, 3]))
        var state = await keyPathActor.value
        XCTAssertEqual(state.count, 10)
        XCTAssertEqual(state.name, "updated")
        XCTAssertEqual(state.items, [1, 2, 3])

        // Test set(_:to:) for keypath
        await keyPathActor.set(\TestState.count, to: 20)
        state = await keyPathActor.value
        XCTAssertEqual(state.count, 20)

        // Test update(to:)
        await keyPathActor.update { state in
            var newState = state
            newState.count += 5
            newState.name = "transformed"
            return newState
        }
        state = await keyPathActor.value
        XCTAssertEqual(state.count, 25)
        XCTAssertEqual(state.name, "transformed")

        // Test update(_:to:) for keypath
        await keyPathActor.update(\TestState.items) { items in
            items + [4, 5]
        }
        state = await keyPathActor.value
        XCTAssertEqual(state.items, [1, 2, 3, 4, 5])
    }

    func testKeyPathActor_complexTypes() async throws {
        struct NestedData: Sendable, Equatable {
            var id: Int
            var metadata: [String: Int]
        }

        struct ComplexState: Sendable {
            var primary: NestedData
            var secondary: NestedData?
            var tags: Set<String>
        }

        let initial = ComplexState(
            primary: NestedData(id: 1, metadata: ["a": 1]),
            secondary: nil,
            tags: ["tag1"]
        )

        let keyPathActor = KeyPathActor(value: initial)

        // Update nested data
        await keyPathActor.set(\ComplexState.primary.id, to: 100)
        var state = await keyPathActor.value
        XCTAssertEqual(state.primary.id, 100)

        // Update optional
        await keyPathActor.set(\ComplexState.secondary, to: NestedData(id: 2, metadata: [:]))
        state = await keyPathActor.value
        XCTAssertNotNil(state.secondary)
        XCTAssertEqual(state.secondary?.id, 2)

        // Update set
        await keyPathActor.update(\ComplexState.tags) { $0.union(["tag2", "tag3"]) }
        state = await keyPathActor.value
        XCTAssertEqual(state.tags, ["tag1", "tag2", "tag3"])
    }

    // MARK: - Actor Reentrancy Tests

    func testForkedActor_actorReentrancy() async throws {
        actor ReentrantActor {
            var callStack: [String] = []

            func methodA() async -> String {
                callStack.append("A-start")
                // Simulate some async work
                try? await Task.sleep(for: .milliseconds(10))
                callStack.append("A-end")
                return "A"
            }

            func methodB() async -> String {
                callStack.append("B-start")
                try? await Task.sleep(for: .milliseconds(10))
                callStack.append("B-end")
                return "B"
            }

            func getCallStack() -> [String] { callStack }
        }

        let reentrantActor = ReentrantActor()

        let forkedActor = ForkedActor(
            actor: reentrantActor,
            leftOutput: { actor in _ = await actor.methodA() },
            rightOutput: { actor in _ = await actor.methodB() }
        )

        _ = try await forkedActor.act()
        let callStack = await reentrantActor.getCallStack()

        // Both methods should have been called
        XCTAssertTrue(callStack.contains("A-start"))
        XCTAssertTrue(callStack.contains("A-end"))
        XCTAssertTrue(callStack.contains("B-start"))
        XCTAssertTrue(callStack.contains("B-end"))
        XCTAssertEqual(callStack.count, 4)
    }

    // MARK: - Actor Extension Tests

    func testActorForkExtension_createsValidFork() async throws {
        actor SimpleActor {
            var value = 0
            func add(_ amount: Int) { value += amount }
            func getValue() -> Int { value }
        }

        let simpleActor = SimpleActor()

        // Use the actor extension method - need to call from within actor context
        let forkedActor = await simpleActor.fork(
            leftOutput: { actor in await actor.add(10) },
            rightOutput: { actor in await actor.add(20) }
        )

        _ = try await forkedActor.act()
        let finalValue = await simpleActor.getValue()

        XCTAssertEqual(finalValue, 30)
    }
}
