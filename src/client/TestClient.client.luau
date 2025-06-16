-- Client Test Script for TightHunter
-- This helps test client-side functionality and provides testing guidance

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Test configuration
local TEST_MODE = true
local SHOW_TEST_GUI = true

local function log(message)
    print("[CLIENT TEST]", message)
end

if not TEST_MODE then
    return
end

log("=== CLIENT SYSTEMS TEST STARTED ===")

-- Create a simple test GUI
local function createTestGUI()
    if not SHOW_TEST_GUI then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TightHunterTestGUI"
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 300, 0, 400)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    mainFrame.BackgroundTransparency = 0.3
    mainFrame.BorderSizePixel = 2
    mainFrame.BorderColor3 = Color3.new(1, 1, 1)
    mainFrame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    title.Text = "TightHunter Test Panel"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextScaled = true
    title.Font = Enum.Font.SourceSansBold
    title.Parent = mainFrame
    
    local instructions = Instance.new("TextLabel")
    instructions.Size = UDim2.new(1, -10, 1, -40)
    instructions.Position = UDim2.new(0, 5, 0, 35)
    instructions.BackgroundTransparency = 1
    instructions.Text = [[TESTING INSTRUCTIONS:

Movement Tests:
• Double-tap W, A, S, D to test dash
• Hold Shift while moving to sprint
• Run toward walls to test wall-running

Expected Results:
• Dash should create dust effects
• Sprint should increase speed
• Wall running should work on vertical surfaces

Data System Test:
• Check F9 console for data loading messages
• Stats should persist between sessions

Press H to hide this panel
Press R to show system status]]
    instructions.TextColor3 = Color3.new(1, 1, 1)
    instructions.TextScaled = true
    instructions.Font = Enum.Font.SourceSans
    instructions.TextXAlignment = Enum.TextXAlignment.Left
    instructions.TextYAlignment = Enum.TextYAlignment.Top
    instructions.Parent = mainFrame
    
    -- Hide/Show functionality
    local isVisible = true
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.H then
            isVisible = not isVisible
            mainFrame.Visible = isVisible
            log(isVisible and "Test GUI shown" or "Test GUI hidden")
        elseif input.KeyCode == Enum.KeyCode.R then
            -- Show system status
            log("=== SYSTEM STATUS ===")
            log("ReplicatedStorage.Shared exists: " .. tostring(ReplicatedStorage:FindFirstChild("Shared") ~= nil))
            log("RemoteEvents folder exists: " .. tostring(ReplicatedStorage:FindFirstChild("RemoteEvents") ~= nil))
            log("Character exists: " .. tostring(player.Character ~= nil))
            if player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    log("WalkSpeed: " .. humanoid.WalkSpeed)
                    log("JumpPower: " .. humanoid.JumpPower)
                    log("PlatformStand: " .. tostring(humanoid.PlatformStand))
                end
            end
            log("====================")
        end
    end)
end

-- Test client module loading
spawn(function()
    wait(2) -- Give time for initialization
    
    log("Testing client module loading...")
    
    local dataHandler = script.Parent:FindFirstChild("DataHandler")
    local movementController = script.Parent:FindFirstChild("MovementController")
    
    if dataHandler and movementController then
        log("✅ Client modules found")
    else
        warn("❌ Some client modules missing:")
        if not dataHandler then warn("  - DataHandler missing") end
        if not movementController then warn("  - MovementController missing") end
    end
end)

-- Test character scripts
player.CharacterAdded:Connect(function(character)
    log("Character spawned, testing character scripts...")
    
    spawn(function()
        wait(1)
        
        local dashScript = character:FindFirstChild("DashClient")
        local inputManager = character:FindFirstChild("InputManager")
        
        log("Character scripts check:")
        log("  - DashClient: " .. tostring(dashScript ~= nil))
        log("  - InputManager: " .. tostring(inputManager ~= nil))
        
        -- Test basic movement setup
        local humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and rootPart then
            log("✅ Character ready for movement testing")
            log("  - Humanoid WalkSpeed: " .. humanoid.WalkSpeed)
            log("  - Humanoid JumpPower: " .. humanoid.JumpPower)
            
            -- Create test GUI after character loads
            createTestGUI()
        else
            warn("❌ Character missing essential components")
        end
    end)
end)

-- Test data system connection
spawn(function()
    wait(3)
    
    log("Testing data system connection...")
    
    local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
    if sharedFolder then
        local remoteEvents = sharedFolder:FindFirstChild("RemoteEvents")
        if remoteEvents then
            log("✅ Can access RemoteEvents module")
        else
            warn("❌ Cannot find RemoteEvents in Shared")
        end
    else
        warn("❌ Cannot find Shared folder")
    end
end)

-- Input testing helper
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Log key presses for testing
    if input.KeyCode == Enum.KeyCode.T then
        log("Test key pressed - systems appear responsive")
    end
end)

log("Client test script loaded. Press H to toggle test GUI, R for system status, T to test input.") 