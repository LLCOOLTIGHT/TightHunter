-- DataHandler: Client-side data management
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local DataHandler = {}
local playerData = nil

local player = Players.LocalPlayer

-- Get remote events
local getPlayerDataRemote = nil
local allocateStatsRemote = nil
local playerDataChangedRemote = nil

-- Initialize remotes when available
local function initializeRemotes()
    getPlayerDataRemote = RemoteEvents:GetRemoteFunction(RemoteEvents.GetPlayerData)
    allocateStatsRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.AllocateStats)
    playerDataChangedRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerDataChanged)
    
    -- Listen for data changes from server
    playerDataChangedRemote.OnClientEvent:Connect(function(newData)
        playerData = newData
        DataHandler.OnDataChanged:Fire(newData)
    end)
end

-- Events
DataHandler.OnDataChanged = Instance.new("BindableEvent")

-- Get current player data
function DataHandler:GetData()
    return playerData
end

-- Request player data from server
function DataHandler:RequestData()
    if getPlayerDataRemote then
        playerData = getPlayerDataRemote:InvokeServer()
        return playerData
    end
    return nil
end

-- Request stat allocation
function DataHandler:AllocateStats(stat, amount)
    if allocateStatsRemote then
        allocateStatsRemote:FireServer(stat, amount)
    end
end

-- Initialize the data handler
function DataHandler:Init()
    initializeRemotes()
    self:RequestData()
    print("Client DataHandler initialized")
end

return DataHandler 