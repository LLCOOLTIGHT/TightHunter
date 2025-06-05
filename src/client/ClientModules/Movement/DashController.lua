local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DashEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Events"):WaitForChild("DashEvent")

local DASH_COOLDOWN = 1.2
local lastDash = 0

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.Q then
        if tick() - lastDash >= DASH_COOLDOWN then
            lastDash = tick()
            DashEvent:FireServer()
        end
    end
end)

return {}
