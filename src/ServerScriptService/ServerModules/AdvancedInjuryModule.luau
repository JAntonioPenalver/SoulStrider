local AdvancedInjuryModule = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local InjuryConfig = require(ReplicatedStorage.Modules.AdvancedInjuries.InjuryConfig)
local InjuryUpdateEvent = ReplicatedStorage:WaitForChild("InjuryUpdateEvent")

-- Estado global de heridas de los jugadores en el servidor
AdvancedInjuryModule.PlayerInjuries = {}
AdvancedInjuryModule.ActiveMedics = {}

-- Configuracion de probabilidades de heridas segun el origen del daño
AdvancedInjuryModule.InjuryChances = {
    ["Puños"] = {
        {Type = "Scratch", Chance = 15}
    },
    ["Espada"] = {
        {Type = "DeepWound", Chance = 25},
        {Type = "Cut", Chance = 25}
    },
    ["Daga"] = {
        {Type = "DeepWound", Chance = 25},
        {Type = "Cut", Chance = 25}
    },
    ["StrongRight"] = {
        {Type = "Fracture", Chance = 50}
    },
    ["Real Goblin"] = {
        {Type = "Scratch", Chance = 10},
        {Type = "DeepWound", Chance = 10}
    },
    ["Default"] = {
        {Type = "Cut", Chance = 10}
    }
}

-- Función para tirar los dados e infligir una herida aleatoria
function AdvancedInjuryModule.RollForInjury(victimPlayer, attackerName)
    local PermadeathModule = require(game.ServerScriptService.ServerModules.PermadeathModule)
    if not PermadeathModule.Active then return end
    
    local chances = AdvancedInjuryModule.InjuryChances[attackerName] or AdvancedInjuryModule.InjuryChances["Default"]
    
    for _, injuryData in ipairs(chances) do
        local roll = math.random(1, 100)
        if roll <= injuryData.Chance then
            -- Elegir una parte del cuerpo aleatoria
            local bodyParts = {"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}
            local randomPart = bodyParts[math.random(1, #bodyParts)]
            
            AdvancedInjuryModule.AddInjury(victimPlayer, randomPart, injuryData.Type)
            
            -- Solo infligir una herida por ataque para no saturar al jugador
            break
        end
    end

    -- INTEGRACIÓN CON SISTEMA DE CONDICIONES SEVERAS (INJURIES) AL ESTAR A MENOS DE 15% DE VIDA
    local char = victimPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 and hum.Health <= hum.MaxHealth * 0.15 then
        local CondicionesModule = require(script.Parent.CondicionesModule)

        -- 1) Chance de 10% para obtener brazo rota o pierna rota
        local roll10 = math.random(1, 100)
        if roll10 <= 10 then
            local conds = {"piernorota", "brazoroto"}
            local selectedCond = conds[math.random(1, #conds)]
            if not CondicionesModule.HasCondicion(victimPlayer, selectedCond) then
                CondicionesModule.Apply(victimPlayer, selectedCond)
            end
        end

        -- 2) Chance de 5% para obtener perdida de ojo o extremidad
        local roll5 = math.random(1, 100)
        if roll5 <= 5 then
            local conds = {"perdidaojo", "extremidad"}
            local selectedCond = conds[math.random(1, #conds)]
            if not CondicionesModule.HasCondicion(victimPlayer, selectedCond) then
                CondicionesModule.Apply(victimPlayer, selectedCond)
            end
        end
    end
end

-- Consumir una herramienta médica de forma segura
local function consumeMedicalItem(player, toolName)
    local backpack = player:FindFirstChild("Backpack")
    local char = player.Character
    
    local tool = (backpack and backpack:FindFirstChild(toolName)) or (char and char:FindFirstChild(toolName))
    if not tool then return false end
    
    local quantity = tool:GetAttribute("Cantidad") or 1
    if quantity > 1 then
        tool:SetAttribute("Cantidad", quantity - 1)
    else
        tool:Destroy()
    end
    return true
end

-- Inicializa las heridas de un jugador
function AdvancedInjuryModule.InitPlayer(player)
    AdvancedInjuryModule.PlayerInjuries[player] = {
        Head = {},
        Torso = {},
        LeftArm = {},
        RightArm = {},
        LeftLeg = {},
        RightLeg = {}
    }
    AdvancedInjuryModule.Replicate(player)
end

-- Limpia las heridas al salir o morir
function AdvancedInjuryModule.ClearPlayer(player)
    AdvancedInjuryModule.PlayerInjuries[player] = nil
end

-- Replica el estado actual de heridas al cliente
function AdvancedInjuryModule.Replicate(player)
    local state = AdvancedInjuryModule.PlayerInjuries[player]
    if state then
        InjuryUpdateEvent:FireClient(player, state)
        -- Si hay un médico activo, replicar también a él con la referencia del paciente
        local medic = AdvancedInjuryModule.ActiveMedics[player]
        if medic and medic.Parent then
            InjuryUpdateEvent:FireClient(medic, state, player)
        end
    end
end

-- Añade una herida a una parte del cuerpo
function AdvancedInjuryModule.AddInjury(player, bodyPart, woundType)
    local state = AdvancedInjuryModule.PlayerInjuries[player]
    if not state then return end
    if not state[bodyPart] then return end
    
    local woundConf = InjuryConfig.WoundTypes[woundType]
    if not woundConf then return end
    
    -- Evitar duplicar fracturas o vidrios en la misma zona
    if woundType == "Fracture" then
        for _, w in ipairs(state[bodyPart]) do
            if w.WoundType == "Fracture" then return end
        end
    end
    if woundType == "Glass" then
        for _, w in ipairs(state[bodyPart]) do
            if w.WoundType == "Glass" then return end
        end
    end
    
    local newWound = {
        WoundType = woundType,
        BleedRate = woundConf.BaseBleedRate,
        Pain = woundConf.BasePain,
        Bandaged = false,
        Sutured = false,
        Disinfected = false,
        Infected = false,
        Splinted = false,
        BurnCreamApplied = false,
        HasGlass = (woundType == "Glass")
    }
    
    table.insert(state[bodyPart], newWound)
    AdvancedInjuryModule.Replicate(player)
    
    -- Mensaje narrador instantáneo de feedback al jugador
    local partConf = InjuryConfig.BodyParts[bodyPart]
    if partConf then
        local woundName = woundConf.DisplayName:lower()
        local articulo = "un"
        if woundType == "DeepWound" or woundType == "Fracture" or woundType == "Burn" then
            articulo = "una"
        end
        
        local msgText = string.format("Parece que tengo una herida en %s, es %s %s", partConf.DisplayName, articulo, woundName)
        
        local NarrateEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
        if NarrateEvent then
            NarrateEvent:FireClient(player, msgText, true)
        end
    end
end

-- Aplica tratamiento a una herida específica
function AdvancedInjuryModule.ApplyTreatment(player, bodyPart, woundIndex, toolName, medic)
    local state = AdvancedInjuryModule.PlayerInjuries[player]
    if not state then return false, "No injury state found" end
    if not state[bodyPart] then return false, "Invalid body part" end
    
    local woundState = state[bodyPart][woundIndex]
    if not woundState then return false, "Wound not found" end
    
    local toolConf = InjuryConfig.MedicalTools[toolName]
    if not toolConf then return false, "Invalid medical item" end
    
    -- Comprobar si el objeto trata este tipo de herida
    local canTreat = false
    for _, t in ipairs(toolConf.Treats) do
        if t == woundState.WoundType then
            canTreat = true
            break
        end
    end
    if not canTreat then return false, "Item cannot treat this wound type" end
    
    -- Validar condiciones específicas (ej. si requiere sutura o ya está suturado)
    if toolConf.RequiresCondition and not toolConf.RequiresCondition(woundState) then
        return false, "Treatment condition not met" end
        
    -- Consumir el objeto del inventario (del médico si existe, de lo contrario del paciente)
    if not toolConf.BypassInventory then
        local user = medic or player
        local consumed = consumeMedicalItem(user, toolName)
        if not consumed then
            return false, "No medical item in inventory"
        end
    end
    
    -- Aplicar el tratamiento
    toolConf.OnApply(woundState, state[bodyPart], woundIndex, player)
    
    -- Si la herida ya no tiene efectos negativos, la removemos o actualizamos
    -- Por ejemplo, un rasguño bandajado ya no sangra ni duele. En Project Zomboid permanece vendado y cicatriza.
    -- Para hacerlo simple e interactivo: si se cura por completo (ej. desinfectante, pinzas aplicadas, o vendado),
    -- dejaremos que permanezca en la lista con el estado actualizado (ej. "Vendado") para simular cicatrización lenta,
    -- y cada cierto tiempo de tick de cicatrización se eliminará.
    
    AdvancedInjuryModule.Replicate(player)
    return true, "Treatment applied successfully"
end

-- Bucle de actualización periódica
function AdvancedInjuryModule.UpdateTick()
    local PermadeathModule = require(game.ServerScriptService.ServerModules.PermadeathModule)
    if not PermadeathModule.Active then return end
    
    for player, state in pairs(AdvancedInjuryModule.PlayerInjuries) do
        if not player.Parent then
            AdvancedInjuryModule.ClearPlayer(player)
            continue
        end
        
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        
        if not hum or hum.Health <= 0 then
            -- Si muere, limpiamos heridas
            local isDead = hum and hum.Health <= 0
            if isDead then
                AdvancedInjuryModule.ClearPlayer(player)
                AdvancedInjuryModule.InitPlayer(player)
            end
            continue
        end
        
        local totalBleed = 0
        local totalPain = 0
        local hasLegFracture = false
        local hasSlowingInjury = false
        local hasInfectedWounds = false
        local stateChanged = false
        
        -- Recorrer heridas
        for partName, partWounds in pairs(state) do
            local activeWounds = {}
            for i = #partWounds, 1, -1 do
                local w = partWounds[i]
                
                -- Cicatrización pasiva: si está vendada, suturada o entablillada, cicatriza lentamente
                if w.Bandaged or w.Splinted or w.Sutured or (w.WoundType == "Burn" and w.BurnCreamApplied) then
                    w.HealingProgress = (w.HealingProgress or 0) + 1
                    if w.HealingProgress >= 45 then
                        if w.Bandaged then
                            if not w.FullyHealed then
                                w.FullyHealed = true
                                stateChanged = true
                            end
                        else
                            -- Curado por completo (no vendado, ej: tablilla/sutura), lo removemos
                            table.remove(partWounds, i)
                            stateChanged = true
                            continue
                        end
                    end
                end
                
                -- Sistema de Infección de Heridas
                local woundConf = InjuryConfig.WoundTypes[w.WoundType]
                if woundConf and woundConf.CanBeInfected then
                    if not w.Disinfected and not w.Infected then
                        w.InfectionProgress = (w.InfectionProgress or 0) + 1
                        if w.InfectionProgress >= 60 then -- 1 minuto (60 segundos) sin desinfectar
                            w.Infected = true
                            stateChanged = true
                        end
                    end
                end
                
                if w.Infected then
                    hasInfectedWounds = true
                end
                
                -- Calcular sangrado y dolor
                if not w.Bandaged then
                    totalBleed = totalBleed + w.BleedRate
                    totalPain = totalPain + w.Pain
                else
                    -- Las vendas reducen el dolor a la mitad
                    totalPain = totalPain + (w.Pain * 0.5)
                end
                
                -- Verificar penalización por fracturas no tratadas/entablilladas
                if w.WoundType == "Fracture" and not w.Splinted then
                    if partName == "LeftLeg" or partName == "RightLeg" then
                        hasLegFracture = true
                    end
                end
                
                table.insert(activeWounds, w)
            end
        end
        
        -- Actualizar atributo de infección general del jugador
        local currentInfection = player:GetAttribute("Infection") or 0
        if hasInfectedWounds then
            -- Aumenta un 1% por minuto (1 / 60 por segundo)
            player:SetAttribute("Infection", math.clamp(currentInfection + (1 / 60), 0, 100))
        else
            -- Si no hay heridas infectadas, la infección disminuye lentamente (0.5% por minuto = 0.5 / 60 por segundo)
            player:SetAttribute("Infection", math.clamp(currentInfection - (0.5 / 60), 0, 100))
        end
        
        -- Aplicar daño por sangrado
        if totalBleed > 0 then
            hum:TakeDamage(totalBleed)
        end
        
        -- Guardar y actualizar dolor en un atributo para efectos visuales (p.ej., latido cardíaco rápido)
        player:SetAttribute("InjuryPain", math.clamp(totalPain, 0, 100))
        player:SetAttribute("BleedingRate", totalBleed)
        
        -- Aplicar velocidad en función de fracturas de piernas
        if hasLegFracture then
            hum.WalkSpeed = 7 -- Velocidad cojeando
        else
            -- Si no hay fractura, restaurar velocidad estándar
            -- (solo si no tiene condicion de piernorota activa)
            local CondicionesModule = require(script.Parent.CondicionesModule)
            local hasPiernaRota = CondicionesModule.HasCondicion(player, "piernorota")
            local hasLostLeg = CondicionesModule.HasLostLeg and CondicionesModule.HasLostLeg(player) or false
            if not hasPiernaRota and not hasLostLeg then
                hum.WalkSpeed = 16
            end
        end
        
        if stateChanged then
            AdvancedInjuryModule.Replicate(player)
        end
    end
end

return AdvancedInjuryModule
