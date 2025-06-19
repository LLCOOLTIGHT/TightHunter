-- WallRunController.client.luau - Dynamic Wallrunning Mechanic
-- Provides linear rise and realistic fall dynamics for wallrunning

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local WallRunController = {}

-- Configuration
local Config = {
    -- Wall detection
    WallDetectionDistance = 5.0,    -- Increased from 3.6 to 5.0 for broader detection
    MinimumMoveSpeed = 0.1,         -- Minimum movement to wallrun
    MinimumHeight = 3,              -- Reduced from 4 to 3 for easier initiation
    
    -- Wallrun physics
    InitialUpwardVelocity = 15,     -- Initial boost when starting wallrun
    LinearRiseSpeed = 10,           -- Linear upward speed during wallrun
    MaxWallRunDuration = 3.0,       -- Maximum time on wall (seconds)
    FallGravity = 50,               -- Gravity when falling off wall
    WallRunSpeed = 20,              -- Forward speed along wall
    
    -- Stamina system
    StaminaCostPerSecond = 15,      -- Stamina consumed per second of wallrunning
    MinStaminaRequired = 20,        -- Minimum stamina to start wallrun
    LowStaminaThreshold = 15,       -- Stamina level at which wallrun becomes unstable
    CriticalStaminaThreshold = 5,   -- Stamina level at which wallrun fails
    
    -- Visual effects
    CameraTilt = 15,                -- Camera tilt angle in degrees
    CameraTiltSpeed = 0.3,          -- Tween speed for camera tilt
    
    MaxWallRunTime = 3.0,           -- Maximum time on wall
    WallRunJumpForce = 35,          -- Jump force when leaving wall
    RiseForce = 12,                 -- Upward force while wallrunning
    CooldownTime = 1.5,             -- Cooldown between wallruns (seconds)
    InvalidAttemptCooldown = 0.5,   -- Brief cooldown after invalid attempt
    
    -- Wall detection parameters
    MaxWallAngle = 0.4,             -- Increased from 0.3 to 0.4 for more forgiving angle
    MinWallAngle = 0.05,            -- Reduced from 0.1 to 0.05 for more forgiving angle
    WallDetectionHeight = 3.0,      -- Increased from 2.4 to 3.0
    WallDetectionWidth = 3.5        -- Increased from 2.8 to 3.5
}

-- Local variables
local player = Players.LocalPlayer
local character = nil
local humanoid = nil
local rootPart = nil
local camera = workspace.CurrentCamera

-- Wallrun state
local wallRunState = {
    isWallRunning = false,
    wallRunTime = 0,
    wallRunStartTime = 0,
    currentWall = nil,
    wallNormal = nil,
    wallDirection = nil,
    wallSide = nil,
    upwardVelocity = Config.RiseForce,
    originalWalkSpeed = 16,
    originalJumpPower = 50,
    wallRunConnection = nil,
    debugParts = {}  -- Store debug visualization parts
}

-- Input state
local inputState = {
    isHoldingSpace = false
}

local cameraEffects = {
    originalCFrame = nil,
    tiltTween = nil
}

local awaitingWallRunApproval = false
local pendingWallData = nil
local lastWallRunEnd = 0        -- Track when last wallrun ended
local lastInvalidAttempt = 0    -- Track failed wallrun attempts

-- Forward declarations for interdependent functions
local startWallRun, endWallRun, updateWallRunPhysics, detectWall

-- Get current player stamina (integration with existing system)
local function getCurrentStamina()
    -- Integrate with the existing MovementController stamina system
    local movementController = _G.MovementController
    if movementController and movementController.GetCurrentStamina then
        return movementController:GetCurrentStamina()
    end
    return 100 -- Default to 100 if no stamina system
end

-- After RemoteEvents require, add helper
local function getRemote(name)
    return RemoteEvents:GetRemoteEvent(name)
end

-- Apply camera tilt effect (DISABLED)
local function applyCameraTilt(angle)
    -- Camera tilt effects disabled per user request
    return
end

-- Disable debug part creation when DEBUG is false
local function createDebugPart()
    if not DEBUG then return nil end
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.5
    part.Color = Color3.new(1, 0, 0)
    part.Size = Vector3.new(0.2, 0.2, 0.2)
    part.Parent = workspace
    table.insert(wallRunState.debugParts, part)
    return part
end

local function clearDebugParts()
    if not DEBUG then return end
    for _, part in ipairs(wallRunState.debugParts) do
        part:Destroy()
    end
    wallRunState.debugParts = {}
end

-- After helper functions, define body mover helpers earlier to ensure they exist before remote events can trigger
local function createBodyMovers()
    -- Remove existing body movers first
    if wallRunState.bodyVelocity then
        wallRunState.bodyVelocity:Destroy()
    end
    if wallRunState.bodyAngularVelocity then
        wallRunState.bodyAngularVelocity:Destroy()
    end

    -- Strong BodyVelocity to keep player on wall
    wallRunState.bodyVelocity = Instance.new("BodyVelocity")
    wallRunState.bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    if wallRunState.wallDirection then
        wallRunState.bodyVelocity.Velocity = wallRunState.wallDirection * Config.WallRunSpeed + Vector3.new(0, Config.LinearRiseSpeed, 0)
    else
        wallRunState.bodyVelocity.Velocity = Vector3.new(0, Config.LinearRiseSpeed, 0)
    end
    wallRunState.bodyVelocity.Parent = rootPart

    -- Orientation control (optional)
    wallRunState.bodyAngularVelocity = Instance.new("BodyAngularVelocity")
    wallRunState.bodyAngularVelocity.MaxTorque = Vector3.new(0, 4000, 0)
    wallRunState.bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
    wallRunState.bodyAngularVelocity.Parent = rootPart
end

local function removeBodyMovers()
    if wallRunState.bodyVelocity then
        wallRunState.bodyVelocity:Destroy()
        wallRunState.bodyVelocity = nil
    end
    if wallRunState.bodyAngularVelocity then
        wallRunState.bodyAngularVelocity:Destroy()
        wallRunState.bodyAngularVelocity = nil
    end
end

-- Remote event connection function with proper state management
local function connectWallRunAlign()
    local wallRunAlignRemote = getRemote("WallRunAlign")
    if wallRunAlignRemote then
        print("[Controller] Found WallRunAlign remote, connecting...")
        wallRunAlignRemote.OnClientEvent:Connect(function(isWallRunning, wallNormal, side)
            print(('[Controller] Received WallRunAlign: isWallRunning=%s, Normal=%s, Side=%s')
                :format(tostring(isWallRunning), tostring(wallNormal), tostring(side)))

            -- Cooldown checks only when starting a new wallrun
            local currentTime = tick()
            if isWallRunning then
                if wallRunState.isWallRunning then return end
                if currentTime - lastWallRunEnd < Config.CooldownTime then return end
                if currentTime - lastInvalidAttempt < Config.InvalidAttemptCooldown then return end

                startWallRun(wallNormal, side)
            else
                -- Ensure we end wallrun if server tells us to
                endWallRun()
            end
        end)
        print('[Controller] Successfully connected to WallRunAlign remote')
    else
        warn("[Controller] WallRunAlign remote not found!")
    end
end

-- Start wallrunning
startWallRun = function(wallNormal, side)
    if wallRunState.isWallRunning then return end
    
    print("[Controller] Starting wallrun...")
    
    -- Calculate wall direction from normal
    local wallDirection = wallNormal:Cross(Vector3.new(0, 1, 0)).Unit
    -- Ensure wall direction matches movement direction
    if humanoid and humanoid.MoveDirection.Magnitude > 0 then
        if wallDirection:Dot(humanoid.MoveDirection) < 0 then
            wallDirection = -wallDirection
        end
    end
    
    -- Find the wall object through raycast (for name display)
    local wall = nil
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {character}
    
    local raycast = workspace:Raycast(rootPart.Position, wallNormal * -3, rayParams)
    if raycast and raycast.Instance then
        wall = raycast.Instance
    end
    
    -- Set wallrun state
    wallRunState.isWallRunning = true
    wallRunState.wallRunTime = 0
    wallRunState.wallRunStartTime = tick()
    wallRunState.currentWall = wall
    wallRunState.wallNormal = wallNormal
    wallRunState.wallDirection = wallDirection
    wallRunState.wallSide = side
    wallRunState.upwardVelocity = Config.InitialUpwardVelocity
    wallRunState.originalWalkSpeed = humanoid.WalkSpeed
    wallRunState.originalJumpPower = humanoid.JumpPower
    
    -- Disable default movement
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    
    -- Create physics controllers
    createBodyMovers()
    
    -- Start wallrun physics update loop
    wallRunState.wallRunConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not wallRunState.isWallRunning then
            -- Connection might persist for a frame after being disconnected
            if wallRunState.wallRunConnection then
                wallRunState.wallRunConnection:Disconnect()
                wallRunState.wallRunConnection = nil
            end
            return
        end

        -- Check for timeout first
        local currentTime = tick()
        if currentTime - wallRunState.wallRunStartTime >= Config.MaxWallRunDuration then
            print("[Controller] Wallrun timed out after", Config.MaxWallRunDuration, "seconds")
            endWallRun()
            return
        end
        
        -- Update wallrun physics
        updateWallRunPhysics(deltaTime)
        
        -- Check if still touching wall
        local canWallRun, hitWall, _ = detectWall()
        if not canWallRun or hitWall ~= wallRunState.currentWall then
            print("[Controller] Lost contact with wall, ending wallrun")
            endWallRun()
        end
    end)
    
    -- Apply camera tilt based on wall side
    local tiltAngle = Config.CameraTilt
    if side == "LEFT" then
        tiltAngle = -tiltAngle
    end
    applyCameraTilt(tiltAngle)
    
    -- No need to notify server here; server already approved
    awaitingWallRunApproval = false
    
    print("[Controller] Started wallrunning on:", wall and wall.Name or "Unknown Wall")
    
    -- Fallback: ensure wallrun cannot exceed time limit even if Heartbeat fails
    task.delay(Config.MaxWallRunDuration + 0.05, function()
        if wallRunState.isWallRunning then
            warn("[Controller] Fallback timeout trigger – forcing wallrun end")
            endWallRun()
        end
    end)
end

-- Enhanced wallrun ending with cooldown tracking
endWallRun = function()
    if not wallRunState.isWallRunning then return end
    
    print("[Controller] Ending wallrun...")
    
    wallRunState.isWallRunning = false
    lastWallRunEnd = tick()  -- Record when wallrun ended
    
    if wallRunState.wallRunConnection then
        if wallRunState.wallRunConnection.Connected then
            wallRunState.wallRunConnection:Disconnect()
        end
        wallRunState.wallRunConnection = nil
    end
    
    -- Restore humanoid settings
    if humanoid then
        humanoid.WalkSpeed = wallRunState.originalWalkSpeed
        humanoid.JumpPower = wallRunState.originalJumpPower
    end
    
    -- Send end event to server
    local playerWallRunRemote = getRemote("PlayerWallRun")
    if playerWallRunRemote then
        playerWallRunRemote:FireServer(false, wallRunState.currentWall, wallRunState.wallSide)
        print("[Controller] Sent wallrun end to server")
    else
        print("[Controller] Failed to send wallrun end - PlayerWallRun remote not found")
    end
    
    wallRunState.currentWall = nil
    wallRunState.wallSide = nil
    
    -- Clean up physics controllers
    removeBodyMovers()
    
    -- Clear debug visualization
    clearDebugParts()
    
    print("[Controller] Ended wallrunning")
end

-- Wall detection helper
local function isValidWall(hit)
    if not hit or not hit.Instance then
        if DEBUG then print("[DEBUG] Invalid hit - no instance") end
        return false
    end
    
    if not hit.Instance.CanCollide then
        if DEBUG then print("[DEBUG] Invalid hit - not collidable") end
        return false
    end
    
    -- Only allow normals that are mostly horizontal (i.e. |Y| small)
    local ny = hit.Normal.Y
    local isHorizontal = math.abs(ny) < 0.2
    if not isHorizontal then
        if DEBUG then print("[DEBUG] Invalid hit - not horizontal enough. Y normal:", ny) end
    end
    return isHorizontal
end

-- Enhanced wall detection with proper filtering
detectWall = function()
    if not character or not humanoid or not rootPart then
        if DEBUG then print("[DEBUG] Missing character parts") end
        return false, nil, nil
    end
    
    -- Check cooldowns first
    local currentTime = tick()
    if currentTime - lastWallRunEnd < Config.CooldownTime then
        if DEBUG then print("[DEBUG] On cooldown") end
        return false, nil, nil  -- On cooldown
    end
    
    if currentTime - lastInvalidAttempt < Config.InvalidAttemptCooldown then
        if DEBUG then print("[DEBUG] On invalid attempt cooldown") end
        return false, nil, nil  -- Brief cooldown after invalid attempt
    end
    
    -- Only detect walls when moving and at proper height
    local moveMagnitude = humanoid.MoveDirection.Magnitude
    if moveMagnitude < Config.MinimumMoveSpeed then
        if DEBUG then print("[DEBUG] Not moving fast enough:", moveMagnitude) end
        return false, nil, nil
    end
    
    local heightAboveGround = rootPart.Position.Y - workspace.FallenPartsDestroyHeight
    if heightAboveGround < Config.MinimumHeight then
        if DEBUG then print("[DEBUG] Too close to ground:", heightAboveGround) end
        return false, nil, nil
    end
    
    -- Setup raycast parameters
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {character}
    rayParams.IgnoreWater = true
    
    -- Cast from multiple vertical offsets for better detection
    local verticalOffsets = {
        Vector3.new(0, 0, 0),           -- Waist height
        Vector3.new(0, 1.5, 0),         -- Upper chest height
        Vector3.new(0, -0.5, 0),        -- Lower body height
        Vector3.new(0, 2.5, 0)          -- Head height
    }
    
    local characterCenter = rootPart.Position
    local rightVector = rootPart.CFrame.RightVector
    local forwardVector = rootPart.CFrame.LookVector
    local moveDirection = humanoid.MoveDirection
    
    -- Cast rays in a wider pattern with more angles
    local directions = {
        rightVector * Config.WallDetectionDistance,                                   -- Right
        -rightVector * Config.WallDetectionDistance,                                  -- Left
        (rightVector + forwardVector).Unit * Config.WallDetectionDistance,            -- Forward-right
        (-rightVector + forwardVector).Unit * Config.WallDetectionDistance,           -- Forward-left
        (rightVector * 0.5 + forwardVector).Unit * Config.WallDetectionDistance,      -- Diagonal right
        (-rightVector * 0.5 + forwardVector).Unit * Config.WallDetectionDistance,     -- Diagonal left
        (rightVector * 0.3 + forwardVector).Unit * Config.WallDetectionDistance,      -- Shallow right
        (-rightVector * 0.3 + forwardVector).Unit * Config.WallDetectionDistance,     -- Shallow left
    }
    
    -- Clear previous debug parts
    clearDebugParts()
    
    for offsetIndex, offset in ipairs(verticalOffsets) do
        local origin = characterCenter + offset
        for dirIndex, direction in ipairs(directions) do
            -- Start ray slightly away from character to avoid self-hits
            local rayStart = origin + direction.Unit * 1.5  -- Reduced from 2 to 1.5
            local rayEnd = rayStart + direction
            
            -- Visualize ray
            local debugPart = createDebugPart()
            if debugPart then
                debugPart.Position = rayStart
                debugPart.CFrame = CFrame.lookAt(rayStart, rayEnd)
                debugPart.Size = Vector3.new(0.2, 0.2, direction.Magnitude)
            end
            
            if DEBUG then print("[DEBUG] Casting ray from", rayStart, "to", rayEnd) end
            local raycast = workspace:Raycast(rayStart, direction, rayParams)
            
            if isValidWall(raycast) then
                local wallNormal = raycast.Normal
                
                if moveDirection.Magnitude > 0 then
                    local dot = moveDirection:Dot(wallNormal)
                    -- More forgiving angle check
                    if math.abs(dot) < 0.98 then  -- Increased from 0.95 to 0.98
                        if DEBUG then print(('[DEBUG] Wall hit @%s | Dot: %.2f - VALID'):format(tostring(offset), dot)) end
                        
                        -- Determine side with more forgiving check
                        local rightDot = rightVector:Dot(-wallNormal)
                        local side = rightDot > 0 and "RIGHT" or "LEFT"
                        
                        -- Visualize successful wall detection
                        local successPart = createDebugPart()
                        if successPart then
                            successPart.Position = raycast.Position
                            successPart.Color = Color3.new(0, 1, 0)
                            successPart.Size = Vector3.new(0.5, 0.5, 0.5)
                        end
                        
                        return true, raycast.Instance, side
                    else
                        if DEBUG then print("[DEBUG] Wall too parallel to movement. Dot:", dot) end
                    end
                end
            end
        end
    end
    
    if DEBUG then print("[DEBUG] No valid walls found after checking all directions") end
    return false, nil, nil
end

-- Update wallrun physics
updateWallRunPhysics = function(deltaTime)
    if not wallRunState.isWallRunning or not wallRunState.bodyVelocity then
        return
    end
    
    wallRunState.wallRunTime = wallRunState.wallRunTime + deltaTime
    
    -- Calculate upward velocity with linear rise and realistic fall
    local timeNormalized = wallRunState.wallRunTime / Config.MaxWallRunDuration
    
    if timeNormalized < 0.2 then
        -- Linear rise phase (first 20% of wallrun)
        wallRunState.upwardVelocity = Config.LinearRiseSpeed
    else
        -- Realistic fall phase (last 80% of wallrun)
        local fallProgress = (timeNormalized - 0.2) / 0.8
        wallRunState.upwardVelocity = (Config.LinearRiseSpeed * (1 - fallProgress) - (Config.FallGravity * fallProgress * fallProgress))
    end
    
    -- Calculate velocity components
    local forwardVelocity = wallRunState.wallDirection * Config.WallRunSpeed
    local upwardVelocity = Vector3.new(0, wallRunState.upwardVelocity, 0)
    local totalVelocity = forwardVelocity + upwardVelocity
    
    -- Apply velocity
    wallRunState.bodyVelocity.Velocity = totalVelocity
    
    -- End wallrun if time exceeded or fell too much
    if wallRunState.wallRunTime >= Config.MaxWallRunDuration or 
       wallRunState.upwardVelocity < -20 then
        print("[CLIENT] Ending wallrun - Time:", wallRunState.wallRunTime)
        endWallRun()
    end
end

-- Input handling with cooldown awareness
local function handleInput(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Space then
        local currentTime = tick()
        
        -- Check cooldowns before attempting wallrun
        if currentTime - lastWallRunEnd < Config.CooldownTime then
            print(("[CLIENT] Wallrun on cooldown. Time remaining: %.1f seconds"):format(
                Config.CooldownTime - (currentTime - lastWallRunEnd)))
            return
        end
        
        if currentTime - lastInvalidAttempt < Config.InvalidAttemptCooldown then
            print("[CLIENT] Recently failed wallrun attempt, brief cooldown active")
            return
        end
        
        if not wallRunState.isWallRunning then
            local wallFound, wall, side = detectWall()
            if wallFound then
                -- Send wallrun request to server
                local playerWallRunRemote = getRemote("PlayerWallRun")
                if playerWallRunRemote then
                    playerWallRunRemote:FireServer(true, wall, side)
                    print("[CLIENT] Sent wallrun request to server")
                else
                    warn("[CLIENT] PlayerWallRun remote not found")
                end
            else
                -- Track failed attempt to prevent spam
                lastInvalidAttempt = currentTime
                print("[CLIENT] No valid wall found for wallrunning")
            end
        else
            -- Jump off wall
            endWallRun()
            
            if humanoid then
                humanoid.Jump = true
                local bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                bodyVelocity.Velocity = rootPart.CFrame.LookVector * Config.WallRunJumpForce
                bodyVelocity.Parent = rootPart
                
                game:GetService("Debris"):AddItem(bodyVelocity, 0.5)
            end
        end
    end
end

-- Character setup
local function setupCharacter(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    
    -- Reset wallrun state
    endWallRun()
end

-- Main update loop
local function update()
    if not character or not humanoid or not rootPart then return end
    
    -- Update movement state
    inputState.isMoving = humanoid.MoveDirection.Magnitude > Config.MinimumMoveSpeed
end

-- Initialize
function WallRunController:Init()
    -- Set up input handling
    UserInputService.InputBegan:Connect(handleInput)
    
    -- Set up character handling
    Players.LocalPlayer.CharacterAdded:Connect(function(newCharacter)
        setupCharacter(newCharacter)
    end)
    
    -- Setup current character if it exists
    if Players.LocalPlayer.Character then
        setupCharacter(Players.LocalPlayer.Character)
    end
    
    -- Connect remote events
    connectWallRunAlign()
    
    print("WallRunController initialized")
end

-- Public functions
function WallRunController:IsWallRunning()
    return wallRunState.isWallRunning
end

function WallRunController:GetWallRunTime()
    return wallRunState.wallRunTime
end

function WallRunController:GetCurrentStamina()
    -- Get current stamina from the movement controller
    local movementController = _G.MovementController
    if movementController and movementController.GetCurrentStamina then
        return movementController:GetCurrentStamina()
    end
    return 100 -- Default value if no stamina system is available
end

function WallRunController:ForceEndWallRun()
    endWallRun()
end

-- Make available globally for integration
_G.WallRunController = WallRunController

-- Call Init to activate the controller
WallRunController:Init()

return WallRunController 