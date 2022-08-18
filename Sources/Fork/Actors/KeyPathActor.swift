/// A generic Actor that uses KeyPaths to update and set values
public actor KeyPathActor<Value> {
    
    /// The wrapped value of the Actor
    public var value: Value
    
    /// Wrapped the Value into a KeyPathActor
    public init(value: Value) { self.value = value }
    
    /// Set the value
    public func set(
        to newValue: Value
    ) { value = newValue }
    
    /// Set the key path to a new value
    public func set<KeyPathValue>(
        _ keyPath: WritableKeyPath<Value, KeyPathValue>,
        to newValue: KeyPathValue
    ) { value[keyPath: keyPath] = newValue }
    
    /// Update the value
    public func update(
        to newValue: (Value) -> Value
    ) { set(to: newValue(value)) }
    
    /// Update the key path to a new value
    public func update<KeyPathValue>(
        _ keyPath: WritableKeyPath<Value, KeyPathValue>,
        to newValue: (KeyPathValue) -> KeyPathValue
    ) { set(keyPath, to: newValue(value[keyPath: keyPath])) }
}
