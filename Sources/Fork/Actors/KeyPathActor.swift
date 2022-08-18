public actor KeyPathActor<Value> {
    public var value: Value
    
    public init(value: Value) { self.value = value }
    
    public func set(
        to newValue: Value
    ) { value = newValue }
    
    public func set<KeyPathValue>(
        _ keyPath: WritableKeyPath<Value, KeyPathValue>,
        to newValue: KeyPathValue
    ) { value[keyPath: keyPath] = newValue }
    
    public func update(
        to newValue: (Value) -> Value
    ) { set(to: newValue(value)) }
    
    public func update<KeyPathValue>(
        _ keyPath: WritableKeyPath<Value, KeyPathValue>,
        to newValue: (KeyPathValue) -> KeyPathValue
    ) { set(keyPath, to: newValue(value[keyPath: keyPath])) }
}
