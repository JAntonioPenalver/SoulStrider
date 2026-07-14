local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FishingModule = require(script.Parent.ServerModules.FishingModule)

local fishingEvent = ReplicatedStorage:WaitForChild("FishingEvent")

-- Anti-spam rudimentary cooldown per player
local cooldowns = {}

fishingEvent.OnServerEvent:Connect(function(player, action)
    if action == "Caught" then
        local lastCaught = cooldowns[player.UserId] or 0
        if tick() - lastCaught < 2 then
            -- Suspected spam
            return
        end
        
        cooldowns[player.UserId] = tick()
        
        local success = FishingModule.GiveFish(player)
        if success then
            print(player.Name .. " pescó un pez!")
            local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)
            LoreModule.AddMasteryXP(player, "Pesca", 1)
        end
    end
end)
