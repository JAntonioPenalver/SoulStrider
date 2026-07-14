local tool = script.Parent
local player = game.Players.LocalPlayer
local uis = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Variables de Referencia (Se actualizan al atacar)
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- FIX: Limpiar atributos al aparecer para evitar bloqueos de la vida anterior
character:SetAttribute("CannotAttack", false)
character:SetAttribute("IsBlocking", false)

-- Eventos y VFX
local ParryShakeEvent = ReplicatedStorage:FindFirstChild("ParryShakeEvent")
if not ParryShakeEvent then
	ParryShakeEvent = Instance.new("RemoteEvent")
	ParryShakeEvent.Name = "ParryShakeEvent"
	ParryShakeEvent.Parent = ReplicatedStorage
end

local event = ReplicatedStorage:WaitForChild("CombatEvent")
local function doCameraShake()
	local camera = workspace.CurrentCamera
	local startTime = tick()
	local duration = 0.25
	local intensity = 0.6
	
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		if elapsed > duration then
			connection:Disconnect()
			return
		end
		
		local factor = 1 - (elapsed / duration)
		local offsetX = (math.random() - 0.5) * intensity * factor
		local offsetY = (math.random() - 0.5) * intensity * factor
		local offsetZ = (math.random() - 0.5) * intensity * factor
		
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(offsetX * 5), math.rad(offsetY * 5), math.rad(offsetZ * 5))
	end)
end

ParryShakeEvent.OnClientEvent:Connect(function()
	doCameraShake()
end)

local hitEffectBase = ReplicatedStorage:WaitForChild("Hit1")
local blockEffectBase = ReplicatedStorage:WaitForChild("Block")

local AIR_HIT_SOUND_ID = "rbxassetid://138208560796742"
local ENEMY_HIT_SOUND_ID = "rbxassetid://136699507852787"

-- Variables de Estado
local combo = 1
local lastAttack = 0
local lastHeavy = 0
local BASE_ATTACK_DELAY = 0.6
local FINISHER_ATTACK_DELAY = 0.6
local HEAVY_COOLDOWN = 4.0
local isHoldingSpace = false

-- Manejo del valor NoJump
local noJumpTimer = nil
local function setNoJump(state)
	character = player.Character
	if not character then return end

	if state then
		if noJumpTimer then
			task.cancel(noJumpTimer)
			noJumpTimer = nil
		end
		character:SetAttribute("NoJump", true)
		local val = character:FindFirstChild("NoJump")
		if not val then
			val = Instance.new("BoolValue")
			val.Name = "NoJump"
			val.Value = true
			val.Parent = character
		end
	else
		if noJumpTimer then
			task.cancel(noJumpTimer)
		end
		noJumpTimer = task.delay(1.2, function()
			if character and character.Parent then
				character:SetAttribute("NoJump", nil)
				local val = character:FindFirstChild("NoJump")
				if val then
					val:Destroy()
				end
			end
			noJumpTimer = nil
		end)
	end
end

local isEquipped = false
local isAttacking = false
local isBlocking = false
local wantsToBlock = false -- 🔥 FIX CLAVE
local currentAttackDelay = BASE_ATTACK_DELAY
local activeBlockAttachment = nil
local BLOCK_COOLDOWN_ATTR = "BlockCooldownUntil"
local BLOCK_BREAK_SIGNAL_ATTR = "BlockBreakSignal"
local BLOCK_SERVER_ACK_GRACE = 0.25
local blockAckDeadline = 0
local lastBlockBreakSignal = character:GetAttribute(BLOCK_BREAK_SIGNAL_ATTR) or 0

-- Animaciones
local anims = {
	["Hit1"] = "rbxassetid://71921396788056",
	["Hit2"] = "rbxassetid://108453156992815",
	["Hit3"] = "rbxassetid://132089398125860",
	["Hit4"] = "rbxassetid://98135448106596",
	["Hit5"] = "rbxassetid://82409302527625",
	["Heavy"] = "rbxassetid://136717746431438",
	["Idle"] = "rbxassetid://78102962840394",
	["Block"] = "rbxassetid://77799026661567"
}

local tracks = {}

local function loadAnimations()
	for _, t in pairs(tracks) do
		pcall(function() t:Stop() t:Destroy() end)
	end
	table.clear(tracks)

	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	for name, id in pairs(anims) do
		local a = Instance.new("Animation")
		a.AnimationId = id
		tracks[name] = animator:LoadAnimation(a)
	end
end

loadAnimations()

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid")
	character:SetAttribute("CannotAttack", false)
	character:SetAttribute("IsBlocking", false)
	isAttacking = false
	isBlocking = false
	wantsToBlock = false
	combo = 1
	loadAnimations()
end)

-- VFX
local function playHitEffect(targetPart)
	if not hitEffectBase then return end
	local attachment = Instance.new("Attachment", targetPart)
	local p = hitEffectBase:Clone()
	p.Parent = attachment
	p.Size = NumberSequence.new(4)
	p.Lifetime = NumberRange.new(0.1, 0.25)
	p.Enabled = false
	p:Emit(15)
	game.Debris:AddItem(attachment, 0.4)
end

local function playCombatSound(soundId)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = 1
	s.Parent = root
	s:Play()
	game.Debris:AddItem(s, 2)
end

-- Hitbox local
local function checkHitbox(range)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(root.Position, root.CFrame.LookVector * range, params)

	if result and result.Instance then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChild("Humanoid") then
			playHitEffect(result.Instance)
			return model
		end
	end
	return nil
end

-- VFX de bloqueo
local function stopBlockEffect()
	if activeBlockAttachment then
		activeBlockAttachment:Destroy()
		activeBlockAttachment = nil
	end
end

local function startBlockEffect()
	stopBlockEffect()

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not blockEffectBase then return end

	local attachment = Instance.new("Attachment")
	attachment.Name = "BlockEffectAttachment"
	attachment.Position = Vector3.new(0, 0, -2.5)
	attachment.Parent = root

	local effect = blockEffectBase:Clone()
	effect.Parent = attachment
	if effect:IsA("ParticleEmitter") then
		effect.Enabled = true
	end

	activeBlockAttachment = attachment
end

-- 🛡️ BLOQUEO (FIXED)
local function toggleBlock(state)
	-- Asegurar referencias actuales
	character = player.Character
	if not character then return end
	humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	
	wantsToBlock = state

	-- No bloquear mientras atacas
	if state and isAttacking then return end
	if state then
		local blockCooldownUntil = character:GetAttribute(BLOCK_COOLDOWN_ATTR) or 0
		if time() < blockCooldownUntil then
			wantsToBlock = false
			return
		end
	end

	isBlocking = state
	if state then
		blockAckDeadline = tick() + BLOCK_SERVER_ACK_GRACE
	else
		blockAckDeadline = 0
	end
	event:FireServer("Block", state)

	if state then
		if tracks["Block"] then tracks["Block"]:Play(0.2) end
		startBlockEffect()
	else
		if tracks["Block"] then tracks["Block"]:Stop(0.2) end
		stopBlockEffect()
	end
end

-- ⚔️ ATAQUE
local function attack()
	-- Actualizar referencias justo antes de atacar
	character = player.Character
	humanoid = character and character:FindFirstChild("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then return end

	if isAttacking or isBlocking then return end
	if character:GetAttribute("CannotAttack") then return end
	if tick() - lastAttack < currentAttackDelay then return end

	lastAttack = tick()
	isAttacking = true

	-- Añadir NoJump al empezar a golpear
	setNoJump(true)

	local currentCombo = combo
	local animName = "Hit"..tostring(currentCombo)
	if tracks[animName] then tracks[animName]:Play() end

	task.delay(0.1, function()
		playCombatSound(AIR_HIT_SOUND_ID)
		event:FireServer("LightAttack", currentCombo, isHoldingSpace)
	end)

	currentAttackDelay = (currentCombo == 5) and FINISHER_ATTACK_DELAY or BASE_ATTACK_DELAY

	combo += 1
	if combo > 5 then combo = 1 end

	task.delay(0.4, function()
		isAttacking = false
		
		-- Iniciar temporizador de quitar NoJump (se quitará tras 1.2 segundos de dejar de golpear)
		setNoJump(false)

		-- 🔥 si sigue manteniendo bloqueo, vuelve automáticamente
		if wantsToBlock then
			toggleBlock(true)
		end
	end)

	task.delay(1.5, function()
		if tick() - lastAttack >= 1.5 then
			combo = 1
			currentAttackDelay = BASE_ATTACK_DELAY
		end
	end)
end

-- 💥 HEAVY
local function heavy()
	-- Actualizar referencias
	character = player.Character
	humanoid = character and character:FindFirstChild("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then return end
	
	if isAttacking or isBlocking then return end
	if character:GetAttribute("CannotAttack") then return end
	if tick() - lastHeavy < HEAVY_COOLDOWN then return end

	lastHeavy = tick()
	isAttacking = true

	-- Añadir NoJump al empezar a golpear
	setNoJump(true)

	if tracks["Heavy"] then tracks["Heavy"]:Play() end

	task.delay(0.2, function()
		tracks["Heavy"]:AdjustSpeed(0)
		task.wait(0.5)
		tracks["Heavy"]:AdjustSpeed(1)

		playCombatSound(AIR_HIT_SOUND_ID)
		event:FireServer("HeavyAttack")

		task.delay(0.3, function()
			isAttacking = false

			-- Iniciar temporizador de quitar NoJump
			setNoJump(false)

			if wantsToBlock then
				toggleBlock(true)
			end
		end)
	end)
end

-- Tool
tool.Equipped:Connect(function()
	isEquipped = true
end)

tool.Unequipped:Connect(function()
	isEquipped = false
	isAttacking = false
	isBlocking = false
	wantsToBlock = false
	isHoldingSpace = false

	combo = 1
	currentAttackDelay = BASE_ATTACK_DELAY

	toggleBlock(false)

	stopBlockEffect()

	for _, t in pairs(tracks) do
		t:Stop()
	end

	-- Quitar NoJump inmediatamente al desequipar
	if noJumpTimer then
		task.cancel(noJumpTimer)
		noJumpTimer = nil
	end
	if character and character.Parent then
		character:SetAttribute("NoJump", nil)
		local val = character:FindFirstChild("NoJump")
		if val then
			val:Destroy()
		end
	end
end)

-- 🔄 LOOP PRINCIPAL (FIX CLAVE)
RunService.RenderStepped:Connect(function()
	if not isEquipped then return end

	local blockBreakSignal = character:GetAttribute(BLOCK_BREAK_SIGNAL_ATTR) or 0
	if blockBreakSignal > lastBlockBreakSignal then
		lastBlockBreakSignal = blockBreakSignal
		wantsToBlock = false
		if isBlocking then
			toggleBlock(false)
		else
			if tracks["Block"] then tracks["Block"]:Stop(0.1) end
			stopBlockEffect()
		end
	end

	-- 🔥 SI EL SERVIDOR ROMPE BLOQUEO / DESACTIVA BLOQUEO
	if isBlocking and character:GetAttribute("IsBlocking") == false then
		if wantsToBlock and tick() < blockAckDeadline then
			-- Esperamos breve confirmacion del servidor para no cortar el bloqueo al instante.
		else
			isBlocking = false
			wantsToBlock = false
			if tracks["Block"] then tracks["Block"]:Stop(0.1) end
			stopBlockEffect()
		end
	end

	-- Idle
	if humanoid.MoveDirection.Magnitude > 0 then
		if tracks["Idle"].IsPlaying then
			tracks["Idle"]:Stop(0.3)
		end
	else
		if not tracks["Idle"].IsPlaying and not isAttacking and not isBlocking then
			tracks["Idle"]:Play(0.3)
		end
	end
end)

-- Inputs
tool.Activated:Connect(attack)

uis.InputBegan:Connect(function(input, gp)
	if gp or not isEquipped then return end
	if not humanoid or humanoid.Health <= 0 then return end

	if input.KeyCode == Enum.KeyCode.R then
		heavy()
	elseif input.KeyCode == Enum.KeyCode.F then
		toggleBlock(true)
	end
end)

uis.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		wantsToBlock = false
		if humanoid and humanoid.Health > 0 then
			toggleBlock(false)
		end
	end
end)

-- Detector físico de teclado para Espacio (ignora gameProcessedEvent y key sinking)
uis.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then
		isHoldingSpace = true
	end
end)

uis.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then
		isHoldingSpace = false
	end
end)