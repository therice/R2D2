local _, AddOn = ...
local Compress = AddOn.Libs.Compress
local Serialize = AddOn.Libs.AceSerializer
local Base64 = AddOn.Libs.Base64
local Class = AddOn.Libs.Class
local Logging = AddOn.Libs.Logging
local Util = AddOn.Libs.Util

local CompressedDb = Class('CompressedDb')
local CompressedDbEntry = Class('CompressedDbEntry')

AddOn.components.Models.CompressedDb = CompressedDb
AddOn.components.Models.CompressedDbEntry = CompressedDbEntry

local function compress(data)
    if data == nil then return nil end
    
    local serialized = Serialize:Serialize(data)
    local compressed = Compress:Compress(serialized)
    local encoded = Base64:Encode(compressed)
    return encoded
end

local function decompress(data)
    if data == nil then return nil end
    
    local decoded = Base64:Decode(data)
    local decompressed, message = Compress:Decompress(decoded)
    if not decompressed then
        error('Could not de-compress decoded data : ' .. message)
        return
    end
    local success, raw = Serialize:Deserialize(decompressed)
    if not success then
        error('Could not de-serialize de-compressed data')
    end
    return raw
end

-- This doesn't work due to semantics of how thinks like table.insert works
-- e.g. using raw(get/set) vs access through functions overridden in setmetatable
--[[
function CompressedDb.static:create(db)
    local _db = db
    local d = {}
    
    local mt = {
        __newindex = function (d,k,v)
            --error('__newindex')
            Logging:Debug("__newindex %s", tostring(k))
            _db[k] = CompressedDb:compress(v)
        end,
        __index = function(d, k)
            Logging:Debug("__index %s", tostring(k))
            return CompressedDb:decompress(_db[k])
        end,
        __pairs = function(d)
            Logging:Debug("__pairs")
            return pairs(_db)
        end,
        __len = function(d)
            Logging:Debug("__len")
            return #_db
        end,
        __tableinsert = function(db, v)
            Logging:Debug("__tableinsert %s", tostring(k))
            
            return table.insert(_db, v)
        end
    }
    
    return setmetatable(d,mt)
end
--]]


-- be warned, everything under the namespace for DB passed to this constructor
-- needs to be compressed, there is no mixing and matching
-- exception to this is top-level table keys
--
-- also, this class isn't meant to be designed for every possible use case
-- it was designed with a very narrow use case in mind - specifically recording very large numbers
-- of table like entries for a realm or realm/character combination
-- such as loot history
function CompressedDb:initialize(db)
    self.db = db
end

function CompressedDb:get(key)
    -- print(format('get(%s)', tostring(key)))
    return decompress(self.db[key])
end

function CompressedDb:put(key, value)
    -- print(format('put(%s) :%s', tostring(key), Util.Objects.ToString(value)))
    self.db[key] = compress(value)
end

function CompressedDb:del(key, index)
    if Util.Objects.IsEmpty(index) then
        tremove(self.db, key)
    else
        local v = self:get(key)
        if not Util.Objects.IsTable(v) then
            error("Attempt to delete from a non-table value : " .. type(v))
        end
        tremove(v, index)
        self:put(key, v)
    end
end

function CompressedDb:insert(value)
    Util.Tables.Push(self.db, compress(value))
end

function CompressedDb:insert(value, key)
    if Util.Objects.IsEmpty(key) then
        Util.Tables.Push(self.db, compress(value))
    else
        local v = self:get(key)
        if not Util.Objects.IsTable(v) then
            error("Attempt to insert into a non-table value : " .. type(v))
        end
        Util.Tables.Push(v, value)
        self:put(key, v)
    end
    
end

function CompressedDb:__len()
    return #self.db
end

function CompressedDb.static.pairs(cdb)
    local function stateless_iter(tbl, k)
        local v
        k, v = next(tbl, k)
        if v ~= nil then return k, decompress(v) end
    end
    
    return stateless_iter, cdb.db, nil
end

function CompressedDb.static.ipairs(cdb)
    local function stateless_iter(tbl, i)
        i = i + 1
        local v = tbl[i]
        if v ~= nil then return i, decompress(v) end
    end
    
    return stateless_iter, cdb.db, 0
end

if _G.R2D2_Testing then
    function CompressedDb.static:decompress(data) return decompress(data) end
    function CompressedDb.static:compress(data) return compress(data) end
end
