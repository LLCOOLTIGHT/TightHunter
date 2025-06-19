-- WallRunAnimator.client.luau - Visual Effects and Animation for Wallrunning
-- Handles camera effects, character animations, and visual feedback

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

local WallRunAnimator = {}

-- Configuration
local Config = {
    -- Camera effects
    CameraTilt = 15,                    -- Camera tilt angle in degrees
    CameraTiltSpeed = 0.3,              -- Tween speed for camera tilt
    CameraShakeIntensity = 2,           -- Camera shake when starting wallrun
    CameraShakeDuration = 0.1,          -- Duration of camera shake
    
    -- Visual effects
    WallRunTrailEnabled = true,         -- Enable particle trail during wallrun
    WallRunTrailColor = Color3.new(1, 1, 1),  -- Trail color (white)
    WallRunTrailTransparency = 0.5,     -- Trail transparency
    
    -- Animation settings
    WallRunRightAnimationId = "rbxassetid://119027232377757",  -- Right wallrun animation
    WallRunLeftAnimationId = "rbxassetid://75665325893459",    -- Left wallrun animation
    WallRunAnimationSpeed = 1.2,        -- Animation playback speed
    AnimationBlendTime = 0.2,           -- Time to blend between animations
    AnimationFadeTime = 0.15,           -- Time to fade out animations
    
    -- Sound effects
    WallRunStartSound = "rbxassetid://0",   -- Sound when starting wallrun
    WallRunLoopSound = "rbxassetid://0",    -- Looping sound during wallrun
    WallRunEndSound = "rbxassetid://0",     -- Sound when ending wallrun
}

-- Local variables
local player = Players.LocalPlayer
local character = nil
local humanoid = nil
local rootPart = nil
local camera = workspace.CurrentCamera

-- Animation state
local animationState = {
    wallRunRightAnimation = nil,
    wallRunLeftAnimation = nil,
    wallRunRightAnimationTrack = nil,
    wallRunLeftAnimationTrack = nil,
    currentAnimationTrack = nil,
    cameraTiltTween = nil,
    isAnimating = false,
    animationBlendTween = nil,
    
    -- Sound objects
    startSound = nil,
    loopSound = nil,
    endSound = nil,
    
    -- Effects
    wallRunTrail = nil,
    wallRunEffect = nil,
}

-- Create sound objects
local function createSounds()
    if not rootPart then return end
    
    -- Start sound
    if animationState.startSound then
        animationState.startSound:Destroy()
    end
    animationState.startSound = Instance.new("Sound")
    animationState.startSound.SoundId = Config.WallRunStartSound
    animationState.startSound.Volume = 0.5
    animationState.startSound.Parent = rootPart
    
    -- Loop sound
    if animationState.loopSound then
        animationState.loopSound:Destroy()
    end
    animationState.loopSound = Instance.new("Sound")
    animationState.loopSound.SoundId = Config.WallRunLoopSound
    animationState.loopSound.Volume = 0.3
    animationState.loopSound.Looped = true
    animationState.loopSound.Parent = rootPart
    
    -- End sound
    if animationState.endSound then
        animationState.endSound:Destroy()
    end
    animationState.endSound = Instance.new("Sound")
    animationState.endSound.SoundId = Config.WallRunEndSound
    animationState.endSound.Volume = 0.4
    animationState.endSound.Parent = rootPart
end

-- Create wallrun animations
local function createWallRunAnimation(animId, name)
    local animation = Instance.new("Animation")
    animation.AnimationId = animId
    animation.Name = name
    
    local animationTrack = humanoid:LoadAnimation(animation)
    animationTrack.Priority = Enum.AnimationPriority.Action
    animationTrack.Looped = true  -- Use Looped instead of Loop
    
    return animationTrack
end

-- Create animations
local function setupAnimations()
    if not humanoid then return end
    
    print("[Animator] Setting up animations...")
    
    -- Create wallrun animations
    animationState.wallRunRightAnimationTrack = createWallRunAnimation(
        "rbxassetid://75665325893459",   -- Right wallrun animation (swapped)
        "WallRunRight"
    )
    
    animationState.wallRunLeftAnimationTrack = createWallRunAnimation(
        "rbxassetid://119027232377757",  -- Left wallrun animation (swapped)
        "WallRunLeft"
    )
    
    print("[Animator] Animations created successfully")
end

-- Apply camera tilt effect (DISABLED)
local function applyCameraTilt(angle, duration)
    -- Camera tilt effects disabled per user request
    return
end

-- Create camera shake effect (DISABLED)
local function applyCameraShake()
    -- Camera shake effects disabled per user request
    return
end

-- Create wallrun trail effect
local function createWallRunTrail()
    if not rootPart or not Config.WallRunTrailEnabled then return end
    
    -- Clean up existing trail
    if animationState.wallRunTrail then
        animationState.wallRunTrail:Destroy()
    end
    
    -- Create attachment points for trail
    local attachment0 = Instance.new("Attachment")
    attachment0.Name = "WallRunTrailAttachment0"
    attachment0.Position = Vector3.new(0, -2, 0)
    attachment0.Parent = rootPart
    
    local attachment1 = Instance.new("Attachment")
    attachment1.Name = "WallRunTrailAttachment1"
    attachment1.Position = Vector3.new(0, 0, 0)
    attachment1.Parent = rootPart
    
    -- Create trail
    animationState.wallRunTrail = Instance.new("Trail")
    animationState.wallRunTrail.Attachment0 = attachment0
    animationState.wallRunTrail.Attachment1 = attachment1
    animationState.wallRunTrail.Color = ColorSequence.new(Config.WallRunTrailColor)
    animationState.wallRunTrail.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, Config.WallRunTrailTransparency),
        NumberSequenceKeypoint.new(1, 1)
    }
    animationState.wallRunTrail.WidthScale = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0.2)
    }
    animationState.wallRunTrail.Lifetime = 0.5
    animationState.wallRunTrail.MinLength = 0
    animationState.wallRunTrail.FaceCamera = true
    animationState.wallRunTrail.Parent = rootPart
end

-- Remove wallrun trail effect
local function removeWallRunTrail()
    if animationState.wallRunTrail then
        animationState.wallRunTrail:Destroy()
        animationState.wallRunTrail = nil
    end
    
    -- Clean up attachments
    if rootPart then
        local attachment0 = rootPart:FindFirstChild("WallRunTrailAttachment0")
        local attachment1 = rootPart:FindFirstChild("WallRunTrailAttachment1")
        
        if attachment0 then attachment0:Destroy() end
        if attachment1 then attachment1:Destroy() end
    end
end

-- Smoothly blend between animations
local function blendAnimation(newTrack)
    if animationState.currentAnimationTrack then
        -- Fade out current animation
        animationState.currentAnimationTrack:Stop(Config.AnimationFadeTime)
    end
    
    -- Start new animation with fade in
    if newTrack then
        newTrack:Play(Config.AnimationBlendTime)
        newTrack:AdjustSpeed(Config.WallRunAnimationSpeed)
        animationState.currentAnimationTrack = newTrack
    end
end

-- Start wallrun animations and effects
local function startWallRunAnimations(wallNormal)
    if animationState.isAnimating then return end
    print("[Animator] Starting animations...")
    
    animationState.isAnimating = true
    
    -- Play start sound
    if animationState.startSound and animationState.startSound.SoundId ~= "rbxassetid://0" then
        animationState.startSound:Play()
    end
    
    -- Start loop sound
    if animationState.loopSound and animationState.loopSound.SoundId ~= "rbxassetid://0" then
        animationState.loopSound:Play()
    end
    
    -- Determine which side the wall is on and play appropriate animation
    local isRightWall = false
    if wallNormal and rootPart then
        local rightVector = rootPart.CFrame.RightVector
        local wallToPlayerDot = wallNormal:Dot(rightVector)
        isRightWall = wallToPlayerDot > 0
    end

    -- Smoothly blend to the appropriate wallrun animation
    if isRightWall then
        if animationState.wallRunRightAnimationTrack then
            print("[Animator] Playing RIGHT animation.")
            blendAnimation(animationState.wallRunRightAnimationTrack)
        else
            print("[Animator] RIGHT animation track not found!")
        end
    else
        if animationState.wallRunLeftAnimationTrack then
            print("[Animator] Playing LEFT animation.")
            blendAnimation(animationState.wallRunLeftAnimationTrack)
        else
            print("[Animator] LEFT animation track not found!")
        end
    end

    -- Create visual effects
    createWallRunTrail()
end

-- End wallrun animations and effects
local function endWallRunAnimations()
    if not animationState.isAnimating then return end
    print("[Animator] Ending animations...")
    
    animationState.isAnimating = false
    
    -- Stop sounds
    if animationState.loopSound then
        animationState.loopSound:Stop()
    end
    
    if animationState.endSound and animationState.endSound.SoundId ~= "rbxassetid://0" then
        animationState.endSound:Play()
    end
    
    -- Smoothly fade out current animation
    if animationState.currentAnimationTrack then
        animationState.currentAnimationTrack:Stop(Config.AnimationFadeTime)
        animationState.currentAnimationTrack = nil
    end
    
    -- Remove visual effects
    removeWallRunTrail()
end

-- After RemoteEvents require, add helper
local function getRemote(name)
    return RemoteEvents:GetRemoteEvent(name)
end

-- Add initialization logging
print("[Animator] WallRunAnimator script starting...")

-- Handle wallrun alignment from server
local function onWallRunAlign(isWallRunning, wallNormal, wall)
    print(("[Animator] Received WallRunAlign event: isWallRunning=%s"):format(tostring(isWallRunning)))
    if isWallRunning then
        startWallRunAnimations(wallNormal)
    else
        endWallRunAnimations()
    end
end

-- Connect to remote event
local function connectWallRunAlign()
    local wallRunAlignRemote = getRemote("WallRunAlign")
    if wallRunAlignRemote then
        print("[Animator] Found WallRunAlign remote, connecting...")
        wallRunAlignRemote.OnClientEvent:Connect(onWallRunAlign)
        print("[Animator] Successfully connected to WallRunAlign remote")
    else
        warn("[Animator] WallRunAlign remote not found!")
    end
end

-- Character setup
local function setupCharacter(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    
    -- Create sounds and animations
    createSounds()
    setupAnimations()
    
    -- Reset animation state
    endWallRunAnimations()
end

-- Initialize
function WallRunAnimator:Init()
    print("[Animator] Initializing WallRunAnimator...")
    
    -- Set up character handling
    Players.LocalPlayer.CharacterAdded:Connect(function(newCharacter)
        setupCharacter(newCharacter)
    end)
    
    -- Setup current character if it exists
    if Players.LocalPlayer.Character then
        setupCharacter(Players.LocalPlayer.Character)
    end
    
    -- Connect remote events
    connectWallRunAlign()
    
    print("[Animator] WallRunAnimator initialized successfully")
end

-- Public functions
function WallRunAnimator:IsAnimating()
    return animationState.isAnimating
end

function WallRunAnimator:ForceEndAnimations()
    endWallRunAnimations()
end

-- Make available globally for integration
_G.WallRunAnimator = WallRunAnimator

-- Call Init to activate the controller
WallRunAnimator:Init()

return WallRunAnimator 