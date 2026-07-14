local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PermadeathModule = require(game.ServerScriptService.ServerModules.PermadeathModule)

Players.PlayerAdded:Connect(function(p)
	if PermadeathModule.Active then 
		PermadeathModule.Registry[p.UserId] = {name = PermadeathModule.GetFullName(p), username = p.Name, died = false} 
	end
	PermadeathModule.TrackPlayer(p)
end)
for _, p in pairs(Players:GetPlayers()) do PermadeathModule.TrackPlayer(p) end

-- Note: Command triggering is handled by RPCommandsModule calling PermadeathModule.SetState
