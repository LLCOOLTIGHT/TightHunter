-- WallRunTestScript.server.luau - Test Script for Wallrunning Mechanics
-- Creates demo walls for testing the wallrunning system

local workspace = game:GetService("Workspace")

local TestWalls = {}

-- Configuration for test walls
local Config = {
    WallHeight = 50,
    WallWidth = 4,
    WallLength = 100,
    WallColor = Color3.fromRGB(100, 100, 100),
    WallMaterial = Enum.Material.Concrete,
    SpawnHeight = 10,
}

-- Create a test wall
local function createWall(position, rotation, name)
    local wall = Instance.new("Part")
    wall.Name = name or "TestWall"
    wall.Size = Vector3.new(Config.WallLength, Config.WallHeight, Config.WallWidth)
    wall.Position = position
    wall.Rotation = rotation or Vector3.new(0, 0, 0)
    wall.Color = Config.WallColor
    wall.Material = Config.WallMaterial
    wall.Anchored = true
    wall.CanCollide = true
    wall.Parent = workspace
    
    -- Add a small platform at the base for easier access
    local platform = Instance.new("Part")
    platform.Name = name .. "_Platform"
    platform.Size = Vector3.new(10, 2, 10)
    platform.Position = position - Vector3.new(0, (Config.WallHeight/2) + 1, Config.WallWidth + 8)
    platform.Color = Color3.fromRGB(80, 80, 80)
    platform.Material = Enum.Material.Plastic
    platform.Anchored = true
    platform.CanCollide = true
    platform.Parent = workspace
    
    return wall, platform
end

-- Create a corner setup for testing turning while wallrunning
local function createCornerWalls(centerPosition)
    -- Create two perpendicular walls
    local wall1, platform1 = createWall(
        centerPosition + Vector3.new(-Config.WallLength/2, 0, 0),
        Vector3.new(0, 0, 0),
        "CornerWall1"
    )
    
    local wall2, platform2 = createWall(
        centerPosition + Vector3.new(0, 0, -Config.WallLength/2),
        Vector3.new(0, 90, 0),
        "CornerWall2"
    )
    
    return {wall1, wall2}, {platform1, platform2}
end

-- Create parallel walls for advanced wallrunning practice
local function createParallelWalls(centerPosition, spacing)
    spacing = spacing or 20
    
    local wall1, platform1 = createWall(
        centerPosition + Vector3.new(-spacing/2, 0, 0),
        Vector3.new(0, 0, 0),
        "ParallelWall1"
    )
    
    local wall2, platform2 = createWall(
        centerPosition + Vector3.new(spacing/2, 0, 0),
        Vector3.new(0, 0, 0),
        "ParallelWall2"
    )
    
    -- Add connecting platforms for practice
    for i = 1, 3 do
        local connectPlatform = Instance.new("Part")
        connectPlatform.Name = "ConnectPlatform" .. i
        connectPlatform.Size = Vector3.new(4, 1, 4)
        connectPlatform.Position = centerPosition + Vector3.new(
            (i - 2) * spacing/3,
            Config.WallHeight/4 * i,
            -spacing
        )
        connectPlatform.Color = Color3.fromRGB(120, 120, 120)
        connectPlatform.Material = Enum.Material.Plastic
        connectPlatform.Anchored = true
        connectPlatform.CanCollide = true
        connectPlatform.Parent = workspace
    end
    
    return {wall1, wall2}, {platform1, platform2}
end

-- Initialize test environment
local function initializeTestWalls()
    print("Creating wallrun test environment...")
    
    -- Clear existing test walls
    for _, wall in ipairs(workspace:GetChildren()) do
        if string.find(wall.Name, "TestWall") or string.find(wall.Name, "Wall") or string.find(wall.Name, "Platform") then
            wall:Destroy()
        end
    end
    
    -- Create basic test walls
    local basePosition = Vector3.new(0, Config.WallHeight/2 + Config.SpawnHeight, 0)
    
    -- Single straight wall
    local straightWall, straightPlatform = createWall(
        basePosition + Vector3.new(0, 0, 50),
        Vector3.new(0, 0, 0),
        "StraightTestWall"
    )
    TestWalls[#TestWalls + 1] = straightWall
    
    -- Corner walls
    local cornerWalls, cornerPlatforms = createCornerWalls(
        basePosition + Vector3.new(80, 0, 0)
    )
    for _, wall in ipairs(cornerWalls) do
        TestWalls[#TestWalls + 1] = wall
    end
    
    -- Parallel walls
    local parallelWalls, parallelPlatforms = createParallelWalls(
        basePosition + Vector3.new(-80, 0, 0),
        25
    )
    for _, wall in ipairs(parallelWalls) do
        TestWalls[#TestWalls + 1] = wall
    end
    
    -- Create a spawn platform
    local spawnPlatform = Instance.new("Part")
    spawnPlatform.Name = "SpawnPlatform"
    spawnPlatform.Size = Vector3.new(20, 4, 20)
    spawnPlatform.Position = Vector3.new(0, Config.SpawnHeight, 0)
    spawnPlatform.Color = Color3.fromRGB(0, 255, 0)
    spawnPlatform.Material = Enum.Material.Neon
    spawnPlatform.Anchored = true
    spawnPlatform.CanCollide = true
    spawnPlatform.Parent = workspace
    
    -- Add instructional signs
    local function createSign(position, text)
        local sign = Instance.new("Part")
        sign.Name = "InstructionSign"
        sign.Size = Vector3.new(8, 6, 0.2)
        sign.Position = position
        sign.Color = Color3.fromRGB(255, 255, 0)
        sign.Material = Enum.Material.Neon
        sign.Anchored = true
        sign.CanCollide = false
        sign.Parent = workspace
        
        local gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Front
        gui.Parent = sign
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Text = text
        textLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.TextScaled = true
        textLabel.BackgroundTransparency = 1
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.Parent = gui
    end
    
    createSign(
        Vector3.new(0, Config.SpawnHeight + 8, 10),
        "WALLRUN CONTROLS:\nHold SPACE + Move toward wall\nRelease SPACE to stop\n\nWASD to move\nLEFT SHIFT to sprint"
    )
    
    print("Wallrun test environment created!")
    print("- Straight wall for basic testing")
    print("- Corner walls for turning practice")
    print("- Parallel walls for advanced moves")
    print("- Green spawn platform at center")
end

-- Initialize the test environment
initializeTestWalls()

-- Optional: Create a command to regenerate walls
game.Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        if message:lower() == "/resetwalls" and player.Name == "YourUsernameHere" then -- Replace with your username
            initializeTestWalls()
        end
    end)
end)

return TestWalls 