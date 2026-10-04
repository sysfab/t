---t - the only table library you will need
---@class tlib
---@field nocopy tlib.nocopy
local lib = {}

local function raw_pairs(t)
    return next, t, nil
end

local get_metatable = debug and debug.getmetatable or getmetatable

lib.concat = table.concat
lib.foreach = table.foreach
lib.foreachi = table.foreachi
lib.getn = table.getn
lib.insert = table.insert
lib.maxn = table.maxn
lib.move = table.move
lib.pack = table.pack or rawget(_G, "pack") or function(...)
    return {n = select("#", ...), ...}
end
lib.remove = table.remove
lib.sort = table.sort

local native_unpack = table.unpack or rawget(_G, "unpack")
if native_unpack then
    lib.unpack = native_unpack
else
    local function unpack_values(t, first, last)
        if first > last then return end
        return t[first], unpack_values(t, first + 1, last)
    end

    function lib.unpack(t, first, last)
        return unpack_values(t, first or 1, last or #t)
    end
end

---In-place variants that mutate and return their input table.
---@class tlib.nocopy
lib.nocopy = {}

-- Loops
---Calls a function once for each key-value pair in unspecified order.
---@generic K, V
---@param t table<K, V>
---@param func fun(value: V, key: K)
function lib.for_pairs(t, func)
    for k,v in raw_pairs(t) do
        func(v,k)
    end
end

---Calls a function once for each array element in index order.
---@generic V
---@param t V[]
---@param func fun(value: V, index: integer)
function lib.for_ipairs(t, func)
    for i,v in ipairs(t) do
        func(v,i)
    end
end

-- Checks
---Returns whether a value is a table with no entries.
---@param t any
---@return boolean
function lib.is_empty(t)
    return type(t) == "table" and next(t) == nil
end

---Returns whether a table contains the given value.
---@generic K, V
---@param t table<K, V>
---@param value V
---@return boolean
function lib.has(t, value)
    for k,v in raw_pairs(t) do
        if value == v then return true end
    end
    return false
end

---Returns whether a table contains the given key.
---@generic K, V
---@param t table<K, V>
---@param key K
---@return boolean
function lib.has_key(t, key)
    return rawget(t, key) ~= nil
end

---Counts all entries, or entries accepted by an optional predicate.
---@generic K, V
---@param t table<K, V>
---@param func? fun(value: V, key: K): any
---@return integer
function lib.count(t, func)
    local count = 0
    for key, value in raw_pairs(t) do
        if func == nil or func(value, key) then
            count = count + 1
        end
    end
    return count
end

---Returns the key and value of the first entry accepted by a predicate.
---@generic K, V
---@param t table<K, V>
---@param func fun(value: V, key: K): any
---@return K? key
---@return V? value
function lib.find(t, func)
    if lib.is_array(t) then
        for k,v in ipairs(t) do
            if func(v,k) then return k,v end
        end
    else
        for k,v in raw_pairs(t) do
            if func(v,k) then return k,v end
        end
    end
    return nil
end

---Returns whether any entry makes a predicate return a truthy value.
---@generic K, V
---@param t table<K, V>
---@param func fun(value: V, key: K): any
---@return boolean
function lib.any(t, func)
    for k, v in raw_pairs(t) do
        if func(v, k) then return true end
    end
    return false
end

---Returns whether every entry makes a predicate return a truthy value.
---@generic K, V
---@param t table<K, V>
---@param func fun(value: V, key: K): any
---@return boolean
function lib.all(t, func)
    for k, v in raw_pairs(t) do
        if not func(v, k) then return false end
    end
    return true
end

---Returns whether a value is a dense, one-based array.
---@param t any
---@return boolean
function lib.is_array(t)
    if type(t) ~= "table" then return false end

    local count = 0
    local max = 0
    for k in raw_pairs(t) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
            return false
        end

        count = count + 1
        if k > max then max = k end
    end

    return count == max
end

---Returns whether two values are equal, comparing table contents one level deep.
---@param left any
---@param right any
---@return boolean
function lib.equals(left, right)
    if rawequal(left, right) then return true end
    if type(left) ~= "table" or type(right) ~= "table" then
        return left == right
    end

    for key, value in raw_pairs(left) do
        if not rawequal(value, rawget(right, key)) then return false end
    end
    for key in raw_pairs(right) do
        if rawget(left, key) == nil then return false end
    end
    return true
end

local function equals_deep(left, right, left_to_right, right_to_left)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end

    if left_to_right[left] or right_to_left[right] then
        return left_to_right[left] == right and right_to_left[right] == left
    end
    left_to_right[left] = right
    right_to_left[right] = left

    if rawequal(left, right) then return true end

    for key, value in raw_pairs(left) do
        local other = rawget(right, key)
        if other == nil or not equals_deep(value, other, left_to_right, right_to_left) then
            return false
        end
    end
    for key in raw_pairs(right) do
        if rawget(left, key) == nil then return false end
    end
    return true
end

---Returns whether two values are recursively equal, preserving cycle and reference structure.
---@param left any
---@param right any
---@return boolean
function lib.equals_deep(left, right)
    return equals_deep(left, right, {}, {})
end

-- Generators
---Returns a new table containing only entries accepted by a predicate.
---@generic K, V
---@param t table<K, V>
---@param func fun(value: V, key: K): any
---@return table<K, V>
function lib.filter(t, func)
    local result = {}
    local write = 1
    if lib.is_array(t) then
        for index = 1, #t do
            local value = t[index]
            if func(value, index) then
                result[write] = value
                write = write + 1
            end
        end
    else
        for key, value in raw_pairs(t) do
            if func(value, key) then result[key] = value end
        end
    end
    return result
end

---Splits an array into values accepted and rejected by a predicate.
---@generic V
---@param t V[]
---@param func fun(value: V, index: integer): any
---@return V[] accepted
---@return V[] rejected
function lib.partition(t, func)
    local accepted = {}
    local rejected = {}
    for index, value in ipairs(t) do
        local destination = func(value, index) and accepted or rejected
        destination[#destination + 1] = value
    end
    return accepted, rejected
end

---Combines all entries into one value using an accumulator function.
---@generic K, V, A
---@param t table<K, V>
---@param func fun(accumulator: A|V, value: V, key: K): A
---@param ... A Optional initial accumulator.
---@return A|V|nil
function lib.reduce(t, func, ...)
    local has_initial = select("#", ...) > 0
    local accumulator = ...

    if lib.is_array(t) then
        local first = 1
        if not has_initial then
            accumulator = t[1]
            first = 2
        end
        for index = first, #t do
            accumulator = func(accumulator, t[index], index)
        end
    else
        for key, value in raw_pairs(t) do
            if has_initial then
                accumulator = func(accumulator, value, key)
            else
                accumulator = value
                has_initial = true
            end
        end
    end

    return accumulator
end

---Flattens one level of nested arrays into a new array.
---@param t any[]
---@return any[]
function lib.flatten(t)
    local result = {}
    local write = 1
    for _, value in ipairs(t) do
        if type(value) == "table" and lib.is_array(value) then
            for index = 1, #value do
                result[write] = value[index]
                write = write + 1
            end
        else
            result[write] = value
            write = write + 1
        end
    end
    return result
end

local function append_flattened(result, value, active)
    if type(value) == "table" and lib.is_array(value) then
        if active[value] then error("cycle detected in flatten_deep") end
        active[value] = true
        for _, nested in ipairs(value) do
            append_flattened(result, nested, active)
        end
        active[value] = nil
    else
        result[#result + 1] = value
    end
end

---Recursively flattens nested arrays and errors when it encounters a cycle.
---@param t any[]
---@return any[]
function lib.flatten_deep(t)
    local result = {}
    if type(t) ~= "table" then return result end

    local active = {[t] = true}
    for _, value in ipairs(t) do
        append_flattened(result, value, active)
    end
    return result
end

---Returns a new array containing values between two inclusive indices.
---@generic V
---@param t V[]
---@param first integer
---@param last? integer
---@return V[]
function lib.slice(t, first, last)
    assert(type(first) == "number" and first % 1 == 0,
        "first must be an integer")
    assert(last == nil or type(last) == "number" and last % 1 == 0,
        "last must be an integer")

    local result = {}
    local final = math.min(last or #t, #t)
    for index = math.max(first, 1), final do
        result[#result + 1] = t[index]
    end
    return result
end

---Splits an array into arrays containing at most the requested number of values.
---@generic V
---@param t V[]
---@param size integer
---@return V[][]
function lib.chunk(t, size)
    assert(type(size) == "number" and size > 0 and size % 1 == 0,
        "size must be a positive integer")

    local result = {}
    for first = 1, #t, size do
        local chunk = {}
        local last = math.min(first + size - 1, #t)
        for index = first, last do
            chunk[#chunk + 1] = t[index]
        end
        result[#result + 1] = chunk
    end
    return result
end

---Removes entries rejected by a predicate from the input table in place.
---@generic K, V
---@param t table<K, V>
---@param func fun(value: V, key: K): any
---@return table<K, V> t
function lib.nocopy.filter(t, func)
    if lib.is_array(t) then
        local write = 1
        local length = #t
        for read = 1, length do
            local value = t[read]
            if func(value, read) then
                t[write] = value
                write = write + 1
            end
        end
        for i = write, length do
            t[i] = nil
        end
    else
        for k,v in raw_pairs(t) do
            if not func(v,k) then
                t[k] = nil
            end
        end
    end
    return t
end

---Transforms every value and returns the results in a new table.
---@generic K, V, R
---@param t table<K, V>
---@param func fun(value: V, key: K): R
---@return table<K, R>
function lib.map(t, func)
    local n = {}
    for k,v in raw_pairs(t) do
        n[k] = func(v,k)
    end
    return n
end

---Transforms every key and returns the results in a new table.
---@generic K, V, R
---@param t table<K, V>
---@param func fun(value: V, key: K): R
---@return table<R, V>
function lib.map_keys(t, func)
    local result = {}
    for key, value in raw_pairs(t) do
        result[func(value, key)] = value
    end
    return result
end

---Transforms every key in place and returns the input table.
---@generic K, V, R
---@param t table<K, V>
---@param func fun(value: V, key: K): R
---@return table<R, V> t
function lib.nocopy.map_keys(t, func)
    local result = lib.map_keys(t, func)
    for key in raw_pairs(t) do
        t[key] = nil
    end
    for key, value in raw_pairs(result) do
        t[key] = value
    end
    return t
end

---Returns a new table containing only the requested keys.
---@generic K, V
---@param t table<K, V>
---@param keys K[]
---@return table<K, V>
function lib.pick(t, keys)
    local result = {}
    for _, key in ipairs(keys) do
        local value = rawget(t, key)
        if value ~= nil then result[key] = value end
    end
    return result
end

---Returns a shallow copy without the requested keys.
---@generic K, V
---@param t table<K, V>
---@param keys K[]
---@return table<K, V>
function lib.omit(t, keys)
    local omitted = {}
    for _, key in ipairs(keys) do
        omitted[key] = true
    end

    local result = {}
    for key, value in raw_pairs(t) do
        if not omitted[key] then result[key] = value end
    end
    return result
end

---Groups values into arrays under keys produced by a callback.
---@generic K, V, G
---@param t table<K, V>
---@param func fun(value: V, key: K): G
---@return table<G, V[]>
function lib.group_by(t, func)
    local result = {}
    local iterator = lib.is_array(t) and ipairs or raw_pairs
    for key, value in iterator(t) do
        local group = func(value, key)
        local values = result[group]
        if values == nil then
            values = {}
            result[group] = values
        end
        values[#values + 1] = value
    end
    return result
end

---Indexes values under keys produced by a callback.
---@generic K, V, I
---@param t table<K, V>
---@param func fun(value: V, key: K): I
---@return table<I, V>
function lib.index_by(t, func)
    local result = {}
    local iterator = lib.is_array(t) and ipairs or raw_pairs
    for key, value in iterator(t) do
        result[func(value, key)] = value
    end
    return result
end

---Transforms every value in the input table in place.
---@generic K, V, R
---@param t table<K, V>
---@param func fun(value: V, key: K): R
---@return table<K, R> t
function lib.nocopy.map(t, func)
    for k,v in raw_pairs(t) do
        t[k] = func(v,k)
    end
    return t
end

local function map_deep_copy(tbl, func, copies)
    if copies[tbl] then return copies[tbl] end

    local n = {}
    copies[tbl] = n
    for k,v in raw_pairs(tbl) do
        local key = k
        if type(k) == "table" then
            key = map_deep_copy(k, func, copies)
        end
        if type(v) == "table" then
            n[key] = map_deep_copy(v, func, copies)
        else
            n[key] = func(v,k)
        end
    end

    local metatable = get_metatable(tbl)
    if type(metatable) == "table" then
        setmetatable(n, metatable)
    end
    return n
end

---Recursively transforms non-table values into a new table structure.
---Table-valued keys are recursively copied and transformed.
---@param t table
---@param func fun(value: any, key: any): any
---@return table
function lib.map_deep(t, func)
    if type(t) ~= "table" then return t end
    return map_deep_copy(t, func, {})
end

local function map_deep_in_place(tbl, func, visited)
    if visited[tbl] then return tbl end
    visited[tbl] = true

    for k,v in raw_pairs(tbl) do
        if type(k) == "table" then
            map_deep_in_place(k, func, visited)
        end
        if type(v) == "table" then
            map_deep_in_place(v, func, visited)
        else
            tbl[k] = func(v,k)
        end
    end
    return tbl
end

---Recursively transforms non-table values in place, including values nested in table keys.
---@param t table
---@param func fun(value: any, key: any): any
---@return table t
function lib.nocopy.map_deep(t, func)
    if type(t) ~= "table" then return t end
    return map_deep_in_place(t, func, {})
end

---Returns a new array containing every key in unspecified order.
---@generic K, V
---@param t table<K, V>
---@return K[]
function lib.keys(t)
    local result = {}
    local write = 1
    for key in raw_pairs(t) do
        result[write] = key
        write = write + 1
    end
    return result
end

---Returns a new array containing every value in unspecified order.
---@generic K, V
---@param t table<K, V>
---@return V[]
function lib.values(t)
    local result = {}
    local write = 1
    for _, value in raw_pairs(t) do
        result[write] = value
        write = write + 1
    end
    return result
end

---Pairs corresponding elements from two arrays up to the shorter length.
---@generic L, R
---@param left L[]
---@param right R[]
---@return table<integer, [L, R]>
function lib.zip(left, right)
    local n = {}
    local length = math.min(#left, #right)
    for i = 1, length do
        n[i] = {left[i], right[i]}
    end
    return n
end

---Returns a new array with duplicate values removed in first-seen order.
---@generic V
---@param t V[]
---@return V[]
function lib.unique(t)
    local result = {}
    local seen = {}
    local write = 1
    for _, value in ipairs(t) do
        if value ~= value or not seen[value] then
            result[write] = value
            write = write + 1
            if value == value then seen[value] = true end
        end
    end
    return result
end

---Removes duplicate values from an array in place, preserving first-seen order.
---@generic V
---@param t V[]
---@return V[] t
function lib.nocopy.unique(t)
    local seen = {}
    local write = 1
    local length = #t
    for read = 1, length do
        local value = t[read]
        if type(value) == "number" and value ~= value or not seen[value] then
            t[write] = value
            write = write + 1
            if not (type(value) == "number" and value ~= value) then
                seen[value] = true
            end
        end
    end
    for i = write, length do
        t[i] = nil
    end
    return t
end

-- Set-like operations (array inputs; results preserve first-seen order)
---Returns the unique values present in either array.
---@generic V
---@param left V[]
---@param right V[]
---@return V[]
function lib.union(left, right)
    local result = {}
    local seen = {}
    local write = 1

    local function append(values)
        for _, value in ipairs(values) do
            if value ~= value or not seen[value] then
                result[write] = value
                write = write + 1
                if value == value then seen[value] = true end
            end
        end
    end

    append(left)
    append(right)
    return result
end

---Returns the unique values present in both arrays.
---@generic V
---@param left V[]
---@param right V[]
---@return V[]
function lib.intersection(left, right)
    local in_right = {}
    for _, value in ipairs(right) do
        if value == value then in_right[value] = true end
    end

    local result = {}
    local seen = {}
    local write = 1
    for _, value in ipairs(left) do
        if value == value and in_right[value] and not seen[value] then
            result[write] = value
            seen[value] = true
            write = write + 1
        end
    end
    return result
end

---Returns the unique values from the left array that are absent from the right.
---@generic V
---@param left V[]
---@param right V[]
---@return V[]
function lib.difference(left, right)
    local in_right = {}
    for _, value in ipairs(right) do
        if value == value then in_right[value] = true end
    end

    local result = {}
    local seen = {}
    local write = 1
    for _, value in ipairs(left) do
        if value ~= value or not in_right[value] and not seen[value] then
            result[write] = value
            write = write + 1
            if value == value then seen[value] = true end
        end
    end
    return result
end

-- Merges
---Shallowly merges two tables into a new table, with right-hand values taking precedence.
---@generic K, V
---@param left table<K, V>
---@param right table<K, V>
---@return table<K, V>
function lib.merge(left, right)
    local result = {}
    for key, value in raw_pairs(left) do
        result[key] = value
    end
    for key, value in raw_pairs(right) do
        result[key] = value
    end
    return result
end

---Shallowly merges the right table into the left table in place.
---@generic K, V
---@param left table<K, V>
---@param right table<K, V>
---@return table<K, V> left
function lib.nocopy.merge(left, right)
    for key, value in raw_pairs(right) do
        left[key] = value
    end
    return left
end

local function collect_tables(value, tables)
    if type(value) ~= "table" or tables[value] then return end
    tables[value] = true
    for key, nested in raw_pairs(value) do
        collect_tables(key, tables)
        collect_tables(nested, tables)
    end
end

local function merge_deep_into(destination, source, active, input_tables)
    active[source] = destination

    for key, value in raw_pairs(source) do
        if type(value) == "table" then
            -- Reuse active ancestors for cycles, but merge repeated branches independently.
            if active[value] then
                rawset(destination, key, active[value])
            else
                local target = rawget(destination, key)
                if type(target) ~= "table" then
                    target = {}
                elseif input_tables[target] then
                    -- Do not mutate an input table that is also reachable from destination.
                    target = merge_deep_into({}, target, {}, input_tables)
                end
                rawset(destination, key,
                    merge_deep_into(target, value, active, input_tables))
            end
        else
            rawset(destination, key, value)
        end
    end
    active[source] = nil
    return destination
end

---Recursively merges two tables into a new structure, preserving cycles.
---@param left table
---@param right table
---@return table
function lib.merge_deep(left, right)
    local result = {}
    local input_tables = {}
    collect_tables(left, input_tables)
    collect_tables(right, input_tables)
    merge_deep_into(result, left, {}, input_tables)
    merge_deep_into(result, right, {}, input_tables)
    return result
end

---Recursively merges the right table into the left table in place, preserving cycles.
---@param left table
---@param right table
---@return table left
function lib.nocopy.merge_deep(left, right)
    if rawequal(left, right) then return left end

    local input_tables = {}
    collect_tables(right, input_tables)
    return merge_deep_into(left, right, {}, input_tables)
end

-- Copies
---Returns a shallow copy of a table, preserving its metatable.
---Non-table values are returned unchanged.
---@generic T
---@param t T
---@return T
function lib.copy(t)
    if type(t) ~= "table" then return t end

    local n = {}
    for k,v in raw_pairs(t) do
        n[k] = v
    end

    local metatable = get_metatable(t)
    if type(metatable) == "table" then
        setmetatable(n, metatable)
    end
    return n
end

local function copy_deep(value, copies)
    if type(value) ~= "table" then return value end
    if copies[value] then return copies[value] end

    local n = {}
    copies[value] = n
    for k,v in raw_pairs(value) do
        n[copy_deep(k, copies)] = copy_deep(v, copies)
    end

    local metatable = get_metatable(value)
    if type(metatable) == "table" then
        setmetatable(n, metatable)
    end
    return n
end

---Recursively copies table keys and values, preserving metatables, shared references, and cycles.
---Non-table values are returned unchanged.
---@generic T
---@param t T
---@return T
function lib.copy_deep(t)
    return copy_deep(t, {})
end

-- Random
---Returns a random array element, or `nil` when the array is empty.
---@generic V
---@param t V[]
---@return V? value
function lib.choice(t)
    if #t == 0 then return nil end
    return t[math.random(#t)]
end

---Returns a randomly shuffled copy of an array.
---@generic V
---@param t V[]
---@return V[]
function lib.shuffle(t)
    local n = {}
    for i,v in ipairs(t) do
        n[i] = v
    end
    for i = #n, 2, -1 do
        local j = math.random(i)
        n[i], n[j] = n[j], n[i]
    end
    return n
end

---Randomly shuffles an array in place.
---@generic V
---@param t V[]
---@return V[] t
function lib.nocopy.shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

---Returns a reversed copy of an array.
---@generic V
---@param t V[]
---@return V[]
function lib.reverse(t)
    local result = {}
    local length = #t
    for index = 1, length do
        result[index] = t[length - index + 1]
    end
    return result
end

---Reverses an array in place.
---@generic V
---@param t V[]
---@return V[] t
function lib.nocopy.reverse(t)
    local length = #t
    for i = 1, math.floor(length / 2) do
        local j = length - i + 1
        t[i], t[j] = t[j], t[i]
    end
    return t
end

return lib
