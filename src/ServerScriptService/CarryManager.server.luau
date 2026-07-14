local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CarryModule = require(script.Parent.ServerModules.CarryModule)

local carryEvent = ReplicatedStorage:WaitForChild("CarryEvent")

carryEvent.OnServerEvent:Connect(function(player, action, targetChar)
    if action == "Carry" and targetChar and targetChar:IsA("Model") then
        local pChar = player.Character
        if pChar and targetChar then
            local pRoot = pChar:FindFirstChild("HumanoidRootPart")
            local tRoot = targetChar:FindFirstChild("HumanoidRootPart")
            if pRoot and tRoot then
                local dist = (pRoot.Position - tRoot.Position).Magnitude
                if dist <= 12 then -- slight leeway on server
                    -- Cannot carry if already carrying someone (check for weld)
                    if not pRoot:FindFirstChild("CarryWeld") then
                        -- Cannot be carried if already being carried
                        if not targetChar:GetAttribute("CarriedBy") then
                            CarryModule.Carry(player, targetChar)
                        end
                    end
                end
            end
        end
    elseif action == "Drop" then
        CarryModule.Drop(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    CarryModule.Drop(player)
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        local humanoid = char:WaitForChild("Humanoid", 10)
        if humanoid then
            humanoid.Died:Connect(function()
                CarryModule.Drop(player)
            end)
        end
    end)
end)
