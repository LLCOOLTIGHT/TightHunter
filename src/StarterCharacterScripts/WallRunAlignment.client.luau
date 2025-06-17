-- WallRunAlignment: Client-side wallrun animation and orientation handler
-- This script receives wallrun alignment data from the server and handles animation/orientation
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local RemoteEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteEvents"))

-- Wallrun Animation System
local wallrunAnimation = Instance.new("Animation")
wallrunAnimation.AnimationId = "rbxassetid://85281402770697"
local wallrunTrack = nil
local isWallRunning = false

-- Wallrun Direction Calculation
local function getWallRunDirection(hrp, wallNormal)
    local runDirection = wallNormal:Cross(Vector3.new(0, 1, 0)).Unit
    if runDirection:Dot(hrp.CFrame.RightVector) < 0 then
        runDirection = -runDirection -- flip if wall is on the left side
    end
    return runDirection
end

-- Smooth rotation function
local function smoothRotateToDirection(hrp, targetDirection, duration)
    local startCFrame = hrp.CFrame
    local targetCFrame = CFrame.new(hrp.Position, hrp.Position + targetDirection)
    
    local tweenInfo = TweenInfo.new(
        duration or 0.2, -- Default 0.2 seconds
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )
    
    local tween = TweenService:Create(hrp, tweenInfo, {
        CFrame = targetCFrame
    })
    
    tween:Play()
    return tween
end

-- Wallrun Animation Functions
local function loadWallrunAnimation()
    if not Humanoid then 
        warn("[WALLRUN ANIMATION] Humanoid not found")
        return false
    end
    
    if wallrunTrack then
        return true -- Already loaded
    end
    
    print("[WALLRUN ANIMATION] Loading animation...")
    local success, err = pcall(function()
        wallrunTrack = Humanoid:LoadAnimation(wallrunAnimation)
        wallrunTrack.Priority = Enum.AnimationPriority.Action -- Set high priority
        wallrunTrack.Looped = true -- Make sure animation loops
    end)
    
    if not success then
        warn("[WALLRUN ANIMATION] Failed to load animation:", err)
        return false
    end
    
    print("[WALLRUN ANIMATION] Animation loaded successfully")
    return true
end

local function playWallrunAnimation()
    if not loadWallrunAnimation() then return end
    
    -- Play animation if not already playing
    if wallrunTrack and not wallrunTrack.IsPlaying then
        print("[WALLRUN ANIMATION] Attempting to play animation...")
        local success, err = pcall(function()
            wallrunTrack:Play(0.1) -- Add fade time for smooth start
        end)
        
        if not success then
            warn("[WALLRUN ANIMATION] Failed to play animation:", err)
            -- Try to reload the animation if it failed
            wallrunTrack = nil
            loadWallrunAnimation()
        else
            print("[WALLRUN ANIMATION] Animation playing successfully")
        end
    end
end

local function stopWallrunAnimation()
    if wallrunTrack and wallrunTrack.IsPlaying then
        print("[WALLRUN ANIMATION] Stopping animation...")
        local success, err = pcall(function()
            wallrunTrack:Stop(0.2) -- Add fade time for smooth stopping
        end)
        
        if not success then
            warn("[WALLRUN ANIMATION] Failed to stop animation:", err)
        else
            print("[WALLRUN ANIMATION] Animation stopped successfully")
        end
    end
end

-- Handle wallrun alignment from server
local function onWallRunAlign(isWallRunning, wallNormal, wall)
    print("[WALLRUN ALIGN] Received alignment event - isWallRunning:", isWallRunning)
    if not HumanoidRootPart or not Humanoid then 
        warn("[WALLRUN ALIGN] Missing character parts")
        return 
    end
    
    isWallRunning = isWallRunning -- Update global state
    
    if isWallRunning and wallNormal then
        print("[WALLRUN ALIGN] Starting wallrun with normal:", wallNormal)
        
        -- Calculate wallrun direction using improved method
        local runDirection = getWallRunDirection(HumanoidRootPart, wallNormal)
        print("[WALLRUN ALIGN] Calculated run direction:", runDirection)
        
        -- Smoothly rotate character to face run direction
        smoothRotateToDirection(HumanoidRootPart, runDirection, 0.2)
        
        -- Play animation after rotation
        playWallrunAnimation()
        
        print("[WALLRUN ALIGN] Wallrun started - Move dir:", Humanoid.MoveDirection, "| Wall normal:", wallNormal, "| Run direction:", runDirection)
    else
        -- Wallrun ended - stop animation
        print("[WALLRUN ALIGN] Stopping wallrun")
        stopWallrunAnimation()
    end
end

-- Continuous check to ensure animation is playing during wallrun
local function onHeartbeat()
    if isWallRunning and (not wallrunTrack or not wallrunTrack.IsPlaying) then
        print("[WALLRUN CHECK] Animation not playing during wallrun - attempting to restart")
        playWallrunAnimation()
    end
end

-- Setup remote event listener
local function setupRemoteEvents()
    print("[WALLRUN ALIGN] Setting up remote events...")
    local alignRemote = RemoteEvents:GetRemoteEvent(RemoteEvents.WallRunAlign)
    alignRemote.OnClientEvent:Connect(onWallRunAlign)
    
    -- Connect heartbeat for animation maintenance
    RunService.Heartbeat:Connect(onHeartbeat)
    
    print("[WALLRUN ALIGN] Remote events setup complete for character:", Character.Name)
end

-- Initialize when character is ready
local success, err = pcall(setupRemoteEvents)
if not success then
    warn("[WALLRUN ALIGN] Failed to setup remote events:", err)
end

-- Character respawn handling
Players.LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    if newCharacter == Character then
        print("[WALLRUN ALIGN] Character respawned - resetting animation track")
        -- Reset animation track for new character
        wallrunTrack = nil
        isWallRunning = false
        
        -- Re-setup remotes
        local success, err = pcall(setupRemoteEvents)
        if not success then
            warn("[WALLRUN ALIGN] Failed to re-setup remote events:", err)
        end
    end
end) 