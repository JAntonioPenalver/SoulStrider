local Players = game:GetService("Players")

local UtilsModule = {}

UtilsModule.ADMIN_IDS = {138637118, 223933804, 261141934}

function UtilsModule.isAdmin(player)
    local admin = false
    
    if game.CreatorType == Enum.CreatorType.Group then
        admin = (player:GetRankInGroup(game.CreatorId) == 255)
    else
        admin = (player.UserId == game.CreatorId)
    end
    
    if table.find(UtilsModule.ADMIN_IDS, player.UserId) then
        admin = true
    end
    
    return admin
end

function UtilsModule.findPlayersByPrefix(prefix)
    local matches = {}
    local targetName = string.lower(prefix or "")
    if targetName == "" then
        return matches
    end

    for _, p in pairs(Players:GetPlayers()) do
        local name = string.lower(p.Name)
        local displayName = string.lower(p.DisplayName)
        
        if name == targetName or displayName == targetName or 
           name:find(targetName, 1, true) or displayName:find(targetName, 1, true) then
            table.insert(matches, p)
        end
    end

    return matches
end

return UtilsModule
