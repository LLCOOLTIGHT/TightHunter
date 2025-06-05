-- RemoteEvents: Defines all remote events used for client-server communication
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

-- Wait for RemoteEvents folder to be created by server
local function waitForRemoteEvents()
    return ReplicatedStorage:WaitForChild("RemoteEvents")
end

-- Player Data Events
RemoteEvents.GetPlayerData = "GetPlayerData"
RemoteEvents.AllocateStats = "AllocateStats"
RemoteEvents.PlayerDataChanged = "PlayerDataChanged"

-- Movement Events
RemoteEvents.PlayerDashed = "PlayerDashed"
RemoteEvents.PlayerWallRun = "PlayerWallRun"
RemoteEvents.PlayerSprintChanged = "PlayerSprintChanged"

-- Combat Events
RemoteEvents.DealDamage = "DealDamage"
RemoteEvents.UseAbility = "UseAbility"

-- Shop/Trade Events
RemoteEvents.PurchaseItem = "PurchaseItem"
RemoteEvents.SellItem = "SellItem"

-- Breathing Style Events
RemoteEvents.LearnBreathingStyle = "LearnBreathingStyle"
RemoteEvents.UpgradeBreathingStyle = "UpgradeBreathingStyle"

-- Helper function to get or create remote events
function RemoteEvents:GetRemoteEvent(eventName)
    local remoteEventsFolder = waitForRemoteEvents()
    local remoteEvent = remoteEventsFolder:FindFirstChild(eventName)
    
    if not remoteEvent then
        remoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = eventName
        remoteEvent.Parent = remoteEventsFolder
    end
    
    return remoteEvent
end

-- Helper function to get or create remote functions
function RemoteEvents:GetRemoteFunction(functionName)
    local remoteEventsFolder = waitForRemoteEvents()
    local remoteFunction = remoteEventsFolder:FindFirstChild(functionName)
    
    if not remoteFunction then
        remoteFunction = Instance.new("RemoteFunction")
        remoteFunction.Name = functionName
        remoteFunction.Parent = remoteEventsFolder
    end
    
    return remoteFunction
end

return RemoteEvents 