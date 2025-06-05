-- Server initialization script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Modules.PlayerData.DataManager)
local RemoteHandler = require(script.RemoteHandler)
local MovementHandler = require(script.MovementHandler)
local ServerScriptService = game:GetService("ServerScriptService")

-- Ensure dynamic code execution is available for server scripts
ServerScriptService.LoadStringEnabled = true

-- Initialize ReplicatedStorage structure first
local function setupReplicatedStorage()
    -- Setup shared modules and remote events here
    local remoteEvents = Instance.new("Folder")
    remoteEvents.Name = "RemoteEvents"
    remoteEvents.Parent = ReplicatedStorage
    
    local remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
    
    print("ReplicatedStorage structure created")
end

-- Initialize all systems in proper order
setupReplicatedStorage()

-- Wait a moment for ReplicatedStorage to replicate
wait(0.1)

-- Initialize core systems
DataManager:Init()
RemoteHandler:Init()
MovementHandler:Init()

print("Server initialized with movement system")
print("Enhanced movement features:")
print("- Stat-based movement speed scaling")
print("- Anti-cheat movement validation")
print("- Multiplayer movement effect synchronization")
