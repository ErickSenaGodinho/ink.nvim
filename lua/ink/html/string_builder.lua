-- String builder to reduce allocations
-- Uses table.concat instead of repeated string concatenation

local M = {}

-- Create a new string builder
function M.new()
  return {
    buffer = {},
    length = 0
  }
end

-- Append string to builder (O(1))
function M.append(sb, str)
  if str and #str > 0 then
    sb.length = sb.length + 1
    sb.buffer[sb.length] = str
  end
end

-- Append multiple strings at once
function M.append_many(sb, ...)
  local args = {...}
  for i = 1, #args do
    if args[i] and #args[i] > 0 then
      sb.length = sb.length + 1
      sb.buffer[sb.length] = args[i]
    end
  end
end

-- Get final string (O(n) only once)
function M.to_string(sb)
  return table.concat(sb.buffer, "", 1, sb.length)
end

-- Get length in bytes (approximate)
function M.byte_length(sb)
  local total = 0
  for i = 1, sb.length do
    total = total + #sb.buffer[i]
  end
  return total
end

-- Clear buffer for reuse
function M.clear(sb)
  sb.length = 0
  -- Keep buffer table allocated to avoid GC
end

-- Check if empty
function M.is_empty(sb)
  return sb.length == 0
end

return M
