-- Client initialization script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")

-- Initialize client-side systems
local player = Players.LocalPlayer
local DataHandler = require(script.DataHandler)
local MovementController = require(script.MovementController)

-- Initialize data handler first
DataHandler:Init()

-- Initialize movement controller
MovementController:Init()

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

print("Client initialized with enhanced movement system")
print("Controls:")
print("- WASD: Move")
print("- Left Shift: Sprint (consumes stamina)")
print("- Q: Dash (2 second cooldown)")
print("- Space: Jump (enhanced wall jump when wall running)")
print("Hello world, from client!")

