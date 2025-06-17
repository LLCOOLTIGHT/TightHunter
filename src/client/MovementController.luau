-- MovementController: Enhanced movement system for TightHunter
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataHandler = require(script.Parent.DataHandler)
local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local MovementController = {}

-- Configuration
local Config = {
    -- Base movement speeds
    BaseWalkSpeed = 16,
    BaseJumpPower = 50,
    
    -- Dash system removed - now handled by StarterCharacterScripts double-tap system
    
    -- Sprint system
    SprintMultiplier = 1.5,
    SprintStaminaCost = 5, -- per second
    MaxStamina = 100,
    StaminaRegen = 10, -- per second
    
    -- Wall running
    WallRunSpeed = 20,
    WallRunDuration = 3,
    WallRunJumpPower = 60,
    
    -- Stat scaling
    AgilitySpeedMultiplier = 0.02, -- 2% speed per agility point
    ConstitutionStaminaMultiplier = 2, -- 2 stamina per constitution point
}

-- Local variables
local player = Players.LocalPlayer
local character = nil
local humanoid = nil
local rootPart = nil

-- Note: Wallrun animation is now handled by WallRunAlignment.client.luau in StarterCharacterScripts
-- This provides server-validated wallrun alignment data for proper animation orientation

-- Movement state (dash-related variables removed)
local movementState = {
    isSprinting = false,
    isWallRunning = false,
    stamina = Config.MaxStamina,
    wallRunStartTime = 0,
    currentWall = nil,
    wallRunBodyVelocity = nil, -- Track the current wall run BodyVelocity
}

-- Input tracking
local keysPressed = {
    W = false,
    A = false,
    S = false,
    D = false,
    LeftShift = false,
    Space = false,
}

-- Events (OnDash removed - handled by StarterCharacterScripts system)
MovementController.OnWallRun = Instance.new("BindableEvent")
MovementController.OnStaminaChanged = Instance.new("BindableEvent")

-- Note: Wallrun animation and orientation logic moved to WallRunAlignment.client.luau
-- This MovementController now only handles client-side physics and fires events to server

-- Get current player stats
local function getPlayerStats()
    local data = DataHandler:GetData()
    if data and data.Stats then
        return data.Stats
    end
    return {Agility = 0, Constitution = 0}
end

-- Calculate speed based on stats
local function calculateSpeed()
    local stats = getPlayerStats()
    local agilityBonus = stats.Agility * Config.AgilitySpeedMultiplier
    return Config.BaseWalkSpeed * (1 + agilityBonus)
end

-- Calculate max stamina based on stats
local function calculateMaxStamina()
    local stats = getPlayerStats()
    return Config.MaxStamina + (stats.Constitution * Config.ConstitutionStaminaMultiplier)
end

-- Update movement speed
local function updateMovementSpeed()
    if not humanoid then return end
    
    local baseSpeed = calculateSpeed()
    local currentSpeed = baseSpeed
    
    -- Apply sprint multiplier
    if movementState.isSprinting and movementState.stamina > 0 then
        currentSpeed = baseSpeed * Config.SprintMultiplier
    end
    
    -- Apply wall running speed
    if movementState.isWallRunning then
        currentSpeed = Config.WallRunSpeed
    end
    
    humanoid.WalkSpeed = currentSpeed
end

-- Old dash function removed - now using enhanced double-tap dash system in StarterCharacterScripts

-- Enhanced wall detection - more precise and prevents false positives
local function isStillTouchingWall()
    if not rootPart or not humanoid then return false, nil, nil end
    
    -- Only detect walls when moving and slightly off the ground (prevents hugging issues)
    if humanoid.MoveDirection.Magnitude < 0.1 or rootPart.Position.Y < workspace.FallenPartsDestroyHeight + 5 then
        return false, nil, nil
    end
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {character}
    
    -- Use shorter, more precise raycasts offset from character center
    local characterCenter = rootPart.Position + Vector3.new(0, 0, 0)
    local directions = {
        rootPart.CFrame.RightVector * 2.5,    -- Right (shorter distance)
        -rootPart.CFrame.RightVector * 2.5,   -- Left  (shorter distance)
    }
    
    -- Check each direction for walls
    for i, direction in pairs(directions) do
        local raycast = workspace:Raycast(characterCenter, direction, rayParams)
        if raycast and raycast.Instance and raycast.Instance.CanCollide then
            -- Additional check: make sure we're actually moving toward or along the wall
            local wallNormal = raycast.Normal
            local moveDirection = humanoid.MoveDirection
            local dotProduct = wallNormal:Dot(moveDirection)
            
            -- Only return true if we're moving somewhat parallel to the wall (not directly into it)
            if math.abs(dotProduct) < 0.8 then  -- Allow some tolerance
                return true, raycast.Instance, wallNormal
            end
        end
    end
    
    return false, nil, nil
end

-- Wall running detection and management
local function detectWallRunning()
    if not rootPart then return end
    
    -- If we're currently wall running, check if we're still touching a wall
    if movementState.isWallRunning then
        local stillTouching, wall, wallNormal = isStillTouchingWall()
        
        -- Check if wall run should end
        local shouldEndWallRun = false
        
        if not stillTouching then
            shouldEndWallRun = true
        elseif tick() - movementState.wallRunStartTime > Config.WallRunDuration then
            shouldEndWallRun = true -- Time limit reached
        elseif humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
            shouldEndWallRun = true -- Landed on ground
        end
        
        if shouldEndWallRun then
            -- End wall run immediately
            if movementState.wallRunBodyVelocity then
                movementState.wallRunBodyVelocity:Destroy()
                movementState.wallRunBodyVelocity = nil
            end
            
            -- Reset humanoid state to ensure proper physics
            if humanoid then
                humanoid.PlatformStand = false
                -- Re-enable default humanoid states
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
            end
            
            movementState.isWallRunning = false
            movementState.currentWall = nil
            MovementController.OnWallRun:Fire(false, nil)
            
            -- Send wallrun end to server
            local wallRunRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerWallRun)
            wallRunRemote:FireServer(false, nil)
            print("[CLIENT] Sent wallrun END to server (natural end)")
            
            return
        end
    else
        -- Not currently wall running, check if we should start
        local touchingWall, wall, wallNormal = isStillTouchingWall()
        
        -- Only start wall running if: moving, in air, and has some velocity
        local velocity = rootPart.AssemblyLinearVelocity
        local isInAir = not humanoid.FloorMaterial or humanoid.FloorMaterial == Enum.Material.Air
        local hasMinimumSpeed = velocity.Magnitude > 10
        
        if touchingWall and wallNormal and humanoid and humanoid.MoveDirection.Magnitude > 0 and isInAir and hasMinimumSpeed then
            -- Set up wallrun state and physics (animation handled by server-client system)
            movementState.currentWall = wall
            movementState.wallRunStartTime = tick()
            movementState.isWallRunning = true
            
            -- Disable default humanoid states that cause jittering
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
            
            -- Prevent falling while wall running (increased Y velocity)
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(0, 4000, 0)
            bodyVelocity.Velocity = Vector3.new(0, 15, 0)
            bodyVelocity.Parent = rootPart
            
            -- Store reference for proper cleanup
            movementState.wallRunBodyVelocity = bodyVelocity
            
            -- Fire local event and send to server for validation
            MovementController.OnWallRun:Fire(true, wall)
            
            -- Send wallrun start to server for validation and animation alignment
            local wallRunRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerWallRun)
            wallRunRemote:FireServer(true, rootPart.Position)
            print("[CLIENT] Sent wallrun START to server at position:", rootPart.Position)
        end
    end
end

-- Stamina management
local function updateStamina(deltaTime)
    local maxStamina = calculateMaxStamina()
    
    -- Consume stamina when sprinting
    if movementState.isSprinting and keysPressed.W and movementState.stamina > 0 then
        movementState.stamina = math.max(0, movementState.stamina - Config.SprintStaminaCost * deltaTime)
    else
        -- Regenerate stamina
        movementState.stamina = math.min(maxStamina, movementState.stamina + Config.StaminaRegen * deltaTime)
    end
    
    -- Stop sprinting if out of stamina
    if movementState.stamina <= 0 then
        movementState.isSprinting = false
    end
    
    MovementController.OnStaminaChanged:Fire(movementState.stamina, maxStamina)
end

-- Input handling
local function onKeyDown(key)
    local keyCode = key.KeyCode.Name
    
    if keyCode == "W" or keyCode == "A" or keyCode == "S" or keyCode == "D" then
        keysPressed[keyCode] = true
    elseif keyCode == "LeftShift" then
        keysPressed.LeftShift = true
        movementState.isSprinting = true
    elseif keyCode == "Space" then
        keysPressed.Space = true
        
        -- Wall run jump
        if movementState.isWallRunning then
            -- Clean up wall run BodyVelocity before jumping
            if movementState.wallRunBodyVelocity then
                movementState.wallRunBodyVelocity:Destroy()
                movementState.wallRunBodyVelocity = nil
            end
            
            local jumpDirection = rootPart.CFrame.LookVector + Vector3.new(0, 1, 0)
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
            bodyVelocity.Velocity = jumpDirection.Unit * Config.WallRunJumpPower
            bodyVelocity.Parent = rootPart
            
            -- Shorter cleanup time to prevent lingering forces
            game:GetService("Debris"):AddItem(bodyVelocity, 0.3)
            
            print("[WALL JUMP] Applied velocity:", math.floor(Config.WallRunJumpPower), "in direction:", jumpDirection.Unit)
            
            -- Re-enable humanoid states when wall jumping
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
            
            movementState.isWallRunning = false
            movementState.currentWall = nil
            MovementController.OnWallRun:Fire(false, nil)
            
            -- Send wallrun end to server (wall jump)
            local wallRunRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerWallRun)
            wallRunRemote:FireServer(false, nil)
            print("[CLIENT] Sent wallrun END to server (wall jump)")
        end
    end
    
    updateMovementSpeed()
end

local function onKeyUp(key)
    local keyCode = key.KeyCode.Name
    
    if keyCode == "W" or keyCode == "A" or keyCode == "S" or keyCode == "D" then
        keysPressed[keyCode] = false
    elseif keyCode == "LeftShift" then
        keysPressed.LeftShift = false
        movementState.isSprinting = false
    elseif keyCode == "Space" then
        keysPressed.Space = false
    end
    
    updateMovementSpeed()
end

-- Character setup
local function onCharacterAdded(newCharacter)
    character = newCharacter
    
    -- Wait for essential parts
    local success, err = pcall(function()
        humanoid = character:WaitForChild("Humanoid", 10)
        rootPart = character:WaitForChild("HumanoidRootPart", 10)
    end)
    
    if not success then
        warn("Failed to get character parts:", err)
        return
    end
    
    -- Reset movement state and clean up any existing BodyVelocity
    if movementState.wallRunBodyVelocity then
        movementState.wallRunBodyVelocity:Destroy()
        movementState.wallRunBodyVelocity = nil
    end
    
    -- Note: Animation reset now handled by WallRunAlignment.client.luau
    
    movementState.stamina = calculateMaxStamina()
    movementState.isSprinting = false
    movementState.isWallRunning = false
    movementState.currentWall = nil
    
    -- Set initial movement speed
    updateMovementSpeed()
end

-- Main update loop
local function onHeartbeat(deltaTime)
    if not character or not humanoid or not rootPart then return end
    
    updateStamina(deltaTime)
    detectWallRunning()
    updateMovementSpeed()
    
    -- Debug wall running every 0.5 seconds (with safety check)
    if tick() % 0.5 < deltaTime and debugWallRunning then
        pcall(debugWallRunning)  -- Safe call to prevent nil errors
    end
    
    -- Detect unexpected launches (high upward velocity)
    if rootPart then
        local velocity = rootPart.AssemblyLinearVelocity
        -- Only warn about really high velocities (>70) or if they persist
        if velocity.Y > 70 then
            warn("[MAJOR LAUNCH DETECTED] Unexpected upward velocity:", math.floor(velocity.Y), "| Wall running:", movementState.isWallRunning)
        elseif velocity.Y > 50 and not movementState.isWallRunning then
            -- Log minor launches for debugging but don't spam console
            print("[Minor Launch]", math.floor(velocity.Y), "Y velocity | Jumping:", keysPressed.Space, "| On ground:", humanoid.FloorMaterial ~= Enum.Material.Air)
        end
    end
end

-- Public functions
function MovementController:GetStamina()
    return movementState.stamina, calculateMaxStamina()
end

function MovementController:IsMoving()
    return humanoid and humanoid.MoveDirection.Magnitude > 0
end

function MovementController:IsSprinting()
    return movementState.isSprinting
end

-- IsDashing function removed - dash system now handled by StarterCharacterScripts

function MovementController:IsWallRunning()
    return movementState.isWallRunning
end

-- Note: Wallrun animation status now handled by WallRunAlignment.client.luau

-- Debug function for wall running
local function debugWallRunning()
    if movementState.isWallRunning then
        local stillTouching = isStillTouchingWall()
        local bodyVelExists = movementState.wallRunBodyVelocity ~= nil
        print("[WALL RUN DEBUG] Still touching:", stillTouching, "| BodyVel exists:", bodyVelExists, "| Time:", math.floor(tick() - movementState.wallRunStartTime), "| Animation handled by WallRunAlignment.client.luau")
        
        if rootPart then
            local velocity = rootPart.AssemblyLinearVelocity
            print("[WALL RUN DEBUG] Current velocity:", math.floor(velocity.X), math.floor(velocity.Y), math.floor(velocity.Z))
        end
    end
end

-- Initialize
function MovementController:Init()
    -- Test UserInputService availability
    if not UserInputService then
        warn("UserInputService not available!")
        return
    end
    
    -- Connect input events with error handling
    local success1, err1 = pcall(function()
        UserInputService.InputBegan:Connect(onKeyDown)
    end)
    
    local success2, err2 = pcall(function()
        UserInputService.InputEnded:Connect(onKeyUp)
    end)
    
    if not success1 then warn("Failed to connect InputBegan:", err1) end
    if not success2 then warn("Failed to connect InputEnded:", err2) end
    
    -- Connect heartbeat
    RunService.Heartbeat:Connect(onHeartbeat)
    
    -- Setup character
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    player.CharacterAdded:Connect(onCharacterAdded)
    
    -- Listen for stat changes
    DataHandler.OnDataChanged.Event:Connect(function()
        updateMovementSpeed()
    end)
end

return MovementController 