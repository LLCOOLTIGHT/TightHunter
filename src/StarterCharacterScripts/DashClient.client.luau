-- Enhanced Dash System with Animations and Double-Tap Controls
local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- BodyGyro for side movement control
local SideGyro = Instance.new("BodyGyro")
SideGyro.MaxTorque = Vector3.new(3e5, 0, 3e5)
SideGyro.P = 5e5
SideGyro.Parent = HumanoidRootPart

-- Dash configuration
local Dashing = false
local DashSpeed = 45
local DashDuration = 0.5 -- Fixed duration instead of relying on animations
local DoubleTaps = {}

-- Animation IDs for different dash directions
local Animations = {
	["DashRight"] = 'rbxassetid://12878249954',
	["DashLeft"] = 'rbxassetid://12878251537',
	["DashFront"] = 'rbxassetid://12878253087',
	["DashBack"] = 'rbxassetid://12878254845',
}

-- Load and prepare all animations with error handling
for i, v in pairs(Animations) do
	local success, err = pcall(function()
		local Anim = Instance.new("Animation")
		Anim.AnimationId = v
		local loadedAnim = Humanoid:LoadAnimation(Anim)
		Animations[i] = loadedAnim
	end)
	
	if not success then
		warn("Failed to load dash animation", i, ":", err)
		Animations[i] = nil -- Set to nil if failed to load
	end
end

-- Enhanced dash function
function Dash(Key)
	if Dashing then
		return
	end

	local DashAnim = "Back"
	local Front = -1
	local Side = 0

	-- Determine dash direction and animation
	if Key == Enum.KeyCode.A then
		Side = -1
		Front = 0
		DashAnim = "Left"
	elseif Key == Enum.KeyCode.D then
		Side = 1
		Front = 0
		DashAnim = "Right"
	elseif Key == Enum.KeyCode.W then
		Side = 0
		Front = 1
		DashAnim = "Front"
	elseif Key == Enum.KeyCode.S then
		Side = 0
		Front = -1
		DashAnim = "Back"
	end

	Dashing = true
	
	-- Play dash animation if available
	local animationTrack = Animations["Dash"..DashAnim]
	if animationTrack then
		local success, err = pcall(function()
			animationTrack:Play()
		end)
		if not success then
			warn("Failed to play dash animation:", err)
		end
	end

	-- Create dash velocity
	local DashVelocity = Instance.new("BodyVelocity")
	DashVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge)
	DashVelocity.P = 9e9
	DashVelocity.Parent = HumanoidRootPart
	
	-- Set initial velocity based on character orientation
	DashVelocity.Velocity = HumanoidRootPart.CFrame.LookVector * (Front * DashSpeed) + HumanoidRootPart.CFrame.RightVector * (Side * DashSpeed)

	-- Spawn dust effect after slight delay
	coroutine.wrap(function()
		task.wait(.1)
		
		-- Create dust effect (if DustTrail exists in ReplicatedStorage)
		local dustTrail = ReplicatedStorage:FindFirstChild("DustTrail")
		if dustTrail then
			local DashEffect = dustTrail:Clone()
			DashEffect.Parent = workspace

			-- Position dust effect based on dash direction
			if DashAnim == "Left" then
				local rightLeg = Character:FindFirstChild("Right Leg")
				if rightLeg then
					if DashEffect:FindFirstChild("DustRight") then
						DashEffect.DustRight:Destroy()
					end
					DashEffect.CFrame = rightLeg.CFrame * CFrame.new(-1, 0, -2)
				end
			elseif DashAnim == "Right" then
				local leftLeg = Character:FindFirstChild("Left Leg")
				if leftLeg then
					if DashEffect:FindFirstChild("DustLeft") then
						DashEffect.DustLeft:Destroy()
					end
					DashEffect.CFrame = leftLeg.CFrame * CFrame.new(3, 2, 5)
				end
			elseif DashAnim == "Front" then
				if DashEffect:FindFirstChild("DustLeft") then
					DashEffect.DustLeft:Destroy()
				end
				DashEffect.CFrame = HumanoidRootPart.CFrame * CFrame.new(0, -1, 3)
			else -- Back
				if DashEffect:FindFirstChild("DustLeft") then
					DashEffect.DustLeft:Destroy()
				end
				DashEffect.CFrame = HumanoidRootPart.CFrame * CFrame.new(0, -1, -0.5)
			end
			
			-- Emit particles
			for i, v in pairs(DashEffect:GetDescendants()) do
				if v:IsA("ParticleEmitter") then
					v:Emit(5)
				end
			end

			-- Clean up effect
			game.Debris:AddItem(DashEffect, 0.5)
		else
			warn("Warning: DustTrail not found in ReplicatedStorage - skipping dust effect")
		end
	end)()

	-- Use timer-based dash instead of animation
	local startTime = tick()
	repeat 
		task.wait()
		if DashVelocity and DashVelocity.Parent then
			DashVelocity.Velocity = HumanoidRootPart.CFrame.LookVector * (Front * DashSpeed) + HumanoidRootPart.CFrame.RightVector * (Side * DashSpeed)
		end
	until (tick() - startTime) >= DashDuration -- Use timer instead of animation

	-- Clean up
	Dashing = false
	if DashVelocity then
		DashVelocity:Destroy()
	end
end

-- Double-tap detection system
function LoadDoubleTap(Key, Funct)
	DoubleTaps[Key] = tick() - 10 -- Initialize with old timestamp
	
	UserInputService.InputBegan:Connect(function(Pressed, Typing)
		if Typing then return end -- Don't dash while typing
		
		if Pressed.KeyCode == Key then
			local currentTime = tick()
			local timeSinceLastTap = currentTime - DoubleTaps[Key]
			
			if timeSinceLastTap < 0.23 then -- Double-tap detected (within 0.23 seconds)
				Funct(Key)
			else
				-- First tap or too slow - record the time
				DoubleTaps[Key] = currentTime
			end
		end
	end)
end

-- Set up double-tap controls for all movement keys
LoadDoubleTap(Enum.KeyCode.W, Dash)
LoadDoubleTap(Enum.KeyCode.A, Dash)
LoadDoubleTap(Enum.KeyCode.S, Dash)
LoadDoubleTap(Enum.KeyCode.D, Dash)

-- Character respawn handling
game.Players.LocalPlayer.CharacterAdded:Connect(function(newCharacter)
	Character = newCharacter
	Humanoid = Character:WaitForChild("Humanoid")
	HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
	
	-- Recreate BodyGyro
	if SideGyro then
		SideGyro:Destroy()
	end
	SideGyro = Instance.new("BodyGyro")
	SideGyro.MaxTorque = Vector3.new(3e5, 0, 3e5)
	SideGyro.P = 5e5
	SideGyro.Parent = HumanoidRootPart
	
	-- Reload animations with error handling
	for i, v in pairs(Animations) do
		if typeof(v) == "AnimationTrack" then
			v:Stop()
		end
		
		local success, err = pcall(function()
			local Anim = Instance.new("Animation")
			Anim.AnimationId = Animations[i] -- Use original ID from the table
			local loadedAnim = Humanoid:LoadAnimation(Anim)
			Animations[i] = loadedAnim
		end)
		
		if not success then
			warn("Failed to reload dash animation", i, ":", err)
			Animations[i] = nil
		end
	end
end)
