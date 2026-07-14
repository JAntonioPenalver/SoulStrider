local Players = game:GetService("Players")
local RagdollModule = require(game.ServerScriptService.ServerModules.RagdollModule)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        RagdollModule.SetupCharacter(character)
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        RagdollModule.SetupCharacter(player.Character)
    end
    player.CharacterAdded:Connect(function(character)
        RagdollModule.SetupCharacter(character)
    end)
end
