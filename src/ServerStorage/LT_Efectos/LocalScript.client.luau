local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local mouse = player:GetMouse()
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")

local tool = script.Parent
local vfxConfig = require(replicatedStorage:WaitForChild("VFXConfig"))
local ltvfx = replicatedStorage:WaitForChild("LTVFX")
local effectEvent = replicatedStorage:WaitForChild("Events"):WaitForChild("VFXEffectEvent")

local ui = player:WaitForChild("PlayerGui"):WaitForChild("EfectosUI")
local mainFrame = ui:WaitForChild("MainFrame")
local itemLabel = mainFrame:WaitForChild("ItemLabel")
local leftBtn = mainFrame:WaitForChild("LeftButton")
local rightBtn = mainFrame:WaitForChild("RightButton")

local effectsList = { "Explosion", "Fuego" }
local currentIndex = 1
local isEquipped = false
local indicator = nil
local currentPosition = Vector3.new()

local function updateUI()
	local effectName = effectsList[currentIndex]
	local config = vfxConfig.Effects[effectName]
	itemLabel.TextTransparency = 1
	itemLabel.Text = "< " .. effectName .. " >"
	tweenService:Create(itemLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
	
	-- Pulse effect on frame
	local originalSize = UDim2.new(0, 350, 0, 70)
	mainFrame.Size = UDim2.new(0, 360, 0, 80)
	tweenService:Create(mainFrame, TweenInfo.new(0.3), {Size = originalSize}):Play()
	
	-- Update indicator size/shape to match template hitbox (respecting fallback size)
	if indicator then
		local template = ltvfx:FindFirstChild(effectName)
		if template and template:IsA("BasePart") then
			local targetSize = template.Size
			if targetSize.X <= 2 or targetSize.Y <= 2 or targetSize.Z <= 2 then
				targetSize = config.HitboxSize or Vector3.new(10, 10, 10)
			end
			indicator.Size = targetSize
			if indicator:IsA("Part") and template:IsA("Part") then
				indicator.Shape = template.Shape
			end
		else
			indicator.Size = config.HitboxSize or Vector3.new(10, 10, 10)
		end
	end
end

local function clearIndicator()
	if indicator then
		indicator:Destroy()
		indicator = nil
	end
end

local function createIndicator()
	clearIndicator()
	local effectName = effectsList[currentIndex]
	local config = vfxConfig.Effects[effectName]
	local template = ltvfx:FindFirstChild(effectName)
	
	indicator = Instance.new("Part")
	indicator.Name = "VFX_Hitbox_Indicator"
	indicator.Color = Color3.fromRGB(255, 0, 0)
	indicator.Material = Enum.Material.Neon
	indicator.Transparency = 0.75
	indicator.CanCollide = false
	indicator.CanQuery = false
	indicator.CanTouch = false
	indicator.Anchored = true
	
	if template and template:IsA("BasePart") then
		local targetSize = template.Size
		if targetSize.X <= 2 or targetSize.Y <= 2 or targetSize.Z <= 2 then
			targetSize = config.HitboxSize or Vector3.new(10, 10, 10)
		end
		indicator.Size = targetSize
		if template:IsA("Part") then
			indicator.Shape = template.Shape
		end
	else
		indicator.Size = config.HitboxSize or Vector3.new(10, 10, 10)
	end
	
	indicator.Parent = workspace
end

local function nextItem()
	currentIndex = currentIndex + 1
	if currentIndex > #effectsList then currentIndex = 1 end
	updateUI()
end

local function prevItem()
	currentIndex = currentIndex - 1
	if currentIndex < 1 then currentIndex = #effectsList end
	updateUI()
end

leftBtn.MouseButton1Click:Connect(prevItem)
rightBtn.MouseButton1Click:Connect(nextItem)

tool.Equipped:Connect(function()
	isEquipped = true
	ui.Enabled = true
	updateUI()
	createIndicator()
end)

tool.Unequipped:Connect(function()
	isEquipped = false
	ui.Enabled = false
	clearIndicator()
end)

userInputService.InputBegan:Connect(function(input, processed)
	if processed or not isEquipped then return end
	if input.KeyCode == Enum.KeyCode.Left then
		prevItem()
	elseif input.KeyCode == Enum.KeyCode.Right then
		nextItem()
	end
end)

runService.RenderStepped:Connect(function()
	if isEquipped and indicator and character:FindFirstChild("HumanoidRootPart") then
		local ray = mouse.UnitRay
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character, indicator}
		params.FilterType = Enum.RaycastFilterType.Exclude
		
		local result = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
		
		if result then
			currentPosition = result.Position
			-- Center position offset by half the indicator size Y to sit flat on the surface
			local targetPos = currentPosition + Vector3.new(0, indicator.Size.Y / 2, 0)
			indicator.CFrame = CFrame.new(targetPos)
		else
			-- Move far away if no hit
			indicator.CFrame = CFrame.new(0, -1000, 0)
		end
	end
end)

tool.Activated:Connect(function()
	if isEquipped and indicator then
		local effectName = effectsList[currentIndex]
		effectEvent:FireServer(effectName, currentPosition)
	end
end)