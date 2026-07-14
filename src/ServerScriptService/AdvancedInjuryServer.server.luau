-- Server Script for Advanced Injury System
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AdvancedInjuryModule = require(ServerScriptService.ServerModules.AdvancedInjuryModule)
local CondicionesModule    = require(ServerScriptService.ServerModules.CondicionesModule)
local ApplyTreatmentEvent = ReplicatedStorage:WaitForChild("ApplyTreatmentEvent")

-- RemoteEvents para solicitud de tratamientos cruzados
local TreatmentRequestEvent = ReplicatedStorage:FindFirstChild("TreatmentRequestEvent")
if not TreatmentRequestEvent then
    TreatmentRequestEvent = Instance.new("RemoteEvent")
    TreatmentRequestEvent.Name = "TreatmentRequestEvent"
    TreatmentRequestEvent.Parent = ReplicatedStorage
end

local StartTreatingEvent = ReplicatedStorage:FindFirstChild("StartTreatingEvent")
if not StartTreatingEvent then
    StartTreatingEvent = Instance.new("RemoteEvent")
    StartTreatingEvent.Name = "StartTreatingEvent"
    StartTreatingEvent.Parent = ReplicatedStorage
end

local function setupPlayer(player)
    AdvancedInjuryModule.InitPlayer(player)
    CondicionesModule.InitPlayer(player)
    
    player.CharacterAdded:Connect(function(char)
        -- Si reaparece limpio, reiniciamos heridas menores
        AdvancedInjuryModule.InitPlayer(player)
        
        -- Re-aplicar las condiciones médicas activas del jugador al nuevo personaje de forma silenciosa
        task.spawn(function()
            task.wait(0.5) -- Esperar a que cargue completamente el personaje
            local condData = CondicionesModule.PlayerCondiciones[player]
            if condData then
                -- Guardar los estados activos
                local temp = {
                    piernorota = condData.piernaRota,
                    brazoroto = condData.brazoRoto,
                    extremidad = condData.perdidaExtremidad,
                    ciego = condData.ciego,
                    perdidaojo = condData.perdidaOjo,
                    concusion = condData.concusion,
                    esquizofrenia = condData.esquizofrenia,
                }
                local lostLimbPart = condData.lostLimbPart
                
                -- Reiniciar el contenedor de estado pero manteniendo lostLimbPart
                CondicionesModule.InitPlayer(player)
                if lostLimbPart then
                    CondicionesModule.PlayerCondiciones[player].lostLimbPart = lostLimbPart
                end
                
                -- Volver a aplicar de forma silenciosa (silent = true)
                for condName, active in pairs(temp) do
                    if active then
                        CondicionesModule.Apply(player, condName, true)
                    end
                end
            end
        end)
    end)
end

-- Inicializar jugadores al unirse
Players.PlayerAdded:Connect(setupPlayer)

-- Inicializar jugadores ya existentes (ej. al probar en Studio)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
    AdvancedInjuryModule.ClearPlayer(player)
    
    -- Limpiar registros de médicos activos si sale el jugador
    AdvancedInjuryModule.ActiveMedics[player] = nil
    for patient, medic in pairs(AdvancedInjuryModule.ActiveMedics) do
        if medic == player then
            AdvancedInjuryModule.ActiveMedics[patient] = nil
        end
    end
end)

-- Conectar evento para aplicar tratamiento (con soporte opcional para médicos)
ApplyTreatmentEvent.OnServerEvent:Connect(function(player, bodyPart, woundIndex, toolName, targetPlayer)
    local patient = targetPlayer or player
    local medic = targetPlayer and player or nil
    local success, message = AdvancedInjuryModule.ApplyTreatment(patient, bodyPart, woundIndex, toolName, medic)
end)

-- Conectar evento de solicitud de auto-replicación del cliente
local InjuryUpdateEvent = ReplicatedStorage:WaitForChild("InjuryUpdateEvent")
InjuryUpdateEvent.OnServerEvent:Connect(function(player)
    AdvancedInjuryModule.Replicate(player)
end)

local lastRequestTimeByPlayer = {}

-- Escuchar solicitudes e interacciones de examen de heridas entre jugadores
TreatmentRequestEvent.OnServerEvent:Connect(function(player, action, targetOrRequester, accepted)
    if action == "Request" then
        local now = time()
        local lastTime = lastRequestTimeByPlayer[player] or 0
        if now - lastTime < 10 then return end -- Cooldown en el servidor (protección antiespam)
        
        local target = targetOrRequester
        if not target or not target:IsA("Player") then return end
        lastRequestTimeByPlayer[player] = now
        
        local char = player.Character
        local targetChar = target.Character
        
        if char and targetChar then
            local pRoot = char:FindFirstChild("HumanoidRootPart")
            local tRoot = targetChar:FindFirstChild("HumanoidRootPart")
            
            if pRoot and tRoot then
                local dist = (pRoot.Position - tRoot.Position).Magnitude
                if dist <= 12 then -- Distancia máxima prudente para examinar
                    TreatmentRequestEvent:FireClient(target, "Prompt", player)
                end
            end
        end
        
    elseif action == "Answer" then
        local requester = targetOrRequester
        if not requester or not requester:IsA("Player") then return end
        
        if accepted then
            -- Registrar al médico para este paciente
            AdvancedInjuryModule.ActiveMedics[player] = requester
            
            -- Enviar el estado de heridas inicial del paciente al médico
            local state = AdvancedInjuryModule.PlayerInjuries[player] or {}
            StartTreatingEvent:FireClient(requester, player, state)
            
            -- Notificación en chat de narrativa local
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(player, "Sistema", "Has permitido que " .. requester.Name .. " trate tus heridas.")
                notify:FireClient(requester, "Sistema", player.Name .. " ha aceptado tu petición. Examinando...")
            end
        else
            local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
            if notify then
                notify:FireClient(requester, "Sistema", player.Name .. " ha rechazado tu petición de tratamiento.")
            end
        end
        
    elseif action == "StopTreating" then
        -- Limpiar el registro cuando el médico cierra la interfaz
        for patient, medic in pairs(AdvancedInjuryModule.ActiveMedics) do
            if medic == player then
                AdvancedInjuryModule.ActiveMedics[patient] = nil
                -- Replicar al médico su propio estado de heridas para restaurar su GUI
                AdvancedInjuryModule.Replicate(player)
            end
        end
    end
end)

-- Bucle de actualización cada 1 segundo
task.spawn(function()
    while true do
        task.wait(1)
        AdvancedInjuryModule.UpdateTick()
        CondicionesModule.UpdateTick()
    end
end)

print("AdvancedInjuryServer Initialized Successfully!")
