-- WallRunAnimator: handles wall run animations based on which side of the wall the player is running on
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local MovementController = require(player.PlayerScripts:WaitForChild("Client"):WaitForChild("MovementController"))

local humanoid
local animations = {
    Left = "rbxassetid://0",  -- placeholder ID
    Right = "rbxassetid://0", -- placeholder ID
}
local tracks = {}
local currentTrack

local function loadAnimations()
    humanoid = player.Character:WaitForChild("Humanoid")
    for side, id in pairs(animations) do
        if id ~= "rbxassetid://0" then
            local anim = Instance.new("Animation")
            anim.AnimationId = id
            tracks[side] = humanoid:LoadAnimation(anim)
        end
    end
end

local function stopCurrent()
    if currentTrack then
        currentTrack:Stop()
        currentTrack = nil
    end
end

local function play(side)
    stopCurrent()
    local track = tracks[side]
    if track then
        track:Play()
        currentTrack = track
    end
end

local function onWallRun(isWallRunning, wall, side)
    if isWallRunning then
        play(side)
    else
        stopCurrent()
    end
end

local function onCharacter(char)
    humanoid = char:WaitForChild("Humanoid")
    loadAnimations()
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
    onCharacter(player.Character)
end

MovementController.OnWallRun.Event:Connect(onWallRun)
