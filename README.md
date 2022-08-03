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

## Basic Example

```swift
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
```

## Service Example

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

let mergedServiceFork: async () -> AppServices = service.merge(
    using: { authFork, configurationOutput in
        guard let services = authFork.merged(...) else { return }
            
        services.logger.log(configurationOutput)
            
        return services
    }
)
```
