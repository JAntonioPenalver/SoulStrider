local tool = script.Parent
local player = game.Players.LocalPlayer
local uis = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Variables de Referencia
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- FIX: Limpiar atributos al aparecer
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

local blockEffectBase = ReplicatedStorage:WaitForChild("Block")

local AIR_HIT_SOUND_ID = "rbxassetid://138208560796742"
local ENEMY_HIT_SOUND_ID = "rbxassetid://135200034075896"

-- Variables de Estado
local combo = 1
local lastAttack = 0
local lastHeavy = 0
local BASE_ATTACK_DELAY = 0.4 -- Daga es un poco más rápida que la espada en delay de combo
local FINISHER_ATTACK_DELAY = 1.0 -- Finisher más rápido
local HEAVY_COOLDOWN = 2.5 -- Heavy con menos cooldown

local isEquipped = false
local isAttacking = false
local isBlocking = false
local wantsToBlock = false
local currentAttackDelay = BASE_ATTACK_DELAY
local activeBlockAttachment = nil
local BLOCK_COOLDOWN_ATTR = "BlockCooldownUntil"
local BLOCK_BREAK_SIGNAL_ATTR = "BlockBreakSignal"
local BLOCK_SERVER_ACK_GRACE = 0.25
local blockAckDeadline = 0
local lastBlockBreakSignal = character:GetAttribute(BLOCK_BREAK_SIGNAL_ATTR) or 0

-- Animaciones proporcionadas por el usuario para DAGA
local anims = {
	["Hit1"] = "rbxassetid://132866001750575",
	["Hit2"] = "rbxassetid://76009150847603",
	["Hit3"] = "rbxassetid://112613054746770",
	["Hit4"] = "rbxassetid://132866001750575", -- Reutilizar Hit1 como 4º golpe/finisher de combo
	["Heavy"] = "rbxassetid://91592072843834", -- Misma animación pesada de espada como fallback
	["Block"] = "rbxassetid://131832857372537",
	["Idle"] = "rbxassetid://112555290001703" 
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
		local track = animator:LoadAnimation(a)
		if track then
			tracks[name] = track
			
			-- Establecer prioridades
			if name == "Block" then
				track.Priority = Enum.AnimationPriority.Action
			elseif name:find("Hit") or name == "Heavy" then
				track.Priority = Enum.AnimationPriority.Action
			elseif name == "Idle" then
				track.Priority = Enum.AnimationPriority.Idle
			end
		end
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

-- Bloqueo
local function toggleBlock(state)
	character = player.Character
	if not character then return end
	humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	
	wantsToBlock = state

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

-- Ataque
local function attack()
	character = player.Character
	humanoid = character and character:FindFirstChild("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then return end

	if isAttacking or isBlocking then return end
	if character:GetAttribute("CannotAttack") then return end
	if tick() - lastAttack < currentAttackDelay then return end

	lastAttack = tick()
	isAttacking = true

	local currentCombo = combo
	local animName = "Hit"..tostring(currentCombo)
	if tracks[animName] then tracks[animName]:Play() end

	task.delay(0.1, function()
		playCombatSound(AIR_HIT_SOUND_ID)
		event:FireServer("LightAttack", currentCombo)
	end)

	currentAttackDelay = (currentCombo == 4) and FINISHER_ATTACK_DELAY or BASE_ATTACK_DELAY

	combo += 1
	if combo > 4 then combo = 1 end

	task.delay(0.3, function() -- Daga se recupera un poco más rápido (era 0.4)
		isAttacking = false
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

-- Heavy
local function heavy()
	character = player.Character
	humanoid = character and character:FindFirstChild("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then return end
	
	if isAttacking or isBlocking then return end
	if character:GetAttribute("CannotAttack") then return end
	if tick() - lastHeavy < HEAVY_COOLDOWN then return end

	lastHeavy = tick()
	isAttacking = true

	if tracks["Heavy"] then tracks["Heavy"]:Play() end

	task.delay(0.15, function() -- Daga es más rápida en el windup del heavy
		tracks["Heavy"]:AdjustSpeed(0)
		task.wait(0.25)
		tracks["Heavy"]:AdjustSpeed(1)

		playCombatSound(AIR_HIT_SOUND_ID)
		event:FireServer("HeavyAttack")

		task.delay(0.25, function()
			isAttacking = false
			if wantsToBlock then
				toggleBlock(true)
			end
		end)
	end)
end

-- Tool
tool.Equipped:Connect(function()
	isEquipped = true
	loadAnimations()
end)

local function cleanup()
	isEquipped = false
	isAttacking = false
	isBlocking = false
	wantsToBlock = false
	combo = 1
	currentAttackDelay = BASE_ATTACK_DELAY
	toggleBlock(false)
	stopBlockEffect()
	for _, t in pairs(tracks) do
		pcall(function()
			t:Stop(0.1)
		end)
	end
end

tool.Unequipped:Connect(cleanup)
script.Destroying:Connect(cleanup)
tool.AncestryChanged:Connect(function()
	if not tool:IsDescendantOf(game) then
		cleanup()
	end
end)

-- Loop Principal
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

	if isBlocking and character:GetAttribute("IsBlocking") == false then
		if wantsToBlock and tick() < blockAckDeadline then
			-- Esperamos confirmación del servidor
		else
			isBlocking = false
			wantsToBlock = false
			if tracks["Block"] then tracks["Block"]:Stop(0.1) end
			stopBlockEffect()
		end
	end

	-- Idle Logic
	if tracks["Idle"] then
		if humanoid.MoveDirection.Magnitude > 0 then
			if tracks["Idle"].IsPlaying then
				tracks["Idle"]:Stop(0.3)
			end
		else
			if not tracks["Idle"].IsPlaying and not isAttacking and not isBlocking then
				tracks["Idle"]:Play(0.3)
			end
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