local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local events = ReplicatedStorage:WaitForChild("Events")
local effectEvent = events:WaitForChild("VFXEffectEvent")
local feedbackEvent = events:WaitForChild("VFXFeedbackEvent")

local ltvfx = ReplicatedStorage:WaitForChild("LTVFX")
local vfxConfig = require(ReplicatedStorage:WaitForChild("VFXConfig"))

local activeBurns = {}

-- Extremely robust spatial distance check for both Players and NPCs/Dummies
local function getHumanoidsInRadius(position, radius)
	local hitPlayers = {}
	
	-- 1. Check active Players
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
			local humanoid = char:FindFirstChild("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local distance = (root.Position - position).Magnitude
				if distance <= radius then
					hitPlayers[humanoid] = char
				end
			end
		end
	end
	
	-- 2. Check Dummies/NPCs direct children of Workspace
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and not Players:GetPlayerFromCharacter(child) then
			local humanoid = child:FindFirstChild("Humanoid")
			local root = child:FindFirstChild("HumanoidRootPart") or child:FindFirstChild("Torso")
			if humanoid and root and humanoid.Health > 0 then
				local distance = (root.Position - position).Magnitude
				if distance <= radius then
					hitPlayers[humanoid] = child
				end
			end
		end
	end
	
	return hitPlayers
end

-- Helper to play a transient sound at a 3D position
local function playSoundAtPosition(soundId, position, volume)
	local soundPart = Instance.new("Part")
	soundPart.Name = "VFX_SoundSource"
	soundPart.Position = position
	soundPart.Transparency = 1
	soundPart.CanCollide = false
	soundPart.CanQuery = false
	soundPart.CanTouch = false
	soundPart.Anchored = true
	soundPart.Parent = workspace
	
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 1
	sound.RollOffMaxDistance = 250 -- Farther reach
	sound.RollOffMinDistance = 10
	sound.Parent = soundPart
	
	sound:Play()
	Debris:AddItem(soundPart, 6) -- Delete sound part after play
end

-- Apply burn status effect to character
local function applyBurnEffect(character, humanoid, config)
	if activeBurns[humanoid] then return end
	activeBurns[humanoid] = true
	
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
	if not rootPart then 
		activeBurns[humanoid] = nil
		return 
	end
	
	-- 1. Apply visual fire particles
	local fuegoTemplate = ltvfx:FindFirstChild("Fuego")
	local clonedEmitters = {}
	local burnAtt = nil
	
	if fuegoTemplate then
		local att = fuegoTemplate:FindFirstChild("VFX_Attachment")
		if att then
			burnAtt = Instance.new("Attachment")
			burnAtt.Name = "BurnAttachment"
			burnAtt.Parent = rootPart
			
			for _, child in ipairs(att:GetChildren()) do
				if child:IsA("ParticleEmitter") then
					local clone = child:Clone()
					clone.Parent = burnAtt
					table.insert(clonedEmitters, clone)
				end
			end
		end
	end
	
	-- 2. Integrate with Advanced Injuries: Apply "Burn" (Quemadura) wound type if it is a real player
	local playerVictim = Players:GetPlayerFromCharacter(character)
	if playerVictim then
		pcall(function()
			local AdvancedInjuryModule = require(game.ServerScriptService.ServerModules.AdvancedInjuryModule)
			local bodyParts = {"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}
			local randomPart = bodyParts[math.random(1, #bodyParts)]
			AdvancedInjuryModule.AddInjury(playerVictim, randomPart, "Burn")
		end)
	end
	
	-- 3. Run visual fire particle timeline and passive tick damage
	task.spawn(function()
		local duration = config.BurnDuration or 6
		local damage = config.BurnDamage or 3
		
		for i = 1, duration do
			task.wait(1)
			if humanoid and humanoid.Parent and humanoid.Health > 0 then
				humanoid:TakeDamage(damage)
			else
				break
			end
		end
		
		-- Fade out particles before destroying attachment
		for _, emitter in ipairs(clonedEmitters) do
			if emitter and emitter.Parent then
				emitter.Enabled = false
			end
		end
		
		task.wait(2)
		if burnAtt then
			burnAtt:Destroy()
		end
		activeBurns[humanoid] = nil
	end)
end

-- Handle Explosion Effect
local function handleExplosion(position, config)
	local template = ltvfx:FindFirstChild("Explosion")
	if not template then return end
	
	-- 1. Play Sound
	playSoundAtPosition(config.SoundId, position, config.Volume)
	
	-- 2. Trigger Screen Shake & Grey Vignette for nearby players
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local distance = (char.HumanoidRootPart.Position - position).Magnitude
			if distance <= config.ShakeRadius then
				local shakeScale = 1 - (distance / config.ShakeRadius)
				local intensity = config.ShakeIntensity * shakeScale
				local duration = config.ShakeDuration
				feedbackEvent:FireClient(player, "Explosion", intensity, duration)
			end
		end
	end
	
	-- 3. Spawn Visual Part
	local part = template:Clone()
	part.CFrame = CFrame.new(position)
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Anchored = true
	part.Parent = workspace
	
	-- Determine Hitbox Size
	local hitboxSize = part.Size
	if hitboxSize.X <= 2 or hitboxSize.Y <= 2 or hitboxSize.Z <= 2 then
		hitboxSize = config.HitboxSize or Vector3.new(20, 20, 20)
	end
	
	-- Enable emitters
	local att = part:FindFirstChild("VFX_Attachment")
	if att then
		for _, child in ipairs(att:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = true
			end
		end
	end
	
	-- 4. Deal Instant Damage using distance check
	local radius = hitboxSize.X / 2
	local targets = getHumanoidsInRadius(position, radius)
	for humanoid, _ in pairs(targets) do
		humanoid:TakeDamage(config.Damage)
	end
	
	-- 5. Fade and Cleanup particles
	task.spawn(function()
		task.wait(config.Duration)
		if att then
			for _, child in ipairs(att:GetChildren()) do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
		end
		Debris:AddItem(part, config.CleanUpDebris)
	end)
end

-- Handle Fuego (Fire) Effect
local function handleFuego(position, config)
	local template = ltvfx:FindFirstChild("Fuego")
	if not template then return end
	
	-- 1. Spawn Fire part
	local part = template:Clone()
	part.CFrame = CFrame.new(position)
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Anchored = true
	part.Parent = workspace
	
	-- 2. Create Looped 3D Spatial Audio
	local sound = Instance.new("Sound")
	sound.SoundId = config.SoundId
	sound.Volume = config.Volume or 1
	sound.Looped = true
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 60
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.Parent = part
	sound:Play()
	
	-- Determine Hitbox Size
	local hitboxSize = part.Size
	if hitboxSize.X <= 2 or hitboxSize.Y <= 2 or hitboxSize.Z <= 2 then
		hitboxSize = config.HitboxSize or Vector3.new(12, 12, 12)
	end
	
	-- Enable emitters
	local att = part:FindFirstChild("VFX_Attachment")
	if att then
		for _, child in ipairs(att:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = true
			end
		end
	end
	
	-- 3. Start Damage Ticking Loop using distance check
	local radius = hitboxSize.X / 2
	task.spawn(function()
		while part and part.Parent do
			task.wait(config.TickInterval)
			if not part or not part.Parent then break end
			
			local targets = getHumanoidsInRadius(part.Position, radius)
			for humanoid, character in pairs(targets) do
				humanoid:TakeDamage(config.Damage)
				
				-- Chance to apply Burn status effect
				if math.random() < config.BurnChance then
					applyBurnEffect(character, humanoid, config)
				end
			end
		end
	end)
end

-- Listen to remote event triggers
effectEvent.OnServerEvent:Connect(function(player, effectName, position)
	if typeof(position) ~= "Vector3" then return end
	local effectConfig = vfxConfig.Effects[effectName]
	if not effectConfig then return end
	
	if effectName == "Explosion" then
		handleExplosion(position, effectConfig)
	elseif effectName == "Fuego" then
		handleFuego(position, effectConfig)
	end
end)