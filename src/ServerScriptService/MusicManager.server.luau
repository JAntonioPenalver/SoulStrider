local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MusicModule = require(game.ServerScriptService.ServerModules.MusicModule)
local Utils = require(game.ServerScriptService.ServerModules.UtilsModule)
local MusicEvent = ReplicatedStorage:WaitForChild("MusicEvent")

MusicEvent.OnServerEvent:Connect(function(player, action, id)
    if not Utils.isAdmin(player) then return end
    if action == "Play" then MusicModule.Play(id)
    elseif action == "Stop" then MusicModule.Stop() end
end)
