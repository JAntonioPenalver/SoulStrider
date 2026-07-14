local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)

local loreNameEvent = ReplicatedStorage:FindFirstChild("LoreNameEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
loreNameEvent.Name = "LoreNameEvent"
local toggleTagEvent = ReplicatedStorage:FindFirstChild("ToggleTagEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
toggleTagEvent.Name = "ToggleTagEvent"

Players.PlayerAdded:Connect(LoreModule.Setup)
for _, p in pairs(Players:GetPlayers()) do LoreModule.Setup(p) end

loreNameEvent.OnServerEvent:Connect(function(player, name, age)
    LoreModule.SetLore(player, name, age)
end)

toggleTagEvent.OnServerEvent:Connect(function(player, visible)
    LoreModule.ToggleTag(player, visible)
end)
