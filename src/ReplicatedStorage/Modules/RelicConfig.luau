local RelicConfig = {}

-- Configuración general de Reliquias
RelicConfig.AllowStackingSameRelic = false -- Evita acumular buffs de reliquias idénticas
RelicConfig.MaxEquippedRelics = 3          -- Ranuras totales de reliquias

-- Tabla de reliquias configurables
RelicConfig.Relics = {
    ["Collar Del Guerrero"] = {
        BuffType = "MaxHealth",
        BuffValue = 35, -- +50 Vida Máxima
        DropChance = 0.05, -- 15% de probabilidad
        Description = "Un robusto collar de guerrero que incrementa tu vida máxima en 50 puntos.",
        Slot = "RelicSlot1"
    },
    ["Pelaje Caotico"] = {
        BuffType = "Damage",
        BuffValue = 5, -- +6 de Daño físico plano
		DropChance = 0.05, -- 10% de probabilidad
        Description = "Pelaje oscuro que imbuye al portador de una fuerza caótica, sumando +6 de daño.",
        Slot = "RelicSlot2"
    },
    ["Gafas del Destino"] = {
        BuffType = "Speed",
        BuffValue = 2, -- +4 de Velocidad
		DropChance = 0.05, -- 12% de probabilidad
        Description = "Gafas místicas que permiten prever obstáculos, otorgando +4 de velocidad.",
        Slot = "RelicSlot3"
    },
    ["Tiras del Aventurero"] = {
        BuffType = "Stamina",
        BuffValue = 35, -- +35 de Estamina Máxima
		DropChance = 0.05, -- 15% de probabilidad
        Description = "Cintas de cuero de aventurero que aumentan tu resistencia otorgando +35 de estamina.",
        Slot = "RelicSlot4"
    }
}

return RelicConfig
