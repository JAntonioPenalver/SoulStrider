local InjuryConfig = {}

-- Definición de las partes del cuerpo (R15 y R6 compatibles)
InjuryConfig.BodyParts = {
    Head = {DisplayName = "Cabeza", Order = 1},
    Torso = {DisplayName = "Torso", Order = 2},
    LeftArm = {DisplayName = "Brazo Izquierdo", Order = 3},
    RightArm = {DisplayName = "Brazo Derecho", Order = 4},
    LeftLeg = {DisplayName = "Pierna Izquierda", Order = 5},
    RightLeg = {DisplayName = "Pierna Derecha", Order = 6},
}

-- Tipos de heridas y su severidad inicial / efectos
InjuryConfig.WoundTypes = {
    Scratch = {
        DisplayName = "Rasguño",
        BaseBleedRate = 0.05, -- Daño por tick
        BasePain = 10,
        CanBeInfected = true,
    },
    Cut = {
        DisplayName = "Corte",
        BaseBleedRate = 0.15,
        BasePain = 25,
        CanBeInfected = true,
    },
    DeepWound = {
        DisplayName = "Herida Profunda",
        BaseBleedRate = 0.35,
        BasePain = 50,
        RequiresSuture = true,
        CanBeInfected = true,
    },
    Fracture = {
        DisplayName = "Fractura",
        BaseBleedRate = 0,
        BasePain = 60,
        SlowsMovement = true,
    },
    Burn = {
        DisplayName = "Quemadura",
        BaseBleedRate = 0.02,
        BasePain = 40,
        RequiresBurnCream = true,
    },
    Glass = {
        DisplayName = "Vidrio Incrustado",
        BaseBleedRate = 0.25,
        BasePain = 45,
        RequiresTweezers = true,
    }
}

-- Herramientas Médicas Modulares
-- Cada herramienta declara qué tipo de herida trata y el callback de su efecto.
InjuryConfig.MedicalTools = {
    ["Venda"] = {
        DisplayName = "Venda",
        Treats = {"Scratch", "Cut", "DeepWound", "Burn"},
        RequiresCondition = function(woundState)
            return not woundState.Bandaged
        end,
        OnApply = function(woundState)
            woundState.Bandaged = true
            woundState.BleedRate = 0 -- Detiene el sangrado temporalmente
        end
    },
    ["Retirar Vendaje"] = {
        DisplayName = "Retirar Vendaje",
        Treats = {"Scratch", "Cut", "DeepWound", "Burn"},
        BypassInventory = true,
        RequiresCondition = function(woundState)
            return woundState.Bandaged == true
        end,
        OnApply = function(woundState, partWounds, woundIndex, player)
            woundState.Bandaged = false
            if woundState.FullyHealed then
                table.remove(partWounds, woundIndex)
                return
            end
            
            local woundConf = InjuryConfig.WoundTypes[woundState.WoundType]
            if woundConf then
                local baseBleed = woundConf.BaseBleedRate or 0
                if woundState.Sutured then
                    woundState.BleedRate = baseBleed * 0.25
                else
                    woundState.BleedRate = baseBleed
                end
            end
        end
    },
    ["Sutura"] = {
        DisplayName = "Sutura",
        Treats = {"DeepWound"},
        RequiresCondition = function(woundState)
            return not woundState.Sutured
        end,
        OnApply = function(woundState)
            woundState.Sutured = true
            woundState.BleedRate = woundState.BleedRate * 0.25 -- Reduce drásticamente el sangrado
        end
    },
    ["Desinfectante"] = {
        DisplayName = "Desinfectante",
        Treats = {"Scratch", "Cut", "DeepWound"},
        OnApply = function(woundState)
            woundState.Infected = false
            woundState.Disinfected = true
        end
    },
    ["Crema para Quemaduras"] = {
        DisplayName = "Crema para Quemaduras",
        Treats = {"Burn"},
        OnApply = function(woundState)
            woundState.BurnCreamApplied = true
            woundState.BleedRate = 0
        end
    },
    ["Pinzas"] = {
        DisplayName = "Pinzas",
        Treats = {"Glass"},
        RequiresCondition = function(woundState)
            return woundState.HasGlass
        end,
        OnApply = function(woundState)
            woundState.HasGlass = false
            -- Al sacar el vidrio queda una herida profunda
            woundState.WoundType = "DeepWound"
            woundState.BleedRate = 0.35
        end
    },
    ["Tablilla"] = {
        DisplayName = "Tablilla",
        Treats = {"Fracture"},
        OnApply = function(woundState)
            woundState.Splinted = true
        end
    }
}

return InjuryConfig
