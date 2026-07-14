local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local tool = script.Parent
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local MagicConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MagicConfig"))
local MagicEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("MagicEvent")

local spellName = "Hielo_LanzaDeHielo"
local config = MagicConfig.Spells[spellName]

local lastCastTime = 0

tool.Activated:Connect(function()
	-- Verify MagicLevel client-side
	local requiredLevelName = config.Level
	local requiredLevelInt = 0
	if requiredLevelName == MagicConfig.Levels.Principiante then requiredLevelInt = 1
	elseif requiredLevelName == MagicConfig.Levels.Intermedio then requiredLevelInt = 2
	elseif requiredLevelName == MagicConfig.Levels.Avanzado then requiredLevelInt = 3
	elseif requiredLevelName == MagicConfig.Levels.Sagrado then requiredLevelInt = 4
	elseif requiredLevelName == MagicConfig.Levels.Divino then requiredLevelInt = 5
	end
	
	local playerLevel = player:GetAttribute("MagicLevel") or 0
	if playerLevel < requiredLevelInt then
		return
	end

	local now = os.clock()
	if now - lastCastTime < config.Cooldown then
		return
	end
	
	local char = player.Character
	
	-- Verify Mana client-side before sending
	local currentMana = player:GetAttribute("Mana") or 0
	local maxMana = player:GetAttribute("MaxMana") or 100
	local costPercent = config.ManaCost or 0
	local actualCost = (costPercent / 100) * maxMana
	
	if currentMana < actualCost then
		return
	end
	
	lastCastTime = now
	
	-- Start Cooldown HUD item on client
	local UIManager = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("UIManager"))
	UIManager.StartCooldown(spellName, config.Cooldown)
	
	-- Target position along the camera's look direction from the character to prevent shiftlock issues
	local camera = workspace.CurrentCamera
	local targetPos
	if char and char:FindFirstChild("HumanoidRootPart") and camera then
		local hrp = char.HumanoidRootPart
		local startPos = hrp.Position + hrp.CFrame.LookVector * 3
		targetPos = startPos + camera.CFrame.LookVector * 100
	else
		targetPos = mouse.Hit.Position
	end
	
	-- Fire to the server
	MagicEvent:FireServer(spellName, targetPos)
end)
