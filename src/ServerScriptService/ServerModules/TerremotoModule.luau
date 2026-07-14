local TerremotoModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = require(script.Parent.UtilsModule)

function TerremotoModule.Trigger(player, targetQuery, duration)
    if not Utils.isAdmin(player) then return end
    
    local event = ReplicatedStorage:FindFirstChild("TerremotoEvent")
    if not event then
        event = Instance.new("RemoteEvent")
        event.Name = "TerremotoEvent"
        event.Parent = ReplicatedStorage
    end
    
    local endDuration = tonumber(duration) or 9
    
    if targetQuery == "all" then
        event:FireAllClients(endDuration)
    elseif targetQuery and targetQuery ~= "" then
        local targets = Utils.findPlayersByPrefix(targetQuery)
        for _, t in ipairs(targets) do
            event:FireClient(t, endDuration)
        end
    end
end

return TerremotoModule