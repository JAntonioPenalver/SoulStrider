local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SurvivalModule = require(game.ServerScriptService.ServerModules.SurvivalModule)

Players.PlayerAdded:Connect(function(p)
    SurvivalModule.Setup(p)
end)

for _, p in pairs(Players:GetPlayers()) do 
    SurvivalModule.Setup(p) 
end

Players.PlayerRemoving:Connect(SurvivalModule.Save)

task.spawn(function()
    while true do
        task.wait(60)
        for _, p in pairs(Players:GetPlayers()) do SurvivalModule.Save(p) end
    end
end)

game:BindToClose(function()
    for _, p in pairs(Players:GetPlayers()) do SurvivalModule.Save(p) end
    task.wait(2)
end)

ReplicatedStorage:WaitForChild("EatFoodEvent").OnServerEvent:Connect(function(player, tool)
    SurvivalModule.EatFood(player, tool)
end)

ReplicatedStorage:WaitForChild("UseItemEvent").OnServerEvent:Connect(function(player, tool)
    SurvivalModule.UseItem(player, tool)
end)
