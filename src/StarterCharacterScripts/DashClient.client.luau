local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DashBindable = RS:WaitForChild("BindableFunctions"):WaitForChild("DashBindable")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local DashDuration = 0.3
local Rate = 0.03
local DashStrength = 100
local MinDashStrength = 20
local Iterations = math.floor(DashDuration / Rate)
local Reduction = (DashStrength - MinDashStrength) / Iterations

DashBindable.OnInvoke = function(initialDirection)
    local velocity = Instance.new("BodyVelocity")
    velocity.MaxForce = Vector3.new(1e5, 0, 1e5)
    velocity.P = 1e5
    velocity.Velocity = Vector3.zero
    velocity.Parent = hrp

    local currentStrength = DashStrength

    for i = 1, Iterations do
        local look = hrp.CFrame:VectorToWorldSpace(initialDirection)
        velocity.Velocity = look.Unit * currentStrength
        currentStrength = math.max(currentStrength - Reduction, MinDashStrength)
        task.wait(Rate)
    end

    velocity:Destroy()
end
