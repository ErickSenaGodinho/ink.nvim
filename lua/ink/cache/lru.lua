-- lua/ink/cache/lru.lua
-- LRU (Least Recently Used) cache implementation for parsed chapters
-- Prevents excessive memory usage by limiting cache size

local M = {}

function M.new(max_size)
    local cache = {
        max_size = max_size or 10,
        items = {},
        order = {},  -- Array of keys in access order (oldest to newest)
        key_positions = {}  -- Key -> position in order array for fast lookup
    }

    -- Get item from cache
    function cache:get(key)
        local value = self.items[key]
        if value then
            -- Move to end (most recently used)
            self:_move_to_end(key)
            return value
        end
        return nil
    end

    -- Put item in cache
    function cache:put(key, value)
        -- If key exists, update and move to end
        if self.items[key] then
            self.items[key] = value
            self:_move_to_end(key)
            return
        end

        -- If cache is full, evict oldest
        if #self.order >= self.max_size then
            local oldest_key = table.remove(self.order, 1)
            self.items[oldest_key] = nil
            self.key_positions[oldest_key] = nil

            -- Update positions after removal
            for i, k in ipairs(self.order) do
                self.key_positions[k] = i
            end
        end

        -- Add new item
        self.items[key] = value
        table.insert(self.order, key)
        self.key_positions[key] = #self.order
    end

    -- Remove item from cache
    function cache:remove(key)
        if not self.items[key] then return end

        self.items[key] = nil
        local pos = self.key_positions[key]
        if pos then
            table.remove(self.order, pos)
            self.key_positions[key] = nil

            -- Update positions after removal
            for i = pos, #self.order do
                self.key_positions[self.order[i]] = i
            end
        end
    end

    -- Clear all cache
    function cache:clear()
        self.items = {}
        self.order = {}
        self.key_positions = {}
    end

    -- Get cache size
    function cache:size()
        return #self.order
    end

    -- Check if key exists
    function cache:has(key)
        return self.items[key] ~= nil
    end

    -- Internal: move key to end of order (most recently used)
    function cache:_move_to_end(key)
        local pos = self.key_positions[key]
        if not pos then return end

        -- If already at end, nothing to do
        if pos == #self.order then return end

        -- Remove from current position
        table.remove(self.order, pos)

        -- Add to end
        table.insert(self.order, key)

        -- Update all positions from old position onwards
        for i = pos, #self.order do
            self.key_positions[self.order[i]] = i
        end
    end

    return cache
end

return M
