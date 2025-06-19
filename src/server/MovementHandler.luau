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
    rayParams.IgnoreWater = true
    
    -- Use raycasts identical to the client logic for consistency
    local characterCenter = rootPart.Position
    local rightVector = rootPart.CFrame.RightVector
    local forwardVector = rootPart.CFrame.LookVector
    
    -- Match client-side detection distance (3.5 studs) so that both
    -- sides evaluate the exact same wall candidates. Using the same
    -- distance prevents subtle desyncs where the client succeeds but
    -- the server, using a longer ray, starts the cast inside the wall
    -- or overshoots thin geometry.
    local DETECTION_DISTANCE = 3.5

    local directions = {
        rightVector * DETECTION_DISTANCE,                         -- Right
        -rightVector * DETECTION_DISTANCE,                        -- Left
        (rightVector + forwardVector).Unit  * DETECTION_DISTANCE, -- Forward-right
        (-rightVector + forwardVector).Unit * DETECTION_DISTANCE, -- Forward-left
    }
    
    -- Cast from two vertical offsets (waist & head height) for robustness
    local verticalOffsets = { Vector3.new(0, 0, 0), Vector3.new(0, 2, 0) }

    for offsetIndex, offset in ipairs(verticalOffsets) do
        local origin = characterCenter + offset
        for dirIndex, direction in ipairs(directions) do
            -- Offset the ray origin 2 studs away from the player (identical to client)
            -- so that the cast does not immediately start within the character model
            -- and has a better chance of detecting thin walls that are touching the
            -- player. This mirrors the client logic exactly.
            local rayStart = origin + direction.Unit * 2
            local raycast = workspace:Raycast(rayStart, direction, rayParams)
            
            if raycast and raycast.Instance then
                if raycast.Instance.CanCollide then
                    local wallNormal = raycast.Normal
                    local moveDirection = humanoid.MoveDirection
                    
                    if moveDirection.Magnitude > 0 then
                        local dot = moveDirection:Dot(wallNormal)
                        
                        -- Only log successful validations to reduce spam
                        if math.abs(dot) < 0.9 then
                            print(('[SERVER DEBUG] Wall validation PASSED! Normal: %s, Dot: %.2f'):format(tostring(wallNormal), dot))
                            return true, wallNormal
                        end
                    end
                end
            end
        end
    end
    
    -- Only log when no walls found to help with debugging failed attempts
    print(('[SERVER DEBUG] No walls found for %s at position: %s'):format(player.Name, tostring(characterCenter)))
    return false, nil
end

-- Handle wall running events
local function onPlayerWallRun(player, isWallRunning, wallPosition)
    local playerState = playerMovementStates[player]
    if not playerState then return end
    
    -- Server-side validation for wallrunning
    if isWallRunning then
        local canWallRun, wallNormal = detectWallRunning(player)
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
        
        -- Determine which side of the wall the player is on (LEFT/RIGHT) by comparing the
        -- player's right vector to the wall normal. A positive dot product means the wall
        -- is on the right side of the player, otherwise it's on the left.
        local side = "RIGHT"
        local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            local rightDot = rootPart.CFrame.RightVector:Dot(-wallNormal)
            if rightDot < 0 then
                side = "LEFT"
            end
        end
        
        -- Send alignment data to client for proper animation orientation
        local alignRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.WallRunAlign)
        alignRemote:FireClient(player, true, wallNormal, side)
        
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