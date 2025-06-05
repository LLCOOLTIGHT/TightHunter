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
    
    -- Dash system (ENHANCED)
    DashCooldown = 2, -- seconds
    DashDistance = 80, -- Increased from 50
    DashSpeed = 200, -- Increased from 100
    DashDuration = 0.4, -- Increased from 0.3
    
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

-- Movement state
local movementState = {
    isDashing = false,
    isSprinting = false,
    isWallRunning = false,
    stamina = Config.MaxStamina,
    lastDashTime = 0,
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

-- Events
MovementController.OnDash = Instance.new("BindableEvent")
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
        print("Sprinting at speed:", currentSpeed)
    end
    
    -- Apply wall running speed
    if movementState.isWallRunning then
        currentSpeed = Config.WallRunSpeed
    end
    
    humanoid.WalkSpeed = currentSpeed
end

-- Enhanced dash function with better visuals
local function performDash()
    if movementState.isDashing then 
        print("Dash blocked: Already dashing")
        return 
    end
    
    local currentTime = tick()
    if currentTime - movementState.lastDashTime < Config.DashCooldown then 
        local timeLeft = Config.DashCooldown - (currentTime - movementState.lastDashTime)
        print("Dash blocked: Cooldown remaining:", math.ceil(timeLeft), "seconds")
        return 
    end
    
    if not rootPart or not humanoid then 
        print("Dash blocked: No character")
        return 
    end
    
    print("=== DASH STARTING ===")
    movementState.isDashing = true
    movementState.lastDashTime = currentTime
    
    -- Store original position for debugging
    local startPos = rootPart.Position
    
    -- Calculate dash direction
    local moveVector = humanoid.MoveDirection
    if moveVector.Magnitude == 0 then
        moveVector = rootPart.CFrame.LookVector
    end
    
    print("Dash direction vector:", moveVector)
    print("Player position before dash:", startPos)
    
    -- Create MUCH stronger dash effect
    local dashDirection = moveVector.Unit * Config.DashSpeed
    
    -- Remove any existing BodyVelocity objects first
    for _, obj in pairs(rootPart:GetChildren()) do
        if obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") then
            obj:Destroy()
        end
    end
    
    -- Create powerful dash velocity
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(10000, 0, 10000) -- Much stronger force
    bodyVelocity.Velocity = dashDirection
    bodyVelocity.Parent = rootPart
    
    -- Add upward force to make dash more noticeable
    local upwardForce = Instance.new("BodyVelocity")
    upwardForce.MaxForce = Vector3.new(0, 5000, 0)
    upwardForce.Velocity = Vector3.new(0, 20, 0) -- Small upward boost
    upwardForce.Parent = rootPart
    
    print("Created BodyVelocity with velocity:", dashDirection)
    print("Dash force applied for", Config.DashDuration, "seconds")
    
    -- Fire dash event
    MovementController.OnDash:Fire(dashDirection)
    
    -- Clean up after dash duration
    spawn(function()
        wait(Config.DashDuration)
        if bodyVelocity and bodyVelocity.Parent then
            bodyVelocity:Destroy()
        end
        if upwardForce and upwardForce.Parent then
            upwardForce:Destroy()
        end
        
        local endPos = rootPart.Position
        local distance = (endPos - startPos).Magnitude
        print("=== DASH COMPLETED ===")
        print("Distance traveled:", math.floor(distance), "studs")
        print("Player position after dash:", endPos)
        
        movementState.isDashing = false
    end)
end

-- Wall running detection
local function detectWallRunning()
    if not rootPart or movementState.isDashing then return end
    
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
        print("Out of stamina! Sprint disabled.")
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
        print("Sprint activated!")
    elseif keyCode == "Space" then
        keysPressed.Space = true
        
        -- Wall run jump
        if movementState.isWallRunning then
            print("Wall jump activated!")
            local jumpDirection = rootPart.CFrame.LookVector + Vector3.new(0, 1, 0)
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
            bodyVelocity.Velocity = jumpDirection.Unit * Config.WallRunJumpPower
            bodyVelocity.Parent = rootPart
            game:GetService("Debris"):AddItem(bodyVelocity, 0.5)
            
            movementState.isWallRunning = false
            movementState.currentWall = nil
        end
    elseif keyCode == "Q" then
        -- Dash ability
        print("Q pressed - attempting dash...")
        performDash()
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
        print("Sprint deactivated!")
    elseif keyCode == "Space" then
        keysPressed.Space = false
    end
    
    updateMovementSpeed()
end

-- Character setup
local function onCharacterAdded(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    print("Character setup complete!")
    print("Humanoid:", humanoid)
    print("RootPart:", rootPart)
    
    -- Reset movement state
    movementState.stamina = calculateMaxStamina()
    movementState.isDashing = false
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

function MovementController:IsDashing()
    return movementState.isDashing
end

function MovementController:IsWallRunning()
    return movementState.isWallRunning
end

-- Initialize
function MovementController:Init()
    -- Connect events
    UserInputService.InputBegan:Connect(onKeyDown)
    UserInputService.InputEnded:Connect(onKeyUp)
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
    
    print("MovementController initialized with enhanced debugging")
end

return MovementController 