local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RPCommandEvent = ReplicatedStorage:WaitForChild("RPCommandEvent")

local CommandRegistry = require(game.ServerScriptService.ServerModules.CommandRegistry)

-- Pre-initialize TerremotoEvent
local TerremotoEvent = ReplicatedStorage:FindFirstChild("TerremotoEvent")
if not TerremotoEvent then
    TerremotoEvent = Instance.new("RemoteEvent")
    TerremotoEvent.Name = "TerremotoEvent"
    TerremotoEvent.Parent = ReplicatedStorage
end

-- Pre-initialize VintageEvent
local VintageEvent = ReplicatedStorage:FindFirstChild("VintageEvent")
if not VintageEvent then
    VintageEvent = Instance.new("RemoteEvent")
    VintageEvent.Name = "VintageEvent"
    VintageEvent.Parent = ReplicatedStorage
end
local RPCommandsModule = require(game.ServerScriptService.ServerModules.RPCommandsModule)

-- Registrar todos los comandos
RPCommandsModule.Init()

-- Escuchar evento de chat para comandos
RPCommandEvent.OnServerEvent:Connect(function(player, cmd, msg)
    print("[RPCommandServer] " .. player.Name .. " ejecutó: " .. tostring(cmd) .. " con argumentos: " .. tostring(msg))
    CommandRegistry.Execute(player, cmd, msg)
end)
