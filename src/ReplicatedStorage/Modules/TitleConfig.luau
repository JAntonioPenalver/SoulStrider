local TitleConfig = {
	Titles = {
		{
			Id = "GoblinSlayer",
			DisplayName = "Goblin Slayer",
			Description = "Mata a 50 Goblins o monstruos",
			Color = Color3.fromRGB(100, 255, 100), -- Green tier
			CheckUnlock = function(playerData)
				return (playerData.pveKills or 0) >= 20
			end,
			RequirementsText = "PVE Kills: %d / 50",
			GetProgress = function(playerData)
				return playerData.pveKills or 0, 20
			end
		},
		{
			Id = "Cazador",
			DisplayName = "Cazador de Bestias",
			Description = "Consigue 100 bajas PVE",
			Color = Color3.fromRGB(150, 150, 255), -- Blue tier
			CheckUnlock = function(playerData)
				return (playerData.pveKills or 0) >= 100
			end,
			RequirementsText = "PVE Kills: %d / 100",
			GetProgress = function(playerData)
				return playerData.pveKills or 0, 100
			end
		},
		{
			Id = "Pacifista",
			DisplayName = "Sanador Divino",
			Description = "Cura heridas de tus compañeros 5 veces",
			Color = Color3.fromRGB(255, 215, 0), -- Gold tier
			CheckUnlock = function(playerData)
				return (playerData.heals or 0) >= 5
			end,
			RequirementsText = "Curas: %d / 5",
			GetProgress = function(playerData)
				return playerData.heals or 0, 5
			end
		},
		{
			Id = "Gladiador",
			DisplayName = "Gladiador Eterno",
			Description = "Derrota a 25 jugadores en combate singular",
			Color = Color3.fromRGB(255, 100, 100), -- Red tier
			CheckUnlock = function(playerData)
				return (playerData.pvpKills or 0) >= 25
			end,
			RequirementsText = "PVP Kills: %d / 25",
			GetProgress = function(playerData)
				return playerData.pvpKills or 0, 25
			end
		}
	}
}
return TitleConfig