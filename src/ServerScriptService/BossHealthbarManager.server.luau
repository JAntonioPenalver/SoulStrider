local Players = game:GetService("Players")
local BossHealthbarModule = require(game.ServerScriptService.ServerModules.BossHealthbarModule)

Players.PlayerRemoving:Connect(function(player)
	if BossHealthbarModule.CurrentTarget == player then
		BossHealthbarModule.TrackTarget(nil)
	end
end)
