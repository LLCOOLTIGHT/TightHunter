-- Client initialization script
-- Client script starting

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for shared modules with timeout
local Shared = nil
local success, err = pcall(function()
    Shared = ReplicatedStorage:WaitForChild("Shared", 10)
end)

if not success then
    warn("Failed to get Shared folder:", err)
    return
end

-- Initialize client-side systems
local player = Players.LocalPlayer

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

local success2, err2 = pcall(function()
    MovementController = require(script.MovementController)
end)

if not success2 then
    warn("Failed to load MovementController:", err2)
    return
end

-- Initialize data handler first
local success3, err3 = pcall(function()
    DataHandler:Init()
end)

if not success3 then
    warn("Failed to initialize DataHandler:", err3)
    return
end

-- Initialize movement controller
local success4, err4 = pcall(function()
    MovementController:Init()
end)

if not success4 then
    warn("Failed to initialize MovementController:", err4)
    return
end

-- Setup data change listener
DataHandler.OnDataChanged.Event:Connect(function(newData)
    -- Data updated silently - can add UI updates here
end)

-- Setup movement event listeners
-- Old dash event listener removed - dash system now handled by StarterCharacterScripts

MovementController.OnWallRun.Event:Connect(function(isWallRunning, wall)
    if isWallRunning then
        -- Wall running started - can add visual effects here
    else
        -- Wall running stopped
    end
end)

MovementController.OnStaminaChanged.Event:Connect(function(currentStamina, maxStamina)
    -- This could update a stamina UI bar
    local staminaPercent = math.floor((currentStamina / maxStamina) * 100)
    if staminaPercent <= 20 then
        -- Low stamina warning could go here
    end
end)

-- Client initialized successfully with enhanced movement system

