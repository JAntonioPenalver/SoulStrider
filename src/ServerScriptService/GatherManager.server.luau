-- GatherManager: escucha hits del cliente y delega al GatherModule
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GatherModule = require(game.ServerScriptService.ServerModules.GatherModule)

local GatherHitEvent = ReplicatedStorage:WaitForChild("GatherHitEvent")

GatherHitEvent.OnServerEvent:Connect(function(player, targetPart)
    local success, result, health, resourceName = GatherModule.OnHit(player, targetPart)
    if success then
        if result == "hit" then
            GatherModule.PlayHitEffect(targetPart)
        end
        
        -- Otorgar experiencia de Recolección (Minería o Tala)
        if resourceName == "ArbolTalable" then
            local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)
            LoreModule.AddMasteryXP(player, "Tala", 1)
        elseif resourceName == "Piedra" or resourceName == "Hierro" then
            local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)
            LoreModule.AddMasteryXP(player, "Mineria", 1)
        end
    else
        -- Opcional: print("Gather fallido para "..player.Name..": "..tostring(result))
    end
end)
