local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local tool = script.Parent
local spawnEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SpawnDungeonEvent")

local ui = nil
local indicator = nil
local renderConnection = nil

local function cleanup()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if indicator then
		indicator:Destroy()
		indicator = nil
	end
	if ui then
		ui.Enabled = false
	end
end

tool.Equipped:Connect(function()
	-- Find or wait for UI
	local pgui = player:WaitForChild("PlayerGui", 5)
	if pgui then
		ui = pgui:WaitForChild("DungeonsUI", 5)
		if ui then
			ui.Enabled = true
		end
	end
	
	-- Create red flat neon cylinder indicator
	indicator = Instance.new("Part")
	indicator.Name = "Dungeon_Indicator"
	indicator.Shape = Enum.PartType.Cylinder
	indicator.Size = Vector3.new(0.2, 40, 40)
	indicator.Color = Color3.fromRGB(255, 50, 50)
	indicator.Material = Enum.Material.Neon
	indicator.Transparency = 0.7
	indicator.Anchored = true
	indicator.CanCollide = false
	indicator.CanQuery = false
	indicator.CanTouch = false
	indicator.Parent = game.Workspace
	
	-- Connect render step to update position
	renderConnection = RunService.RenderStepped:Connect(function()
		if indicator and mouse then
			-- Cast flat on ground, rotate cylinder axis along vertical
			indicator.CFrame = CFrame.new(mouse.Hit.Position) * CFrame.Angles(0, 0, math.pi / 2)
		end
	end)
end)

tool.Unequipped:Connect(cleanup)
tool.Destroying:Connect(cleanup)

tool.Activated:Connect(function()
	if mouse and mouse.Hit then
		spawnEvent:FireServer(mouse.Hit.Position)
	end
end)
