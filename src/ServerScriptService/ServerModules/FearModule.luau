local FearModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = require(script.Parent.UtilsModule)

function FearModule.Trigger(player, targetQuery, duration)
	if not Utils.isAdmin(player) then return end
	local event = ReplicatedStorage:FindFirstChild("FearEvent")
	if not event then return end
	
	if targetQuery == "all" then
		event:FireAllClients(duration)
	elseif targetQuery and targetQuery ~= "" then
		local targets = Utils.findPlayersByPrefix(targetQuery)
		for _, t in ipairs(targets) do
			event:FireClient(t, duration)
		end
	end
end

return FearModule