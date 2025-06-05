-- Client initialization script
print("=== CLIENT SCRIPT STARTING ===")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("DEBUG: Services loaded")

-- Wait for shared modules with timeout
local Shared = nil
local success, err = pcall(function()
    Shared = ReplicatedStorage:WaitForChild("Shared", 10)
end)

if not success then
    warn("Failed to get Shared folder:", err)
    return
end

print("DEBUG: Shared folder found")

-- Initialize client-side systems
local player = Players.LocalPlayer
print("DEBUG: Player:", player.Name)

-- Load modules with error handling
local DataHandler = nil
local MovementController = nil

local success1, err1 = pcall(function()
    DataHandler = require(script.DataHandler)
end)

if not success1 then
    warn("Failed to load DataHandler:", err1)
    return
end

print("DEBUG: DataHandler loaded")

local success2, err2 = pcall(function()
    MovementController = require(script.MovementController)
end)

if not success2 then
    warn("Failed to load MovementController:", err2)
    return
end

print("DEBUG: MovementController loaded")

-- Initialize data handler first
local success3, err3 = pcall(function()
    DataHandler:Init()
end)

if not success3 then
    warn("Failed to initialize DataHandler:", err3)
    return
end

print("DEBUG: DataHandler initialized")

-- Initialize movement controller
local success4, err4 = pcall(function()
    MovementController:Init()
end)

if not success4 then
    warn("Failed to initialize MovementController:", err4)
    return
end

print("DEBUG: MovementController initialized")

-- Setup data change listener
DataHandler.OnDataChanged.Event:Connect(function(newData)
    print("Player data updated:", newData.Stats.Level, "Level", newData.Stats.EXP, "EXP")
    print("Agility:", newData.Stats.Agility, "Constitution:", newData.Stats.Constitution)
end)

-- Setup movement event listeners
MovementController.OnDash.Event:Connect(function(direction)
    print("Player dashed in direction:", direction)
    -- Here you could add visual/audio effects for dashing
end)

MovementController.OnWallRun.Event:Connect(function(isWallRunning, wall)
    if isWallRunning then
        print("Started wall running on:", wall.Name)
        -- Here you could add wall running visual effects
    else
        print("Stopped wall running")
    end
end)

MovementController.OnStaminaChanged.Event:Connect(function(currentStamina, maxStamina)
    -- This could update a stamina UI bar
    local staminaPercent = math.floor((currentStamina / maxStamina) * 100)
    if staminaPercent <= 20 then
        -- Low stamina warning could go here
    end
end)

print("=== CLIENT INITIALIZED SUCCESSFULLY ===")
print("Enhanced movement system ready!")
print("Controls:")
print("- WASD: Move")
print("- Left Shift: Sprint (consumes stamina)")
print("- Q: Dash (2 second cooldown)")
print("- Space: Jump (enhanced wall jump when wall running)")
print("=== PRESS KEYS TO TEST MOVEMENT ===")

