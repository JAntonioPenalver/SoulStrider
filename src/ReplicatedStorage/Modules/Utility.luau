local Utility = {}
local RES = game.ReplicatedStorage
local RP = game:GetService("ReplicatedStorage")
local TweenService = game:GetService('TweenService') 
local Debris = game:GetService("Debris")
local RS = game:GetService("RunService")

function Utility.Knockback(Parent,Velocity,Lifetime)
	if not Lifetime then
		Lifetime = .2 
	end
	local Attachment = Instance.new('Attachment') Debris:AddItem(Attachment,Lifetime) 
	Attachment.Parent = Parent 
	local BV = Instance.new('LinearVelocity',Attachment)

	BV.Attachment0 = Attachment
	BV.MaxForce = 30000
	BV.VectorVelocity = Velocity
end

function Utility.SoundEffect(SoundEffect,Parent,Combat)
	local Sound = SoundEffect:Clone()
	Sound.Parent = Parent
	Debris:AddItem(Sound,SoundEffect.TimeLength)
	Sound:Play()
	return Sound
end

function Utility.Emit(Data)
	local Attachment = Data.Attachment
	local Lifetime = Data.Lifetime or 3
	local Parent = Data.Parent
	local VFX = Attachment:Clone(); VFX.Parent = Parent; Debris:AddItem(VFX,Lifetime)
	
	for _,v in pairs(VFX:GetChildren()) do
		if not v:IsA("ParticleEmitter") then return end
		v:Emit(v:GetAttribute("EmitCount"))
	end
end

return Utility
