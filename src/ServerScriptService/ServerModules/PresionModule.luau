local PresionModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = require(script.Parent.UtilsModule)

function PresionModule.Trigger(player, targetQuery, duration)
	if not Utils.isAdmin(player) then return end
	
	-- Crear el evento si no existe
	local event = ReplicatedStorage:FindFirstChild("PresionEvent")
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "PresionEvent"
		event.Parent = ReplicatedStorage
	end
	
	if string.lower(targetQuery or "") == "all" then
		event:FireAllClients(duration)
	elseif targetQuery and targetQuery ~= "" then
		local targets = Utils.findPlayersByPrefix(targetQuery)
		for _, t in ipairs(targets) do
			event:FireClient(t, duration)
		end
	end
end

return PresionModule