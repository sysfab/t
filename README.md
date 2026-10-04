# t - the only table library you will need

`t` is a dependency-free table utility library for LuaJIT. It extends LuaJIT's
native `table` module with iteration, predicates, transformations, set
operations, copying, merging, randomization, and more.

## Installation

Add `t` to an [lde](https://lde.sh) project:

```sh
lde add t
```

Then require it by package name:

```lua
local t = require("t")
```

`t` targets the LuaJIT runtime provided by lde. Other Lua runtimes are not
supported.

## Quick Start

```lua
local t = require("t")

local users = {
    {name = "Ada", age = 36},
    {name = "Grace", age = 28},
    {name = "Linus", age = 17},
}

local adults = t.filter(users, function(user)
    return user.age >= 18
end)

local names = t.map(adults, function(user)
    return user.name
end)

print(t.concat(names, ", ")) -- Ada, Grace
```

## Conventions

- Call methods with dot syntax: `t.map(input, callback)`, not `t:map(...)`.
- Callbacks receive `(value, key)`. Reducers receive `(accumulator, value, key)`.
- Methods return new tables unless they are under `t.nocopy`.
- `t.nocopy` methods mutate and return the input table.
- Array methods expect dense, one-based arrays unless stated otherwise.
- Map-like traversal uses `next`, so its order is unspecified and `__pairs`
  metamethods are ignored.
- Mapping callbacks used by `map` and `map_deep` may return `nil` to omit or
  delete an entry. Key-producing callbacks must return a non-`nil` key.
- Predicates use LuaJIT's standard truthiness rules.
- Deep operations preserve cycles. `flatten_deep` instead raises an error when it
  encounters a cycle because a cyclic array cannot be flattened finitely.

## Supported Native Table Methods

The following native table methods form `t`'s supported compatibility surface:

```lua
t.concat
t.foreach
t.foreachi
t.getn
t.insert
t.maxn
t.move
t.pack
t.remove
t.sort
t.unpack
```

These retain their native signatures and mutation behavior. This is a fixed
list rather than a dynamic export of every field in `table`. `t.pack` and
`t.unpack` use runtime implementations when available and otherwise provide
equivalent behavior.

## Iteration

### `t.for_pairs(input, callback)`

Calls `callback(value, key)` for every raw entry using `next`. Iteration order
is unspecified and `__pairs` metamethods are ignored.

```lua
t.for_pairs({width = 80, height = 24}, function(value, key)
    print(key, value)
end)
```

### `t.for_ipairs(input, callback)`

Calls `callback(value, index)` for every array element in index order.

## Checks

### `t.is_empty(value) -> boolean`

Returns `true` only when `value` is a table with no entries. Non-table values
return `false`.

### `t.has(input, value) -> boolean`

Returns whether any entry is equal to `value`.

### `t.has_key(input, key) -> boolean`

Returns whether `key` is present in the table. Values supplied by an `__index`
metatable are ignored.

```lua
t.has_key({name = "Ada"}, "name") -- true
t.has_key({name = "Ada"}, "age")  -- false
```

### `t.count(input [, predicate]) -> integer`

Returns the number of entries in a table. When a predicate is supplied, only
entries for which `predicate(value, key)` returns a truthy value are counted.

```lua
t.count({a = 10, b = 20}) -- 2

t.count({1, 2, 3, 4}, function(value)
    return value % 2 == 0
end) -- 2
```

### `t.find(input, predicate) -> key?, value?`

Returns the key and value of the first entry for which
`predicate(value, key)` is truthy. Returns `nil` when no entry matches. Arrays
are searched in index order; map order is unspecified.

```lua
local index, value = t.find({10, 20, 30}, function(item)
    return item > 15
end)

print(index, value) -- 2  20
```

### `t.any(input, predicate) -> boolean`

Returns `true` when at least one call to `predicate(value, key)` returns a
truthy value. An empty table returns `false`.

### `t.all(input, predicate) -> boolean`

Returns `true` when every call to `predicate(value, key)` returns a truthy
value. An empty table returns `true`.

### `t.is_array(value) -> boolean`

Returns whether `value` is a dense table whose keys are consecutive positive
integers starting at `1`. The empty table is considered an array.

### `t.equals(left, right) -> boolean`

Returns whether two values are equal. Tables are compared one level deep, so
nested tables must be the same table. Table keys use normal Lua identity.

```lua
t.equals({x = 1, y = 2}, {x = 1, y = 2}) -- true
t.equals({x = {1}}, {x = {1}})           -- false
```

### `t.equals_deep(left, right) -> boolean`

Recursively compares table values. Cycles and shared references are supported
and must have corresponding structure in both values. Table keys use normal Lua
identity.

```lua
t.equals_deep({user = {id = 1}}, {user = {id = 1}}) -- true
t.equals_deep({1, {2, 3}}, {1, {2, 4}})             -- false
```

## Transformations

### `t.filter(input, predicate) -> table`

Returns entries for which `predicate(value, key)` is truthy. Array results are
compacted while preserving order; map results retain their original keys.

### `t.partition(input, predicate) -> accepted, rejected`

Splits an array into values for which `predicate(value, index)` is truthy and
those for which it is falsey. Both result arrays preserve input order.

```lua
local even, odd = t.partition({1, 2, 3, 4}, function(value)
    return value % 2 == 0
end)

-- even is {2, 4}
-- odd is {1, 3}
```

### `t.map(input, callback) -> table`

Returns a new table with the same keys and values produced by
`callback(value, key)`. A `nil` result omits that key.

```lua
local squares = t.map({2, 3, 4}, function(value)
    return value * value
end)
-- {4, 9, 16}
```

### `t.map_keys(input, callback) -> table`

Returns a new table with the same values under keys produced by
`callback(value, key)`. Traversal order is unspecified. If multiple entries
produce the same key, the last visited value wins. Returning `nil` raises the
standard LuaJIT `table index is nil` error.

```lua
local upper = t.map_keys({first = "Ada", last = "Lovelace"}, function(_, key)
    return key:upper()
end)

-- upper is {FIRST = "Ada", LAST = "Lovelace"}
```

### `t.pick(input, keys) -> table`

Returns a shallow table containing only the requested keys. Missing keys and
values provided by an `__index` metatable are ignored.

```lua
local public = t.pick({id = 1, name = "Ada", password = "secret"}, {
    "id",
    "name",
})

-- public is {id = 1, name = "Ada"}
```

### `t.omit(input, keys) -> table`

Returns a shallow copy without the requested keys.

```lua
local public = t.omit({id = 1, name = "Ada", password = "secret"}, {
    "password",
})

-- public is {id = 1, name = "Ada"}
```

### `t.group_by(input, callback) -> table`

Groups values into arrays under the keys returned by `callback(value, key)`.
Array input preserves value order within each group; map input order is
unspecified. Returning `nil` from the callback raises the standard LuaJIT
`table index is nil` error.

```lua
local grouped = t.group_by({1, 2, 3, 4}, function(value)
    return value % 2 == 0 and "even" or "odd"
end)

-- grouped.even is {2, 4}
-- grouped.odd is {1, 3}
```

### `t.index_by(input, callback) -> table`

Indexes values under the keys returned by `callback(value, key)`. Arrays are
visited in index order; map order is unspecified. If multiple values produce
the same key, the last visited value wins. Returning `nil` from the callback
raises the standard LuaJIT `table index is nil` error.

```lua
local users = {
    {id = 10, name = "Ada"},
    {id = 20, name = "Grace"},
}

local by_id = t.index_by(users, function(user)
    return user.id
end)

-- by_id[10].name is "Ada"
```

### `t.map_deep(input, callback) -> table`

Recursively copies `input` and transforms each non-table value with
`callback(value, key)`. Table-valued keys are recursively copied and mapped.
Shared references, cycles, and table metatables are preserved. A `nil` callback
result omits the corresponding value. If the debug library is unavailable, a
metatable hidden by `__metatable` cannot be preserved.

### `t.reduce(input, callback [, initial]) -> value?`

Combines entries with `callback(accumulator, value, key)`. Without an initial
value, the first entry becomes the accumulator. Reducing an empty table without
an initial value returns `nil`.

```lua
local total = t.reduce({2, 4, 6}, function(sum, value)
    return sum + value
end, 0)
-- 12
```

### `t.flatten(input) -> array`

Returns a new array with one level of nested arrays flattened.

```lua
t.flatten({1, {2, 3}, 4}) -- {1, 2, 3, 4}
```

### `t.flatten_deep(input) -> array`

Recursively flattens nested arrays. Raises `cycle detected in flatten_deep` if
a nested array refers back to an active ancestor. Reusing the same non-cyclic
array in separate branches is allowed.

```lua
t.flatten_deep({1, {2, {3, 4}}}) -- {1, 2, 3, 4}
```

### `t.slice(input, first [, last]) -> array`

Returns a new array containing values between the inclusive `first` and `last`
indices. `last` defaults to the end of the input. Both bounds must be integers
and are clamped to the array bounds.

```lua
t.slice({"a", "b", "c", "d"}, 2, 3) -- {"b", "c"}
t.slice({"a", "b", "c", "d"}, 3)    -- {"c", "d"}
```

### `t.chunk(input, size) -> array`

Splits an array into smaller arrays containing at most `size` values. `size`
must be a positive integer.

```lua
t.chunk({1, 2, 3, 4, 5}, 2) -- {{1, 2}, {3, 4}, {5}}
```

### `t.keys(input) -> array`

Returns all keys in unspecified order.

### `t.values(input) -> array`

Returns all values in unspecified order.

### `t.zip(left, right) -> array`

Pairs corresponding array elements up to the length of the shorter input.

```lua
t.zip({"a", "b"}, {1, 2, 3}) -- {{"a", 1}, {"b", 2}}
```

## Set Operations

Set operations accept arrays, remove duplicate values, and preserve first-seen
order. Equality follows Lua's table-key equality rules.

### `t.unique(input) -> array`

Returns the input values without duplicates.

### `t.union(left, right) -> array`

Returns unique values found in either array, scanning `left` before `right`.

### `t.intersection(left, right) -> array`

Returns unique values from `left` that also occur in `right`.

### `t.difference(left, right) -> array`

Returns unique values from `left` that do not occur in `right`.

```lua
t.union({1, 2}, {2, 3})        -- {1, 2, 3}
t.intersection({1, 2}, {2, 3}) -- {2}
t.difference({1, 2}, {2, 3})   -- {1}
```

## Merging

### `t.merge(left, right) -> table`

Returns a shallow merge. Entries from `right` replace entries with the same key
from `left`. Nested tables remain shared with their source.

### `t.merge_deep(left, right) -> table`

Recursively merges table values into a new structure. Right-hand scalar values
take precedence, neither input is mutated, and cycles are preserved. A shared
non-cyclic source table reached through multiple keys is merged independently
at each key, so existing branches do not lose data.

```lua
local defaults = {
    host = "localhost",
    database = {port = 5432, pool = 5},
}

local config = t.merge_deep(defaults, {
    database = {pool = 20},
})

-- config.database is {port = 5432, pool = 20}
```

## Copying

### `t.copy(value) -> value`

Returns a shallow copy of a table and preserves its metatable. Non-table values
are returned unchanged. If the debug library is unavailable, a metatable hidden
by `__metatable` cannot be preserved.

### `t.copy_deep(value) -> value`

Recursively copies table keys and values. Metatables, shared references, and
cycles are preserved. Non-table values are returned unchanged. If the debug
library is unavailable, metatables hidden by `__metatable` cannot be preserved.

## Randomization And Order

Random methods use Lua's global `math.random` generator. Seed it according to
your application's requirements.

### `t.choice(input) -> value?`

Returns a random array element, or `nil` for an empty array.

### `t.shuffle(input) -> array`

Returns a randomly shuffled copy using the Fisher-Yates algorithm.

### `t.reverse(input) -> array`

Returns a reversed copy of an array.

## In-Place Operations

The `nocopy` namespace contains mutating variants. Each operation returns the
same table it receives.

| Method | Behavior |
| --- | --- |
| `t.nocopy.filter(input, predicate)` | Removes entries rejected by the predicate. Arrays are compacted. |
| `t.nocopy.map(input, callback)` | Replaces every value with the callback result. A `nil` result deletes the entry. |
| `t.nocopy.map_keys(input, callback)` | Replaces every key with the callback result. A `nil` key raises an error. |
| `t.nocopy.map_deep(input, callback)` | Recursively replaces every non-table value, including values nested in table-valued keys. A `nil` result deletes the entry. Cycles are supported. |
| `t.nocopy.merge(left, right)` | Shallowly merges `right` into `left`. Nested tables remain shared with `right`. |
| `t.nocopy.merge_deep(left, right)` | Recursively merges `right` into `left`. Inherited left-hand values are ignored, existing left-hand tables also reachable from `right` are copied before merging, and cycles are preserved. |
| `t.nocopy.unique(input)` | Removes duplicate array values while preserving first-seen order. |
| `t.nocopy.shuffle(input)` | Randomly shuffles an array in place. |
| `t.nocopy.reverse(input)` | Reverses an array in place. |

```lua
local values = {1, 2, 3, 4}

t.nocopy.filter(values, function(value)
    return value % 2 == 0
end)

-- values is now {2, 4}
```

```lua
local config = {
    host = "localhost",
    database = {port = 5432, pool = 5},
}

t.nocopy.merge_deep(config, {
    database = {pool = 20},
})

-- config.database is {port = 5432, pool = 20}
```
