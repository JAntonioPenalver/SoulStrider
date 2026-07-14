local SurvivalModule = {}
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local hungerStore = DataStoreService:GetDataStore("PlayerHunger_V1")
local thirstStore = DataStoreService:GetDataStore("PlayerThirst_V1")

function SurvivalModule.Save(player)
    if player:GetAttribute("Wiped") == true then
        print("[SURVIVAL SYSTEM] Ignorando autoguardado para " .. player.Name .. " por estar en estado Wiped.")
        return
    end
    local h = player:FindFirstChild("Hunger")
    local t = player:FindFirstChild("Thirst")
    if h then pcall(function() hungerStore:SetAsync("Hunger_"..player.UserId, {UserId = player.UserId, Username = player.Name, Value = h.Value}) end) end
    if t then pcall(function() thirstStore:SetAsync("Thirst_"..player.UserId, {UserId = player.UserId, Username = player.Name, Value = t.Value}) end) end
end

function SurvivalModule.Setup(player)
    local hunger = player:FindFirstChild("Hunger") or Instance.new("NumberValue", player)
    hunger.Name = "Hunger"
    hunger.Value = 100
    
    local thirst = player:FindFirstChild("Thirst") or Instance.new("NumberValue", player)
    thirst.Name = "Thirst"
    thirst.Value = 100
    
    -- Initialize Mana attributes
    local maxMana = 100 + (player:FindFirstChild("Mana") and player.Mana.Value or 0) * 10
    player:SetAttribute("MaxMana", maxMana)
    if not player:GetAttribute("Mana") then
        player:SetAttribute("Mana", maxMana)
    end
    
    pcall(function()
        local hData = hungerStore:GetAsync("Hunger_"..player.UserId)
        if hData then hunger.Value = type(hData) == "table" and hData.Value or hData end
        local tData = thirstStore:GetAsync("Thirst_"..player.UserId)
        if tData then thirst.Value = type(tData) == "table" and tData.Value or tData end
    end)
    
    -- Passive loops for decay and mana regeneration
    task.spawn(function()
        while player.Parent do
            task.wait(2)
            local PermadeathModule = require(game.ServerScriptService.ServerModules.PermadeathModule)
            if PermadeathModule.Active then
                local rate = (100/3600) * 2
                if hunger.Value > 0 then
                    hunger.Value = math.max(0, hunger.Value - rate)
                elseif player.Character and player.Character:FindFirstChild("Humanoid") then
                    player.Character.Humanoid:TakeDamage(2)
                end
                if thirst.Value > 0 then
                    thirst.Value = math.max(0, thirst.Value - rate)
                elseif player.Character and player.Character:FindFirstChild("Humanoid") then
                    player.Character.Humanoid:TakeDamage(2)
                end
            end
        end
    end)
    
    task.spawn(function()
        while player.Parent do
            task.wait(1)
            -- Passive Mana Regeneration: 2% of MaxMana per second
            local currentMaxMana = player:GetAttribute("MaxMana") or 100
            local currentMana = player:GetAttribute("Mana") or currentMaxMana
            local regenAmount = (2 / 100) * currentMaxMana -- 2% of MaxMana
            if currentMana < currentMaxMana then
                player:SetAttribute("Mana", math.min(currentMaxMana, currentMana + regenAmount))
            end
        end
    end)
end

-- ─────────────────────────────────────────────────────────
-- Helper interno: reduce cantidad o destruye el tool
-- ─────────────────────────────────────────────────────────
local function consumeOne(tool)
    local qty = tool:GetAttribute("Cantidad") or 1
    if qty > 1 then
        tool:SetAttribute("Cantidad", qty - 1)
    else
        tool:Destroy()
    end
end

-- ─────────────────────────────────────────────────────────
-- Tabla de valores de comida y bebida
-- Añadir aquí nuevos alimentos o bebidas
-- ─────────────────────────────────────────────────────────
local FOOD_VALUES = {
    ["Pan"]             = 30,
    ["Zanahoria"]       = 12,
    ["Lechuga"]         = 8,
    ["Naranja"]         = 15,
    ["Manzana"]         = 15,
    ["Venda"]           = 5,
    ["SteakOnBone"]     = 35,
    ["Steak"]           = 35,
    ["Arroz con carne"] = 28,
    ["Carne"]           = 25,
}

local DRINK_VALUES = {
    ["Agua"]      = 25,
    ["Agua Pura"] = 30,
    ["Cafe"]      = 15,
    ["Vino"]      = 20,
}

local lastUse = {} -- [playerId] = tick()

function SurvivalModule.EatFood(player, toolOrName)
    if tick() - (lastUse[player.UserId] or 0) < 0.5 then return end
    lastUse[player.UserId] = tick()
    
    local tool = nil
    local itemName = ""

    if typeof(toolOrName) == "Instance" then
        pcall(function() itemName = toolOrName.Name end)
        tool = toolOrName
        
        -- Si el tool ya no es válido (destruido por consolidación), buscamos uno igual
        if not tool.Parent or not itemName or itemName == "" then
            tool = player.Backpack:FindFirstChild(itemName) or (player.Character and player.Character:FindFirstChild(itemName))
        end
    elseif type(toolOrName) == "string" then
        itemName = toolOrName
        -- Buscar el tool en el inventario/character para poder descontar cantidad
        tool = player.Backpack:FindFirstChild(itemName) or (player.Character and player.Character:FindFirstChild(itemName))
    end

    if not itemName or itemName == "" then return end
    
    local consumed = false

    if FOOD_VALUES[itemName] and player:FindFirstChild("Hunger") then
        player.Hunger.Value = math.min(100, player.Hunger.Value + FOOD_VALUES[itemName])
        consumed = true
    end
    if DRINK_VALUES[itemName] and player:FindFirstChild("Thirst") then
        player.Thirst.Value = math.min(100, player.Thirst.Value + DRINK_VALUES[itemName])
        consumed = true
    end

    if consumed and tool then
        consumeOne(tool)
    end
end

-- ─────────────────────────────────────────────────────────
-- Tabla de efectos al usar items (no comida)
-- Añade aquí nuevos items usables
-- ─────────────────────────────────────────────────────────
local USE_EFFECTS = {
    ["Venda"] = function(player, tool)
        local char = player.Character
        local hum  = char and char:FindFirstChild("Humanoid")
        if hum then
            hum.Health = math.min(hum.MaxHealth, hum.Health + 25)
            consumeOne(tool)
        end
    end,
    ["Botiquín"] = function(player, tool)
        local char = player.Character
        local hum  = char and char:FindFirstChild("Humanoid")
        if hum then
            hum.Health = hum.MaxHealth
            consumeOne(tool)
        end
    end,
    -- Añade más efectos aquí:
    -- ["NombreItem"] = function(player, tool) ... end,
}

function SurvivalModule.UseItem(player, toolOrName)
    if tick() - (lastUse[player.UserId] or 0) < 0.5 then return end
    lastUse[player.UserId] = tick()
    
    local tool = nil
    local itemName = ""

    if typeof(toolOrName) == "Instance" then
        pcall(function() itemName = toolOrName.Name end)
        tool = toolOrName
        
        if not tool.Parent or not itemName or itemName == "" then
            tool = player.Backpack:FindFirstChild(itemName) or (player.Character and player.Character:FindFirstChild(itemName))
        end
    elseif type(toolOrName) == "string" then
        itemName = toolOrName
        tool = player.Backpack:FindFirstChild(itemName) or (player.Character and player.Character:FindFirstChild(itemName))
    end

    if not itemName or itemName == "" then return end
    
    local effect = USE_EFFECTS[itemName]
    if effect and tool then
        effect(player, tool)
    end
end

return SurvivalModule

