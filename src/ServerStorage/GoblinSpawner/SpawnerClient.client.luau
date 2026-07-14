local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local tool = script.Parent
local event = game.ReplicatedStorage:WaitForChild("SpawnGoblinEvent")

tool.Activated:Connect(function()
    local targetPos = mouse.Hit.Position
    event:FireServer(targetPos)
end)
