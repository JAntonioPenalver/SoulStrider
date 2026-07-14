local RagdollModule = {}

local attachmentCFrames = {
	["Neck"] = {CFrame.new(0, 1, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1), CFrame.new(0, -0.5, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1)},
	["Left Shoulder"] = {CFrame.new(-1.3, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1), CFrame.new(0.2, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1)},
	["Right Shoulder"] = {CFrame.new(1.3, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), CFrame.new(-0.2, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)},
	["Left Hip"] = {CFrame.new(-0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1)},
	["Right Hip"] = {CFrame.new(0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1)},
}

local ragdollInstanceNames = {
	["RagdollAttachment"] = true,
	["RagdollConstraint"] = true,
	["ColliderPart"] = true,
}

local function createColliderPart(part)
	if not part then return end
	local rp = Instance.new("Part")
	rp.Name = "ColliderPart"
	rp.Size = part.Size/1.7
	rp.Massless = true			
	rp.CFrame = part.CFrame
	rp.Transparency = 1
	
	local wc = Instance.new("WeldConstraint")
	wc.Part0 = rp
	wc.Part1 = part
	
	wc.Parent = rp
	rp.Parent = part
end

function RagdollModule.SetRagdoll(character, value)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if value then
        humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
        
        -- Unequip tools when ragdolled
        humanoid:UnequipTools()
        
        for _, motor in pairs(character:GetDescendants()) do
            if motor:IsA("Motor6D") and attachmentCFrames[motor.Name] then
                motor.Enabled = false;
                local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
                a0.CFrame = attachmentCFrames[motor.Name][1]
                a1.CFrame = attachmentCFrames[motor.Name][2]

                a0.Name = "RagdollAttachment"
                a1.Name = "RagdollAttachment"

                createColliderPart(motor.Part1)

                local b = Instance.new("BallSocketConstraint")
                b.Attachment0 = a0
                b.Attachment1 = a1
                b.Name = "RagdollConstraint"
                
                b.Radius = 0.15
                b.LimitsEnabled = true
                b.TwistLimitsEnabled = false
                b.MaxFrictionTorque = 0
                b.Restitution = 0
                b.UpperAngle = 90
                b.TwistLowerAngle = -45
                b.TwistUpperAngle = 45

                if motor.Name == "Neck" then
                    b.TwistLimitsEnabled = true
                    b.UpperAngle = 45
                    b.TwistLowerAngle = -70
                    b.TwistUpperAngle = 70
                end
                
                a0.Parent = motor.Part0
                a1.Parent = motor.Part1
                b.Parent = motor.Parent
            end
        end
        
        humanoid.AutoRotate = false
        character:SetAttribute("LastRag", tick())
    else
        if humanoid.Health < 1 then return end
        for _, instance in pairs(character:GetDescendants()) do
            if ragdollInstanceNames[instance.Name] then
                instance:Destroy()
            end

            if instance:IsA("Motor6D") then
                instance.Enabled = true;
            end
        end
        
        humanoid.AutoRotate = true
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

function RagdollModule.SetupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = true

    local ragdollValue = character:FindFirstChild("IsRagdoll")
    if not ragdollValue then
        ragdollValue = Instance.new("BoolValue")
        ragdollValue.Name = "IsRagdoll"
        ragdollValue.Parent = character
    end
    
    character:SetAttribute("LastRag", 0)

    ragdollValue.Changed:Connect(function(val)
        RagdollModule.SetRagdoll(character, val)
    end)

    -- Prevent tool equipping while ragdolled
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            if ragdollValue.Value then
                local player = game:GetService("Players"):GetPlayerFromCharacter(character)
                if player then
                    local backpack = player:FindFirstChildOfClass("Backpack")
                    if backpack then
                        task.defer(function()
                            if child.Parent == character then
                                child.Parent = backpack
                            end
                        end)
                    end
                end
            end
        end
    end)

    humanoid.Died:Once(function()
        ragdollValue.Value = true
    end)
end

return RagdollModule
