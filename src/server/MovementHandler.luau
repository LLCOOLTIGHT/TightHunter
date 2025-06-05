-- MovementHandler: Server-side movement effect management
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))
local DataManager = require(script.Parent.Modules.PlayerData.DataManager)

local MovementHandler = {}

-- Movement effect tracking
local playerMovementStates = {}

-- Initialize player movement state
local function initPlayerMovementState(player)
    playerMovementStates[player] = {
        isSprinting = false,
        isWallRunning = false,
        lastDashTime = 0,
    }
end

-- Clean up player movement state
local function cleanupPlayerMovementState(player)
    playerMovementStates[player] = nil
end

-- Handle player dash events
local function onPlayerDashed(player, direction, dashPosition)
    -- Validate dash (basic anti-cheat)
    local currentTime = tick()
    local playerState = playerMovementStates[player]
    
    if not playerState then return end
    
    -- Check cooldown (2 second cooldown)
    if currentTime - playerState.lastDashTime < 1.8 then -- Slightly less than client for lag tolerance
        warn("Player " .. player.Name .. " attempted to dash too quickly")
        return
    end
    
    playerState.lastDashTime = currentTime
    
    -- Broadcast dash effect to all other players
    local dashRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerDashed)
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            dashRemote:FireClient(otherPlayer, player, direction, dashPosition)
        end
    end
    
    print(player.Name .. " dashed")
end

-- Handle wall running events
local function onPlayerWallRun(player, isWallRunning, wallPosition)
    local playerState = playerMovementStates[player]
    if not playerState then return end
    
    playerState.isWallRunning = isWallRunning
    
    -- Broadcast wall running to all other players
    local wallRunRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerWallRun)
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            wallRunRemote:FireClient(otherPlayer, player, isWallRunning, wallPosition)
        end
    end
    
    if isWallRunning then
        print(player.Name .. " started wall running")
    else
        print(player.Name .. " stopped wall running")
    end
end

-- Handle sprint state changes
local function onPlayerSprintChanged(player, isSprinting)
    local playerState = playerMovementStates[player]
    if not playerState then return end
    
    playerState.isSprinting = isSprinting
    
    -- Broadcast sprint state to all other players
    local sprintRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerSprintChanged)
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            sprintRemote:FireClient(otherPlayer, player, isSprinting)
        end
    end
end

-- Calculate movement speed based on stats (for validation)
local function calculatePlayerSpeed(player)
    local profile = DataManager:Get(player)
    if not profile or not profile.Stats then
        return 16 -- Default speed
    end
    
    local baseSpeed = 16
    local agilityBonus = profile.Stats.Agility * 0.02
    return baseSpeed * (1 + agilityBonus)
end

-- Validate player movement speed (anti-cheat)
local function validatePlayerSpeed(player)
    if not player.Character or not player.Character:FindFirstChild("Humanoid") then
        return
    end
    
    local humanoid = player.Character.Humanoid
    local expectedSpeed = calculatePlayerSpeed(player)
    local currentSpeed = humanoid.WalkSpeed
    
    -- Allow some tolerance for sprint multiplier and wall running
    local maxAllowedSpeed = expectedSpeed * 2 -- Sprint multiplier + some buffer
    
    if currentSpeed > maxAllowedSpeed + 5 then -- 5 unit tolerance
        warn("Player " .. player.Name .. " has suspicious movement speed: " .. currentSpeed .. " (expected max: " .. maxAllowedSpeed .. ")")
        -- Could reset speed or kick player here
        humanoid.WalkSpeed = expectedSpeed
    end
end

-- Public functions
function MovementHandler:GetPlayerMovementState(player)
    return playerMovementStates[player]
end

function MovementHandler:IsPlayerSprinting(player)
    local state = playerMovementStates[player]
    return state and state.isSprinting or false
end

function MovementHandler:IsPlayerWallRunning(player)
    local state = playerMovementStates[player]
    return state and state.isWallRunning or false
end

-- Initialize
function MovementHandler:Init()
    -- Setup remote event handlers
    local dashRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerDashed)
    local wallRunRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerWallRun)
    local sprintRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerSprintChanged)
    
    dashRemote.OnServerEvent:Connect(onPlayerDashed)
    wallRunRemote.OnServerEvent:Connect(onPlayerWallRun)
    sprintRemote.OnServerEvent:Connect(onPlayerSprintChanged)
    
    -- Handle player connections
    Players.PlayerAdded:Connect(initPlayerMovementState)
    Players.PlayerRemoving:Connect(cleanupPlayerMovementState)
    
    -- Initialize existing players
    for _, player in ipairs(Players:GetPlayers()) do
        initPlayerMovementState(player)
    end
    
    -- Anti-cheat: Monitor movement speeds
    game:GetService("RunService").Heartbeat:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            validatePlayerSpeed(player)
        end
    end)
    
    print("MovementHandler initialized")
end

return MovementHandler 