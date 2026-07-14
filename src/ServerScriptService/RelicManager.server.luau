local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RelicConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RelicConfig"))
local relicEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RelicEvent")

-- Asegurar que la carpeta de reliquias equipadas exista
local function getEquippedRelicsFolder(player)
    local folder = player:FindFirstChild("EquippedRelics")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "EquippedRelics"
        folder.Parent = player
    end
    return folder
end

-- Recalcular buffs de reliquias y asignar atributos
local function updateRelicBuffs(player)
    local folder = getEquippedRelicsFolder(player)
    
    local totalBuffs = {
        MaxHealth = 0,
        Speed = 0,
        Damage = 0,
        Stamina = 0
    }
    
    for _, val in ipairs(folder:GetChildren()) do
        if val:IsA("StringValue") and val.Value ~= "" then
            local relicName = val.Value
            local data = RelicConfig.Relics[relicName]
            if data then
                totalBuffs[data.BuffType] = totalBuffs[data.BuffType] + data.BuffValue
            end
        end
    end
    
    player:SetAttribute("RelicMaxHealthBuff", totalBuffs.MaxHealth)
    player:SetAttribute("RelicSpeedBuff", totalBuffs.Speed)
    player:SetAttribute("RelicDamageBuff", totalBuffs.Damage)
    player:SetAttribute("RelicStaminaBuff", totalBuffs.Stamina)
    
    -- Disparar evento a cliente para actualizaciones visuales inmediatas
    relicEvent:FireClient(player, "UpdateBuffs", totalBuffs)
end

-- Desequipar reliquia de un slot
local function unequipSlot(player, slotName)
    local folder = getEquippedRelicsFolder(player)
    local val = folder:FindFirstChild(slotName)
    if val and val.Value ~= "" then
        local relicName = val.Value
        val.Value = ""
        
        -- Destruir accesorio visual del personaje si existe
        local char = player.Character
        if char then
            for _, child in ipairs(char:GetChildren()) do
                if child:IsA("Accessory") and child:GetAttribute("RelicSlot") == slotName then
                    child:Destroy()
                end
            end
        end
        
        -- Buscar la herramienta y quitarle el sufijo de [Equipado]
        local backpack = player:FindFirstChild("Backpack")
        local equippedName = relicName .. " [Equipado]"
        local tool = backpack and backpack:FindFirstChild(equippedName) or char and char:FindFirstChild(equippedName)
        if tool then
            tool.Name = relicName
            tool:SetAttribute("Equipped", false)
        else
            -- Si por alguna razón no se encontró la herramienta (ej. se tiró al suelo), la creamos de vuelta
            if backpack and not backpack:FindFirstChild(relicName) then
                local template = ServerStorage:FindFirstChild(relicName)
                if template and template:IsA("Tool") then
                    local clone = template:Clone()
                    clone:SetAttribute("Cantidad", 1)
                    clone.Parent = backpack
                end
            end
        end
        
        updateRelicBuffs(player)
        
        -- Notificación visual y sonora en chat narrativo
        local narEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
        if narEvent then
            narEvent:FireClient(player, "He desequipado la reliquia: " .. relicName .. ".", true)
        end
        
        print("[RelicManager] Desequipada reliquia " .. relicName .. " del slot " .. slotName)
    end
end

-- Equipar reliquia en su slot correspondiente
local function equipRelic(player, relicName)
    local relicData = RelicConfig.Relics[relicName]
    if not relicData then return end
    
    local folder = getEquippedRelicsFolder(player)
    local slotName = relicData.Slot or "RelicSlot1"
    
    -- Asegurar StringValue del slot
    local val = folder:FindFirstChild(slotName)
    if not val then
        val = Instance.new("StringValue")
        val.Name = slotName
        val.Parent = folder
    end
    
    -- Desequipar lo que esté actualmente en ese slot (devolverá la herramienta vieja al estado normal)
    if val.Value ~= "" then
        unequipSlot(player, slotName)
    end
    
    -- Buscar la herramienta del jugador y marcarla como [Equipado]
    local backpack = player:FindFirstChild("Backpack")
    local char = player.Character
    local tool = backpack and backpack:FindFirstChild(relicName) or char and char:FindFirstChild(relicName)
    if tool then
        tool.Name = relicName .. " [Equipado]"
        tool:SetAttribute("Equipped", true)
        -- Desequipar la herramienta de la mano del jugador para que no la tenga sosteniendo
        if tool.Parent == char then
            tool.Parent = backpack
        end
    end
    
    -- Asignar nuevo valor lógico
    val.Value = relicName
    
    -- Añadir accesorio visual opcional si existe en RelicAssets o ArmorAssets
    local assets = ReplicatedStorage:FindFirstChild("RelicAssets") or ReplicatedStorage:FindFirstChild("ArmorAssets")
    local template = assets and assets:FindFirstChild(relicName)
    if template and template:IsA("Accessory") and char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local clone = template:Clone()
            clone:SetAttribute("RelicSlot", slotName)
            hum:AddAccessory(clone)
        end
    end
    
    updateRelicBuffs(player)
    
    -- Notificación visual y sonora en chat narrativo
    local narEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
    if narEvent then
        narEvent:FireClient(player, "He equipado la reliquia: " .. relicName .. ".", true)
    end
    
    print("[RelicManager] Equipada reliquia " .. relicName .. " en el slot " .. slotName)
end

-- Escuchar evento remoto de equipar/desequipar
relicEvent.OnServerEvent:Connect(function(player, action, relicName)
    if action == "Toggle" then
        -- Limpiar el sufijo si el cliente envía el nombre con [Equipado]
        local cleanName = relicName:gsub("%s*%[Equipado%]", "")
        local relicData = RelicConfig.Relics[cleanName]
        if not relicData then return end
        
        local folder = getEquippedRelicsFolder(player)
        local slotName = relicData.Slot or "RelicSlot1"
        local val = folder:FindFirstChild(slotName)
        
        if val and val.Value == cleanName then
            unequipSlot(player, slotName)
        else
            equipRelic(player, cleanName)
        end
    end
end)

-- Vincular CharacterAdded para volver a cargar visuales y buffs al spawnear
local function setupPlayer(player)
    getEquippedRelicsFolder(player)
    
    player.CharacterAdded:Connect(function(char)
        task.wait(1.2) -- Esperar a que el Humanoid esté completamente listo
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local folder = getEquippedRelicsFolder(player)
            local assets = ReplicatedStorage:FindFirstChild("RelicAssets") or ReplicatedStorage:FindFirstChild("ArmorAssets")
            
            for _, val in ipairs(folder:GetChildren()) do
                if val:IsA("StringValue") and val.Value ~= "" then
                    local relicName = val.Value
                    local slotName = val.Name
                    
                    local template = assets and assets:FindFirstChild(relicName)
                    if template and template:IsA("Accessory") then
                        local clone = template:Clone()
                        clone:SetAttribute("RelicSlot", slotName)
                        hum:AddAccessory(clone)
                    end
                end
            end
            
            -- Recalcular buffs de inmediato para el nuevo personaje
            updateRelicBuffs(player)
        end
    end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(setupPlayer, player)
end
