local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArmorModule = require(game.ServerScriptService.ServerModules.ArmorModule)
local ArmorEvent = ReplicatedStorage:WaitForChild("ArmorEvent")

ArmorEvent.OnServerEvent:Connect(function(player, action, armorName)
	if action == "Equip" then
		ArmorModule.Equip(player, armorName)
	elseif action == "Unequip" then
		ArmorModule.Unequip(player, armorName)
	elseif action == "Toggle" then
		ArmorModule.Toggle(player, armorName)
	end
end)
