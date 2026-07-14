local DungeonConfig = {}

-- ── General Spawner Settings ──────────────────────────────
DungeonConfig.DungeonTemplateName = "Ruinas"       -- Name of the master template in Workspace
DungeonConfig.GoblinTemplateName  = "Real Goblin"  -- Name of the goblin NPC in ReplicatedStorage

-- ── Goblin Combat Settings ────────────────────────────────
DungeonConfig.MinGoblinCount       = 10           -- Minimum goblins spawned
DungeonConfig.MaxGoblinCount       = 12          -- Maximum goblins spawned
DungeonConfig.SpawnPerimeterRadius = 65            -- Distance from center where Goblins spawn

-- ── Victory Feedback Settings ─────────────────────────────
DungeonConfig.VictorySoundId    = "rbxassetid://98646737427339"
DungeonConfig.VictoryVolume     = 3.0              -- Volume of the victory sound
DungeonConfig.VictoryRollOffMax = 300              -- Spatial propagation distance

-- ── Dungeon Cleanup Settings ──────────────────────────────
DungeonConfig.CleanupDelay      = 60              -- Seconds after victory before fadeout starts
DungeonConfig.FadeDuration      = 8              -- Seconds the fade-to-transparent takes

-- ── Dynamic Loot Pool Configuration ───────────────────────
DungeonConfig.LootPool = {
	{Name = "Hacha",            Chance = 0.20, MaxQty = 1,  Stackable = false},
	{Name = "Pico",        Chance = 0.20, MaxQty = 1,  Stackable = false},
	{Name = "Pepita de Hierro", Chance = 0.30, MaxQty = 2, Stackable = true},
	{Name = "Pepita de Cobre", Chance = 0.20, MaxQty = 3, Stackable = true},
	{Name = "Pepita de Oro", Chance = 0.10, MaxQty = 1, Stackable = true},
	{Name = "Piedra",         Chance = 0.80, MaxQty = 2,  Stackable = true},
	{Name = "Tronco",         Chance = 0.80, MaxQty = 3,  Stackable = true},
	{Name = "Palo",           Chance = 0.90, MaxQty = 5, Stackable = true},
	{Name = "Venda",          Chance = 0.70, MaxQty = 3,  Stackable = true},
	{Name = "Libro_Principiante", Chance = 0.15, MaxQty = 1, Stackable = false},
	{Name = "Libro_Intermedio",   Chance = 0.10, MaxQty = 1, Stackable = false},
	{Name = "Libro_Avanzado",     Chance = 0.07, MaxQty = 1, Stackable = false},
	{Name = "Libro_Sagrado",      Chance = 0.04, MaxQty = 1, Stackable = false},
	{Name = "Libro_Divino",       Chance = 0.02, MaxQty = 1, Stackable = false},
}

return DungeonConfig
