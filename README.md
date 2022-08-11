# Fork

*Using a single input create two separate async functions*

## What is Fork?

Fork allows for a single input to create two separate async functions that return potentially different outputs. Forks can also merge their two functions into one which returns a single output.

> The word "fork" has been used to mean "to divide in branches, go separate ways" as early as the 14th century. In the software environment, the word evokes the fork system call, which causes a running process to split itself into two (almost) identical copies that (typically) diverge to perform different tasks.
[Source](https://en.wikipedia.org/wiki/Fork_(software_development)#Etymology)

## Basic usage

```swift
import Fork
```

## Fork Example

```swift
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
        
let output = await mergedFork()

XCTAssertEqual(output, "1010")
```

## ForkedActor Example

```swift
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
```

## Extra Examples

### Service Example

```swift
let service = Fork(
    value: AppConfiguration(),
    leftOutput: { configuration in
        Fork(
            value: AuthService(configuration),
            leftOutput: { authService in ... },
            rightOutput: { authService in ... }
        )
    },
    rightOutput: { configuration in
        ...
    }
)

let mergedServiceFork: async throws () -> AppServices = service.merge(
    using: { authFork, configurationOutput in
        let services = try await authFork.merged(...)
            
        services.logger.log(configurationOutput)
            
        return services
    }
)
```
