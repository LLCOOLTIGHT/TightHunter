local Players = game:GetService("Players")
local ProfileService = require(script.Parent.ProfileService)

local DataManager = {}
local playerProfiles = {}

function DataManager:Get(player)
    return playerProfiles[player]
end

local function loadProfile(player)
    local profile = ProfileService:LoadProfile(player)
    playerProfiles[player] = profile
end

local function saveProfile(player)
    local profile = playerProfiles[player]
    if profile then
        ProfileService:SaveProfile(player, profile)
        playerProfiles[player] = nil
    end
end

function DataManager:Init()
    Players.PlayerAdded:Connect(loadProfile)
    Players.PlayerRemoving:Connect(saveProfile)

    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do
            saveProfile(player)
        end
    end)
end

return DataManager
