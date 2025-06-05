local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local dataStore = DataStoreService:GetDataStore("PlayerProfiles")
local ProfileTemplate = require(script.Parent.ProfileTemplate)

local ProfileService = {}

function ProfileService:LoadProfile(player)
    local userId = tostring(player.UserId)
    local success, data = pcall(function()
        return dataStore:GetAsync(userId)
    end)

    if not success or not data then
        data = ProfileTemplate
    end

    return table.clone(data)
end

function ProfileService:SaveProfile(player, profile)
    local userId = tostring(player.UserId)
    pcall(function()
        dataStore:SetAsync(userId, profile)
    end)
end

return ProfileService
