-- Input Manager (Simplified - Dash system now handles its own inputs)
-- This file is kept for compatibility but the main dash functionality 
-- is now handled directly in DashClient.client.luau with double-tap detection

local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- Input manager loaded - dash controls handled by double-tap system

-- Optional: Add any additional input handling here if needed
-- The dash system is now self-contained in DashClient.client.luau
