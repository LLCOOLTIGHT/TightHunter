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

-- Server-side wallrun detection and validation (identical to client logic)
local function detectWallRunning(player)
    if not player.Character then return false, nil, nil end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not rootPart then return false, nil, nil end
    
    -- Only detect walls when moving and slightly off the ground (identical to client)
    if humanoid.MoveDirection.Magnitude < 0.1 or rootPart.Position.Y < workspace.FallenPartsDestroyHeight + 5 then
        return false, nil, nil
    end
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {player.Character}
    
    -- Use shorter, more precise raycasts offset from character center (identical to client)
    local characterCenter = rootPart.Position + Vector3.new(0, 0, 0)
    local directions = {
        rootPart.CFrame.RightVector * 2.5,    -- Right (shorter distance)
        -rootPart.CFrame.RightVector * 2.5,   -- Left  (shorter distance)
    }
    
    -- Check each direction for walls (identical logic to client)
    for i, direction in pairs(directions) do
        local raycast = workspace:Raycast(characterCenter, direction, rayParams)
        if raycast and raycast.Instance and raycast.Instance.CanCollide then
            -- Additional check: make sure we're actually moving toward or along the wall
            local wallNormal = raycast.Normal
            local moveDirection = humanoid.MoveDirection
            local dotProduct = wallNormal:Dot(moveDirection)
            
            print("[SERVER DEBUG] Found wall:", raycast.Instance.Name, "| Normal:", wallNormal, "| Dot product:", dotProduct)
            
            -- Only return true if we're moving somewhat parallel to the wall (identical to client)
            if math.abs(dotProduct) < 0.8 then  -- Allow some tolerance
                print("[SERVER DEBUG] Wall validation PASSED for", player.Name)
                return true, raycast.Instance, wallNormal
            else
                print("[SERVER DEBUG] Wall validation FAILED - dot product too high:", math.abs(dotProduct))
            end
        end
    end
    
    print("[SERVER DEBUG] No walls found for", player.Name, "at position:", characterCenter)
    
    return false, nil, nil
end

-- Handle wall running events
local function onPlayerWallRun(player, isWallRunning, wallPosition)
    local playerState = playerMovementStates[player]
    if not playerState then return end
    
    -- Server-side validation for wallrunning
    if isWallRunning then
        local canWallRun, wall, wallNormal = detectWallRunning(player)
        if not canWallRun then
            -- Client claimed wallrun but server doesn't detect it - reject
            -- Add more detailed debug information
            local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
            local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if humanoid and rootPart then
                warn("Player " .. player.Name .. " attempted invalid wallrun:")
                warn("  - Position:", rootPart.Position)
                warn("  - MoveDirection:", humanoid.MoveDirection)
                warn("  - MoveDirection.Magnitude:", humanoid.MoveDirection.Magnitude)
                warn("  - Is moving:", humanoid.MoveDirection.Magnitude > 0.1)
                warn("  - Y position check:", rootPart.Position.Y > workspace.FallenPartsDestroyHeight + 5)
            else
                warn("Player " .. player.Name .. " attempted wallrun but character parts missing")
            end
            return
        end
        
        -- Send alignment data to client for proper animation orientation
        local alignRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.WallRunAlign)
        alignRemote:FireClient(player, true, wallNormal, wall)
        
        playerState.isWallRunning = true
        print("[SERVER] Validated wallrun for " .. player.Name .. " with wall normal:", wallNormal)
        print("[SERVER] Sent WallRunAlign event to client")
    else
        -- Wallrun ended
        local alignRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.WallRunAlign)
        alignRemote:FireClient(player, false)
        
        playerState.isWallRunning = false
    end
    
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
    local alignRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.WallRunAlign)
    
    dashRemote.OnServerEvent:Connect(onPlayerDashed)
    wallRunRemote.OnServerEvent:Connect(onPlayerWallRun)
    sprintRemote.OnServerEvent:Connect(onPlayerSprintChanged)
    -- Note: alignRemote is server->client only, no OnServerEvent needed
    
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