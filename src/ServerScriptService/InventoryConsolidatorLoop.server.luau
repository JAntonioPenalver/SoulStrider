--[[
    InventoryManager (Server)
    ════════════════════════════════════════════════════════════
    Consolida ítems apilables en el Backpack y en el Character.

    ARQUITECTURA:
      • Un único consolidador SERVER-SIDE (el cliente no puede
        destruir Tools replicados por el servidor).
      • Usa un sistema de "dirty flag" con task.delay para
        procesar TODAS las adiciones de un mismo frame en un
        solo pase, eliminando race conditions.

    REGLAS DE APILADO:
      • Solo ítems definidos en InventoryConfig.Stackables.
      • Mantiene siempre UN solo Tool por tipo; la cantidad
        se guarda en el atributo "Cantidad".
      • Respeta el límite maxStack definido en InventoryConfig.

    CÓMO AÑADIR NUEVOS ITEMS:
      → Edita únicamente ReplicatedStorage.Modules.InventoryConfig
    ════════════════════════════════════════════════════════════
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryConfig   = require(ReplicatedStorage.Modules.InventoryConfig)

-- Tiempo de espera antes de hacer el pase de consolidación.
-- Permite agrupar múltiples ChildAdded del mismo frame.
local BATCH_DELAY = 0.05

-- ─────────────────────────────────────────────────────────────
-- Pase completo de consolidación sobre un contenedor.
-- Itera todos los Tools apilables y fusiona duplicados.
-- ─────────────────────────────────────────────────────────────
local function consolidateContainer(container)
    if not container or not container.Parent then return end

    local stacks = {} -- [itemName] = Tool (el que conservamos)

    for _, item in ipairs(container:GetChildren()) do
        if not item:IsA("Tool") then continue end
        if not InventoryConfig.IsStackable(item.Name) then continue end

        -- Garantiza que todo item apilable tenga Cantidad
        if item:GetAttribute("Cantidad") == nil then
            item:SetAttribute("Cantidad", 1)
        end
        
        -- Desactivar el drop por defecto de Roblox (tecla Delete/Backspace)
        item.CanBeDropped = false

        local name = item.Name

        if stacks[name] then
            -- Ya existe un representante: suma y elimina el duplicado
            local maxStack = InventoryConfig.GetMaxStack(name)
            local kept     = stacks[name]
            local existQty = kept:GetAttribute("Cantidad") or 1
            local addQty   = item:GetAttribute("Cantidad") or 1
            local merged   = math.min(existQty + addQty, maxStack)

            kept:SetAttribute("Cantidad", merged)
            item:Destroy()

            print(string.format(
                "[InventoryManager] '%s' consolidado (%d+%d→%d) en '%s'",
                name, existQty, addQty, merged, container.Name
            ))
        else
            stacks[name] = item
        end
    end
end

-- ─────────────────────────────────────────────────────────────
-- Observa un contenedor y programa consolidaciones en batch.
-- ─────────────────────────────────────────────────────────────
local function watchContainer(container)
    -- Pase inicial para limpiar cualquier duplicado existente
    consolidateContainer(container)

    local pending = false

    local function scheduleConsolidation()
        if pending then return end -- ya hay un pase programado
        pending = true
        task.delay(BATCH_DELAY, function()
            pending = false
            consolidateContainer(container)
        end)
    end

    container.ChildAdded:Connect(function(item)
        if item:IsA("Tool") and InventoryConfig.IsStackable(item.Name) then
            scheduleConsolidation()
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- Gestión de jugadores
-- ─────────────────────────────────────────────────────────────
local function onPlayerAdded(player)
    -- Backpack
    local backpack = player:WaitForChild("Backpack", 10)
    if backpack then
        watchContainer(backpack)
    end

    -- Character (actual y futuros respawns)
    local function onCharacterAdded(character)
        watchContainer(character)
    end

    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end
