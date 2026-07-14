local UIManager = {}
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local bars = {}
local activeCooldowns = {}
local updateConnection = nil

function UIManager.Init()
	-- Disconnect old connection if any
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	-- Disconnect active cooldowns if any (on respawn)
	for spellName, cd in pairs(activeCooldowns) do
		if cd.Connection then
			cd.Connection:Disconnect()
		end
		if cd.Frame then
			cd.Frame:Destroy()
		end
	end
	activeCooldowns = {}

	local survivalHUD = playerGui:WaitForChild("SurvivalHUD", 10)
	if survivalHUD then
		local container = survivalHUD:WaitForChild("HUDContainer")
		
		local function registerBar(name, folderName)
			local barFrame = container:FindFirstChild(folderName)
			if barFrame then
				bars[name] = {
					Container = barFrame,
					Fill = barFrame:WaitForChild("Fill")
				}
			end
		end
		
		registerBar("Mana", "ManaBarContainer")
		registerBar("Hunger", "HungerBarContainer")
		registerBar("Thirst", "ThirstBarContainer")
		
		local cooldownsContainer = survivalHUD:FindFirstChild("CooldownsContainer")
		if cooldownsContainer then
			cooldownsContainer.Visible = false
		end
	end
	
	-- Conectar actualizaciones
	updateConnection = game:GetService("RunService").RenderStepped:Connect(function()
		UIManager.Update()
	end)
end

function UIManager.Update()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChild("Humanoid")
	if not hum then return end
	
	-- Actualizar Mana
	local mVal = player:GetAttribute("Mana") or 0
	local mmVal = player:GetAttribute("MaxMana") or 100
	UIManager.SetBarValue("Mana", math.clamp(mVal / mmVal, 0, 1))
	
	-- Actualizar Hambre
	local hVal = player:FindFirstChild("Hunger")
	if hVal then 
		UIManager.SetBarValue("Hunger", math.clamp(hVal.Value / 100, 0, 1)) 
	end
	
	-- Actualizar Sed
	local tVal = player:FindFirstChild("Thirst")
	if tVal then 
		UIManager.SetBarValue("Thirst", math.clamp(tVal.Value / 100, 0, 1)) 
	end
end

function UIManager.SetBarValue(name, pct)
	local bar = bars[name]
	if not bar then return end
	
	-- Animación suave de la barra horizontal
	TweenService:Create(bar.Fill, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
		Size = UDim2.new(pct, 0, 1, 0)
	}):Play()
end

function UIManager.StartCooldown(spellName, duration)
	-- Redireccionar cooldowns de magia al nuevo MagicSkillsGui
	if spellName == "Fuego_BolaDeFuego" or spellName == "Hielo_LanzaDeHielo" or spellName == "Tierra_Fisura" then
		if _G.StartMagicCooldown then
			pcall(function()
				_G.StartMagicCooldown(spellName, duration)
			end)
		end
		return
	end

	local survivalHUD = playerGui:WaitForChild("SurvivalHUD", 10)
	if not survivalHUD then return end
	local cooldownsContainer = survivalHUD:WaitForChild("CooldownsContainer")
	
	-- Cancel existing cooldown for this spell if any
	if activeCooldowns[spellName] then
		activeCooldowns[spellName].Connection:Disconnect()
		activeCooldowns[spellName].Frame:Destroy()
		activeCooldowns[spellName] = nil
	end
	
	-- Create item frame
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = spellName
	itemFrame.Size = UDim2.new(1, 0, 0, 21)
	itemFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
	itemFrame.BackgroundTransparency = 0
	itemFrame.BorderSizePixel = 1
	itemFrame.BorderColor3 = Color3.fromRGB(35, 35, 40)
	
	local stroke = Instance.new("UIStroke", itemFrame)
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(45, 45, 50)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	
	local padding = Instance.new("UIPadding", itemFrame)
	padding.PaddingLeft = UDim.new(0, 2)
	padding.PaddingRight = UDim.new(0, 2)
	padding.PaddingTop = UDim.new(0, 2)
	padding.PaddingBottom = UDim.new(0, 2)
	
	local fill = Instance.new("Frame", itemFrame)
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	
	local gradient = Instance.new("UIGradient", fill)
	gradient.Color = ColorSequence.new(Color3.fromRGB(70, 70, 75), Color3.fromRGB(45, 45, 48))
	
	local label = Instance.new("TextLabel", itemFrame)
	label.Name = "Label"
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = spellName .. ": " .. string.format("%.1f", duration) .. "s"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 10
	label.Font = Enum.Font.RobotoMono
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 3
	
	local txtStroke = Instance.new("UIStroke", label)
	txtStroke.Thickness = 1
	txtStroke.Color = Color3.fromRGB(0, 0, 0)
	txtStroke.Transparency = 0.5
	
	itemFrame.Parent = cooldownsContainer
	cooldownsContainer.Visible = true -- Show container
	
	local startTime = os.clock()
	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local remaining = math.max(0, duration - elapsed)
		
		if remaining <= 0 then
			connection:Disconnect()
			itemFrame:Destroy()
			activeCooldowns[spellName] = nil
			
			-- Check if there are any active cooldowns left
			local hasActive = false
			for _, _ in pairs(activeCooldowns) do
				hasActive = true
				break
			end
			if not hasActive then
				cooldownsContainer.Visible = false -- Hide container
			end
		else
			fill.Size = UDim2.new(remaining / duration, 0, 1, 0)
			label.Text = spellName .. ": " .. string.format("%.1f", remaining) .. "s"
		end
	end)
	
	activeCooldowns[spellName] = {
		Frame = itemFrame,
		Connection = connection
	}
end

return UIManager
