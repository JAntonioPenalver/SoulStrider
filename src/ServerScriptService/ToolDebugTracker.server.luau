    game.Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(char)
            char.ChildRemoved:Connect(function(child)
                if child:IsA("Tool") then
                    -- Esperamos un frame para ver si se ha movido a la mochila o si ha muerto
                    task.wait()
                    if child.Parent == nil then
                        local stack = debug.traceback()
                    end
                end
            end)
        end)
    end)
