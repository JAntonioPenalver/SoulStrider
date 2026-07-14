local CombatModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RagdollModule = require(script.Parent.RagdollModule)
local AdvancedInjuryModule = require(script.Parent.AdvancedInjuryModule)
local CondicionesModule = require(script.Parent.CondicionesModule)

-- CONFIG
CombatModule.CONFIG = {
    PARRY_WINDOW = 0.7,
    MAX_BLOCK_HITS = 3,
    STUN_TIME_BROKEN = 3,
    HIT_SLOW_WALKSPEED = 6,
    HIT_SLOW_DURATION = 0.9,
    COMBO_FINISHER_KNOCKBACK = 85, -- Aumentado de 50 a 85
    COMBO_FINISHER_RAGDOLL_DURATION = 2.5, -- Un poco más de tiempo para recuperarse lejos
    CANNOT_ATTACK_ATTR = "CannotAttack",
    BLOCK_COOLDOWN_ATTR = "BlockCooldownUntil",
    BLOCK_BREAK_SIGNAL_ATTR = "BlockBreakSignal",
    BLOCK_REUSE_COOLDOWN = 10,
    BLOCK_HIT_SOUND_ID = "rbxassetid://137927717315258",
    BLOCK_BREAK_SOUND_ID = "rbxassetid://118075813585143",
    PARRY_SOUND_ID = "rbxassetid://136159508882086",
    PARRY_STUN_ANIM_ID = "rbxassetid://107757821085686",
    PARRY_COOLDOWN = 1.5, -- Tiempo mínimo entre parries exitosos
    STRONG_RIGHT_ANIM = "rbxassetid://109278324727138",
	STRONG_RIGHT_SOUND = "rbxassetid://122711481431617",
	NORMAL_HIT_SOUND_ID = "rbxassetid://135200034075896",
	HIT_ANIM_ID = "rbxassetid://111973826261472",
	GOBLIN_PARRY_CHANCE = 0.15,
	GOBLIN_BLOCK_CHANCE = 0.25,
	GOBLIN_PARRY_RAGDOLL_DURATION = 1.5
}

local slowStateByHumanoid = {}
local parryStateByHumanoid = {}
local blockMonitorStateByHumanoid = {}

-- FIND HUMANOID
function CombatModule.FindHumanoid(part)
	local char = part.Parent
	if not char then return end
	return char:FindFirstChildOfClass("Humanoid") or
		(char.Parent and char.Parent:FindFirstChildOfClass("Humanoid"))
end

function CombatModule.PlayCharacterSound(character, soundId)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = 2 -- Aumentado de 1 a 2
	s.Parent = root
	s:Play()
	game.Debris:AddItem(s, 2)
end

function CombatModule.PlayHitEffect(victimChar, effectName)
	local vRoot = victimChar:FindFirstChild("HumanoidRootPart")
	if not vRoot then return end
	
	local templateName = effectName or "Golpe"
	local vfxTemplate = workspace:FindFirstChild(templateName)
	
	if vfxTemplate then
		local mainAttach = vfxTemplate:FindFirstChild("Main")
		if mainAttach then
			local clone = mainAttach:Clone()
			-- FIX: Preservar la rotación del Part original para que el efecto direccional (como Slash) apunte bien
			clone.CFrame = mainAttach.CFrame * vfxTemplate.CFrame.Rotation
			clone.Parent = vRoot
			for _, emitter in ipairs(clone:GetChildren()) do
				if emitter:IsA("ParticleEmitter") then
					emitter.Enabled = false
					emitter:Emit(emitter:GetAttribute("EmitCount") or 15)
				end
			end
			game.Debris:AddItem(clone, 1)
		end
	end
end

function CombatModule.PlayHitAnimation(victimHum)
	local anim = Instance.new("Animation")
	anim.AnimationId = CombatModule.CONFIG.HIT_ANIM_ID
	local animator = victimHum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = victimHum
	end
	local track = animator:LoadAnimation(anim)
	if track then
		track.Looped = false
		track:Play()
	end
end

function CombatModule.EmitParryEffect(victimRoot, attackerRoot)
	local vfxTemplate = nil
	
	-- Primero buscamos en ReplicatedStorage.Fx (donde se guarda de forma segura con Rojo)
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local fxFolder = replicatedStorage:FindFirstChild("Fx")
	if fxFolder then
		vfxTemplate = fxFolder:FindFirstChild("Parry_2") or fxFolder:FindFirstChild("Parry")
	end
	
	-- Si no está ahí, buscamos en el Workspace como fallback temporal
	if not vfxTemplate then
		for _, child in ipairs(workspace:GetChildren()) do
			if (child.Name == "Parry_2" or child.Name == "Parry") and child:IsA("BasePart") then
				vfxTemplate = child
				break
			end
		end
	end
	
	if vfxTemplate and victimRoot then
		local mainAttach = vfxTemplate:FindFirstChild("Main")
		if mainAttach then
			local clone = mainAttach:Clone()
			clone.Parent = victimRoot
			for _, emitter in ipairs(clone:GetChildren()) do
				if emitter:IsA("ParticleEmitter") then
					emitter.Enabled = false
					emitter:Emit(emitter:GetAttribute("EmitCount") or 20)
				end
			end
			game.Debris:AddItem(clone, 1.5)
		end
	end
end

function CombatModule.PlayGoblinBlockVFX(goblinChar, duration)
	local humanoid = goblinChar:FindFirstChild("Humanoid")
	local root = goblinChar:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	-- Play Player's Block Animation
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local blockAnim = Instance.new("Animation")
	blockAnim.AnimationId = "rbxassetid://77799026661567"
	
	local track = nil
	local success, err = pcall(function()
		track = animator:LoadAnimation(blockAnim)
	end)
	
	if success and track then
		track.Looped = false
		track:Play(0.1)
		task.delay(duration or 0.5, function()
			pcall(function()
				if track then
					track:Stop(0.1)
				end
			end)
		end)
	end

	-- Play Player's Block VFX (from ReplicatedStorage)
	local blockEffectBase = ReplicatedStorage:FindFirstChild("Block")
	if blockEffectBase then
		local attachment = Instance.new("Attachment")
		attachment.Name = "GoblinBlockEffectAttachment"
		attachment.Position = Vector3.new(0, 0, -2.0)
		attachment.Parent = root

		local effect = blockEffectBase:Clone()
		effect.Parent = attachment
		if effect:IsA("ParticleEmitter") then
			effect.Enabled = true
		end

		game.Debris:AddItem(attachment, duration or 0.5)
	end
end

function CombatModule.ApplyParryStun(humanoid)
	if not humanoid or humanoid.Health <= 0 then return end
	
	CombatModule.ApplyStun(humanoid, 1, 4)

	local stunAnim = Instance.new("Animation")
	stunAnim.AnimationId = CombatModule.CONFIG.PARRY_STUN_ANIM_ID
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	
	local stunTrack = nil
	local success, err = pcall(function()
		stunTrack = animator:LoadAnimation(stunAnim)
	end)
	
	if success and stunTrack and typeof(stunTrack) == "Instance" and stunTrack:IsA("AnimationTrack") then
		stunTrack.Looped = false
		pcall(function()
			stunTrack:Play()
		end)
		task.delay(1, function()
			pcall(function()
				if stunTrack and stunTrack.Parent then
					stunTrack:Stop()
				end
			end)
		end)
	end
end

function CombatModule.ApplyStun(humanoid, duration, speedLimit)
	if not humanoid or humanoid.Health <= 0 then return end
	local char = humanoid.Parent
	if not char then return end

	if not humanoid:GetAttribute("BaseWalkSpeed") then
		humanoid:SetAttribute("BaseWalkSpeed", humanoid.WalkSpeed >= 16 and humanoid.WalkSpeed or 16)
	end
	
	if not humanoid:GetAttribute("BaseJumpPower") then
		humanoid:SetAttribute("BaseJumpPower", humanoid.JumpPower >= 50 and humanoid.JumpPower or 50)
	end

	char:SetAttribute(CombatModule.CONFIG.CANNOT_ATTACK_ATTR, true)
	humanoid.WalkSpeed = speedLimit -- Reduce la velocidad al límite especificado (ej. 6 en golpe, 4 en parry, 0 en break)
	humanoid.JumpPower = 0

	-- Crear el BoolValue "Stun" en el Character únicamente cuando es golpeado/aturdido
	local stunVal = char:FindFirstChild("Stun")
	if not stunVal then
		stunVal = Instance.new("BoolValue")
		stunVal.Name = "Stun"
		stunVal.Value = true
		stunVal.Parent = char
	end

	local stunEndTime = (humanoid:GetAttribute("StunEndTime") or 0)
	local newStunEnd = tick() + duration
	
	if newStunEnd > stunEndTime then
		humanoid:SetAttribute("StunEndTime", newStunEnd)
	end

	task.delay(duration, function()
		if not humanoid or not humanoid.Parent then return end
		-- Verificamos si este es el último stun activo
		if tick() >= (humanoid:GetAttribute("StunEndTime") or 0) - 0.05 then
			humanoid.WalkSpeed = humanoid:GetAttribute("BaseWalkSpeed") or 16
			humanoid.JumpPower = humanoid:GetAttribute("BaseJumpPower") or 50
			char:SetAttribute(CombatModule.CONFIG.CANNOT_ATTACK_ATTR, false)
			char:SetAttribute("HitSlow", false)

			-- Destruir el BoolValue "Stun" al terminar el aturdimiento
			local val = char:FindFirstChild("Stun")
			if val then
				val:Destroy()
			end
		end
	end)
end

function CombatModule.ApplyHitSlow(humanoid)
	if not humanoid or humanoid.Health <= 0 then return end
	local char = humanoid.Parent
	if char then
		char:SetAttribute("HitSlow", true)
	end
	
	local duration = CombatModule.CONFIG.HIT_SLOW_DURATION
	if char and (char.Name == "Real Goblin" or char:FindFirstChild("GoblinAI")) then
		duration = 1.3
	end
	
	CombatModule.ApplyStun(humanoid, duration, CombatModule.CONFIG.HIT_SLOW_WALKSPEED)
end

function CombatModule.ApplyKnockback(attackerChar, victimChar, force)
	local aRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	local vRoot = victimChar:FindFirstChild("HumanoidRootPart")
	if not aRoot or not vRoot then return end

	-- Calculamos la dirección desde el atacante al objetivo para mayor precisión
	local direction = (vRoot.Position - aRoot.Position).Unit
	if direction.Magnitude < 0.1 then
		direction = aRoot.CFrame.LookVector
	end
	
	-- Aplicamos una fuerza combinada: horizontal potente + vertical para "volar"
	local finalVelocity = (direction * force) + Vector3.new(0, force * 0.4, 0)
	vRoot.AssemblyLinearVelocity = finalVelocity
end

function CombatModule.BreakGuard(character, humanoid)
	character:SetAttribute("IsBlocking", false)
	
	local maxPosture = character:GetAttribute("MaxPosture") or (humanoid.MaxHealth * 0.7)
	character:SetAttribute("Posture", maxPosture)
	
	character:SetAttribute(CombatModule.CONFIG.BLOCK_COOLDOWN_ATTR, time() + CombatModule.CONFIG.BLOCK_REUSE_COOLDOWN)
	character:SetAttribute(CombatModule.CONFIG.BLOCK_BREAK_SIGNAL_ATTR, time())
	CombatModule.PlayCharacterSound(character, CombatModule.CONFIG.BLOCK_BREAK_SOUND_ID)

	local originalJump = humanoid:GetAttribute("BaseJumpPower") or humanoid.JumpPower
	if originalJump < 1 then originalJump = 50 end
	humanoid.JumpPower = 0

	-- Play Stun Pose Animation
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local stunAnim = Instance.new("Animation")
		stunAnim.AnimationId = CombatModule.CONFIG.HIT_ANIM_ID
		local track = nil
		local success, err = pcall(function()
			track = animator:LoadAnimation(stunAnim)
		end)
		if success and track and typeof(track) == "Instance" and track:IsA("AnimationTrack") then
			track.Looped = true
			pcall(function()
				track:Play()
			end)
			task.delay(CombatModule.CONFIG.STUN_TIME_BROKEN, function()
				pcall(function()
					if track and track.Parent then
						track:Stop()
					end
				end)
			end)
		end
	end

	CombatModule.ApplyStun(humanoid, CombatModule.CONFIG.STUN_TIME_BROKEN, 0)

	task.delay(CombatModule.CONFIG.STUN_TIME_BROKEN, function()
		if humanoid and humanoid.Parent then
			humanoid.JumpPower = originalJump
		end
	end)
end

function CombatModule.SetupCharacterBlockMonitor(character)
	-- Esperar a que el Humanoid se cargue de forma segura (evita fallos al aparecer)
	local humanoid = character:WaitForChild("Humanoid", 5) or character:FindFirstChildOfClass("Humanoid")
	if not humanoid then 
		warn("[CombatModule] No se pudo inicializar el monitor de bloqueo: Humanoid no encontrado para " .. tostring(character))
		return 
	end
	if blockMonitorStateByHumanoid[humanoid] then return end

	local maxPosture = humanoid.MaxHealth * 0.7
	character:SetAttribute("MaxPosture", maxPosture)
	if not character:GetAttribute("Posture") then
		character:SetAttribute("Posture", maxPosture)
	end
	if not character:GetAttribute("LastPostureDamageTime") then
		character:SetAttribute("LastPostureDamageTime", 0)
	end

	-- Regeneration Loop
	task.spawn(function()
		while character and character.Parent and humanoid and humanoid.Health > 0 do
			task.wait(0.1)
			local now = time()
			local lastDamage = character:GetAttribute("LastPostureDamageTime") or 0
			local mPosture = character:GetAttribute("MaxPosture") or (humanoid.MaxHealth * 0.7)
			local cPosture = character:GetAttribute("Posture") or mPosture
			
			if now - lastDamage >= 3.0 and cPosture < mPosture then
				local isBlocking = character:GetAttribute("IsBlocking") == true
				local regenPercent = isBlocking and 0.05 or 0.15
				local regenAmount = mPosture * regenPercent * 0.1
				local newPosture = math.min(mPosture, cPosture + regenAmount)
				character:SetAttribute("Posture", newPosture)
			end
		end
	end)

	local state = {
		lastHealth = humanoid.Health,
		ignoreNextHealthChange = false,
	}
	blockMonitorStateByHumanoid[humanoid] = state
	
	character:GetAttributeChangedSignal("IsBlocking"):Connect(function()
		if character:GetAttribute("IsBlocking") == true then
			local now = time()
			local lastEnd = character:GetAttribute("LastBlockEndTime") or 0
			
			-- Si el tiempo desde el último bloqueo es muy corto, penalizamos el inicio del parry
			if (now - lastEnd) < 0.5 then
				-- Marcamos que este bloque no puede hacer parry
				character:SetAttribute("ParryIneligible", true)
			else
				character:SetAttribute("ParryIneligible", false)
			end
			
			character:SetAttribute("BlockStartTime", now)
		else
			character:SetAttribute("LastBlockEndTime", time())
		end
	end)

	humanoid.HealthChanged:Connect(function(newHealth)
		local currentState = blockMonitorStateByHumanoid[humanoid]
		if not currentState then return end

		if currentState.ignoreNextHealthChange then
			currentState.ignoreNextHealthChange = false
			currentState.lastHealth = newHealth
			return
		end

		local damageTaken = currentState.lastHealth - newHealth
		currentState.lastHealth = newHealth
		if damageTaken <= 0 then return end
		if not character:GetAttribute("IsBlocking") then return end

		currentState.ignoreNextHealthChange = true
		humanoid.Health = math.min(humanoid.MaxHealth, newHealth + damageTaken)

		local mPosture = character:GetAttribute("MaxPosture") or (humanoid.MaxHealth * 0.7)
		local cPosture = character:GetAttribute("Posture") or mPosture
		
		local newPosture = math.max(0, cPosture - damageTaken)
		character:SetAttribute("Posture", newPosture)
		character:SetAttribute("LastPostureDamageTime", time())
		
		CombatModule.PlayCharacterSound(character, CombatModule.CONFIG.BLOCK_HIT_SOUND_ID)

		if newPosture <= 0 then
			CombatModule.BreakGuard(character, humanoid)
		end
	end)

	humanoid.Destroying:Connect(function()
		blockMonitorStateByHumanoid[humanoid] = nil
	end)
end

function CombatModule.TagHumanoid(humanoid, player)
    local tag = humanoid:FindFirstChild("creator")
    if tag then tag:Destroy() end
    
    local newTag = Instance.new("ObjectValue")
    newTag.Name = "creator"
    newTag.Value = player
    newTag.Parent = humanoid
    game.Debris:AddItem(newTag, 2) -- La etiqueta dura 2 segundos tras el último golpe
end

function CombatModule.CreateHitbox(attackerChar, range, damage, comboStep, effectName, hitSound, isHoldingSpace)
	local hrp = attackerChar:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local overlap = OverlapParams.new()
	overlap.FilterDescendantsInstances = {attackerChar}
	overlap.FilterType = Enum.RaycastFilterType.Exclude

	local parts = workspace:GetPartBoundsInBox(
		hrp.CFrame * CFrame.new(0, 0, -range/2),
		Vector3.new(5, 6, range + 2),
		overlap
	)

	local hitHumans = {}

	for _, part in ipairs(parts) do
		local hum = CombatModule.FindHumanoid(part)
		if not hum or hitHumans[hum] then continue end

		hitHumans[hum] = true
		local victimChar = hum.Parent
		
		local tool = attackerChar:FindFirstChildOfClass("Tool")
		local isFinisher = (comboStep == 5) or (comboStep == 4 and tool and tool.Name ~= "Puños")
		
		-- SISTEMA CARRY: Respetar I-Frames si está siendo cargado
		if victimChar:GetAttribute("Invincible") == true then continue end

		-- PREDICCION DE GOLPES EN GOBLINS (Parry / Block)
		local isGoblin = victimChar.Name == "Real Goblin" or victimChar:FindFirstChild("GoblinAI") ~= nil
		local isAttackerPlayer = game:GetService("Players"):GetPlayerFromCharacter(attackerChar) ~= nil
		local isStunned = victimChar:FindFirstChild("Stun") ~= nil or victimChar:GetAttribute("CannotAttack") == true

		if isGoblin and isAttackerPlayer and not isStunned then
			local roll = math.random()
			local parryChance = CombatModule.CONFIG.GOBLIN_PARRY_CHANCE or 0.15
			local blockChance = CombatModule.CONFIG.GOBLIN_BLOCK_CHANCE or 0.25
			
			local lastParryTime = victimChar:GetAttribute("LastNPCParryTime") or 0
			local now = time()
			local canParry = (now - lastParryTime) >= 10

			if canParry and roll <= parryChance then
				-- PARRY EXITOSO POR EL GOBLIN
				victimChar:SetAttribute("LastNPCParryTime", now)
				
				local vRoot = victimChar:FindFirstChild("HumanoidRootPart") or part
				local aRoot = attackerChar:FindFirstChild("HumanoidRootPart")
				
				-- Play player's block animation and block effect for feedback
				CombatModule.PlayGoblinBlockVFX(victimChar, 0.4)
				
				-- Emit parry particles and sound
				CombatModule.EmitParryEffect(vRoot, aRoot)
				CombatModule.PlayCharacterSound(victimChar, CombatModule.CONFIG.PARRY_SOUND_ID)
				
				-- Ragdoll the player for 1.5s (Parry stun penalty)
				CombatModule.ApplyRagdoll(attackerChar, CombatModule.CONFIG.GOBLIN_PARRY_RAGDOLL_DURATION or 1.5)
				
				continue
			elseif roll <= (canParry and (parryChance + blockChance) or blockChance) then
				-- BLOCK EXITOSO POR EL GOBLIN
				
				-- Play player's block animation and block effect for feedback
				CombatModule.PlayGoblinBlockVFX(victimChar, 0.5)
				
				-- Play block hit sound
				CombatModule.PlayCharacterSound(victimChar, CombatModule.CONFIG.BLOCK_HIT_SOUND_ID)
				
				continue
			end
		end

		local isBlocking = victimChar:GetAttribute("IsBlocking") == true
		local blockTime = victimChar:GetAttribute("BlockStartTime") or 0
		local isParryIneligible = victimChar:GetAttribute("ParryIneligible") == true
		local now = time()

		-- DEBUG PARRY (Imprime información en la consola de salida de Roblox Studio para diagnosticar)
		local lastParrySuccess = victimChar:GetAttribute("LastParrySuccess") or 0
		local timeDiff = now - blockTime
		local cooldownDiff = now - lastParrySuccess

		-- PARRY
		if isBlocking and not isParryIneligible and timeDiff <= CombatModule.CONFIG.PARRY_WINDOW and cooldownDiff >= CombatModule.CONFIG.PARRY_COOLDOWN then
			victimChar:SetAttribute("LastParrySuccess", now)
			local attackerHum = attackerChar:FindFirstChild("Humanoid")
			if attackerHum then
				CombatModule.ApplyParryStun(attackerHum)
			end
			local vRoot = victimChar:FindFirstChild("HumanoidRootPart") or part
			local aRoot = attackerChar:FindFirstChild("HumanoidRootPart")
			CombatModule.EmitParryEffect(vRoot, aRoot)
			CombatModule.PlayCharacterSound(victimChar, CombatModule.CONFIG.PARRY_SOUND_ID)
			continue
		end

		-- BLOQUEO
		if isBlocking then
			local maxPosture = victimChar:GetAttribute("MaxPosture") or (hum.MaxHealth * 0.7)
			local currentPosture = victimChar:GetAttribute("Posture") or maxPosture
			
			local newPosture = math.max(0, currentPosture - damage)
			victimChar:SetAttribute("Posture", newPosture)
			victimChar:SetAttribute("LastPostureDamageTime", time())
			
			CombatModule.PlayCharacterSound(victimChar, CombatModule.CONFIG.BLOCK_HIT_SOUND_ID)

			if newPosture <= 0 then
				CombatModule.BreakGuard(victimChar, hum)
				hum:TakeDamage(damage)
				CombatModule.ApplyHitSlow(hum)
				if isFinisher then
					task.delay(0.05, function()
						CombatModule.ApplyKnockback(attackerChar, victimChar, CombatModule.CONFIG.COMBO_FINISHER_KNOCKBACK)
						local playerVictim = game:GetService("Players"):GetPlayerFromCharacter(victimChar)
						if playerVictim then
							CombatModule.ApplyRagdoll(victimChar, CombatModule.CONFIG.COMBO_FINISHER_RAGDOLL_DURATION)
						end
					end)
				end
			end
			continue
		end

		-- DAÑO NORMAL
		hum:TakeDamage(damage)

		-- Golpe aéreo de Puños (4º golpe combo aéreo)
		if comboStep == 4 and tool and tool.Name == "Puños" and isHoldingSpace then
			local vHum = victimChar:FindFirstChildOfClass("Humanoid")
			local aHum = attackerChar:FindFirstChildOfClass("Humanoid")
			
			if vHum then
				vHum:ChangeState(Enum.HumanoidStateType.Freefall)
			end
			if aHum then
				aHum:ChangeState(Enum.HumanoidStateType.Freefall)
			end

			-- Lanzar a la víctima hacia arriba (Launcher!)
			local vRoot = victimChar:FindFirstChild("HumanoidRootPart")
			if vRoot then
				vRoot.AssemblyLinearVelocity = Vector3.new(vRoot.AssemblyLinearVelocity.X, 70, vRoot.AssemblyLinearVelocity.Z)
			end
			
			-- Lanzar al atacante hacia arriba coordinadamente (Estilo Uppercut de Deepwoken)
			local aRoot = attackerChar:FindFirstChild("HumanoidRootPart")
			if aRoot then
				aRoot.AssemblyLinearVelocity = Vector3.new(aRoot.AssemblyLinearVelocity.X, 65, aRoot.AssemblyLinearVelocity.Z)
			end
			
			CombatModule.ApplyHitSlow(hum)
			CombatModule.PlayCharacterSound(victimChar, hitSound or CombatModule.CONFIG.NORMAL_HIT_SOUND_ID)
			CombatModule.PlayHitEffect(victimChar, "Golpe")
			CombatModule.PlayHitAnimation(hum)
			
			local attackerPlayer = game:GetService("Players"):GetPlayerFromCharacter(attackerChar)
			if attackerPlayer then
				CombatModule.TagHumanoid(hum, attackerPlayer)
			end
			continue
		end

		-- BRAZO ROTO: si el atacante tiene brazo roto, recibe autodaño al golpear
		local attackerPlayer = game:GetService("Players"):GetPlayerFromCharacter(attackerChar)
		if attackerPlayer and CondicionesModule.HasCondicion(attackerPlayer, "brazoroto") then
			local attackerHum = attackerChar:FindFirstChild("Humanoid")
			if attackerHum and attackerHum.Health > 0 then
				attackerHum:TakeDamage(damage * 0.35) -- 35% del daño vuelve al atacante
			end
		end
        if attackerPlayer then
            CombatModule.TagHumanoid(hum, attackerPlayer)
            
            -- Otorgar experiencia de Armas si usa un arma
            if tool and tool.Name ~= "Puños" and tool.Name ~= "Martillo" and tool.Name ~= "Caña" then
                local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)
                LoreModule.AddMasteryXP(attackerPlayer, "Armas", 1)
            end
            
            -- Descontar durabilidad del arma al asestar un golpe
            if tool and tool.Name ~= "Puños" and tool.Name ~= "StrongRight" then
                local maxD = tool:GetAttribute("MaxDurability") or 100
                local currentD = tool:GetAttribute("Durability") or maxD
                
                if not tool:GetAttribute("MaxDurability") then
                    tool:SetAttribute("MaxDurability", 100)
                    tool:SetAttribute("Durability", 100)
                    maxD = 100
                    currentD = 100
                end
                
                if currentD > 0 then
                    local newD = math.max(0, currentD - 1)
                    tool:SetAttribute("Durability", newD)
                    
                    if newD == 0 then
                        -- ¡El arma se ha roto!
                        CombatModule.PlayCharacterSound(attackerChar, "rbxassetid://9116728377")
                        
                        local NarrateEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
                        if NarrateEvent then
                            NarrateEvent:FireClient(attackerPlayer, string.format("*¡Mi **[%s]** se ha roto por completo!*", tool.Name), true, 4, 1.5)
                        end
                        
                        local humanoid = attackerChar:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            humanoid:UnequipTools()
                        end
                        task.delay(0.2, function()
                            if tool and tool.Parent then
                                tool:Destroy()
                            end
                        end)
                    end
                end
            end
        end
        
		CombatModule.ApplyHitSlow(hum)
		CombatModule.PlayCharacterSound(victimChar, hitSound or CombatModule.CONFIG.NORMAL_HIT_SOUND_ID)
		CombatModule.PlayHitEffect(victimChar, effectName)
		CombatModule.PlayHitAnimation(hum)
		
		if isFinisher then
			task.delay(0.05, function()
				CombatModule.ApplyKnockback(attackerChar, victimChar, CombatModule.CONFIG.COMBO_FINISHER_KNOCKBACK)
				local playerVictim = game:GetService("Players"):GetPlayerFromCharacter(victimChar)
				if playerVictim then
					CombatModule.ApplyRagdoll(victimChar, CombatModule.CONFIG.COMBO_FINISHER_RAGDOLL_DURATION)
				end
			end)
		end

		-- Sistema de Heridas Aleatorias
		local victimPlayer = game:GetService("Players"):GetPlayerFromCharacter(victimChar)
		if victimPlayer then
			local attackerName = "Default"
			if attackerPlayer then
				local tool = attackerChar:FindFirstChildOfClass("Tool")
				if tool then
					attackerName = tool.Name
				else
					attackerName = "Puños"
				end
			else
				attackerName = attackerChar.Name
			end
			AdvancedInjuryModule.RollForInjury(victimPlayer, attackerName)
		end
	end
end

function CombatModule.ApplyRagdoll(character, duration)
	local isRagdoll = character:FindFirstChild("IsRagdoll")
	if isRagdoll then
		isRagdoll.Value = true
		task.delay(duration, function()
			if isRagdoll and isRagdoll.Parent then
				isRagdoll.Value = false
			end
		end)
	else
		-- Fallback directo si no tiene el BoolValue (ej. algunos NPCs)
		RagdollModule.SetRagdoll(character, true)
		task.delay(duration, function()
			if character and character.Parent then
				RagdollModule.SetRagdoll(character, false)
			end
		end)
	end
end

function CombatModule.CreateStrongRightHitbox(attackerChar, damage)
	local hrp = attackerChar:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local range = 6
	local overlap = OverlapParams.new()
	overlap.FilterDescendantsInstances = {attackerChar}
	overlap.FilterType = Enum.RaycastFilterType.Exclude

	local parts = workspace:GetPartBoundsInBox(
		hrp.CFrame * CFrame.new(0, 0, -range/2),
		Vector3.new(6, 6, range + 2),
		overlap
	)

	local hitHumans = {}
	local hitAny = false

	for _, part in ipairs(parts) do
		local hum = CombatModule.FindHumanoid(part)
		if not hum or hitHumans[hum] then continue end
		hitHumans[hum] = true
		hitAny = true
		local victimChar = hum.Parent
		
		-- SISTEMA CARRY: Respetar I-Frames si está siendo cargado
		if victimChar:GetAttribute("Invincible") == true then continue end
		
		-- Daño y Ragdoll
		hum:TakeDamage(damage)
		CombatModule.ApplyHitSlow(hum)
		
		-- Efecto de sonido de golpe
		CombatModule.PlayCharacterSound(victimChar, CombatModule.CONFIG.STRONG_RIGHT_SOUND)
		
		-- VFX (Clonar desde Workspace.StrongRight)
		local vfxTemplate = workspace:FindFirstChild("StrongRight")
		if vfxTemplate then
			local mainAttach = vfxTemplate:FindFirstChild("Main")
			if mainAttach then
				local clone = mainAttach:Clone()
				clone.Parent = victimChar:FindFirstChild("HumanoidRootPart") or part
				for _, emitter in ipairs(clone:GetChildren()) do
					if emitter:IsA("ParticleEmitter") then
						emitter.Enabled = false
						emitter:Emit(25)
					end
				end
				game.Debris:AddItem(clone, 1)
			end
		end

		-- Ragdoll inmediato
		CombatModule.ApplyRagdoll(victimChar, 3)
		
		-- Knockback fuerte
		CombatModule.ApplyKnockback(attackerChar, victimChar, 60)
		
		-- Sistema de Heridas Aleatorias
		local victimPlayer = game:GetService("Players"):GetPlayerFromCharacter(victimChar)
		if victimPlayer then
			AdvancedInjuryModule.RollForInjury(victimPlayer, "StrongRight")
		end
	end
	
	return hitAny
end

local function setToolVisible(tool, visible)
	for _, part in ipairs(tool:GetDescendants()) do
		if part:IsA("BasePart") then
			if not visible then
				if not part:GetAttribute("OriginalTransparency") then
					part:SetAttribute("OriginalTransparency", part.Transparency)
				end
				part.Transparency = 1
			else
				local orig = part:GetAttribute("OriginalTransparency") or 0
				part.Transparency = orig
			end
		end
	end
end

function CombatModule.ThrowShield(player, character, tool)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Evitar lanzamientos concurrentes
	if character:GetAttribute("ShieldThrown") then return end
	character:SetAttribute("ShieldThrown", true)
	character:SetAttribute(CombatModule.CONFIG.CANNOT_ATTACK_ATTR, true)

	-- Clonar las partes visuales del escudo (el Handle) ANTES de hacerlo invisible
	local model = Instance.new("Model")
	model.Name = "ShieldBoomerang"
	
	local clone = tool.Handle:Clone()
	clone.Parent = model
	model.PrimaryPart = clone

	-- Guardar y ocultar el escudo original
	setToolVisible(tool, false)

	-- Parámetros del proyectil
	local speed = 65 -- studs por segundo
	local maxDistance = 45 -- studs
	local damage = tool:GetAttribute("HeavyDamage") or 30
	local relicDamage = player:GetAttribute("RelicDamageBuff") or 0
	damage = damage + relicDamage
	
	local hitEffect = tool:GetAttribute("HitEffect") or "Golpe"
	local hitSound = tool:GetAttribute("HitSound") or CombatModule.CONFIG.NORMAL_HIT_SOUND_ID

	-- Configurar físicas del proyectil
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	
	-- Colocar en posición inicial ligeramente en frente
	local p0 = hrp.Position
	local dir = hrp.CFrame.LookVector
	local targetPos = p0 + dir * maxDistance
	
	model:PivotTo(hrp.CFrame * CFrame.new(0, 0, -2))
	model.Parent = workspace

	local hitList = {}
	local returning = false
	local active = true
	local rotationY = 0

	-- Bucle de simulación del trayecto
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
		if not active then return end
		
		-- Limpieza de seguridad si el personaje o herramienta desaparece
		if not character or not character.Parent or not hrp or not hrp.Parent or not tool or not tool.Parent then
			active = false
			model:Destroy()
			connection:Disconnect()
			return
		end

		-- Rotación continua del escudo sobre el eje Y
		rotationY = rotationY + math.rad(900 * dt) -- 900 grados por segundo (giro rápido)

		local currentPos = model:GetPivot().Position
		local dest = returning and hrp.Position or targetPos
		local moveDir = (dest - currentPos)
		local dist = moveDir.Magnitude

		-- Si está lo suficientemente cerca del destino, cambiar fase o terminar
		local stepDist = speed * dt
		if returning then
			-- En la fase de retorno, si el jugador corre rápido, aumentamos la velocidad para alcanzarlo
			stepDist = math.max(stepDist, (hrp.AssemblyLinearVelocity.Magnitude + 10) * dt)
		end

		if dist < stepDist then
			if not returning then
				returning = true
				-- Limpiar lista de golpes al dar la vuelta para poder golpear de regreso
				table.clear(hitList)
			else
				active = false
				model:Destroy()
				connection:Disconnect()

				-- Restaurar visibilidad y control
				setToolVisible(tool, true)
				character:SetAttribute("ShieldThrown", nil)
				character:SetAttribute(CombatModule.CONFIG.CANNOT_ATTACK_ATTR, false)
				return
			end
		else
			local nextPos = currentPos + moveDir.Unit * stepDist
			local lookCF = CFrame.lookAt(nextPos, nextPos + moveDir.Unit)
			model:PivotTo(lookCF * CFrame.Angles(rotationY, 0, 0))
		end

		-- Detección de colisiones
		local overlap = OverlapParams.new()
		overlap.FilterDescendantsInstances = {character, model}
		overlap.FilterType = Enum.RaycastFilterType.Exclude

		local hitParts = workspace:GetPartBoundsInRadius(model:GetPivot().Position, 4.5, overlap)
		for _, part in ipairs(hitParts) do
			local hum = CombatModule.FindHumanoid(part)
			if hum and hum.Health > 0 and not hitList[hum] then
				hitList[hum] = true
				local victimChar = hum.Parent
				
				-- Aplicar daño e impacto
				hum:TakeDamage(damage)
				CombatModule.ApplyHitSlow(hum)
				CombatModule.PlayCharacterSound(victimChar, hitSound)
				CombatModule.PlayHitEffect(victimChar, hitEffect)
				CombatModule.PlayHitAnimation(hum)
				
				-- Knockback
				CombatModule.ApplyKnockback(character, victimChar, 25)

				-- Taggear creador
				CombatModule.TagHumanoid(hum, player)

				-- Otorgar experiencia de Armas
				local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)
				LoreModule.AddMasteryXP(player, "Armas", 2)
				
				-- Descontar durabilidad del escudo (como si fuera un golpe)
				local maxD = tool:GetAttribute("MaxDurability") or 300
				local currentD = tool:GetAttribute("Durability") or maxD
				if currentD > 0 then
					local newD = math.max(0, currentD - 1)
					tool:SetAttribute("Durability", newD)
					if newD == 0 then
						-- Se rompió en pleno lanzamiento
						CombatModule.PlayCharacterSound(character, "rbxassetid://9116728377")
						local NarrateEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
						if NarrateEvent then
							NarrateEvent:FireClient(player, "*¡Mi **[Escudo]** se ha roto en el aire!*", true, 4, 1.5)
						end
						local humPlayer = character:FindFirstChildOfClass("Humanoid")
						if humPlayer then
							humPlayer:UnequipTools()
						end
						task.delay(0.1, function()
							if tool and tool.Parent then
								tool:Destroy()
							end
						end)
					end
				end
			end
		end
	end)

	-- Timeout de seguridad tras 4 segundos
	task.delay(4, function()
		if active then
			active = false
			pcall(function() model:Destroy() end)
			pcall(function() connection:Disconnect() end)
			pcall(function() 
				if tool and tool.Parent then
					setToolVisible(tool, true)
				end
			end)
			pcall(function() character:SetAttribute("ShieldThrown", nil) end)
			pcall(function() character:SetAttribute(CombatModule.CONFIG.CANNOT_ATTACK_ATTR, false) end)
		end
	end)
end

return CombatModule
