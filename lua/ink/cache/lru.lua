-- lua/ink/cache/lru.lua
-- Generic LRU (Least Recently Used) cache implementation with O(1) operations
-- Uses double-linked list + hash table for constant time access/eviction

local M = {}

-- Create a new LRU cache
-- @param max_size: maximum number of entries to keep
-- @return cache object with get/put methods
function M.new(max_size)
  local cache = {
    max_size = max_size or 10,
    entries = {},      -- key -> node mapping
    count = 0,         -- current number of entries
    head = nil,        -- most recently used (dummy head for easier manipulation)
    tail = nil,        -- least recently used (dummy tail for easier manipulation)
  }

  -- Initialize dummy head and tail nodes
  cache.head = { key = nil, value = nil, prev = nil, next = nil }
  cache.tail = { key = nil, value = nil, prev = nil, next = nil }
  cache.head.next = cache.tail
  cache.tail.prev = cache.head

  -- Remove node from linked list (O(1))
  local function remove_node(node)
    local prev_node = node.prev
    local next_node = node.next
    prev_node.next = next_node
    next_node.prev = prev_node
  end

  -- Add node right after head (most recently used position) (O(1))
  local function add_to_head(node)
    node.prev = cache.head
    node.next = cache.head.next
    cache.head.next.prev = node
    cache.head.next = node
  end

  -- Move node to head (mark as recently used) (O(1))
  local function move_to_head(node)
    remove_node(node)
    add_to_head(node)
  end

  -- Remove tail node (least recently used) (O(1))
  local function pop_tail()
    local node = cache.tail.prev
    if node == cache.head then
      return nil  -- Empty cache
    end
    remove_node(node)
    return node
  end

  -- Get value from cache
  -- @param key: cache key
  -- @return value or nil if not in cache
  -- Time complexity: O(1)
  function cache:get(key)
    local node = self.entries[key]

    if node == nil then
      return nil
    end

    -- Move to head (most recently used)
    move_to_head(node)

    return node.value
  end

  -- Put value into cache
  -- @param key: cache key
  -- @param value: value to store
  -- Time complexity: O(1)
  function cache:put(key, value)
    local node = self.entries[key]

    if node ~= nil then
      -- Update existing node
      node.value = value
      move_to_head(node)
    else
      -- Create new node
      node = { key = key, value = value, prev = nil, next = nil }
      self.entries[key] = node
      add_to_head(node)
      self.count = self.count + 1

      -- Evict if over capacity
      if self.count > self.max_size then
        local tail_node = pop_tail()
        if tail_node then
          self.entries[tail_node.key] = nil
          self.count = self.count - 1
        end
      end
    end
  end

  -- Check if key exists in cache
  -- @param key: cache key
  -- @return boolean
  -- Time complexity: O(1)
  function cache:has(key)
    return self.entries[key] ~= nil
  end

  -- Clear all entries
  -- Time complexity: O(1)
  function cache:clear()
    self.entries = {}
    self.count = 0
    -- Reset linked list
    self.head.next = self.tail
    self.tail.prev = self.head
  end

  -- Get cache size
  -- @return number of entries
  -- Time complexity: O(1)
  function cache:size()
    return self.count
  end

  -- Get cache statistics
  -- @return table with stats
  function cache:stats()
    return {
      size = self.count,
      max_size = self.max_size,
      utilization = string.format("%.1f%%", (self.count / self.max_size) * 100),
    }
  end

  return cache
end

return M
