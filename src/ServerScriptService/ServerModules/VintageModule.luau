local VintageModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = require(script.Parent.UtilsModule)

function VintageModule.Trigger(player, targetQuery, duration)
	if not Utils.isAdmin(player) then return end
	
	local event = ReplicatedStorage:FindFirstChild("VintageEvent")
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = "VintageEvent"
		event.Parent = ReplicatedStorage
	end
	
	if targetQuery == "all" then
		event:FireAllClients(duration)
	elseif targetQuery and targetQuery ~= "" then
		local targets = Utils.findPlayersByPrefix(targetQuery)
		for _, t in ipairs(targets) do
			event:FireClient(t, duration)
		end
	end
end

return VintageModule
