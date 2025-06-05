local DashService = {}
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local DASH_FORCE = 75

function DashService:Dash(player)
    local character = player.Character
    if not character then
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then
        return
    end

    local look = hrp.CFrame.LookVector
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.Velocity = look * DASH_FORCE
    bodyVel.MaxForce = Vector3.new(1e5, 0, 1e5)
    bodyVel.P = 1e5
    bodyVel.Parent = hrp

    Debris:AddItem(bodyVel, 0.2)
end

return DashService
