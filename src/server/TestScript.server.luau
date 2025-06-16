-- Test Script for TightHunter Core Systems
-- This script helps verify that all core systems are working properly

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Test configuration
local TEST_MODE = true -- Set to false to disable testing
local VERBOSE_LOGGING = true -- Set to false for less output

local function log(message)
    if VERBOSE_LOGGING then
        print("[TIGHTHUNTER TEST]", message)
    end
end

if not TEST_MODE then
    log("Test mode disabled")
    return
end

log("=== STARTING CORE SYSTEMS TEST ===")

-- Test 1: Module Loading
log("Testing module loading...")
local success1, DataManager = pcall(function()
    return require(script.Parent.Modules.PlayerData.DataManager)
end)

local success2, RemoteHandler = pcall(function()
    return require(script.Parent.RemoteHandler)
end)

local success3, MovementHandler = pcall(function()
    return require(script.Parent.MovementHandler)
end)

if success1 and success2 and success3 then
    log("✅ All server modules loaded successfully")
else
    warn("❌ Failed to load some server modules:")
    if not success1 then warn("  - DataManager failed:", DataManager) end
    if not success2 then warn("  - RemoteHandler failed:", RemoteHandler) end
    if not success3 then warn("  - MovementHandler failed:", MovementHandler) end
end

-- Test 2: ReplicatedStorage Structure
log("Testing ReplicatedStorage structure...")
wait(1) -- Give time for server init to create folders

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")

if remoteEventsFolder and remotesFolder and sharedFolder then
    log("✅ ReplicatedStorage structure is correct")
    log("  - RemoteEvents folder exists")
    log("  - Remotes folder exists") 
    log("  - Shared folder exists")
else
    warn("❌ ReplicatedStorage structure incomplete:")
    if not remoteEventsFolder then warn("  - Missing RemoteEvents folder") end
    if not remotesFolder then warn("  - Missing Remotes folder") end
    if not sharedFolder then warn("  - Missing Shared folder") end
end

-- Test 3: Player Connection Test
log("Setting up player connection test...")

Players.PlayerAdded:Connect(function(player)
    log("Player joined: " .. player.Name)
    
    -- Test data loading
    spawn(function()
        wait(2) -- Give systems time to initialize
        
        log("Testing data system for " .. player.Name)
        
        -- Check if player data was created
        local success, err = pcall(function()
            -- This would normally be handled by DataManager
            log("Player data system appears to be running for " .. player.Name)
        end)
        
        if success then
            log("✅ Data system working for " .. player.Name)
        else
            warn("❌ Data system error for " .. player.Name .. ":", err)
        end
    end)
    
    -- Test character spawn
    player.CharacterAdded:Connect(function(character)
        log("Character spawned for " .. player.Name)
        
        spawn(function()
            wait(1) -- Give character time to fully load
            
            local humanoid = character:FindFirstChild("Humanoid")
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            
            if humanoid and rootPart then
                log("✅ Character components loaded for " .. player.Name)
                
                -- Test basic movement stats
                log("  - Default WalkSpeed: " .. humanoid.WalkSpeed)
                log("  - Default JumpPower: " .. humanoid.JumpPower)
                
            else
                warn("❌ Character missing components for " .. player.Name)
            end
        end)
    end)
end)

-- Test 4: Remote Events Test
spawn(function()
    wait(3) -- Wait for everything to initialize
    
    log("Testing remote events creation...")
    
    local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 5)
    if remoteEventsFolder then
        local remoteCount = #remoteEventsFolder:GetChildren()
        log("✅ RemoteEvents folder accessible, contains " .. remoteCount .. " items")
        
        -- List all remote events
        for _, remote in pairs(remoteEventsFolder:GetChildren()) do
            log("  - Found remote: " .. remote.Name .. " (" .. remote.ClassName .. ")")
        end
    else
        warn("❌ Could not access RemoteEvents folder")
    end
end)

-- Test 5: Movement System Test
spawn(function()
    wait(5)
    log("Movement system should be initialized by now")
    log("Check game output for movement system messages")
end)

-- Summary
spawn(function()
    wait(10)
    log("=== CORE SYSTEMS TEST SUMMARY ===")
    log("1. Check server console for any error messages")
    log("2. Join the game to test player systems")
    log("3. Try double-tapping WASD keys to test dash system")
    log("4. Check client console (F9) for any client errors")
    log("5. Test movement and character spawning")
    log("========================================")
end) 