local MovementModule = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

-- CONFIGURACIÓN
local BASE_SPEED = 16
local SPRINT_SPEED = 26
local CROUCH_SPEED = 8
local MAX_STAMINA = 100
local STAMINA_DRAIN = 0.2
local STAMINA_REGEN = 0.6
local REGEN_DELAY = 1.0
local LEAN_FACTOR = 0.008

task.spawn(function()
	local staminaStat = player:WaitForChild("Stamina", 10)
	if not staminaStat then return end
	
	local function updateMaxStamina()
		local relicStaminaBuff = player:GetAttribute("RelicStaminaBuff") or 0
		MAX_STAMINA = 100 + (staminaStat.Value * 10) + relicStaminaBuff
		player:SetAttribute("MaxStamina", MAX_STAMINA)
	end
	staminaStat.Changed:Connect(updateMaxStamina)
	player:GetAttributeChangedSignal("RelicStaminaBuff"):Connect(updateMaxStamina)
	updateMaxStamina()
end)

-- CONFIGURACIÓN SLIDE
local SLIDE_COOLDOWN = 5.0
local lastSlideTime = 0

-- CONFIGURACIÓN ROLL
local DASH_STAMINA_COST = 20
local DASH_COOLDOWN = 5.0
local DASH_FORCE = 85
local DASH_DURATION = 0.4

local DASH_ANIMS = {
    Front = "rbxassetid://90366462746600",
    Back = "rbxassetid://90366462746600",
    Left = "rbxassetid://90366462746600",
    Right = "rbxassetid://90366462746600"
}

-- VARIABLES DE ESTADO
local character = nil
local humanoid = nil
local rootPart = nil
local animator = nil
local rootJoint = nil
local originalC0 = nil

local states = {
	isSprinting = false,
	isCrouching = false,
	isSliding = false,
	isDashing = false,
	lastDashTime = 0,
	stamina = MAX_STAMINA,
	lastStaminaUsage = 0
}

local sounds = {}
local tracks = {}


function MovementModule.Init(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")
	animator = humanoid:WaitForChild("Animator")
	
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		rootJoint = char:WaitForChild("LowerTorso"):WaitForChild("Root")
	else
		rootJoint = rootPart:WaitForChild("RootJoint")
	end
	originalC0 = rootJoint.C0
	
	-- CARGAR ANIMACIONES
	local animSprint = Instance.new("Animation")
	animSprint.AnimationId = "rbxassetid://135955953958507"
	tracks.runTrack = animator:LoadAnimation(animSprint)
	
	local animCrouch = Instance.new("Animation")
	animCrouch.AnimationId = "rbxassetid://86740708694556"
	tracks.crouchTrack = animator:LoadAnimation(animCrouch)
	
	local animSlide = Instance.new("Animation")
	animSlide.AnimationId = "rbxassetid://140342781028414"
	tracks.slideTrack = animator:LoadAnimation(animSlide)

	for name, id in pairs(DASH_ANIMS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		tracks["dash"..name] = animator:LoadAnimation(anim)
        tracks["dash"..name].Priority = Enum.AnimationPriority.Action -- Prioridad alta
	end

	player:SetAttribute("Stamina", states.stamina)
		player:SetAttribute("MaxStamina", MAX_STAMINA)
	
	-- Inicializar Sonidos
	local dashSound = Instance.new("Sound")
	dashSound.SoundId = "rbxassetid://8653395088" -- Swoosh rápido
	dashSound.Volume = 0.5
	dashSound.Parent = rootPart
	sounds.dash = dashSound
	
	local slideSound = Instance.new("Sound")
	slideSound.SoundId = "rbxassetid://138269837525273" -- Deslizamiento
	slideSound.Volume = 0.6
	slideSound.Parent = rootPart
	sounds.slide = slideSound

end

function MovementModule.ToggleSprint(active)
	if active and states.stamina > 5 and humanoid.MoveDirection.Magnitude > 0 and not states.isCrouching and not states.isDashing then
		states.isSprinting = true
	else
		states.isSprinting = false
		if tracks.runTrack.IsPlaying then tracks.runTrack:Stop(0.3) end
	end
end

function MovementModule.ToggleCrouch(active)
	states.isCrouching = active
	if active then 
		states.isSprinting = false 
		if tracks.runTrack.IsPlaying then tracks.runTrack:Stop(0.1) end
		if not tracks.crouchTrack.IsPlaying then tracks.crouchTrack:Play(0.3) end
	else
		if tracks.crouchTrack.IsPlaying then tracks.crouchTrack:Stop(0.3) end
	end
end

function MovementModule.StartSlide()
	if states.isSliding or states.stamina < 15 or tick() - lastSlideTime < SLIDE_COOLDOWN then 
		return 
	end
	
	lastSlideTime = tick()
	states.isSliding = true
	states.stamina = math.max(0, states.stamina - 15)
	states.lastStaminaUsage = tick()
	player:SetAttribute("LastStaminaUsage", states.lastStaminaUsage)
	
		tracks.slideTrack:Play()
	if sounds.slide then sounds.slide:Play() end

	
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1, 0, 1) * 30000
	bv.Velocity = rootPart.CFrame.lookVector * 55
	bv.Parent = rootPart
	
	task.delay(0.5, function()
				bv:Destroy()
		if sounds.slide then sounds.slide:Stop() end

		tracks.slideTrack:Stop(0.3)
		states.isSliding = false
	end)
end

function MovementModule.Dash(char, direction)
    if states.isDashing or tick() - states.lastDashTime < DASH_COOLDOWN then return end
    if states.stamina < DASH_STAMINA_COST then return end
    
    -- Limpiar otras animaciones
    if tracks.runTrack.IsPlaying then tracks.runTrack:Stop(0.1) end
    if tracks.crouchTrack.IsPlaying then tracks.crouchTrack:Stop(0.1) end
    
    states.stamina = math.max(0, states.stamina - DASH_STAMINA_COST)
    states.lastStaminaUsage = tick()
    states.lastDashTime = tick()
    states.isDashing = true
    
    local animTrack = tracks["dashFront"]
    local velocityVector = rootPart.CFrame.lookVector
    
    if direction == "Back" then
        animTrack = tracks["dashBack"]
        velocityVector = -rootPart.CFrame.lookVector
    elseif direction == "Left" then
        animTrack = tracks["dashLeft"]
        velocityVector = -rootPart.CFrame.rightVector
    elseif direction == "Right" then
        animTrack = tracks["dashRight"]
        velocityVector = rootPart.CFrame.rightVector
    end
    
        if animTrack then 
        animTrack:Play(0.1) 
        if sounds.dash then sounds.dash:Play() end
    end

    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1, 0, 1) * 100000
    bv.Velocity = velocityVector * DASH_FORCE
    bv.Parent = rootPart
    
    task.delay(DASH_DURATION, function()
        		bv:Destroy()
		if sounds.slide then sounds.slide:Stop() end

        if animTrack then animTrack:Stop(0.3) end -- Detener animación suavemente
        states.isDashing = false
    end)
end

function MovementModule.Update(dt)
	if not character or not humanoid then return end
	
	local moving = humanoid.MoveDirection.Magnitude > 0
	
	if states.isSprinting and moving and not states.isCrouching and not states.isDashing and not states.isSliding then
		if not tracks.runTrack.IsPlaying then tracks.runTrack:Play(0.3) end
	else
		if tracks.runTrack.IsPlaying then tracks.runTrack:Stop(0.3) end
	end

	if states.isCrouching then
		if moving then
			tracks.crouchTrack:AdjustSpeed(1)
		else
			tracks.crouchTrack:AdjustSpeed(0)
		end
	end
	
	local relicSpeedBuff = player:GetAttribute("RelicSpeedBuff") or 0
	local targetSpeed = 16 + (player:FindFirstChild("Velocidad") and player.Velocidad.Value or 0) * 0.5 + relicSpeedBuff
	local sprintBoost = 10
    
	if states.isCrouching then
		targetSpeed = CROUCH_SPEED
	elseif states.isSprinting and states.stamina > 0 and moving then
		targetSpeed = targetSpeed + sprintBoost
		states.stamina = math.max(0, states.stamina - STAMINA_DRAIN)
		states.lastStaminaUsage = tick()
	end
	
	humanoid.WalkSpeed = targetSpeed
	
	if not states.isSprinting and not states.isSliding and not states.isDashing and tick() - states.lastStaminaUsage > REGEN_DELAY then
        local currentMax = player:GetAttribute("MaxStamina") or 100
		states.stamina = math.min(currentMax, states.stamina + STAMINA_REGEN)
	end
	player:SetAttribute("Stamina", states.stamina)
	
	local momentum = rootPart.CFrame:VectorToObjectSpace(rootPart.Velocity) * LEAN_FACTOR
	local angles = (humanoid.RigType == Enum.HumanoidRigType.R15) and {momentum.Z, 0, -momentum.X} or {-momentum.Z, -momentum.X, 0}
	rootJoint.C0 = rootJoint.C0:Lerp(originalC0 * CFrame.Angles(unpack(angles)), dt * 10)
end

return MovementModule
