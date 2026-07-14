local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")
local Debris            = game:GetService("Debris")

local spawnEvent    = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SpawnDungeonEvent")
local DungeonConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DungeonConfig"))
local RelicConfig   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RelicConfig"))

local function isAllowed(player)
	return true
end

-- Populate chest loot
local function populateLoot(chestFolder)
	-- Botín regular
	for _, item in ipairs(DungeonConfig.LootPool) do
		if math.random() <= item.Chance then
			local template = ServerStorage:FindFirstChild(item.Name, true) or ReplicatedStorage:FindFirstChild(item.Name, true)
			if template and template:IsA("Tool") then
				local clone = template:Clone()
				clone:SetAttribute("Cantidad", item.Stackable and math.random(1, item.MaxQty) or 1)
				clone.Parent = chestFolder
			else
				warn("[DungeonManager] Loot template not found: " .. item.Name)
			end
		end
	end
	
	-- Probabilidad de drop de Reliquias
	for relicName, relicData in pairs(RelicConfig.Relics) do
		if math.random() <= relicData.DropChance then
			local template = ServerStorage:FindFirstChild(relicName, true) or ReplicatedStorage:FindFirstChild(relicName, true)
			if template and template:IsA("Tool") then
				local clone = template:Clone()
				clone:SetAttribute("Cantidad", 1) -- Las reliquias son individuales/unstackables
				clone.Parent = chestFolder
				print("[DungeonManager] ¡Reliquia soltada en cofre!: " .. relicName)
			else
				warn("[DungeonManager] Reliquia no encontrada en ServerStorage o ReplicatedStorage: " .. relicName)
			end
		end
	end
end

-- Gradually fade all BaseParts to transparent, then destroy the model
local function fadeAndDestroy(model)
	if not model or not model.Parent then return end

	-- Collect all parts and record starting transparency
	local parts = {}
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			table.insert(parts, {part = desc, startAlpha = desc.Transparency})
		end
	end

	if #parts == 0 then
		model:Destroy()
		return
	end

	local duration = DungeonConfig.FadeDuration  -- seconds
	local steps    = 60                           -- updates per second feel
	local stepTime = duration / steps

	for i = 1, steps do
		task.wait(stepTime)
		if not model or not model.Parent then return end  -- already gone
		local alpha = i / steps  -- 0 -> 1
		for _, entry in ipairs(parts) do
			if entry.part and entry.part.Parent then
				-- Lerp from original transparency to 1
				entry.part.Transparency = entry.startAlpha + (1 - entry.startAlpha) * alpha
			end
		end
	end

	-- All parts fully transparent - destroy
	if model and model.Parent then
		model:Destroy()
	end
end

-- Goblin spawner
local function spawnGoblinsAround(centerPosition, count, onAllDead)
	local activeGoblins      = {}
	local isVictoryTriggered = false

	local function checkVictory()
		if isVictoryTriggered then return end
		local aliveCount = 0
		for _, goblin in ipairs(activeGoblins) do
			if goblin and goblin.Parent and goblin:IsDescendantOf(Workspace) then
				local humanoid = goblin:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health > 0 then
					aliveCount = aliveCount + 1
				end
			end
		end
		if aliveCount <= 0 then
			isVictoryTriggered = true
			onAllDead()
		end
	end

	for i = 1, count do
		local angle    = (i / count) * math.pi * 2
		local offset   = Vector3.new(
			math.cos(angle) * DungeonConfig.SpawnPerimeterRadius,
			0,
			math.sin(angle) * DungeonConfig.SpawnPerimeterRadius
		)
		local spawnPos = centerPosition + offset

		-- Portal FX
		local portal = Instance.new("Part")
		portal.Anchored    = true
		portal.CanCollide  = false
		portal.Transparency = 1
		portal.Position    = spawnPos
		portal.Parent      = Workspace
		local att      = Instance.new("Attachment", portal)
		local fx       = Instance.new("ParticleEmitter", att)
		fx.Texture     = "rbxassetid://244221448"
		fx.Rate        = 100
		fx.Speed       = NumberRange.new(5, 10)
		fx.Lifetime    = NumberRange.new(0.5, 1)
		Debris:AddItem(portal, 3)
		task.delay(1, function() fx.Enabled = false end)

		-- Goblin
		local GoblinTemplate = ReplicatedStorage:WaitForChild(DungeonConfig.GoblinTemplateName)
		local goblinClone    = GoblinTemplate:Clone()
		goblinClone:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 4, 0)))
		goblinClone.Parent = Workspace
		table.insert(activeGoblins, goblinClone)

		local humanoid = goblinClone:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function()
				task.wait(0.2)
				checkVictory()
				task.wait(4.8)
				goblinClone:Destroy()
			end)
		end
	end

	-- Active monitoring fail-safe polling loop: check every 2 seconds
	task.spawn(function()
		while not isVictoryTriggered do
			task.wait(2)
			for _, goblin in ipairs(activeGoblins) do
				if goblin and goblin.Parent then
					local hrp = goblin:FindFirstChild("HumanoidRootPart")
					if hrp and hrp.Position.Y < -50 then
						local hum = goblin:FindFirstChild("Humanoid")
						if hum and hum.Health > 0 then 
							hum.Health = 0 
						end
					end
				end
			end
			checkVictory()
		end
	end)
end

-- Main handler
spawnEvent.OnServerEvent:Connect(function(player, clickPos)
	if not isAllowed(player) then return end

	local ruinsTemplate = Workspace:FindFirstChild(DungeonConfig.DungeonTemplateName)
	if not ruinsTemplate then
		warn("[DungeonManager] Template '" .. DungeonConfig.DungeonTemplateName .. "' not found!")
		return
	end

	-- Clone & place ruins
	local ruinsClone   = ruinsTemplate:Clone()
	ruinsClone.Name    = "Ruinas_Spawned"
	local cframe, size = ruinsTemplate:GetBoundingBox()
	local pivot        = ruinsTemplate:GetPivot()
	local bottomOffset = (cframe.Position.Y - size.Y / 2) - pivot.Position.Y
	local _, rotY, _   = pivot:ToEulerAnglesYXZ()
	ruinsClone:PivotTo(
		CFrame.new(clickPos - Vector3.new(0, bottomOffset, 0)) * CFrame.Angles(0, rotY, 0)
	)
	ruinsClone.Parent = Workspace

	-- Hide chest
	local chest = ruinsClone:FindFirstChild("Cofre", true)
	local chestRelative
	if chest then
		chestRelative = ruinsClone:GetPivot():ToObjectSpace(chest:GetPivot())
		chest.Parent  = ServerStorage
	else
		return
	end

	-- Spawn goblins
	local goblinCount = math.random(DungeonConfig.MinGoblinCount, DungeonConfig.MaxGoblinCount)
	spawnGoblinsAround(clickPos, goblinCount, function()

		-- VICTORY: reveal chest
		local chestTargetPos = ruinsClone:GetPivot():ToWorldSpace(chestRelative)

		-- Audio
		local sPart        = Instance.new("Part")
		sPart.Anchored     = true
		sPart.CanCollide   = false
		sPart.Transparency = 1
		sPart.Position     = chestTargetPos.Position
		sPart.Parent       = Workspace
		local snd              = Instance.new("Sound")
		snd.SoundId            = DungeonConfig.VictorySoundId
		snd.Volume             = DungeonConfig.VictoryVolume
		snd.RollOffMaxDistance = DungeonConfig.VictoryRollOffMax
		snd.Parent             = sPart
		snd:Play()
		Debris:AddItem(sPart, 12)

		-- Golden FX
		local att2         = Instance.new("Attachment", sPart)
		local fx2          = Instance.new("ParticleEmitter", att2)
		fx2.Texture        = "rbxassetid://244221448"
		fx2.Color          = ColorSequence.new(Color3.fromRGB(255, 215, 0))
		fx2.Rate           = 120
		fx2.Speed          = NumberRange.new(8, 15)
		fx2.Lifetime       = NumberRange.new(0.6, 1.2)
		task.delay(1.5, function() fx2.Enabled = false end)

		-- Place chest & fill loot
		chest:PivotTo(chestTargetPos)
		chest.Parent = ruinsClone

		-- Narrar evento espacialmente para todos los jugadores en un radio de 120 studs
		local dungeonRadius = 120
		local narEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
		if narEvent then
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
					local dist = (p.Character.HumanoidRootPart.Position - chestTargetPos.Position).Magnitude
					if dist <= dungeonRadius then
						narEvent:FireClient(p, "Que fue ese sonido.. termino..?", true)
					end
				end
			end
		end
		local chestFolder = chest:FindFirstChild("ChestInventory")
		if not chestFolder then
			chestFolder        = Instance.new("Folder")
			chestFolder.Name   = "ChestInventory"
			chestFolder.Parent = chest
		end
		chestFolder:ClearAllChildren()
		populateLoot(chestFolder)

		-- CLEANUP: wait delay, then fade & destroy
		task.spawn(function()
			print("[DungeonManager] Dungeon cleanup in " .. DungeonConfig.CleanupDelay .. "s...")
			task.wait(DungeonConfig.CleanupDelay)
			print("[DungeonManager] Starting fadeout over " .. DungeonConfig.FadeDuration .. "s...")
			if ruinsClone and ruinsClone.Parent then
				fadeAndDestroy(ruinsClone)
			end
		end)
	end)
end)
