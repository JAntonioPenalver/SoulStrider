local FishingModule = {}
local ServerStorage = game:GetService("ServerStorage")

function FishingModule.GiveFish(player)
    local pezTool = ServerStorage:FindFirstChild("Pez")
    if pezTool then
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            local existingPez = backpack:FindFirstChild("Pez") or (player.Character and player.Character:FindFirstChild("Pez"))
            
            if existingPez then
                local current = existingPez:GetAttribute("Cantidad") or 1
                existingPez:SetAttribute("Cantidad", current + 1)
                return true
            else
                local clone = pezTool:Clone()
                clone:SetAttribute("Cantidad", 1)
                clone.Parent = backpack
                return true
            end
        end
    end
    return false
end

return FishingModule
