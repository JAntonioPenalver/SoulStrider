local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = require(game.ServerScriptService.ServerModules.UtilsModule)

-- Crear un RemoteEvent para avisar al cliente que abra el menú
local openEvent = ReplicatedStorage:FindFirstChild("OpenMusicMenu") or Instance.new("RemoteEvent", ReplicatedStorage)
openEvent.Name = "OpenMusicMenu"

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg)
        if string.lower(msg) == "/musica" then
            if Utils.isAdmin(player) then
                -- Avisar al cliente que abra el GUI
                openEvent:FireClient(player)
            else
                print("[MusicCommand] Player " .. player.Name .. " is not an admin.")
            end
        end
    end)
end)
