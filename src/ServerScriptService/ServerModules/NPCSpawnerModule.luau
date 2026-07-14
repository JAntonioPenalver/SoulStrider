local NPCSpawnerModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function NPCSpawnerModule.SpawnGoblin(player, spawnPosition)
    local GoblinTemplate = ReplicatedStorage:WaitForChild("Real Goblin")
    local goblinClone = GoblinTemplate:Clone()
    goblinClone:PivotTo(CFrame.new(spawnPosition + Vector3.new(0, 5, 0)))
    goblinClone.Parent = game.Workspace

    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Position = spawnPosition
    part.Parent = game.Workspace
    local attachment = Instance.new("Attachment", part)
    local particles = Instance.new("ParticleEmitter", attachment)
    particles.Texture = "rbxassetid://244221448"
    particles.Rate = 100
    particles.Speed = NumberRange.new(5, 10)
    particles.Lifetime = NumberRange.new(0.5, 1)
    task.delay(1, function()
        particles.Enabled = false
        task.wait(1)
        part:Destroy()
    end)
    local humanoid = goblinClone:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Died:Connect(function()
            task.wait(5)
            goblinClone:Destroy()
        end)
    end
end

function NPCSpawnerModule.SpawnMahkred(player, spawnPosition)
    local template = ReplicatedStorage:WaitForChild("Real Mahkred")
    local clone = template:Clone()
    clone.Name = "Mahkred"
    -- Posicionar de pie: resetear rotacion, solo trasladar
    local hrp = clone:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 5, 0))
    else
        clone:PivotTo(CFrame.new(spawnPosition + Vector3.new(0, 5, 0)))
    end
    clone.Parent = game.Workspace
    -- Efecto de spawn
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Position = spawnPosition
    part.Parent = game.Workspace
    local att = Instance.new("Attachment", part)
    local particles = Instance.new("ParticleEmitter", att)
    particles.Texture = "rbxassetid://244221448"
    particles.Rate = 100
    particles.Speed = NumberRange.new(5, 10)
    particles.Lifetime = NumberRange.new(0.5, 1)
    task.delay(1, function()
        particles.Enabled = false
        task.wait(1)
        part:Destroy()
    end)
end

return NPCSpawnerModule
