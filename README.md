# Fork

*Parallelize two or more async functions*

## What is Fork?

Fork is a Swift library that allows for parallelizing multiple async functions. It provides a Fork struct that takes a single input and splits it into two separate async functions that return different outputs. The two functions can then be merged into one which returns a single output.

## Why use Fork?

Asynchronous programming in Swift can be made easier with the async-await syntax, but it can still be challenging to parallelize multiple functions. Fork simplifies this by allowing developers to create parallel tasks with ease.

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

Now, using Fork we could simiplfy this to just a couple of lines!

```swift
let photos = try await photoNames.asyncMap(downloadPhoto(named:))
show(photos)
```

When using Fork, functions will be ran in parallel and higher order forks will also be ran in parallel.

## Objects 
- `Fork`: Using a single input create two separate async functions that return `LeftOutput` and `RightOutput`.
- `ForkedActor`: Using a single actor create two separate async functions that are passed the actor.
    - `KeyPathActor`: A generic Actor that uses KeyPaths to update and set values.
- `ForkedArray`: Using a single array and a single async function, parallelize the work for each value of the array.

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

let actorValue = await forkedActor.act().value

XCTAssertEqual(actorValue, 3)
```

### ForkedActor KeyPathActor<Int> Example

```swift
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
```

## ForkedArray Example

A ForkedArray makes it easy to perform an asynchronous function on all of the elements in an Array. ForkedArray helps with the [example](#why-use-fork) above.

```swift
let forkedArray = ForkedArray(photoNames, output: downloadPhoto(named:))
let photos = try await forkedArray.output()
```


## Extra Examples

### [Vapor ForkedActor Example](https://github.com/0xLeif/VaporForkDemo)
### [ForkedArray Pictures Example](https://github.com/0xLeif/ForkedArrayPicturesExample)
