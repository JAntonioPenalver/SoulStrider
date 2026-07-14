local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local NotifyPlayerEvent = ReplicatedStorage:WaitForChild("NotifyPlayerEvent")

-- Si ya existe una interfaz de notificaciones de la vida anterior, la erradicamos para evitar botones huérfanos bugueados
local oldGui = playerGui:FindFirstChild("NotificationGui")
if oldGui then
    oldGui:Destroy()
end

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NotificationGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "NotificationContainer"
container.Size = UDim2.new(0, 300, 1, 0)
container.Position = UDim2.new(1, -320, 0, 0)
container.BackgroundTransparency = 1
container.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local padding = Instance.new("UIPadding")
padding.PaddingBottom = UDim.new(0, 20)
padding.PaddingRight = UDim.new(0, 20)
padding.Parent = container

local function createNotification(senderName, message, isHelp)
    -- Play notification sound
    local notifSound = Instance.new("Sound")
    notifSound.SoundId = "rbxassetid://18595195017"
    notifSound.Volume = 0.2
    notifSound.Parent = game:GetService("SoundService")
    notifSound:Play()
    game.Debris:AddItem(notifSound, 2)

    local frame = Instance.new("Frame")
    frame.Name = "Notification"
    frame.Size = UDim2.new(1, 0, 0, 0) -- Height will be dynamic
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.4
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = container
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = isHelp and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 255)
    stroke.Transparency = isHelp and 0.4 or 0.9
    stroke.Thickness = isHelp and 2 or 1
    stroke.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Name = "Sender"
    title.Size = UDim2.new(1, -40, 0, 20)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = isHelp and "🆘 AYUDA: " .. string.upper(senderName) or "NOTIFICACIÓN"
    title.TextColor3 = isHelp and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(200, 200, 200)
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    
    local msgLabel = Instance.new("TextLabel")
    msgLabel.Name = "Message"
    msgLabel.Size = UDim2.new(1, -40, 0, 0)
    msgLabel.Position = UDim2.new(0, 10, 0, 28)
    msgLabel.BackgroundTransparency = 1
    msgLabel.Text = message
    msgLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    msgLabel.TextSize = 14
    msgLabel.Font = Enum.Font.Gotham
    msgLabel.TextWrapped = true
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.TextYAlignment = Enum.TextYAlignment.Top
    msgLabel.Parent = frame
    
    -- Calculate height
    local textHeight = game:GetService("TextService"):GetTextSize(message, 14, Enum.Font.Gotham, Vector2.new(260, 400)).Y
    local finalHeight = math.clamp(textHeight + 50, 60, 450) -- Mínimo 60, Máximo 450
    
    msgLabel.Size = UDim2.new(1, -40, 0, textHeight)
    frame.Size = UDim2.new(1, 0, 0, 0)
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -25, 0, 5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 10
    closeBtn.Active = true
    closeBtn.Parent = frame
    
    local function close()
        if not frame or not frame.Parent then return end
        local t = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1
        })
        t:Play()
        t.Completed:Connect(function()
            frame:Destroy()
        end)
    end
    
    closeBtn.MouseButton1Click:Connect(close)
    
    -- Animation in
    TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 0, finalHeight)
    }):Play()
    
    task.delay(10, close)
end

NotifyPlayerEvent.OnClientEvent:Connect(createNotification)

local function clearNotifications()
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Frame") and child.Name == "Notification" then
            child:Destroy()
        end
    end
end

local function setupCharacter(char)
    local humanoid = char:WaitForChild("Humanoid", 10)
    if humanoid then
        humanoid.Died:Connect(clearNotifications)
    end
end

if player.Character then
    setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)
