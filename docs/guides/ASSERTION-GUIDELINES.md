# Assertion Guidelines for KimiZ

**Target**: 1.5 assertions per function (TigerBeetle standard)

---

## When to Use Assertions

### ✅ Always Assert

1. **Preconditions** (function inputs):
   ```zig
   pub fn process(data: []const u8) !void {
       std.debug.assert(data.len > 0); // Input must be non-empty
       // ...
   }
   ```

2. **Invariants** (state that must always hold):
   ```zig
   pub fn allocate(self: *Self) !void {
       std.debug.assert(self.alloc_count >= self.free_count); // Never more frees than allocs
       // ...
   }
   ```

3. **Postconditions** (function outputs/effects):
   ```zig
   pub fn append(self: *Self, item: T) !void {
       const prev_len = self.items.len;
       try self.items.append(item);
       std.debug.assert(self.items.len == prev_len + 1); // Length increased by 1
   }
   ```

4. **Loop invariants**:
   ```zig
   while (index < max_iterations) {
       std.debug.assert(index < max_iterations); // Loop bound respected
       index += 1;
   }
   ```

5. **Bounds checking**:
   ```zig
   pub fn get(self: *Self, index: usize) T {
       std.debug.assert(index < self.items.len); // Index in bounds
       return self.items[index];
   }
   ```

---

## When NOT to Use Assertions

### ❌ Never Assert

1. **Recoverable errors** (use error returns):
   ```zig
   // ❌ Wrong:
   std.debug.assert(file != null);
   
   // ✅ Correct:
   if (file == null) return error.FileNotFound;
   ```

2. **User input validation** (should fail gracefully):
   ```zig
   // ❌ Wrong:
   std.debug.assert(input.len < MAX_LEN);
   
   // ✅ Correct:
   if (input.len >= MAX_LEN) return error.InputTooLarge;
   ```

3. **External system failures** (network, disk, etc.):
   ```zig
   // ❌ Wrong:
   std.debug.assert(response.status == .ok);
   
   // ✅ Correct:
   if (response.status != .ok) return mapStatusToError(response.status);
   ```

---

## Assertion Patterns

### Pattern 1: Parameter Validation

```zig
pub fn createWorktree(self: *Self, name: []const u8) ![]const u8 {
    std.debug.assert(name.len > 0); // Name must be non-empty
    std.debug.assert(self.repo_path.len > 0); // Manager must be initialized
    
    // ... implementation ...
}
```

### Pattern 2: State Machine Constraints

```zig
pub fn transition(self: *Self, new_state: State) void {
    std.debug.assert(self.state != new_state); // No self-transitions
    std.debug.assert(isValidTransition(self.state, new_state)); // Valid state change
    
    self.state = new_state;
}
```

### Pattern 3: Counter Monotonicity

```zig
pub fn increment(self: *Self) void {
    const prev = self.count;
    self.count += 1;
    std.debug.assert(self.count == prev + 1); // Incremented correctly
    std.debug.assert(self.count > 0); // Never overflowed
}
```

### Pattern 4: Memory Balancing

```zig
pub fn deinit(self: *Self) void {
    std.debug.assert(self.alloc_count == self.free_count); // All memory freed
    std.debug.assert(self.liveSize() == 0); // No leaks
    
    // ... cleanup ...
}
```

### Pattern 5: Collection Consistency

```zig
pub fn remove(self: *Self, index: usize) T {
    std.debug.assert(index < self.items.len); // Index valid
    const prev_len = self.items.len;
    
    const item = self.items.orderedRemove(index);
    
    std.debug.assert(self.items.len == prev_len - 1); // Length decreased
    return item;
}
```

---

## Assertion Density Targets

| Module Type | Target Density | Priority |
|-------------|----------------|----------|
| **Core Algorithms** | 2.0+/fn | P0 |
| **Memory Management** | 2.5+/fn | P0 |
| **Public APIs** | 1.5/fn | P1 |
| **Internal Helpers** | 1.0/fn | P2 |
| **Test Code** | 0.5/fn | P3 |

---

## How to Check Assertion Density

### Manual Check (single file)
```bash
fns=$(grep -c "fn " src/agent/agent.zig)
asserts=$(grep -c "assert(" src/agent/agent.zig)
density=$(echo "scale=2; $asserts / $fns" | bc -l)
echo "$fns functions, $asserts asserts ($density per fn)"
```

### Automated Check (all files)
```bash
make check-assertions
```

### Strict Check (fails if < 1.5/fn)
```bash
make check-assertions-strict
```

### Generate Report
```bash
make report-assertions
```

---

## Common Mistakes

### ❌ Mistake 1: Tautological Assertions
```zig
// Bad: Always true
std.debug.assert(true);
std.debug.assert(x == x);
```

### ❌ Mistake 2: Side Effects in Assertions
```zig
// Bad: Mutation in assert (disabled in release mode!)
std.debug.assert(self.increment() > 0);

// Good: Assert result of pure operation
self.increment();
std.debug.assert(self.count > 0);
```

### ❌ Mistake 3: Too Weak Assertions
```zig
// Bad: Doesn't catch bugs
std.debug.assert(ptr != null or ptr == null); // Always true

// Good: Meaningful check
std.debug.assert(ptr != null); // Pointer must be valid
```

---

## Assertion Checklist

Before submitting code, ask:

- [ ] All function parameters validated?
- [ ] All invariants documented and asserted?
- [ ] All state transitions checked?
- [ ] All loop bounds verified?
- [ ] All counter operations validated?
- [ ] Assertion density ≥ 1.5/fn?

---

## References

- [TigerBeetle Style Guide](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md)
- [Zig Language Reference - assert](https://ziglang.org/documentation/master/#assert)
- [Assertion Density Improvement Plan](../designs/assertion-density-improvement.md)
