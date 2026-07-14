local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeStatEvent = ReplicatedStorage:WaitForChild("UpgradeStatEvent")
local CreateCharacterEvent = ReplicatedStorage:WaitForChild("CreateCharacterEvent")
local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)

-- RemoteFunctions para la nueva interfaz EstadisticasV3
local ToggleTalentEquip = ReplicatedStorage:FindFirstChild("ToggleTalentEquip")
if not ToggleTalentEquip then
    ToggleTalentEquip = Instance.new("RemoteFunction")
    ToggleTalentEquip.Name = "ToggleTalentEquip"
    ToggleTalentEquip.Parent = ReplicatedStorage
end

local UnlockProficiencyNode = ReplicatedStorage:FindFirstChild("UnlockProficiencyNode")
if not UnlockProficiencyNode then
    UnlockProficiencyNode = Instance.new("RemoteFunction")
    UnlockProficiencyNode.Name = "UnlockProficiencyNode"
    UnlockProficiencyNode.Parent = ReplicatedStorage
end

-- Configuración del árbol de habilidades para UnlockProficiencyNode
local PROFICIENCY_NODES = {
    -- SKILLS TREE (X shape branching from center)
    ["Skills_Center"] = { Branch = "Skills", Prereqs = {}, Cost = 1 },
    
    ["Skills_TL1"] = { Branch = "Skills", Prereqs = {"Skills_Center"}, Cost = 1 },
    ["Skills_TL2"] = { Branch = "Skills", Prereqs = {"Skills_TL1"}, Cost = 1 },
    
    ["Skills_TR1"] = { Branch = "Skills", Prereqs = {"Skills_Center"}, Cost = 1 },
    ["Skills_TR2"] = { Branch = "Skills", Prereqs = {"Skills_TR1"}, Cost = 1 },
    
    ["Skills_BL1"] = { Branch = "Skills", Prereqs = {"Skills_Center"}, Cost = 1 },
    ["Skills_BL2"] = { Branch = "Skills", Prereqs = {"Skills_BL1"}, Cost = 1 },
    
    ["Skills_BR1"] = { Branch = "Skills", Prereqs = {"Skills_Center"}, Cost = 1 },
    ["Skills_BR2"] = { Branch = "Skills", Prereqs = {"Skills_BR1"}, Cost = 1 },

    -- LOGISTICIAN TREE
    ["Logistician_Root"] = { Branch = "Logistician", Prereqs = {}, Cost = 1 },
    
    ["Logistician_A1"] = { Branch = "Logistician", Prereqs = {"Logistician_Root"}, Cost = 1 },
    ["Logistician_A2"] = { Branch = "Logistician", Prereqs = {"Logistician_A1"}, Cost = 1 },
    
    ["Logistician_B1"] = { Branch = "Logistician", Prereqs = {"Logistician_Root"}, Cost = 1 },
    ["Logistician_B2"] = { Branch = "Logistician", Prereqs = {"Logistician_B1"}, Cost = 1 },
    
    ["Logistician_C1"] = { Branch = "Logistician", Prereqs = {"Logistician_B1"}, Cost = 1 },
    ["Logistician_C2"] = { Branch = "Logistician", Prereqs = {"Logistician_C1"}, Cost = 1 },

    -- MEDIC TREE
    ["Medic_Root"] = { Branch = "Medic", Prereqs = {}, Cost = 1 },
    
    ["Medic_A1"] = { Branch = "Medic", Prereqs = {"Medic_Root"}, Cost = 1 },
    ["Medic_A2"] = { Branch = "Medic", Prereqs = {"Medic_A1"}, Cost = 1 },
    
    ["Medic_B1"] = { Branch = "Medic", Prereqs = {"Medic_Root"}, Cost = 1 },
    ["Medic_B2"] = { Branch = "Medic", Prereqs = {"Medic_B1"}, Cost = 1 },
    
    ["Medic_C1"] = { Branch = "Medic", Prereqs = {"Medic_Root"}, Cost = 1 },
    ["Medic_C2"] = { Branch = "Medic", Prereqs = {"Medic_C1"}, Cost = 1 },
}

-- Manejar Creación de Personaje
CreateCharacterEvent.OnServerEvent:Connect(function(player, name, lastName, age, gender)
    LoreModule.SetLore(player, name, lastName, age, gender)
end)

local function updatePhysicalStats(player)
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    
    local resilience = player:FindFirstChild("Resilience") and player.Resilience.Value or 1
    local relicMaxHealthBuff = player:GetAttribute("RelicMaxHealthBuff") or 0
    local newMax = 100 + (resilience * 10) + relicMaxHealthBuff
    
    hum.MaxHealth = newMax
    hum.Health = math.min(hum.Health + 10, newMax) -- Curar un poco al subir/cargar
    
    -- Enlazar WalkSpeed con Celerity: Base 16 + 0.5 por cada punto de Celerity
    local celerity = player:FindFirstChild("Celerity") and player.Celerity.Value or 1
    local newSpeed = 16 + (celerity * 0.5)
    hum.WalkSpeed = newSpeed
end

local function syncStats(player)
    local mapping = {
        Resilience = "Resistencia",
        Celerity = "Velocidad",
        Strength = "Energia",
        Dexterity = "Stamina"
    }
    
    for newStat, legacyStat in pairs(mapping) do
        local newObj = player:FindFirstChild(newStat)
        local legacyObj = player:FindFirstChild(legacyStat)
        
        if newObj and legacyObj then
            -- Sincronización inicial
            legacyObj.Value = newObj.Value
            
            -- Sincronizar new -> legacy
            newObj.Changed:Connect(function(val)
                if legacyObj.Value ~= val then
                    legacyObj.Value = val
                end
            end)
            
            -- Sincronizar legacy -> new (limitar al máximo de 9)
            legacyObj.Changed:Connect(function(val)
                if newObj.Value ~= val then
                    newObj.Value = math.min(val, 9)
                end
            end)
        end
    end
end

UpgradeStatEvent.OnServerEvent:Connect(function(player, statName)    
    local allowedStats = {
        ["Dexterity"] = true,
        ["Resilience"] = true,
        ["Precision"] = true,
        ["Strength"] = true,
        ["Celerity"] = true,
        ["Mana"] = true
    }
    
    local legacyMapping = {
        ["Resistencia"] = "Resilience",
        ["Velocidad"] = "Celerity",
        ["Energia"] = "Strength",
        ["Stamina"] = "Dexterity",
    }
    
    if legacyMapping[statName] then
        statName = legacyMapping[statName]
    end
    
    if not allowedStats[statName] then return end
    
    local points = player:FindFirstChild("AttributePoints")
    local statValue = player:FindFirstChild(statName)
    
    if points and statValue and points.Value > 0 then
        -- Limitar a un máximo de 9 para Dexterity, Resilience, Precision, Strength, Celerity
        if statName ~= "Mana" and statValue.Value >= 9 then
            return
        end
        
        points.Value = points.Value - 1
        statValue.Value = statValue.Value + 1
        
        if statName == "Resilience" or statName == "Celerity" then
            updatePhysicalStats(player)
        end
        
        LoreModule.SaveAllData(player)
    end
end)

-- Implementación de ToggleTalentEquip
ToggleTalentEquip.OnServerInvoke = function(player, talentName)
    if not player or typeof(talentName) ~= "string" or talentName == "" then
        return false, "Entrada inválida"
    end
    
    local talentsFolder = player:FindFirstChild("Talents")
    if not talentsFolder or not talentsFolder:FindFirstChild(talentName) then
        return false, "No posees este talento"
    end
    
    local equippedFolder = player:FindFirstChild("EquippedTalents")
    if not equippedFolder then
        equippedFolder = Instance.new("Folder", player)
        equippedFolder.Name = "EquippedTalents"
    end
    
    local existing = equippedFolder:FindFirstChild(talentName)
    if existing then
        -- Desequipar talento
        existing:Destroy()
        pcall(function()
            LoreModule.SaveAllData(player)
        end)
        return true, "Talento desequipado con éxito"
    else
        -- Equipar talento
        if #equippedFolder:GetChildren() >= 4 then
            return false, "Límite de 4 talentos equipados alcanzado"
        end
        
        local val = Instance.new("StringValue")
        val.Name = talentName
        val.Value = talentName
        val.Parent = equippedFolder
        
        pcall(function()
            LoreModule.SaveAllData(player)
        end)
        return true, "Talento equipado con éxito"
    end
end

-- Implementación de UnlockProficiencyNode
UnlockProficiencyNode.OnServerInvoke = function(player, nodeId)
    if not player or typeof(nodeId) ~= "string" or nodeId == "" then
        return false, "Entrada inválida"
    end
    
    local nodeConfig = PROFICIENCY_NODES[nodeId]
    if not nodeConfig then
        return false, "Nodo de habilidad no existe"
    end
    
    local profFolder = player:FindFirstChild("UnlockedProficiencies")
    if not profFolder then
        profFolder = Instance.new("Folder", player)
        profFolder.Name = "UnlockedProficiencies"
    end
    
    if profFolder:FindFirstChild(nodeId) then
        return false, "Habilidad ya desbloqueada"
    end
    
    -- Validar prerrequisitos
    for _, prereqId in ipairs(nodeConfig.Prereqs) do
        if not profFolder:FindFirstChild(prereqId) then
            return false, "No cumples con los requisitos previos"
        end
    end
    
    -- Validar puntos de la sub-pestaña correspondiente
    local pointStatName = nodeConfig.Branch .. "Points"
    local pointsStat = player:FindFirstChild(pointStatName)
    if not pointsStat or pointsStat.Value < nodeConfig.Cost then
        return false, "Puntos insuficientes en " .. nodeConfig.Branch
    end
    
    -- Consumir puntos y desbloquear
    pointsStat.Value = pointsStat.Value - nodeConfig.Cost
    
    local val = Instance.new("StringValue")
    val.Name = nodeId
    val.Value = nodeId
    val.Parent = profFolder
    
    pcall(function()
        LoreModule.SaveAllData(player)
    end)
    
    return true, "Habilidad desbloqueada con éxito"
end

game.Players.PlayerAdded:Connect(function(player)
    LoreModule.Setup(player)
    syncStats(player)
    
    -- Escuchar cambios en buff de reliquia
    player:GetAttributeChangedSignal("RelicMaxHealthBuff"):Connect(function()
        updatePhysicalStats(player)
    end)
    
    local resilienceVal = player:FindFirstChild("Resilience")
    if resilienceVal then
        resilienceVal.Changed:Connect(function()
            updatePhysicalStats(player)
        end)
    end
    
    local celerityVal = player:FindFirstChild("Celerity")
    if celerityVal then
        celerityVal.Changed:Connect(function()
            updatePhysicalStats(player)
        end)
    end
    
    player.CharacterAdded:Connect(function(char)
        task.wait(1.5)
        updatePhysicalStats(player)
    end)
end)

-- Hot-reload para jugadores conectados
for _, player in ipairs(game.Players:GetPlayers()) do
    syncStats(player)
    
    player:GetAttributeChangedSignal("RelicMaxHealthBuff"):Connect(function()
        updatePhysicalStats(player)
    end)
    
    local resilienceVal = player:FindFirstChild("Resilience")
    if resilienceVal then
        resilienceVal.Changed:Connect(function()
            updatePhysicalStats(player)
        end)
    end
    
    local celerityVal = player:FindFirstChild("Celerity")
    if celerityVal then
        celerityVal.Changed:Connect(function()
            updatePhysicalStats(player)
        end)
    end
end
