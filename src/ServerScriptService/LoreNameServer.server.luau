local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local LoreModule = require(ServerScriptService.ServerModules.LoreModule)
local RequestEvent = ReplicatedStorage:WaitForChild("LoreNameRequest")

RequestEvent.OnServerEvent:Connect(function(player, firstName, age)
    if typeof(firstName) ~= "string" or #firstName < 2 or #firstName > 15 then return end
    local numAge = tonumber(age)
    if not numAge or numAge < 10 or numAge > 100 then return end
    
    -- Solo permitir si no tiene nombre todavía
    local fnv = player:FindFirstChild("LoreFirstName")
    if fnv and fnv.Value == "" then
        LoreModule.SetLore(player, firstName, numAge)
        print("Sello el destino de: " .. player.Name .. " como " .. firstName)
    end
end)
