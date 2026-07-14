local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatModule = require(game.ServerScriptService.ServerModules.CombatModule)

local parryShakeEvent = ReplicatedStorage:FindFirstChild("ParryShakeEvent")
if not parryShakeEvent then
	parryShakeEvent = Instance.new("RemoteEvent")
	parryShakeEvent.Name = "ParryShakeEvent"
	parryShakeEvent.Parent = ReplicatedStorage
end

local event = ReplicatedStorage:FindFirstChild("CombatEvent")
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = "CombatEvent"
	event.Parent = ReplicatedStorage
end

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		CombatModule.SetupCharacterBlockMonitor(player.Character)
	end
	player.CharacterAdded:Connect(CombatModule.SetupCharacterBlockMonitor)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(CombatModule.SetupCharacterBlockMonitor)
end)

event.OnServerEvent:Connect(function(player, action, param1, param2)
	local char = player.Character
	if not char then return end

	if action == "Block" then
		if param1 == true then
			local blockCooldownUntil = char:GetAttribute(CombatModule.CONFIG.BLOCK_COOLDOWN_ATTR) or 0
			if time() < blockCooldownUntil then
				char:SetAttribute("IsBlocking", false)
				return
			end

			char:SetAttribute("IsBlocking", true)
			char:SetAttribute("BlockStartTime", time())
		else
			char:SetAttribute("IsBlocking", false)
		end

	elseif action == "LightAttack" then
		if char:GetAttribute(CombatModule.CONFIG.CANNOT_ATTACK_ATTR) then return end
		
		local tool = char:FindFirstChildOfClass("Tool")
		local range = tool and tool:GetAttribute("Range") or 4
		local damage = tool and tool:GetAttribute("Damage") or 10
		local relicDamage = player:GetAttribute("RelicDamageBuff") or 0
		damage = damage + relicDamage
		local effect = tool and tool:GetAttribute("HitEffect") or "Golpe"
		local sound = tool and tool:GetAttribute("HitSound") or CombatModule.CONFIG.NORMAL_HIT_SOUND_ID
		
		CombatModule.CreateHitbox(char, range, damage, tonumber(param1) or 1, effect, sound, param2 == true)

	elseif action == "HeavyAttack" then
		if char:GetAttribute(CombatModule.CONFIG.CANNOT_ATTACK_ATTR) then return end
		
		local tool = char:FindFirstChildOfClass("Tool")
		local range = tool and (tool:GetAttribute("Range") or 4) + 2 or 6
		local damage = tool and tool:GetAttribute("HeavyDamage") or 25
		local relicDamage = player:GetAttribute("RelicDamageBuff") or 0
		damage = damage + relicDamage
		local effect = tool and tool:GetAttribute("HitEffect") or "Golpe"
		local sound = tool and tool:GetAttribute("HitSound") or CombatModule.CONFIG.NORMAL_HIT_SOUND_ID
		
		CombatModule.CreateHitbox(char, range, damage, 0, effect, sound)
	elseif action == "ThrowShield" then
		if char:GetAttribute(CombatModule.CONFIG.CANNOT_ATTACK_ATTR) then return end
		
		local tool = char:FindFirstChildOfClass("Tool")
		if tool and tool.Name == "Escudo" then
			CombatModule.ThrowShield(player, char, tool)
		end
	elseif action == "StrongRight" then
		if char:GetAttribute(CombatModule.CONFIG.CANNOT_ATTACK_ATTR) then return end
		CombatModule.CreateStrongRightHitbox(char, 35) -- 35 de daño
	end
end)
