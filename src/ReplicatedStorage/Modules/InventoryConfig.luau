local InventoryConfig = {}

InventoryConfig.Blacklist = {
    "DefaultTool",
    "Unarmed",
	"Puños",
	"StrongRight",
	"GoblinSpawner",
	"Strong Punch",
	"LT_Fabrics",
	"LT_Efectos",
	"LT_Dungeons",
}

InventoryConfig.Stackables = {
    -- ── Consumibles médicos ───────────────────────────────────
    ["Venda"]             = { maxStack = 20, category = "Medical" },
    ["Botiquín"]          = { maxStack = 20, category = "Medical" },

    -- ── Comida ───────────────────────────────────────────────
    ["Pan"]               = { maxStack = 10, category = "Food" },
	["Zanahoria"]         = { maxStack = 10, category = "Food" },
	["Manzana"]           = { maxStack = 10, category = "Food" },
	["Naranja"]           = { maxStack = 10, category = "Food" },
    ["SteakOnBone"]       = { maxStack = 10, category = "Food" },
    ["Arroz con carne"]   = { maxStack = 10, category = "Food" },

    -- ── Bebidas ──────────────────────────────────────────────
    ["Agua"]         = { maxStack = 10, category = "Drink" },

    -- ── Materiales / Recursos ─────────────────────────────────
    ["Tronco"]            = { maxStack = 99, category = "Material" },
    ["Palo"]              = { maxStack = 99, category = "Material" },
    ["Hoja"]              = { maxStack = 99, category = "Material" },
    ["Piedra"]            = { maxStack = 99, category = "Material" },
    ["Pepita de Hierro"]  = { maxStack = 99, category = "Material" },
    ["Pepita de Cobre"]   = { maxStack = 99, category = "Material" },
    ["Pepita de Oro"]     = { maxStack = 99, category = "Material" },
}

InventoryConfig.Consumibles = InventoryConfig.Stackables

InventoryConfig.ItemMeta = {
    -- ── Médicos ──────────────────────────────────────────────
    ["Venda"] = {
        description = "Cura 25 HP al usarla.",
    },
    ["Botiquín"] = {
        description = "Cura completamente la salud.",
    },
    -- ── Comida ───────────────────────────────────────────────
    ["Pan"] = {
        description = "Recupera 30 puntos de hambre.",
    },
    ["Zanahoria"] = {
        description = "Recupera 12 puntos de hambre.",
    },
    ["Manzana"] = {
        description = "Recupera 15 puntos de hambre.",
    },
    ["Naranja"] = {
        description = "Recupera 15 puntos de hambre.",
    },
    ["SteakOnBone"] = {
        description = "Recupera 35 puntos de hambre.",
    },
    ["Arroz con carne"] = {
        description = "Recupera 28 puntos de hambre.",
    },
    -- ── Bebidas ──────────────────────────────────────────────
    ["Agua Pura"] = {
        description = "Repone 30 puntos de sed.",
    },
    -- ── Materiales ───────────────────────────────────────────
    ["Tronco"] = {
        description = "Tronco de madera para construcción y crafteo.",
    },
    ["Palo"] = {
        description = "Palo de madera silvestre.",
    },
    ["Hoja"] = {
        description = "Hoja verde de árbol.",
    },
    ["Piedra"] = {
        description = "Piedra para construcción y crafteo.",
    },
    ["Pepita de Hierro"] = {
        description = "Mineral de hierro.",
    },
    ["Pepita de Cobre"] = {
        description = "Mineral de cobre.",
    },
    ["Pepita de Oro"] = {
        description = "Mineral de oro.",
    },
}

function InventoryConfig.IsStackable(itemName)
    if InventoryConfig.IsBlacklisted(itemName) then return false end
    
    -- No apilar reliquias
    local hasRelicConfig, RelicConfig = pcall(function()
        return require(game:GetService("ReplicatedStorage").Modules.RelicConfig)
    end)
    if hasRelicConfig and RelicConfig and RelicConfig.Relics[itemName] then
        return false
    end
    
    if InventoryConfig.Stackables[itemName] ~= nil then return true end
    return false
end

function InventoryConfig.IsBlacklisted(itemName)
    return table.find(InventoryConfig.Blacklist, itemName) ~= nil
end

function InventoryConfig.GetMaxStack(itemName)
    local data = InventoryConfig.Stackables[itemName]
    return data and (data.maxStack or 99) or 99
end

function InventoryConfig.GetCategory(itemName)
    local data = InventoryConfig.Stackables[itemName]
    return data and data.category or nil
end

function InventoryConfig.GetDescription(itemName)
    local meta = InventoryConfig.ItemMeta[itemName]
    return meta and meta.description or nil
end

return InventoryConfig
