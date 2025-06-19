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
    isSprinting = false,
    stamina = Config.MaxStamina,
}

-- Input tracking
local keysPressed = {
    W = false,
    A = false,
    S = false,
    D = false,
    LeftShift = false,
}

-- Events
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
    
    humanoid.WalkSpeed = currentSpeed
end

-- Sprint system
local function handleSprint()
    if not humanoid then return end
    
    -- Toggle sprint when shift is pressed/released
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and not movementState.isSprinting then
        movementState.isSprinting = true
        -- Notify server of sprint state change
        local sprintRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerSprintChanged)
        sprintRemote:FireServer(true)
    elseif not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and movementState.isSprinting then
        movementState.isSprinting = false
        -- Notify server of sprint state change
        local sprintRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.PlayerSprintChanged)
        sprintRemote:FireServer(false)
    end
    
    -- Update stamina
    local maxStamina = calculateMaxStamina()
    local isWallRunning = _G.WallRunController and _G.WallRunController:IsWallRunning() or false
    
    if movementState.isSprinting and movementState.stamina > 0 then
        movementState.stamina = math.max(0, movementState.stamina - Config.SprintStaminaCost * RunService.Heartbeat:Wait())
        MovementController.OnStaminaChanged:Fire(movementState.stamina, maxStamina)
    elseif isWallRunning and movementState.stamina > 0 then
        -- Wallrunning consumes stamina at a different rate
        movementState.stamina = math.max(0, movementState.stamina - 8 * RunService.Heartbeat:Wait()) -- 8 stamina per second for wallrunning
        MovementController.OnStaminaChanged:Fire(movementState.stamina, maxStamina)
    elseif not movementState.isSprinting and not isWallRunning and movementState.stamina < maxStamina then
        movementState.stamina = math.min(maxStamina, movementState.stamina + Config.StaminaRegen * RunService.Heartbeat:Wait())
        MovementController.OnStaminaChanged:Fire(movementState.stamina, maxStamina)
    end
end

-- Input handling
local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.LeftShift then
        keysPressed.LeftShift = true
    elseif input.KeyCode == Enum.KeyCode.W then
        keysPressed.W = true
    elseif input.KeyCode == Enum.KeyCode.A then
        keysPressed.A = true
    elseif input.KeyCode == Enum.KeyCode.S then
        keysPressed.S = true
    elseif input.KeyCode == Enum.KeyCode.D then
        keysPressed.D = true
    end
end

local function onInputEnded(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.LeftShift then
        keysPressed.LeftShift = false
    elseif input.KeyCode == Enum.KeyCode.W then
        keysPressed.W = false
    elseif input.KeyCode == Enum.KeyCode.A then
        keysPressed.A = false
    elseif input.KeyCode == Enum.KeyCode.S then
        keysPressed.S = false
    elseif input.KeyCode == Enum.KeyCode.D then
        keysPressed.D = false
    end
end

-- Character setup
local function setupCharacter(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    
    -- Set initial speeds
    humanoid.WalkSpeed = Config.BaseWalkSpeed
    humanoid.JumpPower = Config.BaseJumpPower
    
    -- Reset movement state
    movementState.isSprinting = false
    movementState.stamina = calculateMaxStamina()
    
    -- Reset input state
    for key in pairs(keysPressed) do
        keysPressed[key] = false
    end
end

-- Main update loop
local function update()
    if not character or not humanoid or not rootPart then return end
    
    -- Update movement speed based on current state
    updateMovementSpeed()
    
    -- Handle sprinting
    handleSprint()
end

-- Initialize
function MovementController:Init()
    -- Set up input handling
    UserInputService.InputBegan:Connect(onInputBegan)
    UserInputService.InputEnded:Connect(onInputEnded)
    
    -- Set up character handling
    player.CharacterAdded:Connect(setupCharacter)
    if player.Character then
        setupCharacter(player.Character)
    end
    
    -- Start update loop
    RunService.Heartbeat:Connect(update)
end

-- Public functions for integration with other systems
function MovementController:GetCurrentStamina()
    return movementState.stamina
end

function MovementController:GetMaxStamina()
    return calculateMaxStamina()
end

function MovementController:ConsumeStamina(amount)
    movementState.stamina = math.max(0, movementState.stamina - amount)
    local maxStamina = calculateMaxStamina()
    MovementController.OnStaminaChanged:Fire(movementState.stamina, maxStamina)
    return movementState.stamina
end

function MovementController:SetStamina(value)
    local maxStamina = calculateMaxStamina()
    movementState.stamina = math.clamp(value, 0, maxStamina)
    MovementController.OnStaminaChanged:Fire(movementState.stamina, maxStamina)
    return movementState.stamina
end

-- Stamina management
local function updateStamina(deltaTime)
    local maxStamina = calculateMaxStamina()
    local isWallRunning = _G.WallRunController and _G.WallRunController:IsWallRunning() or false
    
    -- Only regenerate stamina when not wall-running and not sprinting
    if not movementState.isSprinting and not isWallRunning and movementState.stamina < maxStamina then
        movementState.stamina = math.min(maxStamina, movementState.stamina + Config.StaminaRegen * deltaTime)
        MovementController.OnStaminaChanged:Fire(movementState.stamina, maxStamina)
    end
    
    -- Stop sprinting if out of stamina
    if movementState.stamina <= 0 then
        movementState.isSprinting = false
    end
end

-- Initialize
MovementController:Init()

-- Make available globally for wallrunning integration
_G.MovementController = MovementController

return MovementController 