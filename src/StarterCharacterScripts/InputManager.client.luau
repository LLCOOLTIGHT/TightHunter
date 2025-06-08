local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local DashBindable = RS:WaitForChild("BindableFunctions"):WaitForChild("DashBindable")

local dashDirection = Vector3.new(0, 0, -1)

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    if input.KeyCode == Enum.KeyCode.Q then
        DashBindable:Invoke(dashDirection)
    end

    if input.KeyCode == Enum.KeyCode.W then dashDirection = Vector3.new(0, 0, -1) end
    if input.KeyCode == Enum.KeyCode.A then dashDirection = Vector3.new(-1, 0, 0) end
    if input.KeyCode == Enum.KeyCode.S then dashDirection = Vector3.new(0, 0, 1) end
    if input.KeyCode == Enum.KeyCode.D then dashDirection = Vector3.new(1, 0, 0) end
end)
