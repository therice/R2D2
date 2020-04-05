local _, AddOn = ...
local Class = AddOn.Libs.Class
local Util  = AddOn.Libs.Util
local ItemUtil = AddOn.Libs.ItemUtil
local Logging = AddOn.Libs.Logging

local GuildMember = Class('GuildMember')

AddOn.components.Models.GuildMember = GuildMember

--[[
https://wowwiki.fandom.com/wiki/API_GetGuildRosterInfo
    class can be either of the following formats, which will then be handled to provide class and classFileName
        class : String - The class (Mage, Warrior, etc) of the player.
        classFileName  String - Upper-case English classname - localisation independent.
    rank : String - The member's rank in the guild ( Guild Master, Member ...)
    rankIndex : Number - The number corresponding to the guild's rank. The Rank Index starts at 0, add 1 to correspond with the index used in GuildControlGetRankName(index)
--]]
function GuildMember:initialize(name, class, rank, rankIndex)
    self.name = name
    
    if Util.Objects.IsEmpty(class) then
        error("Must specify 'class' (either display name or upper-case name)")
    end
    
    -- if all upper case, assume it's the classFileName attribute
    if Util.Strings.IsUpper(class) then
        self.classId = ItemUtil.ClassTagNameToId[class]
        self.class = ItemUtil.ClassIdToDisplayName[self.classId]
        self.classTag = class
    -- otherwise, assume it's the class attribute
    else
        self.classId = ItemUtil.ClassDisplayNameToId[class]
        self.class = class
        self.classTag = ItemUtil.ClassIdToFileName[self.classId]
    end
    
    self.rank = rank or ""
    self.rankIndex = rankIndex or nil
end