local replicatedStorage = game:GetService("ReplicatedStorage")
local events = replicatedStorage:WaitForChild("Events")
local buildEvent = events:WaitForChild("BuildStructureEvent")
local prefabs = replicatedStorage:WaitForChild("Prefabs")
local config = require(replicatedStorage:WaitForChild("PrefabConfig"))

local function isValidStructure(name)
	for _, item in ipairs(config.Structures) do
		if item.Name == name then return true end
	end
	return false
end

local buildCooldowns = {}
local HAMMER_COOLDOWN = 2
local HAMMER_SOUND_ID = "rbxassetid://9118631050"
local HAMMER_VOLUME = 4 -- Puedes subir este número para que suene más fuerte

local function getRequiredClicks(name)
	for _, item in ipairs(config.Structures) do
		if item.Name == name then return item.RequiredClicks or 1 end
	end
	return 1
end

buildEvent.OnServerEvent:Connect(function(player, action, itemName, data)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	
	if action == "PlaceBlueprint" then
		local name = itemName
		local cframe = data
		
		if not isValidStructure(name) then return end
		
		if (character.HumanoidRootPart.Position - cframe.Position).Magnitude > 50 then return end
		
		local original = prefabs:FindFirstChild(name)
		if original then
			local blueprint = original:Clone()
			blueprint.Name = name .. "_Blueprint"
			blueprint:SetAttribute("IsBlueprint", true)
			blueprint:SetAttribute("OriginalName", name)
			blueprint:SetAttribute("CurrentClicks", 0)
			blueprint:SetAttribute("RequiredClicks", getRequiredClicks(name))
			
			for _, part in ipairs(blueprint:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0.5
					part.Color = Color3.fromRGB(0, 255, 255)
					part.Material = Enum.Material.Neon
					part.CanCollide = false
					part.Anchored = true
				end
			end
			
			blueprint:PivotTo(cframe)
			blueprint.Parent = workspace
		end
	elseif action == "FinalizeBuild" then
		local blueprintModel = itemName 
		if blueprintModel and blueprintModel:GetAttribute("IsBlueprint") then
			-- Cooldown check
			local level = 1
			local maestriasFolder = player:FindFirstChild("Maestrias")
			if maestriasFolder then
				local construccion = maestriasFolder:FindFirstChild("Construccion")
				if construccion and construccion:FindFirstChild("Level") then
					level = construccion.Level.Value
				end
			end
			local dynamicCooldown = math.max(0.3, HAMMER_COOLDOWN - (level - 1) * 0.1)
			
			local lastClick = buildCooldowns[player.UserId] or 0
			if tick() - lastClick < dynamicCooldown then return end
			buildCooldowns[player.UserId] = tick()
			
			-- Distance check for building
			if (character.HumanoidRootPart.Position - blueprintModel:GetPivot().Position).Magnitude > 40 then return end
			
			-- Play animation
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
				local anim = Instance.new("Animation")
				anim.AnimationId = "rbxassetid://131129717971511"
				local track = animator:LoadAnimation(anim)
				if track then
					track:Play()
					track:AdjustSpeed(math.max(1, 2.0 / dynamicCooldown))
				end
			end
			
			-- Play sound
			local sound = Instance.new("Sound")
			sound.SoundId = HAMMER_SOUND_ID
			sound.Volume = HAMMER_VOLUME
			sound.Parent = blueprintModel:FindFirstChildWhichIsA("BasePart") or workspace.Terrain
			sound:Play()
			game:GetService("Debris"):AddItem(sound, 2)
			
			-- Emit construction particles from Workspace.Construccion for 1 second
			local construccionPart = workspace:FindFirstChild("Construccion")
			if construccionPart then
				local targetPart = blueprintModel:FindFirstChildWhichIsA("BasePart")
				if targetPart then
					-- Create temporary attachment at the center of the target part
					local attachment = Instance.new("Attachment")
					attachment.Name = "ConstructionVFXAttachment"
					attachment.Parent = targetPart
					
					-- Clone all particle emitters from Workspace.Construccion
					local clonedEmitters = {}
					for _, child in ipairs(construccionPart:GetChildren()) do
						if child:IsA("ParticleEmitter") then
							local clone = child:Clone()
							clone.Enabled = true
							clone.Parent = attachment
							table.insert(clonedEmitters, clone)
						end
					end
					
					-- Keep emitting for 1 second, then stop emitting and cleanup after particles disappear
					task.spawn(function()
						task.wait(1.0)
						for _, emitter in ipairs(clonedEmitters) do
							emitter.Enabled = false
						end
						task.wait(2.0)
						attachment:Destroy()
					end)
				end
			end
			
			-- Increment clicks
			local current = blueprintModel:GetAttribute("CurrentClicks") or 0
			local required = blueprintModel:GetAttribute("RequiredClicks") or 1
			current = current + 1
			blueprintModel:SetAttribute("CurrentClicks", current)
			
			-- Otorgar experiencia de Construcción
			local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)
			LoreModule.AddMasteryXP(player, "Construccion", 1)
			
			-- Visual feedback (optional: make it less transparent or change color?)
			-- For now just check if finished
			if current >= required then
				local originalName = blueprintModel:GetAttribute("OriginalName")
				local original = prefabs:FindFirstChild(originalName)
				if original then
					local finalModel = original:Clone()
					finalModel:PivotTo(blueprintModel:GetPivot())
					finalModel.Parent = workspace
					blueprintModel:Destroy()
				end
			end
		end
	end
end)
