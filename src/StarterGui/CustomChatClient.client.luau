local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
local generalChannel = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")

local ADMIN_IDS = {138637118, 223933804}
local isAdmin = table.find(ADMIN_IDS, player.UserId) ~= nil or player.UserId == game.CreatorId

local COMMANDS = {
    {name = "/w", usage = "/w [mensaje]", desc = "Susurro local", admin = false},
    {name = "/t", usage = "/t [mensaje]", desc = "Pensamiento", admin = false},
    {name = "/notify", usage = "/notify [jugador] [mensaje]", desc = "Enviar notificación", admin = true},
    {name = "/pd on", usage = "/pd on", desc = "Activar Muerte Permanente", admin = true},
    {name = "/pd off", usage = "/pd off", desc = "Desactivar Muerte Permanente", admin = true},
    {name = "/aceptar", usage = "/aceptar [jugador]", desc = "Aceptar jugador en muerte permanente", admin = true},
    {name = "/lowsanity", usage = "/lowsanity [jugador/all] [mensaje]", desc = "Efecto cordura baja", admin = true},
    {name = "/trauma", usage = "/trauma [jugador/all] [mensaje]", desc = "Efecto trauma", admin = true},
    {name = "/blind", usage = "/blind [jugador/all]", desc = "Cegar jugador", admin = true},
    {name = "/unblind", usage = "/unblind [jugador/all]", desc = "Quitar ceguera", admin = true},
    {name = "/cutscene", usage = "/cutscene [on/off/vintage]", desc = "Controlar cinemática (on | off | vintage)", admin = true},
    {name = "/sethunger", usage = "/sethunger [jugador] [cantidad]", desc = "Ajustar hambre (0-100)", admin = true},
    {name = "/setthirst", usage = "/setthirst [jugador] [cantidad]", desc = "Ajustar sed (0-100)", admin = true},
    {name = "/wipe", usage = "/wipe [jugador]", desc = "Borrar datos de personaje", admin = true},
    {name = "/narrar", usage = "/narrar [mensaje]", desc = "Mensaje de narrador global", admin = true},
    {name = "/track", usage = "/track [jugador/all]", desc = "Rastrear vida de jugador", admin = true},
    {name = "/untrack", usage = "/untrack [jugador/all]", desc = "Quitar rastreo", admin = true},
    {name = "/help", usage = "/help [mensaje]", desc = "Pedir ayuda a administración", admin = false},
    {name = "/healthbar", usage = "/healthbar [jugador] [NombreDisplay]", desc = "Mostrar barra de jefe", admin = true},
    {name = "/ragdoll", usage = "/ragdoll [jugador]", desc = "Tirar al jugador al suelo", admin = true},
    {name = "/unragdoll", usage = "/unragdoll [jugador]", desc = "Levantar al jugador", admin = true},
    {name = "/weather", usage = "/weather rain | nieve | niebla | clear", desc = "Controlar el clima global", admin = true},
    {name = "/nombre", usage = "/nombre [jugador] [nombre]", desc = "Cambiar nombre de rol", admin = true},
    {name = "/apellido", usage = "/apellido [jugador] [apellido]", desc = "Cambiar apellido de rol", admin = true},
    {name = "/glow", usage = "/glow [jugador]", desc = "Añadir brillo blanco al jugador", admin = true},
    {name = "/unglow", usage = "/unglow [jugador]", desc = "Quitar brillo al jugador", admin = true},
    {name = "/injuries", usage = "/injuries [condicion] [jugador/all]", desc = "Aplicar condicion medica (ciego/piernorota/brazoroto/extremidad/perdidaojo/concusion/esquizofrenia). Para quitar: /injuries remove [condicion] [jugador]", admin = true},
    {name = "/efecto", usage = "/efecto [tipo] [jugador/all] [tiempo]", desc = "Lanzar efecto personalizado (heartbeat/ansiedad/fear/prowler/presion)", admin = true},
    {name = "/pensamiento", usage = "/pensamiento [jugador/all] [mensaje]", desc = "Vignette negra y mensaje instantáneo", admin = true},
    {name = "/givetalent", usage = "/givetalent [jugador/all]", desc = "Dar 3 talentos aleatorios", admin = true},
    {name = "/give", usage = "/give [jugador/all] [item]", desc = "Dar un objeto (apilable si ya tiene)", admin = true},
    {name = "/pay", usage = "/pay [oro,plata,bronce] [jugador] [cantidad]", desc = "Dar dinero a un jugador", admin = true},
    {name = "/rejoin", usage = "/rejoin", desc = "Reiniciar conexión a la experiencia", admin = false},
    {name = "/menu", usage = "/menu", desc = "Volver al menú principal", admin = false},
    {name = "/givepoints", usage = "/givepoints [jugador] [cantidad]", desc = "Dar puntos de atributo", admin = true},
	{name = "/musica", usage = "/musica", desc = "Abrir menu de musica", admin = true},
    {name = "/honor", usage = "/honor [jugador] [%]", desc = "Ajustar nivel de honor (0-100)", admin = true},
    {name = "/infeccion", usage = "/infeccion [jugador] [%]", desc = "Ajustar nivel de infección (0-100)", admin = true},
    {name = "/libros", usage = "/libros", desc = "Obtener todos los libros de magia", admin = true},
    {name = "/setmagiclevel", usage = "/setmagiclevel [jugador] [nivel]", desc = "Establecer nivel de magia (0-5)", admin = true},
    {name = "/instant", usage = "/instant [mensaje]", desc = "Mensaje narrativo local instantáneo", admin = true},
    {name = "/grantinstant", usage = "/grantinstant [jugador]", desc = "Permitir a un jugador usar /instant", admin = true},
    {name = "/revokeinstant", usage = "/revokeinstant [jugador]", desc = "Quitar permiso de usar /instant", admin = true},
    {name = "/herida", usage = "/herida [jugador] [ZonaCuerpo] [Herida]", desc = "Provocar una herida avanzada", admin = true},
	{name = "/medicos", usage = "/medicos [jugador]", desc = "Recibir suministros médicos", admin = true},
    {name = "/givetp", usage = "/givetp [jugador] [cantidad]", desc = "Dar Puntos de Talento (TP)", admin = true},
    {name = "/removefilter on", usage = "/removefilter on", desc = "Remover filtro de chat para idiomas personalizados", admin = true},
    {name = "/removefilter off", usage = "/removefilter off", desc = "Reestablecer filtro de chat", admin = true},
    {name = "/ciclardia on", usage = "/ciclardia on", desc = "Activar ciclo del día progresivo (1h/10m)", admin = true},
    {name = "/ciclardia off", usage = "/ciclardia off", desc = "Desactivar ciclo del día progresivo", admin = true},
    {name = "/tiempo", usage = "/tiempo [0-24]", desc = "Establecer la hora del día (ClockTime)", admin = true},
    {name = "/time", usage = "/time [0-24]", desc = "Establecer la hora del día (ClockTime)", admin = true},
    {name = "/data", usage = "/data [jugador]", desc = "Modificar datos de personaje", admin = true},
    {name = "/checklives", usage = "/checklives [jugador]", desc = "Consultar vidas (PKs)", admin = true},
    {name = "/setlives", usage = "/setlives [jugador] [cantidad]", desc = "Establecer vidas (PKs)", admin = true},
    {name = "/ignore", usage = "/ignore [jugador]", desc = "NPCs ignoran al jugador", admin = true},
    {name = "/unignore", usage = "/unignore [jugador]", desc = "NPCs dejan de ignorar al jugador", admin = true},
}

-- UI Creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CustomChatGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 1000000
ScreenGui.Parent = script.Parent

local Frame = Instance.new("Frame")
Frame.Name = "ChatBarFrame"
Frame.Size = UDim2.new(0, 280, 0, 32)
Frame.Position = UDim2.new(0, 20, 0, 20)
Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Frame.BackgroundTransparency = 0.5
Frame.BorderSizePixel = 0
Frame.Visible = false
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 4)
UICorner.Parent = Frame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(255, 255, 255)
UIStroke.Transparency = 0.8
UIStroke.Thickness = 1
UIStroke.Parent = Frame

local Icon = Instance.new("TextLabel")
Icon.Name = "ChatIcon"
Icon.Size = UDim2.new(0, 32, 1, 0)
Icon.Position = UDim2.new(0, 5, 0, 0)
Icon.BackgroundTransparency = 1
Icon.Text = "💬"
Icon.TextSize = 14
Icon.TextColor3 = Color3.fromRGB(255, 255, 255)
Icon.Font = Enum.Font.GothamMedium
Icon.Parent = Frame

local TextBox = Instance.new("TextBox")
TextBox.Name = "ChatInput"
TextBox.Size = UDim2.new(1, -45, 1, 0)
TextBox.Position = UDim2.new(0, 35, 0, 0)
TextBox.BackgroundTransparency = 1
TextBox.Font = Enum.Font.Gotham
TextBox.TextSize = 14
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.PlaceholderText = "Escribir..."
TextBox.PlaceholderColor3 = Color3.fromRGB(180, 180, 180)
TextBox.Text = ""
TextBox.ClearTextOnFocus = true
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.Parent = Frame

-- Suggestion UI
local SuggestionFrame = Instance.new("ScrollingFrame")
SuggestionFrame.Name = "SuggestionFrame"
SuggestionFrame.Size = UDim2.new(0, 300, 0, 150)
SuggestionFrame.Position = UDim2.new(0, 20, 0, 55)
SuggestionFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
SuggestionFrame.BackgroundTransparency = 0.5
SuggestionFrame.BorderSizePixel = 0
SuggestionFrame.Visible = false
SuggestionFrame.ScrollBarThickness = 4
SuggestionFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
SuggestionFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
SuggestionFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
SuggestionFrame.Parent = ScreenGui

local SuggestionCorner = Instance.new("UICorner")
SuggestionCorner.CornerRadius = UDim.new(0, 4)
SuggestionCorner.Parent = SuggestionFrame

local SuggestionList = Instance.new("UIListLayout")
SuggestionList.Padding = UDim.new(0, 2)
SuggestionList.Parent = SuggestionFrame

local SuggestionPadding = Instance.new("UIPadding")
SuggestionPadding.PaddingTop = UDim.new(0, 5)
SuggestionPadding.PaddingBottom = UDim.new(0, 5)
SuggestionPadding.PaddingLeft = UDim.new(0, 10)
SuggestionPadding.PaddingRight = UDim.new(0, 10)
SuggestionPadding.Parent = SuggestionFrame

TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")
	if message.Text then
		local formatted = message.Text:gsub("%*%*(.-)%*%*", "<b>%1</b>")
		formatted = formatted:gsub("%*(.-)%*", "<i>%1</i>")
		props.Text = formatted
	end
	return props
end

local function updateSuggestions(text)
    for _, child in pairs(SuggestionFrame:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    
    if text == "" or string.sub(text, 1, 1) ~= "/" then
        SuggestionFrame.Visible = false
        return
    end
    
    local matches = {}
    local lowerText = string.lower(text)
    
    for _, cmd in pairs(COMMANDS) do
        local hasAccess = true
        if cmd.admin then
            if not isAdmin then
                if cmd.name == "/instant" and player:GetAttribute("CanUseInstant") == true then
                    hasAccess = true
                else
                    hasAccess = false
                end
            end
        end
        if not hasAccess then continue end
        
        if string.sub(cmd.name, 1, #lowerText) == lowerText then
            table.insert(matches, cmd)
        end
    end
    
    if #matches > 0 then
        SuggestionFrame.Visible = true
        local totalHeight = (#matches * 25) + 10
        SuggestionFrame.Size = UDim2.new(0, 300, 0, math.min(totalHeight, 150))
        
        for _, match in pairs(matches) do
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 0, 20)
            label.BackgroundTransparency = 1
            label.Text = "<b>" .. match.name .. "</b> <font color='#aaaaaa'>" .. match.usage .. "</font>"
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.TextSize = 13
            label.Font = Enum.Font.Gotham
            label.RichText = true
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = SuggestionFrame
        end
    else
        SuggestionFrame.Visible = false
    end
end

TextBox:GetPropertyChangedSignal("Text"):Connect(function()
    updateSuggestions(TextBox.Text)
end)

-- Function to show/hide chat bar
local function setChatVisible(visible)
    if visible then
        Frame.Visible = true
        Frame.BackgroundTransparency = 1
        UIStroke.Transparency = 1
        TextBox.TextTransparency = 1
        Icon.TextTransparency = 1
        
        TextBox:CaptureFocus()
        
        TweenService:Create(Frame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {BackgroundTransparency = 0.5}):Play()
        TweenService:Create(UIStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Transparency = 0.8}):Play()
        TweenService:Create(TextBox, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {TextTransparency = 0}):Play()
        TweenService:Create(Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {TextTransparency = 0}):Play()
    else
        TextBox:ReleaseFocus()
        local t1 = TweenService:Create(Frame, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {BackgroundTransparency = 1})
        local t2 = TweenService:Create(UIStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Transparency = 1})
        local t3 = TweenService:Create(TextBox, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {TextTransparency = 1})
        local t4 = TweenService:Create(Icon, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {TextTransparency = 1})
        
        t1:Play()
        t2:Play()
        t3:Play()
        t4:Play()
        
        t1.Completed:Connect(function()
            if not TextBox:IsFocused() then
                Frame.Visible = false
            end
        end)
    end
end

-- Key detection
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.Slash or input.KeyCode == Enum.KeyCode.T then
        setChatVisible(true)
        task.wait()
        TextBox.Text = ""
    end
end)

-- Cerrar chat y limpiar texto cuando se abre el menú de Roblox (evita envíos accidentales al salir con Esc + L + Enter)
game:GetService("GuiService").MenuOpened:Connect(function()
    setChatVisible(false)
    TextBox.Text = ""
end)

TextBox.FocusLost:Connect(function(enterPressed)
    local message = TextBox.Text
    if enterPressed and #message > 0 then
        task.spawn(function()
            local lowerMsg = string.lower(message)
            if string.sub(lowerMsg, 1, 3) == "/w " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/w", string.sub(message, 4))
            elseif string.sub(lowerMsg, 1, 3) == "/t " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/t", string.sub(message, 4))
            elseif string.sub(lowerMsg, 1, 8) == "/notify " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/notify", string.sub(message, 9))
            elseif string.sub(lowerMsg, 1, 7) == "/track " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/track", string.sub(message, 8))
            elseif string.sub(lowerMsg, 1, 9) == "/untrack " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/untrack", string.sub(message, 10))
            elseif string.sub(lowerMsg, 1, 6) == "/help " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/help", string.sub(message, 7))
            elseif string.sub(lowerMsg, 1, 11) == "/healthbar " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/healthbar", string.sub(message, 12))
            elseif lowerMsg == "/healthbar" then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/healthbar", "")
            elseif string.sub(lowerMsg, 1, 9) == "/ragdoll " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/ragdoll", string.sub(message, 10))
            elseif string.sub(lowerMsg, 1, 11) == "/unragdoll " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/unragdoll", string.sub(message, 12))
            elseif string.sub(lowerMsg, 1, 9) == "/weather " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/weather", string.sub(message, 10))
            elseif string.sub(lowerMsg, 1, 8) == "/nombre " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/nombre", string.sub(message, 9))
            elseif string.sub(lowerMsg, 1, 10) == "/apellido " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/apellido", string.sub(message, 11))
            elseif string.sub(lowerMsg, 1, 6) == "/glow " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/glow", string.sub(message, 7))
            elseif string.sub(lowerMsg, 1, 8) == "/unglow " then
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer("/unglow", string.sub(message, 9))
            elseif string.sub(lowerMsg, 1, 4) == "/pd " or lowerMsg == "/pd" or
                   string.sub(lowerMsg, 1, 6) == "/data " or lowerMsg == "/data" or
                   string.sub(lowerMsg, 1, 12) == "/checklives " or lowerMsg == "/checklives" or
                   string.sub(lowerMsg, 1, 10) == "/setlives " or lowerMsg == "/setlives" or
                   string.sub(lowerMsg, 1, 7) == "/blind " or lowerMsg == "/blind" or
                   string.sub(lowerMsg, 1, 9) == "/unblind " or lowerMsg == "/unblind" or
                   string.sub(lowerMsg, 1, 10) == "/cutscene " or lowerMsg == "/cutscene" or
                   string.sub(lowerMsg, 1, 6) == "/wipe " or
                   string.sub(lowerMsg, 1, 8) == "/narrar " or
                   string.sub(lowerMsg, 1, 11) == "/lowsanity " or
                   string.sub(lowerMsg, 1, 8) == "/trauma " or
                   string.sub(lowerMsg, 1, 11) == "/sethunger " or
                   string.sub(lowerMsg, 1, 11) == "/setthirst " or
                   string.sub(lowerMsg, 1, 6) == "/give " or lowerMsg == "/give" or
                   string.sub(lowerMsg, 1, 5) == "/pay " or lowerMsg == "/pay" or
                   string.sub(lowerMsg, 1, 8) == "/efecto " or lowerMsg == "/efecto" or
                   string.sub(lowerMsg, 1, 13) == "/pensamiento " or lowerMsg == "/pensamiento" or
                   string.sub(lowerMsg, 1, 11) == "/givetalent " or lowerMsg == "/givetalent" or
                   string.sub(lowerMsg, 1, 7) == "/honor " or lowerMsg == "/honor" or
                   string.sub(lowerMsg, 1, 11) == "/infeccion " or lowerMsg == "/infeccion" or
                   lowerMsg == "/rejoin" or
                   lowerMsg == "/menu" or
                   string.sub(lowerMsg, 1, 12) == "/givepoints " or lowerMsg == "/givepoints" or
                   string.sub(lowerMsg, 1, 9) == "/instant " or lowerMsg == "/instant" or
                   string.sub(lowerMsg, 1, 14) == "/grantinstant " or lowerMsg == "/grantinstant" or
                   string.sub(lowerMsg, 1, 15) == "/revokeinstant " or lowerMsg == "/revokeinstant" or
                   string.sub(lowerMsg, 1, 8) == "/herida " or lowerMsg == "/herida" or
                   string.sub(lowerMsg, 1, 9) == "/medicos " or lowerMsg == "/medicos" or
                   string.sub(lowerMsg, 1, 8) == "/givetp " or lowerMsg == "/givetp" or
                   string.sub(lowerMsg, 1, 7) == "/libros" or
                   string.sub(lowerMsg, 1, 15) == "/setmagiclevel " or lowerMsg == "/setmagiclevel" or
                   string.sub(lowerMsg, 1, 10) == "/injuries " or lowerMsg == "/injuries" or
                   string.sub(lowerMsg, 1, 14) == "/removefilter " or lowerMsg == "/removefilter" or
                   string.sub(lowerMsg, 1, 11) == "/ciclardia " or lowerMsg == "/ciclardia" or
                   string.sub(lowerMsg, 1, 8) == "/tiempo " or lowerMsg == "/tiempo" or
                   string.sub(lowerMsg, 1, 9) == "/aceptar " or lowerMsg == "/aceptar" or
                   string.sub(lowerMsg, 1, 8) == "/ignore " or lowerMsg == "/ignore" or
                   string.sub(lowerMsg, 1, 10) == "/unignore " or lowerMsg == "/unignore" or
                   string.sub(lowerMsg, 1, 6) == "/time " or lowerMsg == "/time" then
                
                local split = string.split(message, " ")
                local cmdName = split[1]
                local cmdArgs = table.concat(split, " ", 2)
                ReplicatedStorage:WaitForChild("RPCommandEvent"):FireServer(cmdName, cmdArgs)
            else
                if ReplicatedStorage:GetAttribute("ChatFilterDisabled") == true then
                    ReplicatedStorage:WaitForChild("UnfilteredChatEvent"):FireServer(message)
                else
                    generalChannel:SendAsync(message)
                end
            end
        end)
    end
    setChatVisible(false)
    SuggestionFrame.Visible = false
    TextBox.Text = ""
end)

-- Detect being hit while typing (DESACTIVADO TEMPORALMENTE A PETICIÓN)
--[[
local currentHumanoid = nil
local lastHealth = 100
local healthConnection = nil

local function connectHumanoid(char)
    if healthConnection then
        healthConnection:Disconnect()
        healthConnection = nil
    end
    if not char then return end
    local humanoid = char:WaitForChild("Humanoid", 5)
    if humanoid then
        currentHumanoid = humanoid
        lastHealth = humanoid.Health
        healthConnection = humanoid.HealthChanged:Connect(function(health)
            if health < lastHealth then
                if TextBox:IsFocused() then
                    local message = TextBox.Text
                    TextBox.Text = message .. "-"
                    TextBox:ReleaseFocus(true)
                end
            end
            lastHealth = health
        end)
    end
end

player.CharacterAdded:Connect(connectHumanoid)
if player.Character then
    connectHumanoid(player.Character)
end
--]]
