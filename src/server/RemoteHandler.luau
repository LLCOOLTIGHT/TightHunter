-- RemoteHandler: Handles client requests on the server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.Modules.PlayerData.DataManager)
local StatService = require(script.Parent.Modules.PlayerData.StatService)

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local RemoteHandler = {}

-- Initialize remote event handlers
function RemoteHandler:Init()
    -- Handle GetPlayerData requests
    local getPlayerDataRemote = RemoteEvents:GetRemoteFunction(RemoteEvents.GetPlayerData)
    getPlayerDataRemote.OnServerInvoke = function(player)
        local profile = DataManager:Get(player)
        return profile
    end
    
    -- Handle AllocateStats requests
    local allocateStatsRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.AllocateStats)
    allocateStatsRemote.OnServerEvent:Connect(function(player, stat, amount)
        local success = StatService:Allocate(player, stat, amount)
        if success then
            -- Send updated data to client
            local playerDataChangedRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerDataChanged)
            local updatedProfile = DataManager:Get(player)
            playerDataChangedRemote:FireClient(player, updatedProfile)
        end
    end)
    
    print("RemoteHandler initialized")
end

return RemoteHandler 