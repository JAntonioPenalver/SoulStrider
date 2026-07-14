local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local replicatedStorage = game:GetService("ReplicatedStorage")
local buildEvent = replicatedStorage:WaitForChild("Events"):WaitForChild("BuildStructureEvent")

local tool = script.Parent

local lastClick = 0
local COOLDOWN = 1.4

tool.Activated:Connect(function()
	if tick() - lastClick < COOLDOWN then return end
	
	local character = player.Character
	if not character then return end
	
	local target = mouse.Target
	if target then
		local distance = (character.HumanoidRootPart.Position - target.Position).Magnitude
		if distance > 40 then return end
		
		-- Check if the target itself or any ancestor is a blueprint
		local blueprint = target
		while blueprint and not blueprint:GetAttribute("IsBlueprint") do
			blueprint = blueprint.Parent
		end
		
		if blueprint and blueprint:GetAttribute("IsBlueprint") then
			lastClick = tick()
			buildEvent:FireServer("FinalizeBuild", blueprint)
		end
	end
end)
