local UniversalPrompt = {}

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

function UniversalPrompt.Show(titleText, yesText, noText)
	-- Evitar prompts duplicados
	local existing = playerGui:FindFirstChild("UniversalPromptGui")
	if existing then existing:Destroy() end

	local thread = coroutine.running()
	local selectedResult = nil

	-- 1. ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "UniversalPromptGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	-- 2. CanvasGroup principal para fade suave y bordes redondeados limpios
	local frame = Instance.new("CanvasGroup")
	frame.Name = "PromptFrame"
	frame.Size = UDim2.new(0.35, 0, 0.25, 0)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	frame.GroupTransparency = 1 -- Inicialmente invisible para Fade In
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	-- Relación de aspecto para consistencia responsive en móvil, consola y PC
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 2.3
	aspect.Parent = frame

	-- Bordes redondeados
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	-- Borde metálico suave
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1.2
	stroke.Transparency = 0.85
	stroke.Parent = frame

	-- Degradado metálico oscuro del fondo
	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 24, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 16))
	})
	bgGrad.Rotation = 45
	bgGrad.Parent = frame

	-- 3. Label de Título / Pregunta
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(0.9, 0, 0.45, 0)
	titleLabel.Position = UDim2.new(0.5, 0, 0.1, 0)
	titleLabel.AnchorPoint = Vector2.new(0.5, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText or "¿Desea aceptar la petición?"
	titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
	titleLabel.TextSize = 20
	titleLabel.Font = Enum.Font.Garamond
	titleLabel.TextWrapped = true
	titleLabel.TextScaled = true
	titleLabel.Parent = frame

	local titleSizeConstraint = Instance.new("UITextSizeConstraint")
	titleSizeConstraint.MaxTextSize = 22
	titleSizeConstraint.Parent = titleLabel

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Thickness = 1.5
	titleStroke.Transparency = 0.7
	titleStroke.Parent = titleLabel

	-- 4. Contenedor de Botones
	local btnContainer = Instance.new("Frame")
	btnContainer.Name = "ButtonContainer"
	btnContainer.Size = UDim2.new(0.95, 0, 0.32, 0)
	btnContainer.Position = UDim2.new(0.5, 0, 0.58, 0)
	btnContainer.AnchorPoint = Vector2.new(0.5, 0)
	btnContainer.BackgroundTransparency = 1
	btnContainer.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Padding = UDim.new(0.08, 0)
	listLayout.Parent = btnContainer

	-- Función auxiliar para crear y estilizar botones
	local function createButton(name, text, normalColor, strokeColor, gradStart, gradEnd, textCol, resultValue)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0.4, 0, 0.85, 0)
		btn.BackgroundColor3 = normalColor
		btn.BorderSizePixel = 0
		btn.Text = text
		btn.TextColor3 = textCol
		btn.TextSize = 16
		btn.Font = Enum.Font.Garamond
		btn.Parent = btnContainer

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn

		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = strokeColor
		btnStroke.Thickness = 1
		btnStroke.Transparency = 0.5
		btnStroke.Parent = btn

		local btnGrad = Instance.new("UIGradient")
		btnGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, gradStart),
			ColorSequenceKeypoint.new(1, gradEnd)
		})
		btnGrad.Rotation = 90
		btnGrad.Parent = btn

		local btnScale = Instance.new("UIScale")
		btnScale.Parent = btn

		-- Animaciones de Hover y Click
		btn.MouseEnter:Connect(function()
			TweenService:Create(btnScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
			TweenService:Create(btnStroke, TweenInfo.new(0.2), {Transparency = 0.1, Thickness = 1.4}):Play()
		end)

		btn.MouseLeave:Connect(function()
			TweenService:Create(btnScale, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {Scale = 1.0}):Play()
			TweenService:Create(btnStroke, TweenInfo.new(0.2), {Transparency = 0.5, Thickness = 1}):Play()
		end)

		btn.MouseButton1Down:Connect(function()
			TweenService:Create(btnScale, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Scale = 0.95}):Play()
		end)

		btn.MouseButton1Click:Connect(function()
			if selectedResult ~= nil then return end
			selectedResult = resultValue

			-- Desvanecimiento de salida (Fade Out)
			local tOut = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {GroupTransparency = 1})
			tOut:Play()
			tOut.Completed:Connect(function()
				screenGui:Destroy()
				task.spawn(thread, selectedResult)
			end)
		end)
	end

	-- Crear Botón Sí (Verde Oscuro Esmeralda)
	createButton(
		"YesButton",
		yesText or "Sí",
		Color3.fromRGB(30, 45, 35),
		Color3.fromRGB(70, 160, 90),
		Color3.fromRGB(40, 65, 48),
		Color3.fromRGB(20, 32, 24),
		Color3.fromRGB(220, 255, 230),
		true
	)

	-- Crear Botón No (Rojo Oscuro Crimson)
	createButton(
		"NoButton",
		noText or "No",
		Color3.fromRGB(45, 30, 30),
		Color3.fromRGB(160, 70, 70),
		Color3.fromRGB(65, 40, 40),
		Color3.fromRGB(32, 20, 20),
		Color3.fromRGB(255, 220, 220),
		false
	)

	-- 5. Fade In al iniciar
	TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()

	-- Retorna y cede el hilo hasta que el jugador elija
	return coroutine.yield()
end

return UniversalPrompt
