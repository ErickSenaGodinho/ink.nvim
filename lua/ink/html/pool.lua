-- Object pool for reusing tables and reducing GC pressure
-- Tables are expensive to allocate and garbage collect

local M = {}

-- Pool for reusable tables
local table_pool = {}
local pool_size = 0
local max_pool_size = 50

-- Get a clean table from pool or create new one
function M.get_table()
  if pool_size > 0 then
    local tbl = table_pool[pool_size]
    table_pool[pool_size] = nil
    pool_size = pool_size - 1
    return tbl
  end
  return {}
end

-- Return table to pool (clears it first)
function M.release_table(tbl)
  -- Clear table contents
  for k in pairs(tbl) do
    tbl[k] = nil
  end

  -- Return to pool if not full
  if pool_size < max_pool_size then
    pool_size = pool_size + 1
    table_pool[pool_size] = tbl
  end
end

-- Get multiple tables at once
function M.get_tables(count)
  local tables = {}
  for i = 1, count do
    tables[i] = M.get_table()
  end
  return unpack(tables)
end

-- Release multiple tables at once
function M.release_tables(...)
  local tables = {...}
  for i = 1, #tables do
    if tables[i] then
      M.release_table(tables[i])
    end
  end
end

-- Clear pool (for testing/cleanup)
function M.clear_pool()
  table_pool = {}
  pool_size = 0
end

-- Get pool statistics
function M.stats()
  return {
    size = pool_size,
    max_size = max_pool_size,
    utilization = string.format("%.1f%%", (pool_size / max_pool_size) * 100)
  }
end

return M
