# Fork

*Using a single input create two separate async functions*

## What is Fork?

Fork allows for a single input to create two separate async functions that return potentially different outputs. Forks can also merge their two functions into one which returns a single output.

> The word "fork" has been used to mean "to divide in branches, go separate ways" as early as the 14th century. In the software environment, the word evokes the fork system call, which causes a running process to split itself into two (almost) identical copies that (typically) diverge to perform different tasks.
[Source](https://en.wikipedia.org/wiki/Fork_(software_development)#Etymology)

## Why use Fork?

Swift async-await makes it easy to write more complicated asynchronous code, but it can be difficult to parallelize multiple functions.

The [Swift Book](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html#ID641) has the following example for downloading multiple images.

```swift
let firstPhoto = await downloadPhoto(named: photoNames[0])
let secondPhoto = await downloadPhoto(named: photoNames[1])
let thirdPhoto = await downloadPhoto(named: photoNames[2])

let photos = [firstPhoto, secondPhoto, thirdPhoto]
show(photos)
```

Now the code above is still asynchronous, but will only run one function at a time. In the example above, `firstPhoto` will be set first, then `secondPhoto`, and finally `thirdPhoto`.

To run these three async functions in parallel we need to change the code to this following example.

```swift
async let firstPhoto = downloadPhoto(named: photoNames[0])
async let secondPhoto = downloadPhoto(named: photoNames[1])
async let thirdPhoto = downloadPhoto(named: photoNames[2])

let photos = await [firstPhoto, secondPhoto, thirdPhoto]
show(photos)
```

The above code will now download all three photos at the same time. When all the photos have been downloaded it will show the photos.

This is a simple async-await example of running code in parallel in which you might not need to use Fork. More complicated examples though might require async dependencies. For example what if we needed to authenticate with a server; then use the auth token to download the photos while also fetching some data from the database. This is where Fork is useful!

When using Fork or ForkedActor, both functions will be ran in parallel. Higher order forks will also be ran in parallel.

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

### [Vapor ForkedActor Example](https://github.com/0xLeif/VaporForkDemo)

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
