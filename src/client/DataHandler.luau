-- DataHandler: Client-side data management
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = nil
local success, err = pcall(function()
    RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
end)

if not success then
    warn("DataHandler: Failed to load RemoteEvents:", err)
    return {}
end

local DataHandler = {}
local playerData = nil

local player = Players.LocalPlayer

-- Get remote events
local getPlayerDataRemote = nil
local allocateStatsRemote = nil
local playerDataChangedRemote = nil

-- Initialize remotes when available
local function initializeRemotes()
    local success1, err1 = pcall(function()
        getPlayerDataRemote = RemoteEvents:GetRemoteFunction(RemoteEvents.GetPlayerData)
    end)
    
    if not success1 then
        warn("DataHandler: Failed to get GetPlayerData remote:", err1)
        return false
    end
    
    local success2, err2 = pcall(function()
        allocateStatsRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.AllocateStats)
    end)
    
    if not success2 then
        warn("DataHandler: Failed to get AllocateStats remote:", err2)
        return false
    end
    
    local success3, err3 = pcall(function()
        playerDataChangedRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerDataChanged)
    end)
    
    if not success3 then
        warn("DataHandler: Failed to get PlayerDataChanged remote:", err3)
        return false
    end
    
    -- Listen for data changes from server
    local success4, err4 = pcall(function()
        playerDataChangedRemote.OnClientEvent:Connect(function(newData)
            playerData = newData
            DataHandler.OnDataChanged:Fire(newData)
        end)
    end)
    
    if not success4 then
        warn("DataHandler: Failed to connect to PlayerDataChanged:", err4)
        return false
    end
    
    return true
end

-- Events
DataHandler.OnDataChanged = Instance.new("BindableEvent")

-- Get current player data
function DataHandler:GetData()
    return playerData
end

-- Request player data from server with timeout and retry
function DataHandler:RequestData()
    if not getPlayerDataRemote then
        warn("DataHandler: GetPlayerData remote not available")
        return nil
    end
    
    -- Try multiple times with increasing delays
    for attempt = 1, 3 do
        
        local success, result = pcall(function()
            -- Set a timeout for the invoke call
            local thread = coroutine.running()
            local responded = false
            local response = nil
            
            spawn(function()
                local invokeSuccess, invokeResult = pcall(function()
                    return getPlayerDataRemote:InvokeServer()
                end)
                
                if invokeSuccess then
                    response = invokeResult
                else
                    response = {error = invokeResult}
                end
                responded = true
                coroutine.resume(thread)
            end)
            
            -- Wait up to 5 seconds for response
            spawn(function()
                wait(5)
                if not responded then
                    responded = true
                    response = {error = "Timeout"}
                    coroutine.resume(thread)
                end
            end)
            
            coroutine.yield()
            return response
        end)
        
        if success and result and not result.error then
            playerData = result
            return playerData
        else
            warn("DataHandler: Failed to request player data on attempt", attempt, ":", result and result.error or "Unknown error")
            
            if attempt < 3 then
                wait(attempt) -- Wait 1s, then 2s before retrying
            end
        end
    end
    
    warn("DataHandler: All attempts to get player data failed, using default data")
    -- Return a default profile if all attempts fail
    playerData = {
        Stats = {
            Strength = 0,
            Agility = 0,
            Intelligence = 0,
            Constitution = 0,
            BreathingMastery = 0,
            Level = 1,
            EXP = 0,
        },
        Race = "Human",
        Clan = "Kamado",
        BreathingStyle = "None",
        Abilities = {},
        Inventory = {
            Yen = 0,
            Items = {},
        },
        UnspentStatPoints = 0,
    }
    return playerData
end

-- Request stat allocation
function DataHandler:AllocateStats(stat, amount)
    if allocateStatsRemote then
        allocateStatsRemote:FireServer(stat, amount)
    end
end

-- Initialize the data handler
function DataHandler:Init()
    local success, err = pcall(function()
        local remoteSuccess = initializeRemotes()
        if not remoteSuccess then
            error("Failed to initialize remotes")
        end
        
        -- Don't block initialization on data request
        spawn(function()
            self:RequestData()
        end)
    end)
    
    if not success then
        warn("DataHandler: Initialization failed:", err)
        error("DataHandler initialization failed: " .. tostring(err))
    end
end

return DataHandler 