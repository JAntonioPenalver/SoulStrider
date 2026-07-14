local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCSpawnerModule = require(game.ServerScriptService.ServerModules.NPCSpawnerModule)
local SpawnGoblinEvent = ReplicatedStorage:WaitForChild("SpawnGoblinEvent")

SpawnGoblinEvent.OnServerEvent:Connect(function(player, spawnPosition)
    NPCSpawnerModule.SpawnGoblin(player, spawnPosition)
end)

local SpawnMahkredEvent = ReplicatedStorage:WaitForChild("SpawnMahkredEvent")
SpawnMahkredEvent.OnServerEvent:Connect(function(player, spawnPosition)
    NPCSpawnerModule.SpawnMahkred(player, spawnPosition)
end)
