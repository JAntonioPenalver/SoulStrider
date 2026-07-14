local tool = script.Parent
local player = game.Players.LocalPlayer

tool.Equipped:Connect(function()
    local playerGui = player:WaitForChild("PlayerGui")
    local compassGui = playerGui:FindFirstChild("CompassGui")
    if compassGui then
        compassGui.Enabled = true
    end
end)

tool.Unequipped:Connect(function()
    local playerGui = player:WaitForChild("PlayerGui")
    local compassGui = playerGui:FindFirstChild("CompassGui")
    if compassGui then
        compassGui.Enabled = false
    end
end)
