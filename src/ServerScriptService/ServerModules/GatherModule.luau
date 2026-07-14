local GatherModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HarvestModule = require(script.Parent.HarvestModule)

GatherModule.Resources = {
    ArbolTalable = { requiredTool = {"Hacha", "Axe"}, hitsRequired = 5, lootTemplate = "Tronco", respawnTime = 999, hitSound = "rbxassetid://1911987235" },
    Piedra = { requiredTool = {"Pico", "Pickaxe"}, hitsRequired = 5, lootTemplate = "Piedra", respawnTime = 999, hitSound = "rbxassetid://117793859307433" },
	Hierro = { requiredTool = {"Pico", "Pickaxe"}, hitsRequired = 10, lootTemplate = "Pepita de Hierro", respawnTime = 999, hitSound = "rbxassetid://117793859307433" },
	Cobre = { requiredTool = {"Pico", "Pickaxe"}, hitsRequired = 8, lootTemplate = "Pepita de Cobre", respawnTime = 999, hitSound = "rbxassetid://117793859307433" },
	Oro = { requiredTool = {"Pico", "Pickaxe"}, hitsRequired = 15, lootTemplate = "Pepita de Oro", respawnTime = 999, hitSound = "rbxassetid://117793859307433" },
}

local resourceHealth = {}
local hitCooldown = {}
local COOLDOWN = 0.4

-- Limpieza de memoria cuando el jugador sale
Players.PlayerRemoving:Connect(function(player)
    hitCooldown[player] = nil
end)

local function findResourceRoot(part)
    local current = part
    while current and current ~= workspace do
        if GatherModule.Resources[current.Name] then return current, current.Name end
        current = current.Parent
    end
    return nil, nil
end

local function getResourcePos(obj)
    if obj:IsA("Model") then
        return obj:GetPivot().Position
    elseif obj:IsA("BasePart") then
        return obj.Position
    end
    return Vector3.zero
end

local function getResourceHealth(obj)
    if not resourceHealth[obj] then
        local config = GatherModule.Resources[obj.Name]
        if not config then return nil end
        resourceHealth[obj] = config.hitsRequired
    end
    return resourceHealth[obj]
end

local function spawnLoot(player, obj, templateName)
    local given = HarvestModule.GiveItem(player, templateName)
    if not given then
        local template = ReplicatedStorage:FindFirstChild(templateName) or game:GetService("StarterPack"):FindFirstChild(templateName)
        if not template then return end
        local loot = template:Clone()
        local spawnPos = getResourcePos(obj) + Vector3.new(math.random(-2, 2), 1, math.random(-2, 2))
        if loot:IsA("Model") then loot:PivotTo(CFrame.new(spawnPos)) else loot.Position = spawnPos end
        loot.Parent = workspace
    end
end

local function scheduleRespawn(objClone, savedParent, savedCFrame, config)
    if config.respawnTime <= 0 then return end
    task.delay(config.respawnTime, function()
        if savedParent and savedParent.Parent then
            objClone.Parent = savedParent
            if objClone:IsA("Model") then objClone:PivotTo(savedCFrame) else objClone.CFrame = savedCFrame end
        end
    end)
end

function GatherModule.OnHit(player, targetPart)
    local now = tick()
    if hitCooldown[player] and (now - hitCooldown[player]) < COOLDOWN then 
        return false, "cooldown" 
    end
    hitCooldown[player] = now

    if not targetPart or not targetPart.Parent then 
        return false, "invalid_target" 
    end
    
    local resourceObj, resourceName = findResourceRoot(targetPart)
    if not resourceObj then 
        warn("[GatherModule] El objeto golpeado por " .. player.Name .. " no es un recurso válido: " .. targetPart.Name)
        return false, "not_resource" 
    end

    local config = GatherModule.Resources[resourceName]
    local char = player.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    
    if not tool or not table.find(config.requiredTool, tool.Name) then 
        return false, "wrong_tool" 
    end

    -- Descontar durabilidad del herramienta al golpear un recurso
    local maxD = tool:GetAttribute("MaxDurability") or 100
    local currentD = tool:GetAttribute("Durability") or maxD
    
    if not tool:GetAttribute("MaxDurability") then
        tool:SetAttribute("MaxDurability", 100)
        tool:SetAttribute("Durability", 100)
        maxD = 100
        currentD = 100
    end
    
    if currentD > 0 then
        local newD = math.max(0, currentD - 1)
        tool:SetAttribute("Durability", newD)
        
        if newD == 0 then
            -- ¡La herramienta se ha roto!
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local s = Instance.new("Sound")
                s.SoundId = "rbxassetid://9116728377"
                s.Volume = 2
                s.Parent = hrp
                s:Play()
                game.Debris:AddItem(s, 2)
            end
            
            local NarrateEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
            if NarrateEvent then
                NarrateEvent:FireClient(player, string.format("*¡Mi **[%s]** se ha roto por completo!*", tool.Name), true, 4, 1.5)
            end
            
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:UnequipTools()
            end
            tool:Destroy()
        end
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local resourcePos = getResourcePos(resourceObj)
    
    -- DISTANCIA SEGURA PARA MULTIJUGADOR (Aumentada para compensar lag)
    if not hrp or (hrp.Position - resourcePos).Magnitude > 100 then 
        warn("[GatherModule] Jugador " .. player.Name .. " demasiado lejos del recurso. Distancia: " .. (hrp and (hrp.Position - resourcePos).Magnitude or "N/A"))
        return false, "too_far" 
    end

    local health = getResourceHealth(resourceObj)
    if health <= 0 then return false, "already_destroyed" end -- Evita dobles golpes finales

    health = health - 1
    resourceHealth[resourceObj] = health

    if health <= 0 then
        resourceHealth[resourceObj] = nil
        local savedParent = resourceObj.Parent
        local savedCFrame = resourceObj:IsA("Model") and resourceObj:GetPivot() or resourceObj.CFrame
        local clone = resourceObj:Clone()
        
        scheduleRespawn(clone, savedParent, savedCFrame, config)
        
        -- CUSTOM MULTI-LOOT DROP LOGIC FOR TREES
        if resourceName == "ArbolTalable" then
            -- 1. Madera (Tronco): 1 a 2 unidades
            local woodCount = math.random(1, 2)
            for i = 1, woodCount do
                spawnLoot(player, resourceObj, "Tronco")
            end
            
            -- 2. Palos (Palo): 2 a 4 unidades
            local stickCount = math.random(2, 4)
            for i = 1, stickCount do
                spawnLoot(player, resourceObj, "Palo")
            end
            
            -- 3. Hojas (Hoja): 3 a 5 unidades
            local leafCount = math.random(3, 5)
            for i = 1, leafCount do
                spawnLoot(player, resourceObj, "Hoja")
            end
            
            -- 4. Manzana (Bajo chance: 20% para 1 manzana)
            if math.random() <= 0.20 then
                spawnLoot(player, resourceObj, "Manzana")
            end
        else
            -- Normal drop for Stone, Iron, etc.
            spawnLoot(player, resourceObj, config.lootTemplate)
        end
        
        resourceObj:Destroy()
        return true, "destroyed", 0, resourceName
    end

    return true, "hit", health, resourceName
end

function GatherModule.GetRequiredTool(targetName)
    local config = GatherModule.Resources[targetName]
    return config and config.requiredTool or nil
end

function GatherModule.PlayHitEffect(targetPart)
    if not targetPart then return end
    local resourceObj, resourceName = findResourceRoot(targetPart)
    if not resourceObj then return end

    local config = GatherModule.Resources[resourceName]
    if not config or not config.hitSound then return end

    local sound = Instance.new("Sound")
    sound.SoundId = config.hitSound
    sound.RollOffMaxDistance = 50
    sound.Volume = 0.8
    sound.Parent = targetPart
    sound:Play()

    local talaPart = workspace:FindFirstChild("Tala")
    local mainAttachment = talaPart and talaPart:FindFirstChild("Main")
    local attach = nil
    
    game:GetService("Debris"):AddItem(sound, 2)
    if attach then
        game:GetService("Debris"):AddItem(attach, 2)
    end
end

return GatherModule
