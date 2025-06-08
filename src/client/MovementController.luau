-- MovementController: Enhanced movement system for TightHunter
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataHandler = require(script.Parent.DataHandler)

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

-- Movement state (dash-related variables removed)
local movementState = {
    isSprinting = false,
    isWallRunning = false,
    stamina = Config.MaxStamina,
    wallRunStartTime = 0,
    currentWall = nil,
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

-- Wall running detection
local function detectWallRunning()
    if not rootPart then return end
    
    local raycast = workspace:Raycast(rootPart.Position, rootPart.CFrame.RightVector * 5)
    if not raycast then
        raycast = workspace:Raycast(rootPart.Position, -rootPart.CFrame.RightVector * 5)
    end
    
    if raycast and raycast.Instance and raycast.Instance.CanCollide then
        local wall = raycast.Instance
        if wall ~= movementState.currentWall then
            movementState.currentWall = wall
            movementState.wallRunStartTime = tick()
            movementState.isWallRunning = true
            
            -- Prevent falling while wall running
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(0, 4000, 0)
            bodyVelocity.Velocity = Vector3.new(0, 5, 0)
            bodyVelocity.Parent = rootPart
            
            MovementController.OnWallRun:Fire(true, wall)
            
            -- End wall run after duration
            game:GetService("Debris"):AddItem(bodyVelocity, Config.WallRunDuration)
        end
    else
        if movementState.isWallRunning then
            movementState.isWallRunning = false
            movementState.currentWall = nil
            MovementController.OnWallRun:Fire(false, nil)
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
            local jumpDirection = rootPart.CFrame.LookVector + Vector3.new(0, 1, 0)
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
            bodyVelocity.Velocity = jumpDirection.Unit * Config.WallRunJumpPower
            bodyVelocity.Parent = rootPart
            game:GetService("Debris"):AddItem(bodyVelocity, 0.5)
            
            movementState.isWallRunning = false
            movementState.currentWall = nil
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
    
    -- Reset movement state
    movementState.stamina = calculateMaxStamina()
    movementState.isSprinting = false
    movementState.isWallRunning = false
    
    -- Set initial movement speed
    updateMovementSpeed()
end

-- Main update loop
local function onHeartbeat(deltaTime)
    if not character or not humanoid or not rootPart then return end
    
    updateStamina(deltaTime)
    detectWallRunning()
    updateMovementSpeed()
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

-- Debug function removed to reduce console spam

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