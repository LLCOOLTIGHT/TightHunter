local DataManager = require(script.Parent.Modules.PlayerData.DataManager)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DashService = require(script.Parent.Modules.Movement.DashService)

DataManager:Init()

local DashEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Events"):WaitForChild("DashEvent")
DashEvent.OnServerEvent:Connect(function(player)
    DashService:Dash(player)
end)

print("Server initialized")
