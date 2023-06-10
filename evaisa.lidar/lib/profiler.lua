local profiler = {}
profiler.__index = profiler

local ffi = require("ffi")

ffi.cdef([[
typedef int BOOL;
typedef unsigned long DWORD;
typedef long LONG;
typedef long long LONGLONG;

typedef union _LARGE_INTEGER {
  struct {
    DWORD LowPart;
    LONG  HighPart;
  } DUMMYSTRUCTNAME;
  struct {
    DWORD LowPart;
    LONG  HighPart;
  } u;
  LONGLONG QuadPart;
} LARGE_INTEGER;

BOOL QueryPerformanceFrequency(
  LARGE_INTEGER *lpFrequency
);

BOOL QueryPerformanceCounter(
  LARGE_INTEGER *lpPerformanceCount
);

]])
local LARGE_INTEGER = ffi.typeof("LARGE_INTEGER")
local LI_freq = LARGE_INTEGER()
ffi.C.QueryPerformanceFrequency(LI_freq)
local freq = LI_freq.QuadPart

local function gettime()
    local LI = LARGE_INTEGER()
    ffi.C.QueryPerformanceCounter(LI)
    local seconds = tonumber(LI.QuadPart) / tonumber(freq)
    local milliseconds = (math.floor((seconds * 1000) * 1000)) / 1000
    return milliseconds
end

function profiler.new(id)
    local self = {}
    self.startTime = 0
    self.stopTime = 0
    self.time_spent = 0
    self.id = id

    function self:start()
        self.startTime = gettime()
    end
    
    function self:stop()
        self.stopTime = gettime()
        self.time_spent = self.time_spent + self:time()
    end
    
    function self:time()
        local time = self.stopTime - self.startTime
        return time
    end

    function self:sum()
        return self.time_spent
    end
    
    function self:print()
        print(table.concat({self.id, self:time()}, ": "))
        --print(self.id .. ": " .. self:time())
    end

    function self:print_sum()
        GamePrint(table.concat({self.id, self:sum()}, ": "))
        --print(self.id .. ": " .. self:sum())
    end

    function self:clear()
        self.time_spent = 0
    end

    return self
end

return profiler