local CarryModule = {}

function CarryModule.Carry(carrierPlayer, targetChar)
    local cChar = carrierPlayer.Character
    if not cChar or not targetChar then return end
    
    local cRoot = cChar:FindFirstChild("HumanoidRootPart") or cChar:FindFirstChild("UpperTorso") or cChar:FindFirstChild("Torso")
    local tRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
    
    if not cRoot or not tRoot then return end
    
    local tRagdoll = targetChar:FindFirstChild("IsRagdoll")
    local cRagdoll = cChar:FindFirstChild("IsRagdoll")
    
    if not tRagdoll or not tRagdoll.Value then return end
    if cRagdoll and cRagdoll.Value then return end
    
    -- Temporarily disable physical ragdoll for animation to play properly
    local RagdollModule = require(script.Parent.RagdollModule)
    RagdollModule.SetRagdoll(targetChar, false)
    
    -- Teleport target to carrier's back
    tRoot.CFrame = cRoot.CFrame * CFrame.new(0, 0, 1.5)
    
    -- Set target state
    local tHum = targetChar:FindFirstChild("Humanoid")
    if tHum then
        tHum.PlatformStand = true -- help with physics glitching
        
        local animator = tHum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = tHum
        end
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://103057527928700"
        local track = animator:LoadAnimation(anim)
        track.Name = "CarryTargetAnim"
        track.Priority = Enum.AnimationPriority.Action
        track.Looped = true
        track:Play()
    end
    
    -- Create Weld
    local weld = Instance.new("WeldConstraint")
    weld.Name = "CarryWeld"
    weld.Part0 = cRoot
    weld.Part1 = tRoot
    weld.Parent = cRoot
    
    -- Create object value to track who we are carrying
    local trackVal = Instance.new("ObjectValue")
    trackVal.Name = "CarryingChar"
    trackVal.Value = targetChar
    trackVal.Parent = cRoot
    
    -- Make target massless
    for _, part in ipairs(targetChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Massless = true
            part.CanCollide = false
        end
    end
    
    -- Set attributes
    targetChar:SetAttribute("Invincible", true)
    targetChar:SetAttribute("CarriedBy", carrierPlayer.UserId)
end

function CarryModule.Drop(carrierPlayer)
    local cChar = carrierPlayer.Character
    if not cChar then return end
    
    local cRoot = cChar:FindFirstChild("HumanoidRootPart")
    if not cRoot then return end
    
    local trackVal = cRoot:FindFirstChild("CarryingChar")
    if not trackVal then return end
    
    local targetChar = trackVal.Value
    trackVal:Destroy()
    
    local weld = cRoot:FindFirstChild("CarryWeld")
    if weld then weld:Destroy() end
    
    if targetChar and targetChar.Parent then
        local tRoot = targetChar:FindFirstChild("HumanoidRootPart")
        if tRoot then
            tRoot.CFrame = cRoot.CFrame * CFrame.new(0, 0, -3)
        end
        
        local tHum = targetChar:FindFirstChild("Humanoid")
        if tHum then
            tHum.PlatformStand = false
            local animator = tHum:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    if track.Name == "CarryTargetAnim" or (track.Animation and track.Animation.AnimationId == "rbxassetid://103057527928700") then
                        track:Stop()
                    end
                end
            end
        end
        
        -- Restore physics
        for _, part in ipairs(targetChar:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Massless = false
                if part.Name == "HumanoidRootPart" or part.Name == "Torso" or part.Name == "Head" then
                    part.CanCollide = true
                end
            end
        end
        
        -- Re-enable physical ragdoll since they are still in ragdoll state
        local tRagdoll = targetChar:FindFirstChild("IsRagdoll")
        if tRagdoll and tRagdoll.Value then
            local RagdollModule = require(script.Parent.RagdollModule)
            RagdollModule.SetRagdoll(targetChar, true)
        end
        
        targetChar:SetAttribute("Invincible", nil)
        targetChar:SetAttribute("CarriedBy", nil)
    end
end

return CarryModule
