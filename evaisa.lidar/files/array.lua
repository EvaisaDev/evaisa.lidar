local array = {

}

array.new = function(chunk_size)
    local self = {
        chunk_size = chunk_size or 256,
        chunks = {}
    }



    self.get = function(self, x, y)
        local chunk_x = math.floor(x / self.chunk_size)
        local chunk_y = math.floor(y / self.chunk_size)

        local chunk = self.chunks[chunk_x] and self.chunks[chunk_x][chunk_y] or nil

        if(chunk == nil) then
            return nil
        end
        
        local rel_x = x % self.chunk_size
        local rel_y = y % self.chunk_size

        return chunk[rel_x * self.chunk_size + rel_y]
    end

    self.set = function(self, x, y, value)
        local chunk_x = math.floor(x / self.chunk_size)
        local chunk_y = math.floor(y / self.chunk_size)

        local chunk = self.chunks[chunk_x] and self.chunks[chunk_x][chunk_y] or nil

        if(chunk == nil) then
            chunk = {}
            self.chunks[chunk_x * self.chunk_size + chunk_y] = chunk
        end
        
        local rel_x = x % self.chunk_size
        local rel_y = y % self.chunk_size

        chunk[rel_x * self.chunk_size + rel_y] = value
    end

    self.has = function(self, x, y)
        local chunk_x = math.floor(x / self.chunk_size)
        local chunk_y = math.floor(y / self.chunk_size)

        local chunk = self.chunks[chunk_x] and self.chunks[chunk_x][chunk_y] or nil

        if(chunk == nil) then
            return false
        end
        
        local rel_x = x % self.chunk_size
        local rel_y = y % self.chunk_size

        return chunk[rel_x * self.chunk_size + rel_y] ~= nil
    end

    self.delete = function(self, x, y)
        local chunk_x = math.floor(x / self.chunk_size)
        local chunk_y = math.floor(y / self.chunk_size)

        local chunk = self.chunks[chunk_x] and self.chunks[chunk_x][chunk_y] or nil

        if(chunk == nil) then
            return false
        end
        
        local rel_x = x % self.chunk_size
        local rel_y = y % self.chunk_size

        chunk[rel_x * self.chunk_size + rel_y] = nil
    end

    return self
end

return array