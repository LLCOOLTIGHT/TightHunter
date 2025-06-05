-- Client initialization script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared")

-- Initialize client-side systems
local player = Players.LocalPlayer
local DataHandler = require(script.Parent.DataHandler)

-- Initialize data handler
DataHandler:Init()

-- Setup data change listener
DataHandler.OnDataChanged.Event:Connect(function(newData)
    print("Player data updated:", newData.Stats.Level, "Level", newData.Stats.EXP, "EXP")
end)

print("Client initialized")
print("Hello world, from client!")

