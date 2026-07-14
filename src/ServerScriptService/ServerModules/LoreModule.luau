local LoreModule = {}
LoreModule.ActiveInventories = {} -- Cache temporal de inventarios en tiempo real

-- ─────────────────────────────────────────────────────────────────────────
-- Sincronización en tiempo real del inventario para cada jugador
-- Evita el bug clásico de Roblox donde la mochila (Backpack) se destruye 
-- antes de que finalice el PlayerRemoving de forma multijugador.
-- ─────────────────────────────────────────────────────────────────────────
function LoreModule.UpdateInventoryCache(player)
    if not player or not player.Parent then return end
    
    local backpackItems = {}
    local backpack = player:FindFirstChild("Backpack")
    local char = player.Character
    
    local hasInvConfig, InventoryConfig = pcall(function()
        return require(game:GetService("ReplicatedStorage").Modules.InventoryConfig)
    end)
    
    local function checkAndAdd(item)
        if item:IsA("Tool") then
            if not hasInvConfig or not table.find(InventoryConfig.Blacklist, item.Name) then
                table.insert(backpackItems, {
                    Name = item.Name,
                    Cantidad = item:GetAttribute("Cantidad") or 1
                })
            end
        end
    end
    
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            checkAndAdd(child)
        end
    end
    if char then
        for _, child in ipairs(char:GetChildren()) do
            checkAndAdd(child)
        end
    end
    
    LoreModule.ActiveInventories[player] = backpackItems
end

function LoreModule.StartInventoryTracking(player)
    LoreModule.ActiveInventories[player] = {}
    
    local function onInventoryChanged()
        LoreModule.UpdateInventoryCache(player)
    end
    
    local connections = {}
    
    local function setupToolListeners(tool)
        if not tool:IsA("Tool") then return end
        -- Conectar listener para cuando cambie el atributo de cantidad
        local conn = tool:GetAttributeChangedSignal("Cantidad"):Connect(onInventoryChanged)
        table.insert(connections, conn)
    end
    
    local function setupContainerListeners(container)
        if not container then return end
        
        -- Listener para cuando se añaden ítems
        local addConn = container.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                setupToolListeners(child)
                onInventoryChanged()
            end
        end)
        table.insert(connections, addConn)
        
        -- Listener para cuando se quitan ítems
        local removeConn = container.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then
                onInventoryChanged()
            end
        end)
        table.insert(connections, removeConn)
        
        -- Configurar herramientas ya existentes
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") then
                setupToolListeners(child)
            end
        end
    end
    
    -- Escuchar el Backpack
    local backpack = player:WaitForChild("Backpack", 10)
    if backpack then
        setupContainerListeners(backpack)
    end
    
    -- Escuchar el Character (por si se equipan/desequipan ítems)
    local function onCharacterAdded(char)
        setupContainerListeners(char)
        onInventoryChanged()
    end
    
    local charAddedConn = player.CharacterAdded:Connect(onCharacterAdded)
    table.insert(connections, charAddedConn)
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    -- Limpiar conexiones al salir
    local removingConn
    removingConn = game.Players.PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == player then
            removingConn:Disconnect()
            for _, conn in ipairs(connections) do
                conn:Disconnect()
            end
        end
    end)
    
    -- Primer escaneo inicial
    onInventoryChanged()
end

local DataStoreService = game:GetService("DataStoreService")
local loreStore = DataStoreService:GetDataStore("PlayerLore_V1")

-- Crear eventos necesarios al inicio para evitar WaitForChild infinito en el cliente
do
    local RS = game:GetService("ReplicatedStorage")
    if not RS:FindFirstChild("PlayTPAuraEvent") then
        local e = Instance.new("RemoteEvent")
        e.Name = "PlayTPAuraEvent"
        e.Parent = RS
    end
end

LoreModule.Apellidos = {"Vritra-Liones", "Beifong-Galand", "Tyrell-Agni", "Caspian-Britannia", "Stonehand", "Vane", "Rivers", "Ashford", "Ironwood", "Skybound"}

function LoreModule.ApplyNametag(character, fullName)
    local head = character:FindFirstChild("Head")
    if not head then return end
    local hum = character:FindFirstChild("Humanoid")
    if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
    local tag = head:FindFirstChild("LoreNametag") or Instance.new("BillboardGui", head)
    tag.Name = "LoreNametag"
    tag.Size = UDim2.new(0, 200, 0, 40)
    tag.MaxDistance = 25
    tag.StudsOffset = Vector3.new(0, 3.5, 0)
    tag.AlwaysOnTop = true
    local label = tag:FindFirstChild("Label") or Instance.new("TextLabel", tag)
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 18
    -- El texto inicial es siempre "??? ???".
    -- El cliente (NametagOverrideClient) lo sobreescribe al nombre real
    -- solo si el jugador local conoce a esta persona.
    label.Text = "??? ???"
    label.TextStrokeTransparency = 0.5
end

function LoreModule.Setup(player)
    if player:GetAttribute("LoreSetupComplete") == true then return end
    player:SetAttribute("LoreSetupComplete", true)

    local lives = player:FindFirstChild("Lives") or Instance.new("IntValue", player)
    lives.Name = "Lives"
    if lives.Value == 0 then lives.Value = 3 end

    local fn = player:FindFirstChild("LoreFirstName") or Instance.new("StringValue", player)
    fn.Name = "LoreFirstName"
    local ln = player:FindFirstChild("LoreLastName") or Instance.new("StringValue", player)
    ln.Name = "LoreLastName"
    local ag = player:FindFirstChild("LoreAge") or Instance.new("IntValue", player)
    ag.Name = "LoreAge"
    
    local gen = player:FindFirstChild("LoreGender") or Instance.new("StringValue", player)
    gen.Name = "LoreGender"
    local ori = player:FindFirstChild("LoreOrigin") or Instance.new("StringValue", player)
    ori.Name = "LoreOrigin"
    if ori.Value == "" then ori.Value = "Campamento Ether" end
    
    local rank = player:FindFirstChild("LoreRank") or Instance.new("StringValue", player)
    rank.Name = "LoreRank"
    if rank.Value == "" then rank.Value = "Novato" end
    
    local race = player:FindFirstChild("LoreRace") or Instance.new("StringValue", player)
    race.Name = "LoreRace"
    if race.Value == "" then race.Value = "???" end
    
    local pve = player:FindFirstChild("PveKills") or Instance.new("IntValue", player)
    pve.Name = "PveKills"
    local pvp = player:FindFirstChild("PvpKills") or Instance.new("IntValue", player)
    pvp.Name = "PvpKills"
    
    local gold = player:FindFirstChild("Gold") or Instance.new("IntValue", player)
    gold.Name = "Gold"
    local silver = player:FindFirstChild("Silver") or Instance.new("IntValue", player)
    silver.Name = "Silver"
    local bronze = player:FindFirstChild("Bronze") or Instance.new("IntValue", player)
    bronze.Name = "Bronze"

    -- Stats Principales
    for _, name in ipairs({"Resistencia", "Stamina", "Velocidad", "Mana", "Energia", "Dexterity", "Resilience", "Precision", "Strength", "Celerity", "LogisticianPoints", "SkillsPoints", "MedicPoints"}) do
        local val = player:FindFirstChild(name) or Instance.new("IntValue", player)
        val.Name = name
    end
    local equippedFolder = player:FindFirstChild("EquippedTalents") or Instance.new("Folder", player)
    equippedFolder.Name = "EquippedTalents"
    local profFolder = player:FindFirstChild("UnlockedProficiencies") or Instance.new("Folder", player)
    profFolder.Name = "UnlockedProficiencies"
    local ap = player:FindFirstChild("AttributePoints") or Instance.new("IntValue", player)
    ap.Name = "AttributePoints"
    
    local tpProg = player:FindFirstChild("TPProgress") or Instance.new("NumberValue", player)
    tpProg.Name = "TPProgress"
    local tpPoints = player:FindFirstChild("TalentPoints") or Instance.new("IntValue", player)
    tpPoints.Name = "TalentPoints"
    local tpDecks = player:FindFirstChild("TPDecksEarned") or Instance.new("IntValue", player)
    tpDecks.Name = "TPDecksEarned"
    
    -- Honor Attributes (Default values: Honor = 50, MaxHonor = 100)
    player:SetAttribute("MaxHonor", 100)
    player:SetAttribute("Honor", 50)
    player:SetAttribute("Infection", 0)
    
    -- Magic Attributes
    player:SetAttribute("MagicLevel", 0)
    player:SetAttribute("MagicAttemptsRemaining", 3)
    player:SetAttribute("MagicLastAttemptDate", "1970-01-01")
    local randHue = math.random()
    player:SetAttribute("MagicColor", Color3.fromHSV(randHue, 0.85, 1.0))
    
    -- Carpeta para talentos (para que el cliente pueda verlos fácilmente)
    local talentsFolder = player:FindFirstChild("Talents") or Instance.new("Folder", player)
    talentsFolder.Name = "Talents"
    
    -- Carpeta para maestrias
    local maestriasFolder = player:FindFirstChild("Maestrias") or Instance.new("Folder", player)
    maestriasFolder.Name = "Maestrias"
    
    local masteriesList = {"Construccion", "Pesca", "Mineria", "Tala", "Combate", "Armas"}
    for _, name in ipairs(masteriesList) do
        local mFolder = maestriasFolder:FindFirstChild(name) or Instance.new("Folder", maestriasFolder)
        mFolder.Name = name
        local lvl = mFolder:FindFirstChild("Level") or Instance.new("IntValue", mFolder)
        lvl.Name = "Level"
        if lvl.Value == 0 then lvl.Value = 1 end
        local xp = mFolder:FindFirstChild("XP") or Instance.new("IntValue", mFolder)
        xp.Name = "XP"
    end
    
    -- Carpeta para amigos
    local friendsFolder = player:FindFirstChild("Friends") or Instance.new("Folder", player)
    friendsFolder.Name = "Friends"
    
    -- Carpeta para conocidos
    local knownFolder = player:FindFirstChild("Known") or Instance.new("Folder", player)
    knownFolder.Name = "Known"
    
    pcall(function()
        local data = loreStore:GetAsync("Lore_"..player.UserId)
        if data then 
            fn.Value = data.FirstName or "" 
            ln.Value = data.LastName or "" 
            ag.Value = data.Age or 0 
            player.LoreGender.Value = data.Gender or "Desconocido"
            player.LoreOrigin.Value = data.Origin or "Campamento Ether"
            player.LoreRank.Value = data.Rank or "Novato"
            player.LoreRace.Value = data.Race or "???"
            player.PveKills.Value = data.PveKills or 0
            player.PvpKills.Value = data.PvpKills or 0
            
            gold.Value = data.Gold or 0
            silver.Value = data.Silver or 0
            bronze.Value = data.Bronze or 0
            
            -- Cargar Sacramentos con Migración de datos antiguos
            player.Resilience.Value = data.Resilience or data.Resistencia or 1
            player.Celerity.Value = data.Celerity or data.Velocidad or 1
            player.Strength.Value = data.Strength or data.Energia or 1
            player.Dexterity.Value = data.Dexterity or data.Stamina or 1
            player.Precision.Value = data.Precision or 1

            -- Cargar Puntos de Habilidad (Proficiencies)
            player.LogisticianPoints.Value = data.LogisticianPoints or 0
            player.SkillsPoints.Value = data.SkillsPoints or 0
            player.MedicPoints.Value = data.MedicPoints or 0

            -- Asegurar compatibilidad para otros scripts
            player.Resistencia.Value = player.Resilience.Value
            player.Velocidad.Value = player.Celerity.Value
            player.Energia.Value = player.Strength.Value
            player.Stamina.Value = data.Stamina or 1
            player.Mana.Value = data.Mana or 1

            -- Cargar Talentos Equipados
            local equippedList = data.EquippedTalents or {}
            for _, tName in ipairs(equippedList) do
                local val = Instance.new("StringValue")
                val.Name = tName
                val.Parent = player.EquippedTalents
            end

            -- Cargar Habilidades Desbloqueadas
            local profList = data.UnlockedProficiencies or {}
            for _, nodeID in ipairs(profList) do
                local val = Instance.new("StringValue")
                val.Name = nodeID
                val.Parent = player.UnlockedProficiencies
            end
            
            -- Cargar inventario guardado
            if data.BackpackItems then
                task.spawn(function()
                    local ServerStorage = game:GetService("ServerStorage")
                    local backpack = player:WaitForChild("Backpack", 12)
                    if backpack then
                        for _, itemInfo in ipairs(data.BackpackItems) do
                            local template = ServerStorage:FindFirstChild(itemInfo.Name)
                            if template and template:IsA("Tool") then
                                -- Evitar duplicados si ya se cargó de algún otro modo
                                if not backpack:FindFirstChild(itemInfo.Name) then
                                    local clone = template:Clone()
                                    clone:SetAttribute("Cantidad", itemInfo.Cantidad or 1)
                                    clone.Parent = backpack
                                end
                            end
                        end
                    end
                end)
            end
            player.AttributePoints.Value = data.AttributePoints or 0
            tpProg.Value = data.TPProgress or 0
            tpPoints.Value = data.TalentPoints or 0
            tpDecks.Value = data.TPDecksEarned or 0
            
            -- Migración: si el jugador viene del sistema antiguo
            -- 1) Convertir TPProgress residual a TalentPoints (3:1)
            if tpProg.Value > 0 then
                local extraTP = math.floor(tpProg.Value / 3)
                tpPoints.Value = tpPoints.Value + extraTP
                tpProg.Value = 0
            end
            
            -- 2) Si tiene TalentPoints del sistema antiguo (sin TPDecksEarned),
            --    cada TP antiguo = 1 baraja ganada
            if (data.TPDecksEarned == nil or data.TPDecksEarned == 0) and tpPoints.Value > 0 then
                local oldTP = tpPoints.Value
                tpDecks.Value = oldTP
                tpPoints.Value = 0
            end
            
            player:SetAttribute("MaxHonor", data.MaxHonor or 100)
            player:SetAttribute("Honor", data.Honor or 50)
            player:SetAttribute("Infection", data.Infection or 0)
            
            -- Cargar datos mágicos
            player:SetAttribute("MagicLevel", data.MagicLevel or 0)
            player:SetAttribute("MagicAttemptsRemaining", data.MagicAttemptsRemaining or 3)
            player:SetAttribute("MagicLastAttemptDate", data.MagicLastAttemptDate or "1970-01-01")
            if data.MagicColor then
                player:SetAttribute("MagicColor", Color3.new(data.MagicColor[1], data.MagicColor[2], data.MagicColor[3]))
            else
                local randHue = math.random()
                player:SetAttribute("MagicColor", Color3.fromHSV(randHue, 0.85, 1.0))
            end
            
            local unlockedList = data.UnlockedSpells or {}
            local MagicConfig = require(game.ReplicatedStorage.Modules.MagicConfig)
            for _, sName in ipairs(unlockedList) do
                player:SetAttribute(MagicConfig.GetSpellAttributeName(sName), true)
            end
            
            -- Cargar talentos guardados
            if data.Talents then
                for _, tName in ipairs(data.Talents) do
                    if not talentsFolder:FindFirstChild(tName) then
                        local tVal = Instance.new("StringValue")
                        tVal.Name = tName
                        tVal.Value = tName
                        tVal.Parent = talentsFolder
                    end
                end
            end
            
            -- Cargar amigos guardados
            if data.Friends then
                for _, friendInfo in ipairs(data.Friends) do
                    local friendUserId = tostring(friendInfo.UserId)
                    if not friendsFolder:FindFirstChild(friendUserId) then
                        local fVal = Instance.new("StringValue")
                        fVal.Name = friendUserId
                        fVal.Value = friendInfo.Name or "Desconocido"
                        fVal.Parent = friendsFolder
                    end
                end
            end
            
            -- Cargar conocidos guardados
            if data.Known then
                for _, knownInfo in ipairs(data.Known) do
                    local knownUserId = tostring(knownInfo.UserId)
                    if not knownFolder:FindFirstChild(knownUserId) then
                        local kVal = Instance.new("StringValue")
                        kVal.Name = knownUserId
                        kVal.Value = knownInfo.Name or "Desconocido"
                        kVal.Parent = knownFolder
                    end
                end
            end
            
            -- Cargar maestrias guardadas
            if data.Maestrias then
                for mName, mData in pairs(data.Maestrias) do
                    local mFolder = maestriasFolder:FindFirstChild(mName)
                    if mFolder then
                        mFolder.Level.Value = mData.Level or 1
                        mFolder.XP.Value = mData.XP or 0
                    end
                end
            end
            
            -- Cargar Reliquias Equipadas
            local eqRelicsFolder = player:FindFirstChild("EquippedRelics") or Instance.new("Folder", player)
            eqRelicsFolder.Name = "EquippedRelics"
            if data.EquippedRelics then
                for slotName, relicName in pairs(data.EquippedRelics) do
                    local val = eqRelicsFolder:FindFirstChild(slotName) or Instance.new("StringValue", eqRelicsFolder)
                    val.Name = slotName
                    val.Value = relicName
                end
            end
            
            -- Cargar Vidas (PKs)
            lives.Value = data.Lives or 3
            
            -- Cargar Condiciones Médicas Persistentes
            if data.Condiciones then
                task.spawn(function()
                    local activeConds = data.Condiciones
                    local lostLimbPart = data.LostLimbPart
                    local Condis = require(game.ServerScriptService.ServerModules.CondicionesModule)
                    if not Condis.PlayerCondiciones[player] then
                        Condis.InitPlayer(player)
                    end
                    local condData = Condis.PlayerCondiciones[player]
                    if condData then
                        if lostLimbPart then condData.lostLimbPart = lostLimbPart end
                        for _, condName in ipairs(activeConds) do
                            Condis.Apply(player, condName)
                        end
                    end
                end)
            end
        end
    end)
    
    local function onChar(char)
        task.wait(0.5)
        if fn.Value ~= "" then LoreModule.ApplyNametag(char, fn.Value .. " " .. ln.Value) end
    end
    local function updateTag()
        if player.Character and fn.Value ~= "" then
            LoreModule.ApplyNametag(player.Character, fn.Value .. " " .. ln.Value)
        end
    end

    fn.Changed:Connect(updateTag)
    ln.Changed:Connect(updateTag)
    player.CharacterAdded:Connect(onChar)
    if player.Character then onChar(player.Character) end
    
    -- Iniciar tracking de inventario en tiempo real
    task.spawn(function()
        LoreModule.StartInventoryTracking(player)
    end)
end

function LoreModule.SaveTalents(player, talentList)
    if player:GetAttribute("Wiped") == true then return end
    local fnv = player:FindFirstChild("LoreFirstName")
    local lnv = player:FindFirstChild("LoreLastName")
    local agv = player:FindFirstChild("LoreAge")
    local gold = player:FindFirstChild("Gold")
    local silver = player:FindFirstChild("Silver")
    local bronze = player:FindFirstChild("Bronze")
    
    pcall(function()
        loreStore:UpdateAsync("Lore_"..player.UserId, function(oldData)
            local newData = oldData or {UserId = player.UserId, Username = player.Name}
            newData.FirstName = fnv and fnv.Value or newData.FirstName or ""
            newData.LastName = lnv and lnv.Value or newData.LastName or ""
            newData.Age = agv and agv.Value or newData.Age or 18
            newData.Gender = player:FindFirstChild("LoreGender") and player.LoreGender.Value or "Desconocido"
            newData.Origin = player:FindFirstChild("LoreOrigin") and player.LoreOrigin.Value or "Campamento Ether"
            newData.Rank = player:FindFirstChild("LoreRank") and player.LoreRank.Value or "Novato"
            newData.Race = player:FindFirstChild("LoreRace") and player.LoreRace.Value or "???"
            newData.Rank = player:FindFirstChild("LoreRank") and player.LoreRank.Value or "Novato"
            newData.Race = player:FindFirstChild("LoreRace") and player.LoreRace.Value or "???"
            newData.PveKills = player:FindFirstChild("PveKills") and player.PveKills.Value or 0
            newData.PvpKills = player:FindFirstChild("PvpKills") and player.PvpKills.Value or 0
            newData.Gold = gold and gold.Value or newData.Gold or 0
            newData.Silver = silver and silver.Value or newData.Silver or 0
            newData.Bronze = bronze and bronze.Value or newData.Bronze or 0
            
            -- Guardar Reliquias Equipadas en SaveTalents
            local equippedRelics = {}
            local folder = player:FindFirstChild("EquippedRelics")
            if folder then
                for _, val in ipairs(folder:GetChildren()) do
                    if val:IsA("StringValue") and val.Value ~= "" then
                        equippedRelics[val.Name] = val.Value
                    end
                end
            end
            newData.EquippedRelics = equippedRelics
            
            -- Guardar Vidas y Condiciones en SaveAllData
            newData.Lives = player:FindFirstChild("Lives") and player.Lives.Value or 3
            
            local activeConds = {}
            local condData = require(game.ServerScriptService.ServerModules.CondicionesModule).PlayerCondiciones[player]
            if condData then
                if condData.piernaRota then table.insert(activeConds, "piernorota") end
                if condData.brazoRoto then table.insert(activeConds, "brazoroto") end
                if condData.perdidaExtremidad then table.insert(activeConds, "extremidad") end
                if condData.ciego then table.insert(activeConds, "ciego") end
                if condData.perdidaOjo then table.insert(activeConds, "perdidaojo") end
                if condData.concusion then table.insert(activeConds, "concusion") end
                if condData.esquizofrenia then table.insert(activeConds, "esquizofrenia") end
                newData.LostLimbPart = condData.lostLimbPart
            end
            newData.Condiciones = activeConds
            
for _, name in ipairs({"Resistencia", "Stamina", "Velocidad", "Mana", "Energia", "AttributePoints", "TPProgress", "TalentPoints", "TPDecksEarned"}) do
                local val = player:FindFirstChild(name)
                newData[name] = val and val.Value or newData[name] or (name == "AttributePoints" and 0 or (name == "TPProgress" and 0 or (name == "TalentPoints" and 0 or (name == "TPDecksEarned" and 0 or 1))))
            end
            
            -- Guardar Inventario en SaveTalents
            local backpackItems = LoreModule.ActiveInventories[player] or {}
            if #backpackItems == 0 then
                local backpack = player:FindFirstChild("Backpack")
                local char = player.Character
                local hasInvConfig, InventoryConfig = pcall(function()
                    return require(game:GetService("ReplicatedStorage").Modules.InventoryConfig)
                end)
                local function checkAndAdd(item)
                    if item:IsA("Tool") then
                        if not hasInvConfig or not table.find(InventoryConfig.Blacklist, item.Name) then
                            table.insert(backpackItems, {
                                Name = item.Name,
                                Cantidad = item:GetAttribute("Cantidad") or 1
                            })
                        end
                    end
                end
                if backpack then
                    for _, child in ipairs(backpack:GetChildren()) do
                        checkAndAdd(child)
                    end
                end
                if char then
                    for _, child in ipairs(char:GetChildren()) do
                        checkAndAdd(child)
                    end
                end
            end
            newData.BackpackItems = backpackItems
            newData.MaxHonor = player:GetAttribute("MaxHonor") or newData.MaxHonor or 100
            newData.Honor = player:GetAttribute("Honor") or newData.Honor or 50
            newData.Infection = player:GetAttribute("Infection") or newData.Infection or 0
            
            -- Guardar datos mágicos
            newData.MagicLevel = player:GetAttribute("MagicLevel") or 0
            newData.MagicAttemptsRemaining = player:GetAttribute("MagicAttemptsRemaining") or 3
            newData.MagicLastAttemptDate = player:GetAttribute("MagicLastAttemptDate") or "1970-01-01"
            local mColor = player:GetAttribute("MagicColor")
            if mColor then
                newData.MagicColor = {mColor.R, mColor.G, mColor.B}
            end
            
            -- Guardar hechizos individuales desbloqueados
            local unlockedSpells = {}
            local MagicConfig = require(game.ReplicatedStorage.Modules.MagicConfig)
            for _, levelMinigames in pairs(MagicConfig.Minigames) do
                for _, sub in ipairs(levelMinigames) do
                    if player:GetAttribute(MagicConfig.GetSpellAttributeName(sub.Spell)) == true then
                        table.insert(unlockedSpells, sub.Spell)
                    end
                end
            end
            newData.UnlockedSpells = unlockedSpells
            
            newData.Talents = talentList
            
            -- Guardar Vidas y Condiciones en SaveTalents
            newData.Lives = player:FindFirstChild("Lives") and player.Lives.Value or 3
            
            local activeConds = {}
            local condData = require(game.ServerScriptService.ServerModules.CondicionesModule).PlayerCondiciones[player]
            if condData then
                if condData.piernaRota then table.insert(activeConds, "piernorota") end
                if condData.brazoRoto then table.insert(activeConds, "brazoroto") end
                if condData.perdidaExtremidad then table.insert(activeConds, "extremidad") end
                if condData.ciego then table.insert(activeConds, "ciego") end
                if condData.perdidaOjo then table.insert(activeConds, "perdidaojo") end
                if condData.concusion then table.insert(activeConds, "concusion") end
                if condData.esquizofrenia then table.insert(activeConds, "esquizofrenia") end
                newData.LostLimbPart = condData.lostLimbPart
            end
            newData.Condiciones = activeConds
            
            local friendsList = {}
            local friendsFolder = player:FindFirstChild("Friends")
            if friendsFolder then
                for _, fVal in ipairs(friendsFolder:GetChildren()) do
                    if fVal:IsA("StringValue") then
                        table.insert(friendsList, {UserId = tonumber(fVal.Name), Name = fVal.Value})
                    end
                end
            end
            newData.Friends = friendsList
            
            local knownList = {}
            local knownFolder = player:FindFirstChild("Known")
            if knownFolder then
                for _, kVal in ipairs(knownFolder:GetChildren()) do
                    if kVal:IsA("StringValue") then
                        table.insert(knownList, {UserId = tonumber(kVal.Name), Name = kVal.Value})
                    end
                end
            end
            newData.Known = knownList
            
            local knownList = {}
            local knownFolder = player:FindFirstChild("Known")
            if knownFolder then
                for _, kVal in ipairs(knownFolder:GetChildren()) do
                    if kVal:IsA("StringValue") then
                        table.insert(knownList, {UserId = tonumber(kVal.Name), Name = kVal.Value})
                    end
                end
            end
            newData.Known = knownList
            
            local maestriasData = {}
            local maestriasFolder = player:FindFirstChild("Maestrias")
            if maestriasFolder then
                for _, mFolder in ipairs(maestriasFolder:GetChildren()) do
                    maestriasData[mFolder.Name] = {
                        Level = mFolder:FindFirstChild("Level") and mFolder.Level.Value or 1,
                        XP = mFolder:FindFirstChild("XP") and mFolder.XP.Value or 0
                    }
                end
            end
            newData.Maestrias = maestriasData
            
            return newData
        end)
    end)
end

function LoreModule.SaveAllData(player)
    if not player then return end
    if player:GetAttribute("Wiped") == true then
        print("[LORE SYSTEM] Ignorando autoguardado para " .. player.Name .. " por estar en estado Wiped.")
        return
    end
    
    local gold = player:FindFirstChild("Gold")
    local silver = player:FindFirstChild("Silver")
    local bronze = player:FindFirstChild("Bronze")
    local fnv = player:FindFirstChild("LoreFirstName")
    local lnv = player:FindFirstChild("LoreLastName")
    local agv = player:FindFirstChild("LoreAge")
    local pve = player:FindFirstChild("PveKills")
    local pvp = player:FindFirstChild("PvpKills")
    
    local success, err = pcall(function()
        loreStore:UpdateAsync("Lore_" .. player.UserId, function(oldData)
            local newData = oldData or {UserId = player.UserId, Username = player.Name}
            
            -- Datos de Identidad
            newData.FirstName = (fnv and fnv.Value) or newData.FirstName or ""
            newData.LastName = (lnv and lnv.Value) or newData.LastName or ""
            newData.Age = (agv and agv.Value) or newData.Age or 18
            newData.Gender = (player:FindFirstChild("LoreGender") and player.LoreGender.Value) or newData.Gender or "Desconocido"
            newData.Origin = (player:FindFirstChild("LoreOrigin") and player.LoreOrigin.Value) or newData.Origin or "Campamento Ether"
            
            -- Estadísticas y Puntos
            local statsToSave = {
                "Resistencia", "Stamina", "Velocidad", "Mana", "Energia", 
                "AttributePoints", "TPProgress", "TalentPoints", "TPDecksEarned",
                "Dexterity", "Resilience", "Precision", "Strength", "Celerity",
                "LogisticianPoints", "SkillsPoints", "MedicPoints"
            }
            for _, name in ipairs(statsToSave) do
                local val = player:FindFirstChild(name)
                if val and val:IsA("ValueBase") then
                    newData[name] = val.Value
                end
            end
            
            -- Guardar Talentos Equipados
            local equippedList = {}
            for _, child in ipairs(player.EquippedTalents:GetChildren()) do
                table.insert(equippedList, child.Name)
            end
            newData.EquippedTalents = equippedList

            -- Guardar Habilidades Desbloqueadas
            local profList = {}
            for _, child in ipairs(player.UnlockedProficiencies:GetChildren()) do
                table.insert(profList, child.Name)
            end
            newData.UnlockedProficiencies = profList
            
            -- Guardar Inventario (Backpack y equipados en Character)
            local backpackItems = LoreModule.ActiveInventories[player] or {}
            if #backpackItems == 0 then
                local backpack = player:FindFirstChild("Backpack")
                local char = player.Character
                local hasInvConfig, InventoryConfig = pcall(function()
                    return require(game:GetService("ReplicatedStorage").Modules.InventoryConfig)
                end)
                local function checkAndAdd(item)
                    if item:IsA("Tool") then
                        if not hasInvConfig or not table.find(InventoryConfig.Blacklist, item.Name) then
                            table.insert(backpackItems, {
                                Name = item.Name,
                                Cantidad = item:GetAttribute("Cantidad") or 1
                            })
                        end
                    end
                end
                if backpack then
                    for _, child in ipairs(backpack:GetChildren()) do
                        checkAndAdd(child)
                    end
                end
                if char then
                    for _, child in ipairs(char:GetChildren()) do
                        checkAndAdd(child)
                    end
                end
            end
            newData.BackpackItems = backpackItems
            
            newData.MaxHonor = player:GetAttribute("MaxHonor") or 100
            newData.Honor = player:GetAttribute("Honor") or 50
            newData.Infection = player:GetAttribute("Infection") or 0
            
            -- Guardar datos mágicos
            newData.MagicLevel = player:GetAttribute("MagicLevel") or 0
            newData.MagicAttemptsRemaining = player:GetAttribute("MagicAttemptsRemaining") or 3
            newData.MagicLastAttemptDate = player:GetAttribute("MagicLastAttemptDate") or "1970-01-01"
            local mColor = player:GetAttribute("MagicColor")
            if mColor then
                newData.MagicColor = {mColor.R, mColor.G, mColor.B}
            end
            
            -- Guardar hechizos individuales desbloqueados
            local unlockedSpells = {}
            local MagicConfig = require(game.ReplicatedStorage.Modules.MagicConfig)
            for _, levelMinigames in pairs(MagicConfig.Minigames) do
                for _, sub in ipairs(levelMinigames) do
                    if player:GetAttribute(MagicConfig.GetSpellAttributeName(sub.Spell)) == true then
                        table.insert(unlockedSpells, sub.Spell)
                    end
                end
            end
            newData.UnlockedSpells = unlockedSpells
            
            -- Dinero y Kills
            if gold then newData.Gold = gold.Value end
            if silver then newData.Silver = silver.Value end
            if bronze then newData.Bronze = bronze.Value end
            if pve then newData.PveKills = pve.Value end
            if pvp then newData.PvpKills = pvp.Value end
            
            -- Guardar Reliquias Equipadas
            local equippedRelics = {}
            local folder = player:FindFirstChild("EquippedRelics")
            if folder then
                for _, val in ipairs(folder:GetChildren()) do
                    if val:IsA("StringValue") and val.Value ~= "" then
                        equippedRelics[val.Name] = val.Value
                    end
                end
            end
            newData.EquippedRelics = equippedRelics
            
            -- Guardar Vidas y Condiciones en SaveAllData
            newData.Lives = player:FindFirstChild("Lives") and player.Lives.Value or 3
            
            local activeConds = {}
            local condData = require(game.ServerScriptService.ServerModules.CondicionesModule).PlayerCondiciones[player]
            if condData then
                if condData.piernaRota then table.insert(activeConds, "piernorota") end
                if condData.brazoRoto then table.insert(activeConds, "brazoroto") end
                if condData.perdidaExtremidad then table.insert(activeConds, "extremidad") end
                if condData.ciego then table.insert(activeConds, "ciego") end
                if condData.perdidaOjo then table.insert(activeConds, "perdidaojo") end
                if condData.concusion then table.insert(activeConds, "concusion") end
                if condData.esquizofrenia then table.insert(activeConds, "esquizofrenia") end
                newData.LostLimbPart = condData.lostLimbPart
            end
            newData.Condiciones = activeConds
            
            local friendsList = {}
            local friendsFolder = player:FindFirstChild("Friends")
            if friendsFolder then
                for _, fVal in ipairs(friendsFolder:GetChildren()) do
                    if fVal:IsA("StringValue") then
                        table.insert(friendsList, {UserId = tonumber(fVal.Name), Name = fVal.Value})
                    end
                end
            end
            newData.Friends = friendsList
            
            local maestriasData = {}
            local maestriasFolder = player:FindFirstChild("Maestrias")
            if maestriasFolder then
                for _, mFolder in ipairs(maestriasFolder:GetChildren()) do
                    maestriasData[mFolder.Name] = {
                        Level = mFolder:FindFirstChild("Level") and mFolder.Level.Value or 1,
                        XP = mFolder:FindFirstChild("XP") and mFolder.XP.Value or 0
                    }
                end
            end
            newData.Maestrias = maestriasData
            
            return newData
        end)
    end)
    
    if not success then
        warn("[LORE SYSTEM] Error guardando datos de " .. player.Name .. ": " .. tostring(err))
    end
end

function LoreModule.AddMoney(player, currencyType, amount)
    local gold = player:FindFirstChild("Gold")
    local silver = player:FindFirstChild("Silver")
    local bronze = player:FindFirstChild("Bronze")
    if not (gold and silver and bronze) then return end

    currencyType = string.lower(currencyType)
    if currencyType == "oro" or currencyType == "gold" then
        gold.Value = gold.Value + amount
    elseif currencyType == "plata" or currencyType == "silver" then
        silver.Value = silver.Value + amount
    elseif currencyType == "bronce" or currencyType == "bronze" then
        bronze.Value = bronze.Value + amount
    end

    -- Conversión: 10 Bronce = 1 Plata, 10 Plata = 1 Oro
    while bronze.Value >= 10 do
        bronze.Value = bronze.Value - 10
        silver.Value = silver.Value + 1
    end
    
    while silver.Value >= 10 do
        silver.Value = silver.Value - 10
        gold.Value = gold.Value + 1
    end
    
    -- Manejo de valores negativos (opcional, para prevenir errores si se resta)
    if bronze.Value < 0 then
        while bronze.Value < 0 and silver.Value > 0 do
            bronze.Value = bronze.Value + 10
            silver.Value = silver.Value - 1
        end
    end
    
    if silver.Value < 0 then
        while silver.Value < 0 and gold.Value > 0 do
            silver.Value = silver.Value + 10
            gold.Value = gold.Value - 1
        end
    end

    LoreModule.SaveAllData(player)
end

function LoreModule.SetLore(player, name, lastName, age, gender)
    local fnv = player:FindFirstChild("LoreFirstName")
    if fnv and fnv.Value == "" then
        fnv.Value = tostring(name)
        player.LoreLastName.Value = tostring(lastName) or LoreModule.Apellidos[math.random(1, #LoreModule.Apellidos)]
        player.LoreAge.Value = tonumber(age) or 18
        player.LoreGender.Value = gender or "Masculino"
        player.LoreOrigin.Value = "Campamento Ether"
        player.LoreRank.Value = "Novato"
        player.LoreRace.Value = "???"
        
        if player.Character then LoreModule.ApplyNametag(player.Character, fnv.Value .. " " .. player.LoreLastName.Value) end
        pcall(function() 
            loreStore:SetAsync("Lore_"..player.UserId, {
                UserId = player.UserId, 
                Username = player.Name, 
                FirstName = fnv.Value, 
                LastName = player.LoreLastName.Value, 
                Age = player.LoreAge.Value,
                Gender = player.LoreGender.Value,
                Origin = player.LoreOrigin.Value,
                Rank = player.LoreRank.Value,
                Race = player.LoreRace.Value,
                Gold = player:FindFirstChild("Gold") and player.Gold.Value or 0,
                Silver = player:FindFirstChild("Silver") and player.Silver.Value or 0,
                Bronze = player:FindFirstChild("Bronze") and player.Bronze.Value or 0,
                Resistencia = player:FindFirstChild("Resistencia") and player.Resistencia.Value or 1,
                Stamina = player:FindFirstChild("Stamina") and player.Stamina.Value or 1,
                Velocidad = player:FindFirstChild("Velocidad") and player.Velocidad.Value or 1,
                Mana = player:FindFirstChild("Mana") and player.Mana.Value or 1,
                Energia = player:FindFirstChild("Energia") and player.Energia.Value or 1,
                AttributePoints = player:FindFirstChild("AttributePoints") and player.AttributePoints.Value or 0,
                TPProgress = player:FindFirstChild("TPProgress") and player.TPProgress.Value or 0,
                TalentPoints = player:FindFirstChild("TalentPoints") and player.TalentPoints.Value or 0,
                TPDecksEarned = player:FindFirstChild("TPDecksEarned") and player.TPDecksEarned.Value or 0,
                MaxHonor = player:GetAttribute("MaxHonor") or 100,
                Honor = player:GetAttribute("Honor") or 50,
                Infection = player:GetAttribute("Infection") or 0,
                Friends = {},
                Known = {},
                Maestrias = {
                    Construccion = {Level = 1, XP = 0},
                    Pesca = {Level = 1, XP = 0},
                    Mineria = {Level = 1, XP = 0},
                    Tala = {Level = 1, XP = 0},
                    Combate = {Level = 1, XP = 0},
                    Armas = {Level = 1, XP = 0}
                }
            }) 
        end)
    end
end

function LoreModule.ToggleTag(player, visible)
    if player.Character and player.Character:FindFirstChild("Head") then
        local tag = player.Character.Head:FindFirstChild("LoreNametag")
        if tag then tag.Enabled = visible end
    end
end

function LoreModule.AddTP(player, amount)
    local tpPoints = player:FindFirstChild("TalentPoints")
    local tpDecks = player:FindFirstChild("TPDecksEarned")
    if not tpPoints or not tpDecks then return end
    
    -- Añadir directamente a TalentPoints (sin conversión intermedia)
    tpPoints.Value = tpPoints.Value + amount
    
    -- Costo progresivo: cada baraja cuesta 2^decksEarned TP
    -- Baraja 1: 1 TP, Baraja 2: 2 TP, Baraja 3: 4 TP, Baraja 4: 8 TP, etc.
    local earned = 0
    local function getNextDeckCost()
        return math.floor(2 ^ tpDecks.Value)
    end
    
    while tpPoints.Value >= getNextDeckCost() do
        local cost = getNextDeckCost()
        tpPoints.Value = tpPoints.Value - cost
        tpDecks.Value = tpDecks.Value + 1
        earned = earned + 1
    end
    
    -- Mensaje siempre que se gana TP
    local narEvent = game.ReplicatedStorage:FindFirstChild("NarrateEvent")
    if narEvent then
        narEvent:FireClient(player, "Parece que he ganado algo de experiencia.", true)
    end
    
    -- Efecto visual y sonoro local (solo para el jugador que gana TP)
    local PlayTPAuraEvent = game.ReplicatedStorage:FindFirstChild("PlayTPAuraEvent")
    if not PlayTPAuraEvent then
        PlayTPAuraEvent = Instance.new("RemoteEvent")
        PlayTPAuraEvent.Name = "PlayTPAuraEvent"
        PlayTPAuraEvent.Parent = game.ReplicatedStorage
    end
    PlayTPAuraEvent:FireClient(player)

    if earned > 0 then
        local QueueTalentDeck = game.ReplicatedStorage:FindFirstChild("QueueTalentDeck")
        if QueueTalentDeck then
            for i = 1, earned do
                QueueTalentDeck:Fire(player)
            end
        end
    end
    
    LoreModule.SaveAllData(player)
end

function LoreModule.AddMasteryXP(player, masteryName, amount)
    local maestriasFolder = player:FindFirstChild("Maestrias")
    if not maestriasFolder then return end
    local mFolder = maestriasFolder:FindFirstChild(masteryName)
    if not mFolder then return end
    
    local lvlVal = mFolder:FindFirstChild("Level")
    local xpVal = mFolder:FindFirstChild("XP")
    if not lvlVal or not xpVal then return end
    
    xpVal.Value = xpVal.Value + amount
    
    local function getNextXP(level)
        return math.floor(10 ^ level)
    end
    
    local leveledUp = false
    while xpVal.Value >= getNextXP(lvlVal.Value) do
        xpVal.Value = xpVal.Value - getNextXP(lvlVal.Value)
        lvlVal.Value = lvlVal.Value + 1
        leveledUp = true
    end
    
    if leveledUp then
        local narEvent = game.ReplicatedStorage:FindFirstChild("NarrateEvent")
        if narEvent then
            narEvent:FireClient(player, "¡He subido de Maestría en " .. masteryName .. "! (Nivel " .. tostring(lvlVal.Value) .. ")", true)
        end
        LoreModule.SaveAllData(player)
    end
end

-- Asegurar auto-guardado al salir del jugador y al apagar el servidor
game.Players.PlayerRemoving:Connect(function(player)
    LoreModule.SaveAllData(player)
end)

game:BindToClose(function()
    for _, player in ipairs(game.Players:GetPlayers()) do
        LoreModule.SaveAllData(player)
    end
end)

return LoreModule
