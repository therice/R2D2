local _, AddOn = ...
local Serialize = AddOn.Libs.AceSerializer
local Base64 = AddOn.Libs.Base64
local Class = AddOn.Libs.Class
local Logging = AddOn.Libs.Logging
local Util = AddOn.Libs.Util
local Compression = Util.Compression

-- compressors that were used either in the past or currently
local LegacyCompressorType = Compression.CompressorType.LibCompress
local CurrentCompressorType = Compression.CompressorType.LibDeflate
local Compressors = Util(
        Compression.GetCompressors(
                LegacyCompressorType,
                CurrentCompressorType
        )
):MapKeys(
        function(i)
            return
                i == 1 and LegacyCompressorType or
                i == 2 and CurrentCompressorType or
                nil
        end
)()

local CompressionSettingsKey = '__CompressionSettings'
local CompressedDb = Class('CompressedDb')
CompressedDb.static.CompressionSettingsKey = CompressionSettingsKey
CompressedDb.static.LegacyCompressorType = LegacyCompressorType

local CompressedDbEntry = Class('CompressedDbEntry')

AddOn.components.Models.CompressedDb = CompressedDb
AddOn.components.Models.CompressedDbEntry = CompressedDbEntry

local function compress(data, type)
    if data == nil then return nil end
    if not Util.Objects.IsNumber(type) then return nil end
    
    local serialized = Serialize:Serialize(data)
    local compressed = Compressors[type]:compress(serialized)
    local encoded = Base64:Encode(compressed)
    return encoded
end

local function decompress(data, type)
    if data == nil then return nil end
    if not Util.Objects.IsNumber(type) then return nil end
    
    local decoded = Base64:Decode(data)
    local decompressed, message = Compressors[type]:decompress(decoded)
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

-- This doesn't work due to semantics of how things like table.insert works
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
    self.compressionType = nil
    
    -- check compression settings on the DB
    -- if not present, or not the current type
    -- upgrade the DB
    local setttings = db[CompressionSettingsKey]
    if not setttings or setttings.type ~= CurrentCompressorType then
        Logging:Warn("Existing compression settings are empty or incompatible - updating DB compression")
        self.compressionType = LegacyCompressorType
        local before, after = 0,0
        for k, v in pairs(self.db) do
            self.db[k] = compress(decompress(v, LegacyCompressorType), CurrentCompressorType)
            before = before + #v
            after = after + #self.db[k]
        end
        Logging:Debug("Database compression updated. Size before = %d, after = %d  reduced (Pct) = %d", before, after, (100.0 - ((after / before) * 100.0)))
        
        self.compressionType = CurrentCompressorType
        self.db[CompressionSettingsKey] = {
            type = self.compressionType
        }
    else
        self.compressionType = setttings.type
        Logging:Debug("Database compression type %d", self.compressionType)
    end
end

function CompressedDb:decompress(data)
    return decompress(data, self.compressionType)
end

function CompressedDb:compress(data)
    return compress(data, self.compressionType)
end

function CompressedDb:get(key)
    -- print(format('get(%s)', tostring(key)))
    return self:decompress(self.db[key])
end

function CompressedDb:put(key, value)
    self.db[key] = self:compress(value)
end

function CompressedDb:del(key, index)
    if Util.Objects.IsEmpty(index) then
        self.db[key] = nil
    else
        local v = self:get(key)
        if not Util.Objects.IsTable(v) then
            error("Attempt to delete from a non-table value : " .. type(v))
        end
        tremove(v, index)
        self:put(key, v)
    end
end

function CompressedDb:insert(value, key)
    if Util.Objects.IsEmpty(key) then
        Util.Tables.Push(self.db, self:compress(value))
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
        if k == CompressionSettingsKey then
            k, v = next(tbl, k)
        end
        if v ~= nil then return k, cdb:decompress(v) end
    end
    
    return stateless_iter, cdb.db, nil
end

function CompressedDb.static.ipairs(cdb)
    local function stateless_iter(tbl, i)
        i = i + 1
        local v = tbl[i]
        if v ~= nil then return i, cdb:decompress(v) end
    end
    
    return stateless_iter, cdb.db, 0
end


if _G.R2D2_Testing then
    function CompressedDb.static:decompress(data, type) return decompress(data, type or CurrentCompressorType) end
    function CompressedDb.static:compress(data, type) return compress(data, type or CurrentCompressorType) end
end
