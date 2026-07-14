local tool = script.Parent
local player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local event = ReplicatedStorage:WaitForChild("CombatEvent")

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

local ANIM_ID = "rbxassetid://109278324727138"
local COOLDOWN = 6.0
local lastUse = 0

local animation = Instance.new("Animation")
animation.AnimationId = ANIM_ID
local track = humanoid:LoadAnimation(animation)

local isEquipped = false
local isActivating = false

tool.Equipped:Connect(function()
    isEquipped = true
    character = player.Character
    humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        track = humanoid:LoadAnimation(animation)
    end
end)

tool.Unequipped:Connect(function()
    isEquipped = false
    isActivating = false
end)

tool.Activated:Connect(function()
    if isActivating then return end
    if character:GetAttribute("CannotAttack") then return end
    if tick() - lastUse < COOLDOWN then return end
    
    lastUse = tick()
    isActivating = true
    
    -- Start Cooldown HUD item on client
    local UIManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIManager"))
    UIManager.StartCooldown("StrongRight", COOLDOWN)
    
    if track then track:Play() end
    
    task.delay(0.5, function()
        event:FireServer("StrongRight")
        
        task.delay(0.5, function()
            isActivating = false
        end)
    end)
end)