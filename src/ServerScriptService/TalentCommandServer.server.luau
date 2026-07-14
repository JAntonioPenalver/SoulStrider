local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShowTalentScreen = ReplicatedStorage:WaitForChild("ShowTalentScreen")
local SelectTalent = ReplicatedStorage:WaitForChild("SelectTalent")
local TalentModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TalentModule"))
local LoreModule = require(game:GetService("ServerScriptService"):WaitForChild("ServerModules"):WaitForChild("LoreModule"))

-- RemoteFunction para que el cliente pida sus datos de perfil
local GetProfileData = ReplicatedStorage:FindFirstChild("GetProfileData")
if not GetProfileData then
	GetProfileData = Instance.new("RemoteFunction")
	GetProfileData.Name = "GetProfileData"
	GetProfileData.Parent = ReplicatedStorage
end

-- Tabla para guardar talentos por jugador
local playerTalents = {}

-- Lista de administradores (puedes añadir más IDs aquí)
local ADMIN_IDS = {138637118, 223933804} 

local function isAdmin(player)
    return table.find(ADMIN_IDS, player.UserId) ~= nil or player.UserId == game.CreatorId
end

local function giveTalents(targetPlayer)
    local allTalents = TalentModule.Talents
    local selected = {}
    local available = {}
    
    -- Obtener talentos que ya posee el jugador para evitar duplicados
    local owned = {}
    local tf = targetPlayer:FindFirstChild("Talents")
    if tf then
        for _, v in ipairs(tf:GetChildren()) do
            owned[v.Name] = true
        end
    end
    
    -- Copiar talentos de la tabla original, omitiendo los ya obtenidos
    for _, t in ipairs(allTalents) do
        if not owned[t.Name] then
            table.insert(available, t)
        end
    end
    
    -- Elegir hasta 3 talentos únicos de los disponibles
    for i = 1, 3 do
        if #available == 0 then break end
        local index = math.random(1, #available)
        table.insert(selected, available[index])
        table.remove(available, index)
    end
    
    -- Si no queda ningún talento por obtener, notificar y retornar
    if #selected == 0 then
        local NotifyPlayerEvent = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
        if NotifyPlayerEvent then
            NotifyPlayerEvent:FireClient(targetPlayer, "Sistema", "Ya tienes todos los talentos disponibles.")
        end
        
        -- Limpiar el estado de barajas pendientes del jugador
        targetPlayer:SetAttribute("PendingDecks", 0)
        targetPlayer:SetAttribute("TalentScreenActive", false)
        return
    end
    
    ShowTalentScreen:FireClient(targetPlayer, selected)
end

-- Sistema de Cola para Barajas de Talentos
local QueueTalentDeck = ReplicatedStorage:FindFirstChild("QueueTalentDeck")
if not QueueTalentDeck then
    QueueTalentDeck = Instance.new("BindableEvent")
    QueueTalentDeck.Name = "QueueTalentDeck"
    QueueTalentDeck.Parent = ReplicatedStorage
end

local function queueTalentDeck(player)
    local pending = player:GetAttribute("PendingDecks") or 0
    player:SetAttribute("PendingDecks", pending + 1)
    
    if not player:GetAttribute("TalentScreenActive") then
        player:SetAttribute("TalentScreenActive", true)
        giveTalents(player)
    end
end

QueueTalentDeck.Event:Connect(queueTalentDeck)

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        if not isAdmin(player) then return end
        
        local split = string.split(message, " ")
        local command = string.lower(split[1])
        
        if command == "/givetalent" then
            local targetName = split[2]
            if not targetName then return end
            
            if string.lower(targetName) == "all" then
                for _, p in ipairs(Players:GetPlayers()) do
                    queueTalentDeck(p)
                end
            else
                for _, p in ipairs(Players:GetPlayers()) do
                    if string.sub(string.lower(p.Name), 1, #targetName) == string.lower(targetName) then
                        queueTalentDeck(p)
                        break
                    end
                end
            end
        end
    end)
end)

-- Manejar la elección del talento
SelectTalent.OnServerEvent:Connect(function(player, talentData)
    if typeof(talentData) ~= "table" or not talentData.Name then return end
    
    -- Guardar el talento en la tabla del jugador
    if not playerTalents[player.UserId] then
        playerTalents[player.UserId] = {}
        -- Intentar cargar los que ya tiene en la carpeta si no están en la tabla
        local tf = player:FindFirstChild("Talents")
        if tf then
            for _, v in ipairs(tf:GetChildren()) do
                table.insert(playerTalents[player.UserId], v.Name)
            end
        end
    end
    
    -- Evitar duplicados (doble check de seguridad)
    if table.find(playerTalents[player.UserId], talentData.Name) then 
        local pending = player:GetAttribute("PendingDecks") or 0
        if pending > 1 then
            player:SetAttribute("PendingDecks", pending - 1)
            task.wait(0.5)
            giveTalents(player)
        else
            player:SetAttribute("PendingDecks", 0)
            player:SetAttribute("TalentScreenActive", false)
        end
        return 
    end
    
    table.insert(playerTalents[player.UserId], talentData.Name)
    
    -- Crear valor físico en el jugador para acceso rápido
    local tf = player:FindFirstChild("Talents") or Instance.new("Folder", player)
    tf.Name = "Talents"
    local tVal = Instance.new("StringValue")
    tVal.Name = talentData.Name
    tVal.Value = talentData.Name
    tVal.Parent = tf
    
    -- Persistir en DataStore vía LoreModule
    LoreModule.SaveTalents(player, playerTalents[player.UserId])
    
    local NotifyPlayerEvent = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
    if NotifyPlayerEvent then
        NotifyPlayerEvent:FireClient(player, "Sistema", "Has obtenido el talento: " .. talentData.Name)
    end
    
    -- Manejar barajas en cola
    local pending = player:GetAttribute("PendingDecks") or 0
    if pending > 1 then
        player:SetAttribute("PendingDecks", pending - 1)
        task.wait(0.5) -- Delay suave para la transición de cierre/apertura
        giveTalents(player)
    else
        player:SetAttribute("PendingDecks", 0)
        player:SetAttribute("TalentScreenActive", false)
    end
end)

-- Limpiar datos al salir
Players.PlayerRemoving:Connect(function(player)
    playerTalents[player.UserId] = nil
end)

-- Responder con datos de perfil del jugador
GetProfileData.OnServerInvoke = function(player)
    local fn = player:FindFirstChild("LoreFirstName")
    local ln = player:FindFirstChild("LoreLastName")
    local ag = player:FindFirstChild("LoreAge")
    
    -- Asegurar que la tabla local esté sincronizada con los valores guardados
    if not playerTalents[player.UserId] then
        playerTalents[player.UserId] = {}
        local tf = player:FindFirstChild("Talents")
        if tf then
            for _, v in ipairs(tf:GetChildren()) do
                table.insert(playerTalents[player.UserId], v.Name)
            end
        end
    end

    return {
        firstName = fn and fn.Value or "",
        lastName  = ln and ln.Value or "",
        age       = ag and ag.Value or 0,
        gender    = player:FindFirstChild("LoreGender") and player.LoreGender.Value or "Masculino",
        origin    = player:FindFirstChild("LoreOrigin") and player.LoreOrigin.Value or "Campamento Ether",
        rank      = player:FindFirstChild("LoreRank") and player.LoreRank.Value or "Novato",
        race      = player:FindFirstChild("LoreRace") and player.LoreRace.Value or "???",
        pvpKills  = player:FindFirstChild("PvpKills") and player.PvpKills.Value or 0,
        pveKills  = player:FindFirstChild("PveKills") and player.PveKills.Value or 0,
        talents   = playerTalents[player.UserId] or {},
    }
end
