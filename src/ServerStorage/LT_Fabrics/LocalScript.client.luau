local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local mouse = player:GetMouse()
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")

local tool = script.Parent
local prefabs = replicatedStorage:WaitForChild("Prefabs")
local config = require(replicatedStorage:WaitForChild("PrefabConfig"))
local buildEvent = replicatedStorage:WaitForChild("Events"):WaitForChild("BuildStructureEvent")

local ui = player:WaitForChild("PlayerGui"):WaitForChild("FabricsUI")
local mainFrame = ui:WaitForChild("MainFrame")
local itemLabel = mainFrame:WaitForChild("ItemLabel")
local leftBtn = mainFrame:WaitForChild("LeftButton")
local rightBtn = mainFrame:WaitForChild("RightButton")

local currentIndex = 1
local ghostModel = nil
local isEquipped = false
local relativePivotOffset = CFrame.new()
local manualRotation = 0 -- Rotation in degrees
local currentGhostCFrame = CFrame.new()

local originalRotation = CFrame.new()

local function updateUI()
	local item = config.Structures[currentIndex]
	itemLabel.TextTransparency = 1
	itemLabel.Text = "< " .. item.DisplayName .. " >"
	tweenService:Create(itemLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
	
	-- Pulse effect on frame
	local originalSize = UDim2.new(0, 350, 0, 70)
	mainFrame.Size = UDim2.new(0, 360, 0, 80)
	tweenService:Create(mainFrame, TweenInfo.new(0.3), {Size = originalSize}):Play()
end

local function clearGhost()
	if ghostModel then
		ghostModel:Destroy()
		ghostModel = nil
	end
end

local function createGhost()
	clearGhost()
	local item = config.Structures[currentIndex]
	local original = prefabs:FindFirstChild(item.Name)
	if original then
		originalRotation = original:GetPivot().Rotation
		ghostModel = original:Clone()
		ghostModel.Name = "Ghost"
		
		for _, part in ipairs(ghostModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0.5
				part.Color = Color3.fromRGB(0, 255, 255)
				part.Material = Enum.Material.Neon
				part.CanCollide = false
				part.CanQuery = false
				part.Anchored = true
			end
		end
		ghostModel.Parent = workspace
		ghostModel:PivotTo(CFrame.new(0, -1000, 0)) -- Hide initially
	end
end

local function nextItem()
	currentIndex = currentIndex + 1
	if currentIndex > #config.Structures then currentIndex = 1 end
	manualRotation = 0
	updateUI()
	createGhost()
end

local function prevItem()
	currentIndex = currentIndex - 1
	if currentIndex < 1 then currentIndex = #config.Structures end
	manualRotation = 0
	updateUI()
	createGhost()
end

leftBtn.MouseButton1Click:Connect(prevItem)
rightBtn.MouseButton1Click:Connect(nextItem)

tool.Equipped:Connect(function()
	isEquipped = true
	ui.Enabled = true
	manualRotation = 0
	updateUI()
	createGhost()
end)

tool.Unequipped:Connect(function()
	isEquipped = false
	ui.Enabled = false
	clearGhost()
end)

userInputService.InputBegan:Connect(function(input, processed)
	if processed or not isEquipped then return end
	if input.KeyCode == Enum.KeyCode.Left then
		prevItem()
	elseif input.KeyCode == Enum.KeyCode.Right then
		nextItem()
	elseif input.KeyCode == Enum.KeyCode.R then
		manualRotation = (manualRotation + 90) % 360
	end
end)

runService.RenderStepped:Connect(function()
	if isEquipped and ghostModel and character:FindFirstChild("HumanoidRootPart") then
		local ray = mouse.UnitRay
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character, ghostModel}
		params.FilterType = Enum.RaycastFilterType.Exclude
		
		local result = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
		
		if result then
			local hitPos = result.Position
			local item = config.Structures[currentIndex]
			
			local _, modelSize
			if ghostModel:IsA("Model") then
				_, modelSize = ghostModel:GetBoundingBox()
			else
				modelSize = ghostModel.Size
			end
			
			-- 1. Base Yaw (Facing player's direction)
			local lookVector = character.HumanoidRootPart.CFrame.LookVector
			local yaw = math.atan2(-lookVector.X, -lookVector.Z)
			
			-- 2. Apply Yaw + Manual Rotation (R key)
			local totalYaw = yaw + math.rad(manualRotation)
			
			-- 3. Combine with Original Rotation
			-- This preserves any tilt the model has in ReplicatedStorage while rotating it horizontally
			local rotationCFrame = CFrame.Angles(0, totalYaw, 0) * originalRotation
			
			-- 4. Apply Custom Config Rotation (if any)
			if item.RotationOffset then
				rotationCFrame = rotationCFrame * CFrame.Angles(math.rad(item.RotationOffset.X), math.rad(item.RotationOffset.Y), math.rad(item.RotationOffset.Z))
			end
			
			-- 5. Calculate Position (Center height + YOffset)
			local yOffset = item.YOffset or 0
			local targetCenter = hitPos + Vector3.new(0, (modelSize.Y / 2) + yOffset, 0)
			
			-- 6. Calculate Final Pivot
			currentGhostCFrame = CFrame.new(targetCenter) * rotationCFrame
			
			ghostModel:PivotTo(currentGhostCFrame)
		else
			-- If no hit, move it far away so it's not visible at the old position
			ghostModel:PivotTo(CFrame.new(0, -1000, 0))
		end
	end
end)

tool.Activated:Connect(function()
	if ghostModel then
		local item = config.Structures[currentIndex]
		buildEvent:FireServer("PlaceBlueprint", item.Name, currentGhostCFrame)
	end
end)
