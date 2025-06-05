local DataManager = require(script.Parent.DataManager)

local XPService = {}

local BASE_XP = 100

function XPService:GetLevelXPRequirement(level)
    return level * BASE_XP
end

function XPService:AddXP(player, amount)
    local profile = DataManager:Get(player)
    if not profile then
        return
    end

    local stats = profile.Stats
    stats.EXP += amount

    local required = XPService:GetLevelXPRequirement(stats.Level)
    while stats.EXP >= required do
        stats.EXP -= required
        stats.Level += 1
        profile.UnspentStatPoints += 5
        print(player.Name .. " reached level " .. stats.Level)
        required = XPService:GetLevelXPRequirement(stats.Level)
    end
end

return XPService
