-- store.lua
local store = {}

-- Helper function to merge/encode two 2D coordinates into a single integer
local function encode_key(x, y)
    local sx = x >= 0 and 2 * x or -2 * x - 1
    local sy = y >= 0 and 2 * y or -2 * y - 1
    return sx + sy * 2^32
end

-- Storage class
local Storage = {}
Storage.__index = Storage

function Storage:new()
  return setmetatable({grid = {}}, self)
end

function Storage:get(x, y)
  local key = encode_key(x, y)
  return self.grid[key]
end

function Storage:set(x, y, data)
  local key = encode_key(x, y)
  self.grid[key] = data
end

function Storage:delete(x, y)
  local key = encode_key(x, y)
  self.grid[key] = nil
end

function store.new()
  return Storage:new()
end

return store