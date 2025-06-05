local DataManager = require(script.Parent.DataManager)

local StatService = {}

-- Valid stat keys to prevent exploits
local validStats = {
    Strength = true,
    Agility = true,
    Intelligence = true,
    Constitution = true,
    BreathingMastery = true,
}

function StatService:Allocate(player, stat, amount)
    local profile = DataManager:Get(player)
    if not profile then
        return false
    end

    if not validStats[stat] then
        return false
    end

    if amount > profile.UnspentStatPoints then
        return false
    end

    profile.Stats[stat] += amount
    profile.UnspentStatPoints -= amount
    print(player.Name .. " upgraded " .. stat .. " by " .. amount)
    return true
end

return StatService
