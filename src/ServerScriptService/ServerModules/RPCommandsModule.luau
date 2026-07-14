local RPCommandsModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CommandRegistry = require(script.Parent.CommandRegistry)
local Utils = require(script.Parent.UtilsModule)
local WeatherModule = require(script.Parent.WeatherModule)
local RagdollModule = require(script.Parent.RagdollModule)
local LoreModule = require(script.Parent.LoreModule)
local PermadeathModule = require(script.Parent.PermadeathModule)
local dayCycleActive = false

local DisplayBubbleEvent = ReplicatedStorage:WaitForChild("DisplayBubbleEvent")
local AdminTrackEvent = ReplicatedStorage:WaitForChild("AdminTrackEvent")

function RPCommandsModule.Init()
    -- Crear evento de chat no filtrado si no existe
    local UnfilteredChatEvent = ReplicatedStorage:FindFirstChild("UnfilteredChatEvent")
    if not UnfilteredChatEvent then
        UnfilteredChatEvent = Instance.new("RemoteEvent")
        UnfilteredChatEvent.Name = "UnfilteredChatEvent"
        UnfilteredChatEvent.Parent = ReplicatedStorage
    end

    UnfilteredChatEvent.OnServerEvent:Connect(function(player, message)
        if ReplicatedStorage:GetAttribute("ChatFilterDisabled") == true and type(message) == "string" and #message > 0 then
            -- Reenviar el mensaje de forma segura como burbuja a todos los jugadores
            for _, target in pairs(Players:GetPlayers()) do
                DisplayBubbleEvent:FireClient(target, player, message)
            end
        end
    end)

    local OpenDataEditorEvent = ReplicatedStorage:FindFirstChild("OpenDataEditorEvent")
    if not OpenDataEditorEvent then
        OpenDataEditorEvent = Instance.new("RemoteEvent")
        OpenDataEditorEvent.Name = "OpenDataEditorEvent"
        OpenDataEditorEvent.Parent = ReplicatedStorage
    end

    -- Evento: el cliente admin solicita datos completos de un jugador (RemoteFunction)
    local RequestPlayerDataEvent = ReplicatedStorage:FindFirstChild("RequestPlayerDataEvent")
    if not RequestPlayerDataEvent then
        RequestPlayerDataEvent = Instance.new("RemoteFunction")
        RequestPlayerDataEvent.Name = "RequestPlayerDataEvent"
        RequestPlayerDataEvent.Parent = ReplicatedStorage
    end

    RequestPlayerDataEvent.OnServerInvoke = function(adminPlayer, targetPlayer)
        if not Utils.isAdmin(adminPlayer) then return nil end
        if not targetPlayer or not targetPlayer.Parent then return nil end

        local data = {}

        -- Identidad (StringValues)
        local stringFields = {"LoreFirstName", "LoreLastName", "LoreGender", "LoreOrigin", "LoreRank", "LoreRace"}
        for _, name in ipairs(stringFields) do
            local val = targetPlayer:FindFirstChild(name)
            if val then data[name] = tostring(val.Value) end
        end

        -- Numeros (IntValues)
        local intFields = {"LoreAge", "Gold", "Silver", "Bronze", "PveKills", "PvpKills",
            "Resistencia", "Stamina", "Velocidad", "Mana", "Energia",
            "AttributePoints", "TalentPoints", "TPDecksEarned", "Lives"}
        for _, name in ipairs(intFields) do
            local val = targetPlayer:FindFirstChild(name)
            if val then data[name] = val.Value end
        end

        -- Atributos del jugador
        data["Honor"] = targetPlayer:GetAttribute("Honor") or 50
        data["MaxHonor"] = targetPlayer:GetAttribute("MaxHonor") or 100
        data["Infection"] = targetPlayer:GetAttribute("Infection") or 0

        -- Condiciones medicas activas
        local CondicionesModule = require(game.ServerScriptService.ServerModules.CondicionesModule)
        local condData = CondicionesModule.PlayerCondiciones[targetPlayer]
        local activeConds = {}
        if condData then
            if condData.piernaRota then table.insert(activeConds, "Pierna Rota") end
            if condData.brazoRoto then table.insert(activeConds, "Brazo Roto") end
            if condData.perdidaExtremidad then table.insert(activeConds, "Perdida Extremidad") end
            if condData.ciego then table.insert(activeConds, "Ceguera") end
            if condData.perdidaOjo then table.insert(activeConds, "Perdida de Ojo") end
            if condData.concusion then table.insert(activeConds, "Concusion") end
            if condData.esquizofrenia then table.insert(activeConds, "Esquizofrenia") end
        end
        data["Condiciones"] = table.concat(activeConds, ", ")
        data["LostLimbPart"] = (condData and condData.lostLimbPart) or ""

        -- Maestrias
        local maestriasFolder = targetPlayer:FindFirstChild("Maestrias")
        if maestriasFolder then
            for _, mFolder in ipairs(maestriasFolder:GetChildren()) do
                local lvl = mFolder:FindFirstChild("Level")
                local xp = mFolder:FindFirstChild("XP")
                data["Maestria_" .. mFolder.Name .. "_Level"] = lvl and lvl.Value or 1
                data["Maestria_" .. mFolder.Name .. "_XP"] = xp and xp.Value or 0
            end
        end

        return data
    end

    local SaveDataEditorEvent = ReplicatedStorage:FindFirstChild("SaveDataEditorEvent")
    if not SaveDataEditorEvent then
        SaveDataEditorEvent = Instance.new("RemoteEvent")
        SaveDataEditorEvent.Name = "SaveDataEditorEvent"
        SaveDataEditorEvent.Parent = ReplicatedStorage
    end

    -- Ahora recibe una tabla de cambios {key = value}
    SaveDataEditorEvent.OnServerEvent:Connect(function(adminPlayer, targetPlayer, changesTable)
        if not Utils.isAdmin(adminPlayer) then return end
        if not targetPlayer or not targetPlayer.Parent then return end
        if type(changesTable) ~= "table" then return end

        local CondicionesModule = require(game.ServerScriptService.ServerModules.CondicionesModule)

        for key, value in pairs(changesTable) do
            -- StringValues directas en el Player
            if key == "LoreFirstName" or key == "LoreLastName" or key == "LoreGender" or
               key == "LoreOrigin" or key == "LoreRank" or key == "LoreRace" then
                local val = targetPlayer:FindFirstChild(key)
                if val then val.Value = tostring(value) end

            -- IntValues/NumberValues directas en el Player
            elseif key == "LoreAge" or key == "Gold" or key == "Silver" or key == "Bronze" or
                   key == "PveKills" or key == "PvpKills" or key == "Resistencia" or
                   key == "Stamina" or key == "Velocidad" or key == "Mana" or key == "Energia" or
                   key == "AttributePoints" or key == "TalentPoints" or key == "TPDecksEarned" or
                   key == "Lives" then
                local val = targetPlayer:FindFirstChild(key)
                if val then
                    local num = tonumber(value)
                    if num then val.Value = num end
                end

            -- Atributos del jugador
            elseif key == "Honor" or key == "MaxHonor" or key == "Infection" then
                local num = tonumber(value)
                if num then targetPlayer:SetAttribute(key, num) end

            -- Condiciones medicas: borrar y re-aplicar segun el texto
            elseif key == "Condiciones" then
                local condData = CondicionesModule.PlayerCondiciones[targetPlayer]
                if condData then
                    condData.piernaRota = false
                    condData.brazoRoto = false
                    condData.perdidaExtremidad = false
                    condData.ciego = false
                    condData.perdidaOjo = false
                    condData.concusion = false
                    condData.esquizofrenia = false
                end
                local trimmed = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
                if trimmed ~= "" then
                    for cond in trimmed:gmatch("[^,]+") do
                        local c = cond:gsub("^%s+", ""):gsub("%s+$", ""):lower()
                        if c == "pierna rota" then CondicionesModule.Apply(targetPlayer, "piernorota")
                        elseif c == "brazo roto" then CondicionesModule.Apply(targetPlayer, "brazoroto")
                        elseif c == "perdida extremidad" then CondicionesModule.Apply(targetPlayer, "extremidad")
                        elseif c == "ceguera" then CondicionesModule.Apply(targetPlayer, "ciego")
                        elseif c == "perdida de ojo" then CondicionesModule.Apply(targetPlayer, "perdidaojo")
                        elseif c == "concusion" then CondicionesModule.Apply(targetPlayer, "concusion")
                        elseif c == "esquizofrenia" then CondicionesModule.Apply(targetPlayer, "esquizofrenia")
                        end
                    end
                end

            -- Maestrias: Maestria_Combate_Level, Maestria_Pesca_XP, etc.
            elseif key:sub(1, 8) == "Maestria" then
                local parts = {}
                for p in key:gmatch("[^_]+") do table.insert(parts, p) end
                if #parts == 3 then
                    local mName = parts[2]
                    local mField = parts[3]
                    local maestriasFolder = targetPlayer:FindFirstChild("Maestrias")
                    if maestriasFolder then
                        local mFolder = maestriasFolder:FindFirstChild(mName)
                        if mFolder then
                            local mVal = mFolder:FindFirstChild(mField)
                            if mVal then
                                local num = tonumber(value)
                                if num then mVal.Value = num end
                            end
                        end
                    end
                end
            end
        end

        -- Actualizar nametag si cambiaron nombre/apellido
        if changesTable["LoreFirstName"] or changesTable["LoreLastName"] then
            local fn = targetPlayer:FindFirstChild("LoreFirstName")
            local ln = targetPlayer:FindFirstChild("LoreLastName")
            if fn and ln and targetPlayer.Character then
                LoreModule.ApplyNametag(targetPlayer.Character, fn.Value .. " " .. ln.Value)
            end
        end

        LoreModule.SaveAllData(targetPlayer)

        local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
        if notify then
            notify:FireClient(adminPlayer, "Sistema", "Datos de " .. targetPlayer.Name .. " actualizados correctamente.")
            notify:FireClient(targetPlayer, "Sistema", "Tus datos de personaje han sido actualizados por un administrador.")
        end
    end)

    -- Chat / Roleplay Commands
    CommandRegistry.Register("/w", function(player, msg)
        if not player.Character or not player.Character:FindFirstChild("Head") then return end
        local senderHead = player.Character.Head
        for _, target in pairs(Players:GetPlayers()) do
            if target.Character and target.Character:FindFirstChild("Head") then
                local dist = (target.Character.Head.Position - senderHead.Position).Magnitude
                if dist <= 5 then
                    DisplayBubbleEvent:FireClient(target, player, "[Susurro]: " .. msg)
                elseif dist <= 40 then
                    DisplayBubbleEvent:FireClient(target, player, "[Inaudible]")
                end
            end
        end
    end)

    CommandRegistry.Register("/t", function(player, msg)
        if not player.Character or not player.Character:FindFirstChild("Head") then return end
        for _, target in pairs(Players:GetPlayers()) do
            if target == player or Utils.isAdmin(target) then
                DisplayBubbleEvent:FireClient(target, player, "[Pensamiento]: " .. msg)
            end
        end
    end)

    -- General Commands
    CommandRegistry.Register("/notify", function(player, msg)
        local args = string.split(msg, " ")
        local targetName = string.lower(args[1] or "")
        local actualMsg = table.concat(args, " ", 2)
        
        if targetName == "all" and actualMsg ~= "" then
            ReplicatedStorage.NotifyPlayerEvent:FireAllClients(player.Name, actualMsg)
        elseif targetName ~= "" and actualMsg ~= "" then
            local targets = Utils.findPlayersByPrefix(targetName)
            if #targets > 0 then
                ReplicatedStorage.NotifyPlayerEvent:FireClient(targets[1], player.Name, actualMsg)
            end
        end
    end)

    CommandRegistry.Register("/help", function(player, msg)
        for _, target in pairs(Players:GetPlayers()) do
            if Utils.isAdmin(target) then
                ReplicatedStorage.NotifyPlayerEvent:FireClient(target, player.Name, msg, true)
            end
        end
    end)

    -- Admin Event/State Commands
    CommandRegistry.Register("/pd", function(player, msg)
        if not Utils.isAdmin(player) then return end
        local event = ReplicatedStorage:FindFirstChild("PDBroadcast")
        if not event then return end
        
        local state = string.lower(string.gsub(msg, "%s+", ""))
        if state == "on" then 
            PermadeathModule.SetState(true, player)
            ReplicatedStorage:SetAttribute("PermadeathActive", true)
            for _, p in ipairs(game.Players:GetPlayers()) do
                p:SetAttribute("PermadeathAccepted", true)
            end
            event:FireAllClients(true)
        elseif state == "off" then 
            PermadeathModule.SetState(false, player)
            ReplicatedStorage:SetAttribute("PermadeathActive", nil)
            event:FireAllClients(false)
            -- Reset PermadeathAccepted attribute when event ends
            for _, p in ipairs(game.Players:GetPlayers()) do
                p:SetAttribute("PermadeathAccepted", nil)
            end
        end
        
        local bridge = ReplicatedStorage:FindFirstChild("CustomCommandBridge")
        if bridge then
            bridge:Fire(player, "/pd " .. msg)
        end
    end)

    CommandRegistry.Register("/aceptar", function(player, msg)
        if not Utils.isAdmin(player) then return end
        local targets = Utils.findPlayersByPrefix(msg)
        for _, t in ipairs(targets) do
            t:SetAttribute("PermadeathAccepted", true)
            local narEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
            if narEvent then
                narEvent:FireClient(t, "Has sido aceptado en el evento de muerte permanente. ¡Buena suerte!", true)
            end
        end
    end)

    CommandRegistry.Register("/cutscene", function(player, msg)
        if not Utils.isAdmin(player) then return end
        local event = ReplicatedStorage:FindFirstChild("CutsceneEvent")
        if not event then return end
        
        local action = string.lower(string.gsub(msg, "%s+", ""))
        if action == "on" then
            event:FireAllClients("on")
        elseif action == "off" then
            event:FireAllClients("off")
        elseif action == "vintage" then
            event:FireAllClients("vintage")
        end
    end)

    CommandRegistry.Register("/wipe", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local query = string.gsub(msg, "^%s+", ""):gsub("%s+$", "")
        if query == "" then
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then notify:FireClient(player, "Sistema", "Uso: /wipe [Username/UserId]") end
            return
        end
        
        local DataStoreService = game:GetService("DataStoreService")
        local loreStore = DataStoreService:GetDataStore("PlayerLore_V1")
        local hungerStore = DataStoreService:GetDataStore("PlayerHunger_V1")
        local thirstStore = DataStoreService:GetDataStore("PlayerThirst_V1")
        local titleStore = DataStoreService:GetDataStore("PlayerEquippedTitles_V1")
        
        local function performAllDataWipe(userId)
            local s1, e1 = pcall(function() loreStore:RemoveAsync("Lore_" .. userId) end)
            local s2, e2 = pcall(function() hungerStore:RemoveAsync("Hunger_" .. userId) end)
            local s3, e3 = pcall(function() thirstStore:RemoveAsync("Thirst_" .. userId) end)
            local s4, e4 = pcall(function() titleStore:RemoveAsync(tostring(userId)) end)
            
            local success = s1 and s2 and s3 and s4
            local errMsg = ""
            if not s1 then errMsg = errMsg .. "Lore: " .. tostring(e1) .. " | " end
            if not s2 then errMsg = errMsg .. "Hunger: " .. tostring(e2) .. " | " end
            if not s3 then errMsg = errMsg .. "Thirst: " .. tostring(e3) .. " | " end
            if not s4 then errMsg = errMsg .. "Titles: " .. tostring(e4) .. " | " end
            
            return success, errMsg
        end
        
        -- Caso 1: Es un UserId numérico directo
        local targetUserId = tonumber(query)
        if targetUserId then
            local targetPlayer = Players:GetPlayerByUserId(targetUserId)
            if targetPlayer then
                targetPlayer:SetAttribute("Wiped", true)
                targetPlayer:Kick("Tus datos han sido completamente borrados (Wipe).")
                
                -- Pequeño wait para dejar que PlayerRemoving se procese y bloquee el guardado
                task.wait(0.5)
                
                local success, err = performAllDataWipe(targetUserId)
                local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
                if notify then
                    if success then
                        notify:FireClient(player, "Sistema", "Wipe exitoso para el jugador online: " .. targetPlayer.Name .. " (UserId: " .. tostring(targetUserId) .. ")")
                    else
                        notify:FireClient(player, "Sistema", "Wipe parcial para " .. targetPlayer.Name .. ". Errores: " .. err)
                    end
                end
            else
                local success, err = performAllDataWipe(targetUserId)
                local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
                if notify then
                    if success then
                        notify:FireClient(player, "Sistema", "Wipe exitoso para el UserId offline: " .. tostring(targetUserId))
                    else
                        notify:FireClient(player, "Sistema", "Error al borrar UserId offline: " .. err)
                    end
                end
            end
            return
        end
        
        -- Caso 2: Es un nombre de jugador online
        local targets = Utils.findPlayersByPrefix(query)
        if #targets > 0 then
            local t = targets[1]
            t:SetAttribute("Wiped", true)
            t:Kick("Tus datos han sido completamente borrados (Wipe).")
            
            -- Pequeño wait para dejar que PlayerRemoving se procese y bloquee el guardado
            task.wait(0.5)
            
            local success, err = performAllDataWipe(t.UserId)
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                if success then
                    notify:FireClient(player, "Sistema", "Wipe exitoso para el jugador online: " .. t.Name .. " (UserId: " .. tostring(t.UserId) .. ")")
                else
                    notify:FireClient(player, "Sistema", "Wipe parcial para " .. t.Name .. ". Errores: " .. err)
                end
            end
            return
        end
        
        -- Caso 3: Jugador offline por su nombre de usuario
        task.spawn(function()
            local success, resolvedUserId = pcall(function()
                return Players:GetUserIdFromNameAsync(query)
            end)
            
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if success and resolvedUserId then
                local removeSuccess, err = performAllDataWipe(resolvedUserId)
                if notify then
                    if removeSuccess then
                        notify:FireClient(player, "Sistema", "Wipe exitoso para el jugador offline: " .. query .. " (UserId: " .. tostring(resolvedUserId) .. ")")
                    else
                        notify:FireClient(player, "Sistema", "Error al borrar offline: " .. err)
                    end
                end
            else
                if notify then
                    notify:FireClient(player, "Sistema", "No se encontró ningún jugador online u offline con el nombre: " .. query)
                end
            end
        end)
    end)

    CommandRegistry.Register("/narrar", function(player, msg)
        if not Utils.isAdmin(player) then return end
        local event = ReplicatedStorage:FindFirstChild("NarrateEvent")
        if event then event:FireAllClients(msg) end
    end)

    CommandRegistry.Register("/instant", function(player, msg)
        local hasAccess = Utils.isAdmin(player) or player:GetAttribute("CanUseInstant") == true
        if not hasAccess then return end
        
        -- Quitar comillas si existen
        local cleanMsg = msg:match('^"%s*(.-)%s*"$') or msg:match("^'%s*(.-)%s*'$") or msg
        if cleanMsg == "" then return end
        
        local event = ReplicatedStorage:FindFirstChild("NarrateEvent")
        if event then
            event:FireClient(player, cleanMsg, true)
        end
    end)

    CommandRegistry.Register("/grantinstant", function(player, msg)
        if not Utils.isAdmin(player) then return end
        local targets = Utils.findPlayersByPrefix(msg)
        for _, t in ipairs(targets) do
            t:SetAttribute("CanUseInstant", true)
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(t, "Sistema", "Se te ha concedido el permiso para usar /instant.")
                notify:FireClient(player, "Sistema", "Permiso /instant concedido a " .. t.Name)
            end
        end
    end)

    CommandRegistry.Register("/revokeinstant", function(player, msg)
        if not Utils.isAdmin(player) then return end
        local targets = Utils.findPlayersByPrefix(msg)
        for _, t in ipairs(targets) do
            t:SetAttribute("CanUseInstant", nil)
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(t, "Sistema", "Se te ha retirado el permiso para usar /instant.")
                notify:FireClient(player, "Sistema", "Permiso /instant retirado a " .. t.Name)
            end
        end
    end)

    -- Toggle State Commands (Blind, Sanity, Trauma)
    local function toggleStateCommand(cmd, player, msg)
        if not Utils.isAdmin(player) then return end
        
        if cmd == "/blind" or cmd == "/unblind" then
            local event = ReplicatedStorage:FindFirstChild("BlindEvent")
            if not event then return end
            local state = (cmd == "/blind")
            if msg == "all" then 
                event:FireAllClients(state)
            else
                local targets = Utils.findPlayersByPrefix(msg)
                for _, t in ipairs(targets) do event:FireClient(t, state) end
            end
        elseif cmd == "/lowsanity" or cmd == "/trauma" then
            local eventName = (cmd == "/lowsanity") and "LowSanityEvent" or "TraumaEvent"
            local event = ReplicatedStorage:FindFirstChild(eventName)
            if not event then return end
            local args = string.split(msg, " ")
            local targetSearch = args[1]
            table.remove(args, 1)
            local content = table.concat(args, " ")
            if string.lower(targetSearch or "") == "all" then
                event:FireAllClients(content)
            else
                local targets = Utils.findPlayersByPrefix(targetSearch)
                for _, t in ipairs(targets) do event:FireClient(t, content) end
            end
        end
    end
    CommandRegistry.Register("/blind", function(p,m) toggleStateCommand("/blind", p, m) end)
    CommandRegistry.Register("/unblind", function(p,m) toggleStateCommand("/unblind", p, m) end)
    CommandRegistry.Register("/lowsanity", function(p,m) toggleStateCommand("/lowsanity", p, m) end)
    CommandRegistry.Register("/trauma", function(p,m) toggleStateCommand("/trauma", p, m) end)

    -- Stat Commands
    local function setStatCommand(cmd, player, msg)
        if not Utils.isAdmin(player) then return end
        local args = string.split(msg, " ")
        if #args >= 2 then
            local targetName = args[1]
            local amount = tonumber(args[2])
            if amount then
                local targets = Utils.findPlayersByPrefix(targetName)
                local attr = (cmd == "/sethunger") and "Hunger" or "Thirst"
                for _, t in ipairs(targets) do
                    local val = t:FindFirstChild(attr)
                    if val then val.Value = math.clamp(amount, 0, 100) end
                end
            end
        end
    end
    CommandRegistry.Register("/sethunger", function(p,m) setStatCommand("/sethunger", p, m) end)
    CommandRegistry.Register("/setthirst", function(p,m) setStatCommand("/setthirst", p, m) end)
    
    -- Command: /give [Player] [Tool]
    CommandRegistry.Register("/give", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local args = string.split(msg, " ")
        if #args < 2 then return end
        
        local targetQuery = args[1]
        local toolQuery = table.concat(args, " ", 2)
        
        local targets = {}
        if string.lower(targetQuery) == "all" then
            targets = Players:GetPlayers()
        else
            targets = Utils.findPlayersByPrefix(targetQuery)
        end
        
        if #targets == 0 then return end
        
        -- Buscar el tool en ServerStorage o ReplicatedStorage
                local function findTool(folder, query)
            for _, item in ipairs(folder:GetDescendants()) do
                if item:IsA("Tool") and (string.lower(item.Name) == string.lower(query) or string.lower(item.Name):find(string.lower(query))) then
                    return item
                end
            end
        end
        local toolTemplate = findTool(game.ServerStorage, toolQuery) or findTool(game.ReplicatedStorage, toolQuery)
    
        if not toolTemplate then
            for _, child in ipairs(game.ServerStorage:GetChildren()) do
                if child:IsA("Tool") and string.lower(child.Name):sub(1, #toolQuery) == string.lower(toolQuery) then
                    toolTemplate = child
                    break
                end
            end
        end
        
        if not toolTemplate then
            toolTemplate = ReplicatedStorage:FindFirstChild(toolQuery)
        end
        
        if not toolTemplate or not toolTemplate:IsA("Tool") then 
            -- Intento final: buscar por prefijo en ReplicatedStorage
            for _, child in ipairs(ReplicatedStorage:GetChildren()) do
                if child:IsA("Tool") and string.lower(child.Name):sub(1, #toolQuery) == string.lower(toolQuery) then
                    toolTemplate = child
                    break
                end
            end
        end
        
        if not toolTemplate or not toolTemplate:IsA("Tool") then return end
        
        for _, target in ipairs(targets) do
            local backpack = target:FindFirstChild("Backpack")
            local char = target.Character
            
            if not backpack then continue end
            
            -- El consolidador ya se encarga de agrupar si simplemente lo clonamos,
            -- pero lo haremos explícitamente para asegurar que el feedback visual sea instantáneo.
            local existing = backpack:FindFirstChild(toolTemplate.Name) or (char and char:FindFirstChild(toolTemplate.Name))
            
            if existing and existing:IsA("Tool") then
                local current = existing:GetAttribute("Cantidad") or 1
                existing:SetAttribute("Cantidad", current + 1)
            else
                local clone = toolTemplate:Clone()
                clone:SetAttribute("Cantidad", 1)
                clone.Parent = backpack
            end
        end
    end)

    -- Player Control Commands
    local function trackCommand(cmd, player, msg)
        if not Utils.isAdmin(player) then return end
        local targetName = string.lower(msg)
        local isTrack = (cmd == "/track")

        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local torso = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Torso") or p.Character:FindFirstChild("UpperTorso")
                if torso then
                    local oldTag = torso:FindFirstChild("AdminTrackTag")
                    if oldTag then oldTag:Destroy() end
                end
            end
        end

        local targets = {}
        if targetName == "all" then
            for _, p in pairs(Players:GetPlayers()) do
                table.insert(targets, p)
            end
        else
            for _, p in pairs(Players:GetPlayers()) do
                if string.lower(p.Name):sub(1, #targetName) == targetName or
                   string.lower(p.DisplayName):sub(1, #targetName) == targetName then
                    table.insert(targets, p)
                    break
                end
            end
        end

        for _, adminPlayer in pairs(Players:GetPlayers()) do
            if Utils.isAdmin(adminPlayer) then
                for _, target in ipairs(targets) do
                    AdminTrackEvent:FireClient(adminPlayer, {
                        action = isTrack and "track" or "untrack",
                        userId = target.UserId,
                    })
                end
            end
        end
    end
    CommandRegistry.Register("/track", function(p,m) trackCommand("/track", p, m) end)
    CommandRegistry.Register("/untrack", function(p,m) trackCommand("/untrack", p, m) end)

    CommandRegistry.Register("/ragdoll", function(player, msg)
        if not Utils.isAdmin(player) then return end
        local targets = Utils.findPlayersByPrefix(msg)
        for _, target in ipairs(targets) do
            if target.Character then
                local val = target.Character:FindFirstChild("IsRagdoll")
                if val then val.Value = true end
            end
        end
    end)
    CommandRegistry.Register("/unragdoll", function(player, msg)
        if not Utils.isAdmin(player) then return end
        local targets = Utils.findPlayersByPrefix(msg)
        for _, target in ipairs(targets) do
            if target.Character then
                local val = target.Character:FindFirstChild("IsRagdoll")
                if val then val.Value = false end
            end
        end
    end)

    local function glowCommand(cmd, player, msg)
        if not Utils.isAdmin(player) then return end
        local targets = Utils.findPlayersByPrefix(msg)
        local isGlow = (cmd == "/glow")
        
        for _, t in ipairs(targets) do
            if t.Character then
                local existing = t.Character:FindFirstChild("AdminGlow")
                if isGlow then
                    if not existing then
                        local highlight = Instance.new("Highlight")
                        highlight.Name = "AdminGlow"
                        highlight.FillTransparency = 1
                        highlight.OutlineColor = Color3.new(1, 1, 1)
                        highlight.OutlineTransparency = 0
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.Parent = t.Character
                    end
                else
                    if existing then
                        existing:Destroy()
                    end
                end
            end
        end
    end
    CommandRegistry.Register("/glow", function(p,m) glowCommand("/glow", p, m) end)
    CommandRegistry.Register("/unglow", function(p,m) glowCommand("/unglow", p, m) end)

    -- Lore Commands
    local function nameCommand(cmd, player, msg)
        if not Utils.isAdmin(player) then return end
        local args = string.split(msg, " ")
        if #args >= 2 then
            local targetName = args[1]
            local newValue = table.concat(args, " ", 2)
            local targets = Utils.findPlayersByPrefix(targetName)
            local attr = (cmd == "/nombre") and "LoreFirstName" or "LoreLastName"
            
            for _, t in ipairs(targets) do
                local val = t:FindFirstChild(attr)
                if val then 
                    val.Value = newValue
                    local fn = t:FindFirstChild("LoreFirstName")
                    local ln = t:FindFirstChild("LoreLastName")
                    local ag = t:FindFirstChild("LoreAge")
                    if fn and ln and ag then
                        local loreStore = game:GetService("DataStoreService"):GetDataStore("PlayerLore_V1")
                        pcall(function() 
                            loreStore:SetAsync("Lore_"..t.UserId, {
                                UserId = t.UserId,
                                Username = t.Name,
                                FirstName = fn.Value, 
                                LastName = ln.Value, 
                                Age = ag.Value
                            }) 
                        end)
                    end
                end
            end
        end
    end
    CommandRegistry.Register("/nombre", function(p,m) nameCommand("/nombre", p, m) end)
    CommandRegistry.Register("/apellido", function(p,m) nameCommand("/apellido", p, m) end)

    -- Money Commands
    CommandRegistry.Register("/pay", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local args = string.split(msg, " ")
        if #args < 3 then 
            -- ReplicatedStorage.NotifyPlayerEvent:FireClient(player, "System", "Uso: /pay [oro,plata,bronce] [Player] [Amount]")
            return 
        end
        
        local currencyType = string.lower(args[1])
        local targetName = args[2]
        local amount = tonumber(args[3])
        
        if not amount then return end
        
        local currencyAttr = ""
        if currencyType == "oro" or currencyType == "gold" then
            currencyAttr = "Gold"
        elseif currencyType == "plata" or currencyType == "silver" then
            currencyAttr = "Silver"
        elseif currencyType == "bronce" or currencyType == "bronze" then
            currencyAttr = "Bronze"
        else
            return
        end
        
        local targets = Utils.findPlayersByPrefix(targetName)
        if #targets == 0 then return end
        
        local LoreModule = require(script.Parent.LoreModule)
        
        for _, t in ipairs(targets) do
            LoreModule.AddMoney(t, currencyType, amount)
            
            -- Notificar a ambos si existe el evento
            local notifyEvent = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notifyEvent then
                notifyEvent:FireClient(t, "Sistema", "Has recibido " .. amount .. " de " .. currencyType)
                notifyEvent:FireClient(player, "Sistema", "Has dado " .. amount .. " de " .. currencyType .. " a " .. t.Name)
            end
        end
    end)

    -- Cinematic Commands
    CommandRegistry.Register("/efecto", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local args = string.split(msg, " ")
        if #args < 2 then return end
        
        local tipo = string.lower(args[1])
        local targetQuery = args[2]
        local duration = tonumber(args[3])
        
        if tipo == "heartbeat" then
            local HeartbeatModule = require(script.Parent.HeartbeatModule)
            HeartbeatModule.Trigger(player, targetQuery, duration)
        elseif tipo == "ansiedad" then
            local AnsiedadModule = require(script.Parent.AnsiedadModule)
            AnsiedadModule.Trigger(player, targetQuery, duration)
        elseif tipo == "fear" then
            local FearModule = require(script.Parent.FearModule)
            FearModule.Trigger(player, targetQuery, duration)
        elseif tipo == "prowler" then
            local ProwlerModule = require(script.Parent.ProwlerModule)
            ProwlerModule.Trigger(player, targetQuery, duration)
        elseif tipo == "presion" then
            local PresionModule = require(script.Parent.PresionModule)
            PresionModule.Trigger(player, targetQuery, duration)
        elseif tipo == "terremoto" then
            local TerremotoModule = require(script.Parent.TerremotoModule)
            TerremotoModule.Trigger(player, targetQuery, duration)
		end
    end)

    CommandRegistry.Register("/pensamiento", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local targetQuery, content = string.match(msg, "^(%S+)%s+(.+)$")
        if not targetQuery or not content then return end
        
        local targets = {}
        if string.lower(targetQuery) == "all" then
            local Players = game:GetService("Players")
            targets = Players:GetPlayers()
        else
            targets = Utils.findPlayersByPrefix(targetQuery)
        end
        
        local penEvent = ReplicatedStorage:FindFirstChild("PensamientoEvent")
        local narEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
        
        for _, t in ipairs(targets) do
            -- 4 seconds hold, 2 seconds fade out
            if penEvent then penEvent:FireClient(t, 4, 2) end
            if narEvent then narEvent:FireClient(t, content, true, 4, 2) end
        end
    end)


    -- Environment Commands
    CommandRegistry.Register("/weather", function(player, msg)
        if not Utils.isAdmin(player) then return end
        local weatherType = string.lower(msg):match("^%s*(.-)%s*$")
        WeatherModule.SetWeather(weatherType)
    end)
    
    CommandRegistry.Register("/healthbar", function(player, msg)
        if not Utils.isAdmin(player) then return end
        local BossHealthbarModule = require(script.Parent.BossHealthbarModule)
        local query = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if query == "" then
            BossHealthbarModule.TrackTarget(nil)
            return
        end

        local targetQuery, customTitle = string.match(query, "^(%S+)%s+(.+)$")
        if not targetQuery then targetQuery = query; customTitle = nil end
        if customTitle then 
            customTitle = customTitle:gsub("^%s+", ""):gsub("%s+$", "")
            if customTitle == "" then customTitle = nil end 
        end

        local targets = Utils.findPlayersByPrefix(targetQuery)
        if targets[1] then
            BossHealthbarModule.TrackTarget(targets[1], customTitle)
        end
    end)

    CommandRegistry.Register("/rejoin", function(player, msg)
        local TeleportService = game:GetService("TeleportService")
        TeleportService:Teleport(game.PlaceId, player)
    end)

    CommandRegistry.Register("/menu", function(player, msg)
        local LoreModule = require(script.Parent.LoreModule)
        pcall(function()
            LoreModule.SaveAllData(player)
        end)
        
        local TeleportService = game:GetService("TeleportService")
        pcall(function()
            TeleportService:Teleport(79321434096177, player)
        end)
    end)

    CommandRegistry.Register("/givepoints", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local args = string.split(msg, " ")
        local targetQuery = args[1]
        local amount = tonumber(args[2]) or 10
        
        if not targetQuery then return end
        
        local targets = {}
        if targetQuery:lower() == "all" then
            targets = game.Players:GetPlayers()
        else
            targets = Utils.findPlayersByPrefix(targetQuery)
        end
        
        local Lore = require(game.ServerScriptService.ServerModules.LoreModule)
        
        for _, t in ipairs(targets) do
            local ap = t:FindFirstChild("AttributePoints")
            if ap then
                ap.Value = ap.Value + amount
                Lore.SaveAllData(t)
                
                local notify = game.ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
                if notify then
                    notify:FireClient(t, "Sistema", "Has recibido " .. amount .. " puntos de atributo.")
                    notify:FireClient(player, "Sistema", "Has otorgado " .. amount .. " puntos a " .. t.Name)
                end
            end
        end
    end)

    CommandRegistry.Register("/honor", function(player, msg)
        if not Utils.isAdmin(player) and not game:GetService("RunService"):IsStudio() and player.Name ~= "BYjoselitoYT" then
            return
        end
        
        local args = string.split(msg, " ")
        local targetQuery = args[1]
        local amount = tonumber(args[2])
        
        if not targetQuery or not amount then 
            return 
        end
        
        local targets = {}
        if targetQuery:lower() == "all" then
            targets = game.Players:GetPlayers()
        else
            targets = Utils.findPlayersByPrefix(targetQuery)
        end
        
        for _, t in ipairs(targets) do
            t:SetAttribute("MaxHonor", 100)
            t:SetAttribute("Honor", math.clamp(amount, 0, 100))
            
            LoreModule.SaveAllData(t)
        end
    end)

    CommandRegistry.Register("/infeccion", function(player, msg)
        if not Utils.isAdmin(player) and not game:GetService("RunService"):IsStudio() and player.Name ~= "BYjoselitoYT" then
            return
        end
        
        local args = string.split(msg, " ")
        local targetQuery = args[1]
        local amount = tonumber(args[2]) or 0
        
        if not targetQuery then 
            return 
        end
        
        local targets = {}
        if targetQuery:lower() == "all" then
            targets = game.Players:GetPlayers()
        else
            targets = Utils.findPlayersByPrefix(targetQuery)
        end
        
        for _, t in ipairs(targets) do
            t:SetAttribute("Infection", math.clamp(amount, 0, 100))
            LoreModule.SaveAllData(t)
            
            local notify = game.ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Has ajustado la infección de " .. t.Name .. " al " .. amount .. "%.")
            end
        end
    end)

    -- ==========================================
    -- NUEVOS COMANDOS DE HERIDAS AVANZADAS
    -- ==========================================
    CommandRegistry.Register("/herida", function(player, msg)
        if not Utils.isAdmin(player) and not game:GetService("RunService"):IsStudio() and player.Name ~= "BYjoselitoYT" then
            return
        end
        
        local args = string.split(msg, " ")
        if #args < 3 then
            local notify = game.ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Uso: /herida [Jugador] [Zona] [TipoHerida]")
            end
            return
        end
        
        local targetQuery = args[1]
        local partQuery = string.lower(args[2] or "")
        local woundQuery = string.lower(args[3] or "")
        
        local bodyPartsMap = {
            cabeza = "Head", head = "Head",
            torso = "Torso",
            brazoizq = "LeftArm", brazoizquierdo = "LeftArm", leftarm = "LeftArm",
            brazoder = "RightArm", brazoderecho = "RightArm", rightarm = "RightArm",
            piernaizq = "LeftLeg", piernaizquierda = "LeftLeg", leftleg = "LeftLeg",
            piernader = "RightLeg", piernaderecha = "RightLeg", rightleg = "RightLeg"
        }
        local mappedPart = bodyPartsMap[partQuery]
        if not mappedPart then
            local notify = game.ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Zona del cuerpo inválida. Opciones: cabeza, torso, brazoizq, brazoder, piernaizq, piernader.")
            end
            return
        end
        
        local woundTypesMap = {
            ["rasguño"] = "Scratch", rasguno = "Scratch", scratch = "Scratch",
            corte = "Cut", cut = "Cut",
            profunda = "DeepWound", profundaherida = "DeepWound", deep = "DeepWound",
            fractura = "Fracture", fracture = "Fracture",
            quemadura = "Burn", burn = "Burn",
            vidrio = "Glass", glass = "Glass"
		}
        local mappedWound = woundTypesMap[woundQuery]
        if not mappedWound then
            local notify = game.ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Tipo de herida inválida. Opciones: rasguño, corte, profunda, fractura, quemadura, vidrio.")
            end
            return
        end
        
        local targets = {}
        if targetQuery:lower() == "all" then
            targets = game.Players:GetPlayers()
        else
            targets = Utils.findPlayersByPrefix(targetQuery)
        end
        
        if #targets == 0 then
            local notify = game.ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Jugador no encontrado.")
            end
            return
        end
        
        local AdvancedInjuryModule = require(game.ServerScriptService.ServerModules.AdvancedInjuryModule)
        
        for _, t in ipairs(targets) do
            AdvancedInjuryModule.AddInjury(t, mappedPart, mappedWound)
        end
    end)

    CommandRegistry.Register("/medicos", function(player, msg)
        if not Utils.isAdmin(player) and not game:GetService("RunService"):IsStudio() and player.Name ~= "BYjoselitoYT" then
            return
        end
        
        local targetQuery = msg ~= "" and msg or player.Name
        local targets = Utils.findPlayersByPrefix(targetQuery)
        
        local medicalItems = {
            "Venda", "Sutura", "Desinfectante", 
            "Crema para Quemaduras", "Pinzas", "Tablilla"
        }

        local function findToolTemplate(name)
            for _, item in ipairs(game.ServerStorage:GetDescendants()) do
                if item:IsA("Tool") and item.Name == name then
                    return item
                end
            end
            for _, item in ipairs(game.ReplicatedStorage:GetDescendants()) do
                if item:IsA("Tool") and item.Name == name then
                    return item
                end
            end
            for _, item in ipairs(game.StarterPack:GetDescendants()) do
                if item:IsA("Tool") and item.Name == name then
                    return item
                end
            end
            return nil
        end
        
        for _, t in ipairs(targets) do
            local backpack = t:FindFirstChild("Backpack")
            if backpack then
                for _, itemName in ipairs(medicalItems) do
                    local existing = backpack:FindFirstChild(itemName) or (t.Character and t.Character:FindFirstChild(itemName))
                    local template = findToolTemplate(itemName)
                    
                    if existing then
                        local isDummy = false
                        if template and #template:GetChildren() > 0 and #existing:GetChildren() == 0 then
                            isDummy = true
                        end
                        
                        if isDummy then
                            local current = existing:GetAttribute("Cantidad") or 1
                            existing:Destroy()
                            local clone = template:Clone()
                            clone:SetAttribute("Cantidad", current + 5)
                            clone.Parent = backpack
                        else
                            local current = existing:GetAttribute("Cantidad") or 1
                            existing:SetAttribute("Cantidad", current + 5)
                        end
                    else
                        if template then
                            local clone = template:Clone()
                            clone:SetAttribute("Cantidad", 5)
                            clone.Parent = backpack
                        else
                            local tool = Instance.new("Tool")
                            tool.Name = itemName
                            tool.RequiresHandle = false
                            tool:SetAttribute("Cantidad", 5)
                            tool.Parent = backpack
                        end
                    end
                end
            end
        end
    end)

    CommandRegistry.Register("/giveTP", function(player, msg)
        if not Utils.isAdmin(player) and not game:GetService("RunService"):IsStudio() and player.Name ~= "BYjoselitoYT" then return end
        
        local args = string.split(msg, " ")
        local targetQuery = args[1]
        local amount = tonumber(args[2])
        
        if not targetQuery or not amount then
            local notify = game.ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then notify:FireClient(player, "Sistema", "Uso: /giveTP [jugador] [cantidad]") end
            return
        end
        
        local targets = {}
        if targetQuery:lower() == "all" then
            targets = game.Players:GetPlayers()
        else
            targets = Utils.findPlayersByPrefix(targetQuery)
        end
        
        local LoreModule = require(script.Parent.LoreModule)
        for _, t in ipairs(targets) do
            task.spawn(function()
                LoreModule.AddTP(t, amount)
                
                local tpPoints = t:FindFirstChild("TalentPoints")
                local tpDecks = t:FindFirstChild("TPDecksEarned")
                local nextCost = tpDecks and math.floor(2 ^ tpDecks.Value) or 1
                local currentTP = tpPoints and tpPoints.Value or 0
                local decksEarned = tpDecks and tpDecks.Value or 0
                
                local notify = game.ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
                if notify then
                    notify:FireClient(player, "Sistema", "Has dado " .. amount .. " TP a " .. t.Name .. " | Barajas: " .. decksEarned .. " | TP: " .. currentTP .. "/" .. nextCost)
                    notify:FireClient(t, "Sistema", "Has ganado " .. amount .. " TP." .. "| Siguiente baraja: " .. currentTP .. "/" .. nextCost .. " TP")
                end
            end)
        end
    end)

    -- Condiciones / Injuries
    local CONDICION_ALIAS = {
        ["ciego"]       = "ciego",
        ["blind"]       = "ciego",
        ["piernorota"]  = "piernorota",
        ["piernarota"]  = "piernorota",
        ["legbroken"]   = "piernorota",
        ["brazoroto"]   = "brazoroto",
        ["brazorota"]   = "brazoroto",
        ["armbroken"]   = "brazoroto",
        ["extremidad"]  = "extremidad",
        ["limbloss"]    = "extremidad",
        ["perdidaojo"]  = "perdidaojo",
        ["eyeloss"]     = "perdidaojo",
        ["concusion"]   = "concusion",
        ["concussion"]  = "concusion",
        ["esquizofrenia"] = "esquizofrenia",
        ["schizo"]      = "esquizofrenia",
    }

    CommandRegistry.Register("/injuries", function(player, msg)
        if not Utils.isAdmin(player) then return end

        local args = string.split(msg, " ")
        local action = string.lower(args[1] or "")
        local targetQuery = args[2] or ""

        -- Soporte para /injuries remove [tipo] [jugador]
        local condicionRaw = action
        local isRemove = false
        if action == "remove" or action == "quitar" then
            isRemove = true
            condicionRaw = string.lower(args[2] or "")
            targetQuery = args[3] or ""
        end

        local condicion = CONDICION_ALIAS[condicionRaw]
        if not condicion then
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Condicion desconocida. Opciones: ciego, piernorota, brazoroto, extremidad, perdidaojo, concusion, esquizofrenia")
            end
            return
        end

        local CondicionesModule = require(script.Parent.CondicionesModule)

        local targets = {}
        if string.lower(targetQuery) == "all" then
            targets = Players:GetPlayers()
        else
            targets = Utils.findPlayersByPrefix(targetQuery)
        end

        if #targets == 0 then
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then notify:FireClient(player, "Sistema", "Jugador no encontrado.") end
            return
        end

        for _, t in ipairs(targets) do
            if isRemove then
                CondicionesModule.Remove(t, condicion)
            else
                CondicionesModule.Apply(t, condicion)
            end
        end
    end)

    -- Comando para remover/activar filtro de chat
    CommandRegistry.Register("/removefilter", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local state = string.lower(string.gsub(msg, "%s+", ""))
        if state == "on" or state == "activar" then
            ReplicatedStorage:SetAttribute("ChatFilterDisabled", true)
            
            -- Notificar a todos los jugadores
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireAllClients("Sistema", "El filtro de chat ha sido DESACTIVADO para permitir idiomas personalizados.")
            end
        elseif state == "off" or state == "desactivar" then
            ReplicatedStorage:SetAttribute("ChatFilterDisabled", nil)
            
            -- Notificar a todos los jugadores
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireAllClients("Sistema", "El filtro de chat ha sido ACTIVADO.")
            end
        else
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Uso: /removefilter [on/off]")
            end
        end
    end)

    -- Comando /ciclardia [on/off]
    CommandRegistry.Register("/ciclardia", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local state = string.lower(string.gsub(msg, "%s+", ""))
        local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
        
        if state == "on" then
            if dayCycleActive then
                if notify then
                    notify:FireClient(player, "Sistema", "El ciclo del día ya está activado.")
                end
                return
            end
            
            dayCycleActive = true
            if notify then
                notify:FireAllClients("Sistema", "El ciclo del día progresivo ha sido ACTIVADO (1 hora de juego cada 10 min reales).")
            end
            
            task.spawn(function()
                while dayCycleActive do
                    task.wait(0.1)
                    if not dayCycleActive then break end
                    -- 1 hora de juego (1.0 ClockTime) cada 10 minutos reales (600s). 
                    -- En 0.1s reales se suma 0.1 / 600 = 1 / 6000
					game.Lighting.ClockTime = (game.Lighting.ClockTime + (1 / 3000)) % 24
                end
            end)
            
        elseif state == "off" then
            if not dayCycleActive then
                if notify then
                    notify:FireClient(player, "Sistema", "El ciclo del día ya está desactivado.")
                end
                return
            end
            
            dayCycleActive = false
            if notify then
                notify:FireAllClients("Sistema", "El ciclo del día progresivo ha sido DESACTIVADO.")
            end
        else
            if notify then
                notify:FireClient(player, "Sistema", "Uso: /ciclardia [on/off]")
            end
        end
    end)

    -- Comando /tiempo [hora] para cambiar el ClockTime directamente
    CommandRegistry.Register("/tiempo", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local hour = tonumber(msg)
        if hour then
            game.Lighting.ClockTime = math.clamp(hour, 0, 24)
        else
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Uso: /tiempo [0-24]")
            end
        end
    end)

    CommandRegistry.Register("/time", function(player, msg)
        if not Utils.isAdmin(player) then return end
        local hour = tonumber(msg)
        if hour then
            game.Lighting.ClockTime = math.clamp(hour, 0, 24)
        else
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Uso: /time [0-24]")
            end
        end
    end)

    CommandRegistry.Register("/setlives", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local args = string.split(msg, " ")
        if #args < 2 then
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then notify:FireClient(player, "Sistema", "Uso: /setlives [jugador] [cantidad]") end
            return
        end
        
        local targetQuery = args[1]
        local amount = tonumber(args[2])
        
        if not targetQuery or not amount then return end
        
        local targets = Utils.findPlayersByPrefix(targetQuery)
        if #targets == 0 then return end
        
        local Lore = require(game.ServerScriptService.ServerModules.LoreModule)
        
        for _, t in ipairs(targets) do
            local lives = t:FindFirstChild("Lives")
            if lives then
                lives.Value = math.clamp(amount, 0, 3)
                Lore.SaveAllData(t)
                
                local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
                if notify then
                    notify:FireClient(t, "Sistema", "Tus vidas ahora son: " .. lives.Value .. "/3")
                    notify:FireClient(player, "Sistema", t.Name .. " -> Vidas: " .. lives.Value .. "/3")
                end
            end
        end
    end)

    CommandRegistry.Register("/checklives", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local targetQuery = msg ~= "" and msg or player.Name
        local targets = Utils.findPlayersByPrefix(targetQuery)
        if #targets == 0 then
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then notify:FireClient(player, "Sistema", "Jugador no encontrado.") end
            return
        end
        
        local t = targets[1]
        local lives = t:FindFirstChild("Lives")
        local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
        if notify and lives then
            notify:FireClient(player, "Sistema", t.Name .. " tiene " .. lives.Value .. "/3 vidas")
        end
    end)

    CommandRegistry.Register("/data", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local targetQuery = msg ~= "" and msg or player.Name
        local targets = Utils.findPlayersByPrefix(targetQuery)
        if #targets == 0 then
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then notify:FireClient(player, "Sistema", "Jugador no encontrado.") end
            return
        end
        
        local t = targets[1]
        -- Ahora solo enviamos el jugador objetivo; el cliente pedira los datos completos via RequestPlayerDataEvent
        local openEvent = ReplicatedStorage:FindFirstChild("OpenDataEditorEvent")
        if openEvent then
            openEvent:FireClient(player, t)
        end
    end)

    -- Comando /ignore [jugador]
    CommandRegistry.Register("/ignore", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local targetQuery = msg ~= "" and msg or player.Name
        local targets = Utils.findPlayersByPrefix(targetQuery)
        
        if #targets == 0 then
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then notify:FireClient(player, "Sistema", "Jugador no encontrado.") end
            return
        end
        
        for _, t in ipairs(targets) do
            t:SetAttribute("IgnoredByNPCs", true)
            
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Los NPCs ahora ignoran a " .. t.Name .. ".")
            end
        end
    end)

    -- Comando /unignore [jugador]
    CommandRegistry.Register("/unignore", function(player, msg)
        if not Utils.isAdmin(player) then return end
        
        local targetQuery = msg ~= "" and msg or player.Name
        local targets = Utils.findPlayersByPrefix(targetQuery)
        
        if #targets == 0 then
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then notify:FireClient(player, "Sistema", "Jugador no encontrado.") end
            return
        end
        
        for _, t in ipairs(targets) do
            t:SetAttribute("IgnoredByNPCs", nil)
            
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Los NPCs ya no ignoran a " .. t.Name .. ".")
            end
        end
    end)

end

return RPCommandsModule
