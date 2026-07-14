local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local MagicConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MagicConfig"))
local CombatModule = require(game.ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatModule"))

local Events = ReplicatedStorage:WaitForChild("Events")
local MagicEvent = Events:WaitForChild("MagicEvent")
local ReplicateFloatingBookEvent = Events:FindFirstChild("ReplicateFloatingBookEvent")
if not ReplicateFloatingBookEvent then
	ReplicateFloatingBookEvent = Instance.new("RemoteEvent")
	ReplicateFloatingBookEvent.Name = "ReplicateFloatingBookEvent"
	ReplicateFloatingBookEvent.Parent = Events
end

local cooldowns = {} -- playerUserId -> spellName -> nextCastTime

-- Utility to check if character is stunned or can't attack
local function canCast(player, char)
	local humanoid = char:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then 
		return false 
	end
	if char:GetAttribute("CannotAttack") == true then
		return false
	end
	
	local stunVal = char:FindFirstChild("Stun")
	if stunVal then
		local isStunned = false
		if stunVal:IsA("BoolValue") then
			isStunned = (stunVal.Value == true)
		else
			isStunned = true
		end
		if isStunned then
			return false
		end
	end
	
	return true
end

-- Function to play cast sound and replication
local function playCastEffects(char, config)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	-- Sound
	local soundId = config.ChargeSoundId or config.SoundId
	if soundId then
		local s = Instance.new("Sound")
		s.SoundId = soundId
		s.Volume = 1.5
		s.RollOffMaxDistance = 150
		s.RollOffMinDistance = 10
		s.Parent = root
		s:Play()
		Debris:AddItem(s, 3)
	end
	
	-- Anim
	local humanoid = char:FindFirstChild("Humanoid")
	if humanoid and config.AnimationId then
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local anim = Instance.new("Animation")
		anim.AnimationId = config.AnimationId
		local track = nil
		local success, err = pcall(function()
			track = animator:LoadAnimation(anim)
			if track then
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = false
				track:Play()
			end
		end)
		if success then
			return track
		end
	end
end

-- Forward declaration of handleImpact
local handleImpact

-- Helper to scale a NumberSequence
local function scaleNumberSequence(sequence, scale)
	local keypoints = sequence.Keypoints
	local newKeypoints = {}
	for _, kp in ipairs(keypoints) do
		table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, kp.Value * scale, kp.Envelope * scale))
	end
	return NumberSequence.new(newKeypoints)
end

-- Spawn and simulate projectile
local function spawnProjectile(casterPlayer, char, targetPos, config)
	local adjustedColor = MagicConfig.GetAdjustedColor(casterPlayer)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local startPos = hrp.Position + hrp.CFrame.LookVector * 3
	local direction = (targetPos - startPos).Unit
	if direction.Magnitude < 0.1 then
		direction = hrp.CFrame.LookVector
	end
	
	-- Create physical projectile
	local projectile
	if config.Name == "Hielo_LanzaDeHielo" then
		local originalLanza = workspace:FindFirstChild("LanzaHielo")
		if originalLanza and originalLanza:IsA("MeshPart") then
			projectile = originalLanza:Clone()
		else
			projectile = Instance.new("MeshPart")
			projectile.MeshId = "rbxassetid://8865000365"
			projectile.Material = Enum.Material.Ice
		end
		projectile.Color = adjustedColor
		projectile.Size = config.Size or Vector3.new(0.397, 0.245, 9.0)
		projectile.CFrame = CFrame.lookAt(startPos, startPos + direction) * CFrame.Angles(0, math.rad(-90), 0)
	else
		projectile = Instance.new("Part")
		projectile.Shape = Enum.PartType.Ball
		projectile.Size = config.Size or Vector3.new(2, 2, 2)
		projectile.Color = adjustedColor
		projectile.Material = Enum.Material.Neon
		projectile.CFrame = CFrame.new(startPos, startPos + direction)
	end
	
	projectile.Name = config.Name .. "_Projectile"
	projectile.CanCollide = false
	projectile.CanTouch = false
	projectile.CanQuery = false
	projectile.Anchored = true
	projectile.Parent = workspace
	
	-- Light source
	local light = Instance.new("PointLight")
	light.Color = adjustedColor
	light.Brightness = 2.5
	light.Range = 12
	light.Parent = projectile
	
	-- Effect setup
	if config.Name == "Hielo_LanzaDeHielo" then
		-- Trail for ice lance (beam trail)
		local att0 = Instance.new("Attachment")
		att0.Name = "Attachment0"
		att0.Position = Vector3.new(4.5, 0, 0)
		att0.Parent = projectile
		
		local att1 = Instance.new("Attachment")
		att1.Name = "Attachment1"
		att1.Position = Vector3.new(-4.5, 0, 0)
		att1.Parent = projectile
		
		local trail = Instance.new("Trail")
		trail.Attachment0 = att0
		trail.Attachment1 = att1
		trail.Color = ColorSequence.new(adjustedColor, adjustedColor:Lerp(Color3.new(0, 0, 0), 0.75))
		trail.Transparency = NumberSequence.new(0.1, 1.0)
		trail.WidthScale = NumberSequence.new(1.0, 0.1)
		trail.Lifetime = 0.6
		trail.FaceCamera = true
		trail.LightEmission = 1.0
		trail.LightInfluence = 0.0
		trail.Parent = projectile
	else
		-- Particles: Clone from Fuego VFX template in ReplicatedStorage
		local fuegoTemplate = ReplicatedStorage:FindFirstChild("LTVFX") and ReplicatedStorage.LTVFX:FindFirstChild("Fuego")
		if fuegoTemplate then
			local att = fuegoTemplate:FindFirstChild("VFX_Attachment")
			if att then
				local cloneAtt = att:Clone()
				cloneAtt.Name = "Attachment"
				cloneAtt.Parent = projectile
				for _, child in ipairs(cloneAtt:GetChildren()) do
					if child:IsA("ParticleEmitter") then
						child.Enabled = true
						child.Size = scaleNumberSequence(child.Size, 0.5)
						child.Color = ColorSequence.new(adjustedColor, adjustedColor:Lerp(Color3.new(1, 1, 1), 0.5))
					end
				end
			end
		end
	end
	
	-- Simulate CFrame loop with Raycast
	local speed = config.Speed
	local lifetime = config.Lifetime
	local startTime = os.clock()
	
	task.spawn(function()
		local currentPos = startPos
		local velocity = direction * speed
		
		while os.clock() - startTime < lifetime and projectile.Parent do
			local dt = RunService.Heartbeat:Wait()
			if not projectile.Parent then break end
			
			local nextPos = currentPos + velocity * dt
			
			-- Raycast
			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = {char, projectile}
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			
			local result = workspace:Raycast(currentPos, nextPos - currentPos, raycastParams)
			if result then
				projectile.Position = result.Position
				handleImpact(casterPlayer, char, result.Position, result.Instance, config)
				break
			end
			
			if config.Name == "Hielo_LanzaDeHielo" then
				projectile.CFrame = CFrame.lookAt(currentPos, nextPos) * CFrame.Angles(0, math.rad(-90), 0)
			else
				projectile.Position = nextPos
			end
			currentPos = nextPos
		end
		
		if projectile.Parent then
			projectile:Destroy()
		end
	end)
end

-- Spawn and simulate Earth Fissure shockwave
local function spawnEarthFissure(casterPlayer, char, targetPos, config)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local casterPos = hrp.Position
	local lookDir = (targetPos - casterPos).Unit
	if lookDir.Magnitude < 0.1 then
		lookDir = hrp.CFrame.LookVector
	end
	lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
	local rightDir = Vector3.new(-lookDir.Z, 0, lookDir.X)
	
	local hitTargets = {} -- Track hit targets per cast to avoid double damage
	
	-- Cone / Triangle pattern (4 rows)
	local rowSpacing = 8
	local stoneSpacing = 6
	local dustTemplate = ReplicatedStorage:FindFirstChild("Fx") and ReplicatedStorage.Fx:FindFirstChild("Dust")
	
	-- Build ignore list ONCE for the entire cast to prevent lag
	local ignoreList = {char}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignoreList, player.Character)
		end
	end
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("Humanoid") then
			local parentModel = desc.Parent
			if parentModel and parentModel:IsA("Model") then
				table.insert(ignoreList, parentModel)
			end
		elseif desc.Name == "EarthFissureStone" then
			table.insert(ignoreList, desc)
		end
	end
	local originalPiedra = workspace:FindFirstChild("Piedra")
	if originalPiedra then
		table.insert(ignoreList, originalPiedra)
	end
	
	task.spawn(function()
		for r = 1, 4 do
			local rowDist = r * rowSpacing
			local numStones = r
			
			for i = 1, numStones do
				local offset = (i - (numStones + 1)/2) * stoneSpacing
				local spawnPos = casterPos + lookDir * rowDist + rightDir * offset
				
				local raycastParams = RaycastParams.new()
				raycastParams.FilterDescendantsInstances = ignoreList
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				
				local result = workspace:Raycast(spawnPos + Vector3.new(0, 10, 0), Vector3.new(0, -25, 0), raycastParams)
				local groundY = result and result.Position.Y or (casterPos.Y - 3)
				
				-- Spawn stone
				local stone
				if originalPiedra and originalPiedra:IsA("UnionOperation") then
					stone = originalPiedra:Clone()
				else
					stone = Instance.new("Part")
					stone.Material = Enum.Material.Slate
					stone.Color = Color3.fromRGB(100, 95, 98)
				end
				stone.Name = "EarthFissureStone"
				stone.Size = Vector3.new(8, 4, 8)
				stone.Anchored = true
				stone.CanCollide = false
				stone.CanTouch = false
				stone.CanQuery = false
				stone.Position = Vector3.new(spawnPos.X, groundY - 4, spawnPos.Z)
				stone.Rotation = Vector3.new(math.random(-15, 15), math.random(0, 360), math.random(-15, 15)) -- natural look
				
				-- Add custom magic glow light to Earth stone
				local adjustedColor = MagicConfig.GetAdjustedColor(casterPlayer)
				local glow = Instance.new("PointLight")
				glow.Color = adjustedColor
				glow.Range = 10
				glow.Brightness = 2.5
				glow.Parent = stone
				
				stone.Parent = workspace
				
				-- Add spawned stone to the ignore list to avoid hitting it on subsequent raycasts
				table.insert(ignoreList, stone)
				
				-- Spawn Dust Particles
				if dustTemplate then
					local dustClone = dustTemplate:Clone()
					dustClone.Position = Vector3.new(spawnPos.X, groundY, spawnPos.Z)
					dustClone.Parent = workspace
					local att = dustClone:FindFirstChild("Attachment")
					local emitter = att and att:FindFirstChild("Dust")
					if emitter then
						emitter:Emit(15)
					end
					Debris:AddItem(dustClone, 2.0)
				end
				
				-- Animate rise and fall
				task.spawn(function()
					local startY = groundY - 4
					local endY = groundY - 0.2
					local duration = 0.2
					local elapsed = 0
					
					while elapsed < duration and stone.Parent do
						local dt = RunService.Heartbeat:Wait()
						elapsed = elapsed + dt
						local t = math.min(1, elapsed / duration)
						local ease = 1 - math.pow(1 - t, 3) -- Ease out cubic
						stone.Position = Vector3.new(spawnPos.X, startY + (endY - startY) * ease, spawnPos.Z)
					end
					if stone.Parent then
						stone.Position = Vector3.new(spawnPos.X, endY, spawnPos.Z)
					end
					
					-- Check for hit targets immediately upon rise
					local overlap = OverlapParams.new()
					overlap.FilterDescendantsInstances = {char}
					overlap.FilterType = Enum.RaycastFilterType.Exclude
					
					local parts = workspace:GetPartBoundsInRadius(Vector3.new(spawnPos.X, groundY, spawnPos.Z), config.HitRadius or 5, overlap)
					for _, part in ipairs(parts) do
						local hum = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
						if hum and hum.Health > 0 and not hitTargets[hum] and hum.Parent ~= char then
							local tChar = hum.Parent
							if tChar:GetAttribute("Invincible") ~= true then
								hitTargets[hum] = true
								
								-- Damage & Slow & Ragdoll
								CombatModule.TagHumanoid(hum, casterPlayer)
								hum:TakeDamage(config.Damage)
								CombatModule.ApplyStun(hum, 2.5, 6) -- 2.5 seconds slow, WalkSpeed = 6
								CombatModule.ApplyRagdoll(tChar, 2)
								
								-- Sound impact
								CombatModule.PlayCharacterSound(tChar, CombatModule.CONFIG.NORMAL_HIT_SOUND_ID)
								
								-- Injury roll
								local victimPlayer = Players:GetPlayerFromCharacter(tChar)
								if victimPlayer then
									pcall(function()
										local AdvancedInjuryModule = require(game.ServerScriptService.ServerModules.AdvancedInjuryModule)
										AdvancedInjuryModule.RollForInjury(victimPlayer, "FisuraDeTierra")
									end)
								end
							end
						end
					end
					
					-- Wait before sinking
					task.wait(4.0)
					
					-- Sink back down
					elapsed = 0
					while elapsed < duration and stone.Parent do
						local dt = RunService.Heartbeat:Wait()
						elapsed = elapsed + dt
						local t = math.min(1, elapsed / duration)
						local ease = math.pow(t, 3) -- Ease in cubic
						stone.Position = Vector3.new(spawnPos.X, endY + (startY - endY) * ease, spawnPos.Z)
					end
					if stone.Parent then
						stone:Destroy()
					end
				end)
			end
			
			-- Wait a short delay before next row expands outwards
			task.wait(0.08)
		end
	end)
end

-- Helper to freeze a character's parts and pause animations
local function freezeCharacter(character, duration)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	
	-- Pause all active animations
	local pausedTracks = {}
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			table.insert(pausedTracks, {
				track = track,
				speed = track.Speed
			})
			track:AdjustSpeed(0)
		end
	end
	
	-- Prevent new animations from starting
	local animationPlayedConn
	if animator then
		animationPlayedConn = animator.AnimationPlayed:Connect(function(track)
			track:AdjustSpeed(0)
		end)
	end

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			if not part:GetAttribute("OriginalMaterial") then
				part:SetAttribute("OriginalMaterial", part.Material.Name)
			end
			if not part:GetAttribute("OriginalColor") then
				part:SetAttribute("OriginalColor", part.Color)
			end
			
			part.Material = Enum.Material.Ice
			part.Color = Color3.fromRGB(150, 220, 255)
		end
	end
	
	task.delay(duration, function()
		if animationPlayedConn then
			animationPlayedConn:Disconnect()
		end
		
		if not character or not character.Parent then return end
		
		-- Resume animations
		for _, info in ipairs(pausedTracks) do
			if info.track and info.track.Parent then
				info.track:AdjustSpeed(info.speed or 1)
			end
		end
		
		-- Restore parts properties
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				local origMatName = part:GetAttribute("OriginalMaterial")
				local origColor = part:GetAttribute("OriginalColor")
				
				if origMatName then
					local mat = Enum.Material[origMatName]
					if mat then
						part.Material = mat
					end
					part:SetAttribute("OriginalMaterial", nil)
				end
				
				if origColor then
					part.Color = origColor
					part:SetAttribute("OriginalColor", nil)
				end
			end
		end
	end)
end

-- Handle Impact (AoE & damage & VFX)
function handleImpact(casterPlayer, casterChar, position, hitInstance, config)
	local adjustedColor = MagicConfig.GetAdjustedColor(casterPlayer)
	if config.Name == "Hielo_LanzaDeHielo" then
		-- Spawn "Congelado" particle effect with a slight delay
		task.delay(0.1, function()
			local congeladoTemplate = workspace:FindFirstChild("Congelado")
			if congeladoTemplate then
				local congeladoPart = congeladoTemplate:Clone()
				congeladoPart.CFrame = CFrame.new(position)
				congeladoPart.Transparency = 1
				congeladoPart.CanCollide = false
				congeladoPart.CanTouch = false
				congeladoPart.CanQuery = false
				congeladoPart.Anchored = true
				congeladoPart.Parent = workspace
				
				local att = congeladoPart:FindFirstChild("Attachment")
				if att then
					for _, emitter in ipairs(att:GetChildren()) do
						if emitter:IsA("ParticleEmitter") then
							emitter.Enabled = true
							emitter.Color = ColorSequence.new(adjustedColor, adjustedColor:Lerp(Color3.new(1, 1, 1), 0.5))
							emitter:Emit(emitter:GetAttribute("EmitCount") or 30)
						end
					end
				end
				
				-- Ice freeze sound
				local s = Instance.new("Sound")
				s.SoundId = "rbxassetid://123722087623254"
				s.Volume = 2
				s.RollOffMaxDistance = 150
				s.RollOffMinDistance = 10
				s.Parent = congeladoPart
				s:Play()
				
				task.spawn(function()
					task.wait(1.5)
					if att then
						for _, emitter in ipairs(att:GetChildren()) do
							if emitter:IsA("ParticleEmitter") then
								emitter.Enabled = false
							end
						end
					end
					task.wait(2.0)
					congeladoPart:Destroy()
				end)
			end
		end)
	else
		-- Create visual explosion
		local explosionTemplate = ReplicatedStorage:FindFirstChild("LTVFX") and ReplicatedStorage.LTVFX:FindFirstChild("Explosion")
		if explosionTemplate then
			local expPart = explosionTemplate:Clone()
			expPart.CFrame = CFrame.new(position)
			expPart.Transparency = 1
			expPart.CanCollide = false
			expPart.CanTouch = false
			expPart.CanQuery = false
			expPart.Anchored = true
			expPart.Parent = workspace
			
			local att = expPart:FindFirstChild("VFX_Attachment")
			if att then
				for _, child in ipairs(att:GetChildren()) do
					if child:IsA("ParticleEmitter") then
						child.Enabled = true
						child.Size = scaleNumberSequence(child.Size, 0.4)
						child.Color = ColorSequence.new(adjustedColor, adjustedColor:Lerp(Color3.new(1, 1, 1), 0.5))
					end
				end
			end
			
			-- Explosion Sound
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://139651066813230"
			s.Volume = 2
			s.RollOffMaxDistance = 200
			s.RollOffMinDistance = 10
			s.Parent = expPart
			s:Play()
			
			-- Fade & destroy
			task.spawn(function()
				task.wait(1.0)
				if att then
					for _, child in ipairs(att:GetChildren()) do
						if child:IsA("ParticleEmitter") then
							child.Enabled = false
						end
					end
				end
				task.wait(2.0)
				expPart:Destroy()
			end)
		end
	end
	
	-- Deal damage
	-- 1. Direct hit check
	local hitChar = hitInstance.Parent
	local hitHumanoid = nil
	if hitChar then
		hitHumanoid = hitChar:FindFirstChildOfClass("Humanoid") or (hitChar.Parent and hitChar.Parent:FindFirstChildOfClass("Humanoid"))
	end
	
	local hitTargets = {} -- Track hit humanoids to avoid double hits
	
	if hitHumanoid and hitHumanoid.Health > 0 and hitHumanoid.Parent ~= casterChar then
		local targetChar = hitHumanoid.Parent
		if targetChar:GetAttribute("Invincible") ~= true then
			hitTargets[hitHumanoid] = true
			
			-- Tag & Damage
			CombatModule.TagHumanoid(hitHumanoid, casterPlayer)
			hitHumanoid:TakeDamage(config.Damage)
			
			if config.Name == "Hielo_LanzaDeHielo" then
				CombatModule.ApplyStun(hitHumanoid, 4, 0)
				task.delay(0.1, function()
					freezeCharacter(targetChar, 4)
				end)
			else
				CombatModule.ApplyHitSlow(hitHumanoid)
				if config.Name == "Fuego_BolaDeFuego" then
					CombatModule.ApplyRagdoll(targetChar, 2)
				end
			end
			
			-- Sound impact
			CombatModule.PlayCharacterSound(targetChar, CombatModule.CONFIG.NORMAL_HIT_SOUND_ID)
			
			-- Injury roll if player
			local victimPlayer = Players:GetPlayerFromCharacter(targetChar)
			if victimPlayer then
				pcall(function()
					local AdvancedInjuryModule = require(game.ServerScriptService.ServerModules.AdvancedInjuryModule)
					AdvancedInjuryModule.RollForInjury(victimPlayer, config.Name == "Hielo_LanzaDeHielo" and "LanzaDeHielo" or "BolaDeFuego")
				end)
			end
		end
	end
	
	-- 2. Small Splash Hitbox (within HitRadius)
	local hitRadius = config.HitRadius or 5
	local overlap = OverlapParams.new()
	overlap.FilterDescendantsInstances = {casterChar}
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	
	local parts = workspace:GetPartBoundsInRadius(position, hitRadius, overlap)
	for _, part in ipairs(parts) do
		local hum = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and not hitTargets[hum] and hum.Parent ~= casterChar then
			local tChar = hum.Parent
			if tChar:GetAttribute("Invincible") ~= true then
				hitTargets[hum] = true
				
				-- Splash damage is 50%
				CombatModule.TagHumanoid(hum, casterPlayer)
				hum:TakeDamage(config.Damage * 0.5)
				
				if config.Name == "Hielo_LanzaDeHielo" then
					CombatModule.ApplyStun(hum, 4, 0)
					task.delay(0.1, function()
						freezeCharacter(tChar, 4)
					end)
				else
					CombatModule.ApplyHitSlow(hum)
					if config.Name == "Fuego_BolaDeFuego" then
						CombatModule.ApplyRagdoll(tChar, 2)
					end
				end
				
				-- Injury roll for splash victims
				local victimPlayer = Players:GetPlayerFromCharacter(tChar)
				if victimPlayer then
					pcall(function()
						local AdvancedInjuryModule = require(game.ServerScriptService.ServerModules.AdvancedInjuryModule)
						AdvancedInjuryModule.RollForInjury(victimPlayer, config.Name == "Hielo_LanzaDeHielo" and "LanzaDeHielo_Splash" or "BolaDeFuego_Splash")
					end)
				end
			end
		end
	end
end

-- Listener
MagicEvent.OnServerEvent:Connect(function(player, spellName, targetPos)
	if typeof(spellName) ~= "string" or typeof(targetPos) ~= "Vector3" then 
		return 
	end
	
	-- Mapeo de compatibilidad para nombres antiguos o con dos puntos enviados por la GUI
	if spellName == "Fuego: Bola de Fuego" or spellName == "Fuego" then
		spellName = "Fuego_BolaDeFuego"
	elseif spellName == "Hielo: Lanza de Hielo" or spellName == "Hielo" then
		spellName = "Hielo_LanzaDeHielo"
	elseif spellName == "Tierra: Fisura" or spellName == "Tierra" then
		spellName = "Tierra_Fisura"
	end
	
	local char = player.Character
	if not char then
		return
	end
	
	if not canCast(player, char) then 
		return 
	end
	
	local spellConfig = MagicConfig.Spells[spellName]
	if not spellConfig then 
		return 
	end
	
	-- MagicLevel validation
	if player:GetAttribute(MagicConfig.GetSpellAttributeName(spellName)) ~= true then
		local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
		if notify then
			notify:FireClient(player, "Magia", "No tienes este hechizo desbloqueado.")
		end
		return
	end
	
	-- Mana validation (Cost is treated as a percentage of MaxMana)
	local maxMana = player:GetAttribute("MaxMana") or 100
	local costPercent = spellConfig.ManaCost or 0
	local actualCost = (costPercent / 100) * maxMana
	local currentMana = player:GetAttribute("Mana") or 0
	
	if currentMana < actualCost then
		local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
		if notify then
			notify:FireClient(player, "Magia", "¡No tienes suficiente Maná!")
		end
		return
	end
	
	-- Deduct mana
	player:SetAttribute("Mana", math.max(0, currentMana - actualCost))
	
	-- Cooldown validation
	local playerCooldowns = cooldowns[player.UserId]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player.UserId] = playerCooldowns
	end
	
	local now = os.clock()
	if playerCooldowns[spellName] and now < playerCooldowns[spellName] then
		return -- Still on cooldown
	end
	
	-- Set cooldown
	playerCooldowns[spellName] = now + spellConfig.Cooldown
	
	-- Replicate floating book effect to all clients
	if ReplicateFloatingBookEvent then
		ReplicateFloatingBookEvent:FireAllClients(player, 5.0)
	end
	
	-- Trigger cast effects (anim & cast sound)
	local track = playCastEffects(char, spellConfig)
	
	-- Wait until animation finishes if it's Hielo_LanzaDeHielo or Tierra_Fisura
	if spellConfig.Name == "Hielo_LanzaDeHielo" or spellConfig.Name == "Tierra_Fisura" then
		if track then
			track.Stopped:Wait()
		else
			task.wait(0.8) -- fallback
		end
		
		-- Play launch sound
		if spellConfig.LaunchSoundId and char:FindFirstChild("HumanoidRootPart") then
			local s = Instance.new("Sound")
			s.SoundId = spellConfig.LaunchSoundId
			s.Volume = 1.5
			s.RollOffMaxDistance = 150
			s.RollOffMinDistance = 10
			s.Parent = char.HumanoidRootPart
			s:Play()
			Debris:AddItem(s, 3)
		end
		
		if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
			if spellConfig.Name == "Tierra_Fisura" then
				spawnEarthFissure(player, player.Character, targetPos, spellConfig)
			else
				spawnProjectile(player, player.Character, targetPos, spellConfig)
			end
		end
	else
		-- Spawn projectile after a short cast delay for fireball
		task.delay(0.2, function()
			if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
				spawnProjectile(player, player.Character, targetPos, spellConfig)
			end
		end)
	end
end)