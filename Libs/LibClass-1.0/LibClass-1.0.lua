-- adapted from https://github.com/kikito/middleclass/blob/master/middleclass.lua

local MAJOR_VERSION = "LibClass-1.0"
local MINOR_VERSION = 11303

local lib, _ = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end


local function _createIndexWrapper(aClass, f)
    if f == nil then
        return aClass.__instanceDict
    else
        return function(self, name)
            local value = aClass.__instanceDict[name]

            if value ~= nil then
                return value
            elseif type(f) == "function" then
                return (f(self, name))
            else
                return f[name]
            end
        end
    end
end

local function _propagateInstanceMethod(aClass, name, f)
    f = name == "__index" and _createIndexWrapper(aClass, f) or f
    aClass.__instanceDict[name] = f

    for subclass in pairs(aClass.subclasses) do
        if rawget(subclass.__declaredMethods, name) == nil then
            _propagateInstanceMethod(subclass, name, f)
        end
    end
end

local function _declareInstanceMethod(aClass, name, f)
    aClass.__declaredMethods[name] = f

    if f == nil and aClass.super then
        f = aClass.super.__instanceDict[name]
    end

    _propagateInstanceMethod(aClass, name, f)
end

local function _tostring(self) return "class " .. self.name end
local function _call(self, ...) return self:new(...) end

local function _createClass(name, super)
    local dict = {}
    dict.__index = dict

    local aClass = { name = name, super = super, static = {},
                     __instanceDict = dict, __declaredMethods = {},
                     subclasses = setmetatable({}, {__mode='k'})  }

    if super then
        setmetatable(aClass.static, {
            __index = function(_,k)
                local result = rawget(dict,k)
                if result == nil then
                    return super.static[k]
                end
                return result
            end
        })
    else
        setmetatable(aClass.static, { __index = function(_,k) return rawget(dict,k) end })
    end

    setmetatable(aClass, { __index = aClass.static, __tostring = _tostring,
                           __call = _call, __newindex = _declareInstanceMethod })

    return aClass
end

local function _includeMixin(aClass, mixin)
    assert(type(mixin) == 'table', "mixin must be a table")

    for name,method in pairs(mixin) do
        if name ~= "included" and name ~= "static" then aClass[name] = method end
    end

    for name,method in pairs(mixin.static or {}) do
        aClass.static[name] = method
    end

    if type(mixin.included)=="function" then mixin:included(aClass) end
    return aClass
end

local function _cycle_aware_copy(t, cache)
    if type(t) ~= 'table' then return t end
    if cache[t] then return cache[t] end
    local res = {}
    cache[t] = res
    local mt = getmetatable(t)

    for k,v in pairs(t) do
        k = _cycle_aware_copy(k, cache)
        v = _cycle_aware_copy(v, cache)
        res[k] = v
    end

    return setmetatable(res,mt)
end

local function _strip_class_metadata(t)
    if type(t) ~= 'table' then return t end
    
    local res = {}
    for k, v in pairs(t) do
        if k ~= "clazz" then
            k = _strip_class_metadata(k)
            v = _strip_class_metadata(v)
            res[k] = v
        end
    end
    
    return res
end

local DefaultMixin = {
    __tostring   = function(self) return "instance of " .. tostring(self.clazz) end,

    initialize   = function(self, ...) end,

    isInstanceOf = function(self, aClass)
        return type(aClass) == 'table' and type(self) == 'table' and
                (self.clazz == aClass or type(self.clazz) == 'table' and type(self.clazz.isSubclassOf) == 'function' and self.clazz:isSubclassOf(aClass))
    end,

    -- creates a clone of current instance, including metadata
    clone = function(self)
        return _cycle_aware_copy(self, {})
    end,

    -- creates a copy of the current instance, but only the actual attributes
    -- class metadata is stripped
    -- useful for serializing the information over the wire
    toTable = function(self)
        return _strip_class_metadata(self)
    end,

    -- allows for manipulation of reconstitute instance before being returned
    afterReconstitute = function(self, instance) return instance end,
    
    --creates a new instance of the class, populating attributes from specified table
    reconstitute = function(self, data)
        assert(type(data) == 'table', "You must provide data(table) from which to re-constitute'")
        local copy = self.clazz:new()
        for k, v in pairs(data) do
            copy[k] = v
        end
        return self.afterReconstitute(self, copy)
    end,
    
    static = {
        allocate = function(self)
            assert(type(self) == 'table', "Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")
            return setmetatable({ clazz = self }, self.__instanceDict)
        end,

        new = function(self, ...)
            assert(type(self) == 'table', "Make sure that you are using 'Class:new' instead of 'Class.new'")
            local instance = self:allocate()
            instance:initialize(...)
            return instance
        end,

        subclass = function(self, name)
            assert(type(self) == 'table', "Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
            assert(type(name) == "string", "You must provide a name(string) for your class")

            local subclass = _createClass(name, self)

            for methodName, f in pairs(self.__instanceDict) do
                _propagateInstanceMethod(subclass, methodName, f)
            end
            subclass.initialize = function(instance, ...) return self.initialize(instance, ...) end

            self.subclasses[subclass] = true
            self:subclassed(subclass)

            return subclass
        end,

        subclassed = function(self, other) end,

        isSubclassOf = function(self, other)
            return type(other)      == 'table' and
                    type(self.super) == 'table' and
                    ( self.super == other or self.super:isSubclassOf(other) )
        end,

        include = function(self, ...)
            assert(type(self) == 'table', "Make sure you that you are using 'Class:include' instead of 'Class.include'")
            for _,mixin in ipairs({...}) do _includeMixin(self, mixin) end
            return self
        end,
    }
}

function lib.class(name, super)
    assert(type(name) == 'string', "A name (string) is needed for the new class")
    return super and super:subclass(name) or _includeMixin(_createClass(name), DefaultMixin)
end

setmetatable(lib, { __call = function(_, ...) return lib.class(...) end })
