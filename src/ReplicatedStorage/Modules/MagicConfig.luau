local MagicConfig = {}

MagicConfig.Levels = {
	Principiante = "Principiante",
	Intermedio = "Intermedio",
	Avanzado = "Avanzado",
	Sagrado = "Sagrado",
	Divino = "Divino"
}

MagicConfig.Spells = {
	["Fuego_BolaDeFuego"] = {
		Name = "Fuego_BolaDeFuego",
		Level = MagicConfig.Levels.Principiante,
		Cooldown = 5,
		ManaCost = 10,
		Damage = 30,
		AnimationId = "rbxassetid://134876169332130",
		SoundId = "rbxassetid://135322692456554",
		Speed = 130,
		Lifetime = 4.0,
		Size = Vector3.new(1.5, 1.5, 1.5),
		Color = Color3.fromRGB(255, 65, 0),
		LightColor = Color3.fromRGB(255, 120, 30),
		HitRadius = 5
	},
	["Hielo_LanzaDeHielo"] = {
		Name = "Hielo_LanzaDeHielo",
		Level = MagicConfig.Levels.Principiante,
		Cooldown = 7,
		ManaCost = 15,
		Damage = 40,
		AnimationId = "rbxassetid://72131114156459",
		ChargeSoundId = "rbxassetid://82271313074659",
		LaunchSoundId = "rbxassetid://111073883373173",
		Speed = 150,
		Lifetime = 3.0,
		Size = Vector3.new(0.397, 0.245, 9.0),
		Color = Color3.fromRGB(160, 220, 255),
		LightColor = Color3.fromRGB(180, 240, 255),
		HitRadius = 5
	},
	["Tierra_Fisura"] = {
		Name = "Tierra_Fisura",
		Level = MagicConfig.Levels.Principiante,
		Cooldown = 6,
		ManaCost = 12,
		Damage = 12,
		AnimationId = "rbxassetid://118195670671365",
		LaunchSoundId = "rbxassetid://134151970066674",
		HitRadius = 5
	}
}

-- Minigames configurados por nivel y elementos (para arrastrar palabras en casillas)
MagicConfig.Minigames = {
	[1] = { -- Principiante
		{
			Type = "Fuego",
			Spell = "Fuego_BolaDeFuego",
			Sentence = "Yo, canalizando el {1} del {2}, invoco una {3} ardiente.",
			Slots = {"calor", "fuego", "esfera"},
			Words = {"calor", "fuego", "esfera", "hielo", "tierra", "viento"}
		},
		{
			Type = "Hielo",
			Spell = "Hielo_LanzaDeHielo",
			Sentence = "Con el {1} del {2}, congelo el aire en una {3} afilada.",
			Slots = {"frio", "invierno", "lanza"},
			Words = {"frio", "invierno", "lanza", "fuego", "roca", "espada"}
		},
		{
			Type = "Tierra",
			Spell = "Tierra_Fisura",
			Sentence = "Golpeando la {1}, quiebro el {2} abriendo una gran {3} en la tierra.",
			Slots = {"roca", "suelo", "fisura"},
			Words = {"roca", "suelo", "fisura", "agua", "fuego", "viento"}
		}
	},
	[2] = { -- Intermedio (Marcador de posición para desarrollo futuro)
		{
			Type = "General",
			Spell = "HechizoIntermedio",
			Sentence = "El poder se {1} en el {2} mientras la magia {3} a mi alrededor.",
			Slots = {"concentra", "cuerpo", "fluye"},
			Words = {"concentra", "cuerpo", "fluye", "destruye", "alma", "agua"}
		}
	},
	[3] = { -- Avanzado
		{
			Type = "General",
			Spell = "HechizoAvanzado",
			Sentence = "Despierto los {1} antiguos, desatando la {2} del cosmos sobre mi {3}.",
			Slots = {"secretos", "furia", "destino"},
			Words = {"secretos", "furia", "destino", "camino", "magia", "sol"}
		}
	},
	[4] = { -- Sagrado
		{
			Type = "General",
			Spell = "HechizoSagrado",
			Sentence = "Que la luz {1} expulse la {2} y traiga la {3} eterna.",
			Slots = {"sagrada", "oscuridad", "paz"},
			Words = {"sagrada", "oscuridad", "paz", "justicia", "guerra", "sombra"}
		}
	},
	[5] = { -- Divino
		{
			Type = "General",
			Spell = "HechizoDivino",
			Sentence = "Trascendiendo la {1} mortal, alcanzo la {2} de la creación {3}.",
			Slots = {"existencia", "esencia", "divina"},
			Words = {"existencia", "esencia", "divina", "fuerza", "vida", "caos"}
		}
	}
}

-- Helper para ajustar el color de magia basado en el honor del jugador
function MagicConfig.GetAdjustedColor(player)
	local baseColor = player:GetAttribute("MagicColor") or Color3.fromRGB(160, 100, 255)
	local honor = player:GetAttribute("Honor") or 50
	
	if honor < 50 then
		-- Honor bajo: Oscurecer e interpolar a negro (mientras menor honor, más oscuro)
		local t = (50 - honor) / 50
		return baseColor:Lerp(Color3.new(0, 0, 0), t * 0.85) -- hasta un 85% más oscuro
	else
		-- Honor alto: Aclarar/brillar e interpolar a blanco/luminoso
		local t = (honor - 50) / 50
		return baseColor:Lerp(Color3.new(1, 1, 1), t * 0.60) -- hasta un 60% más claro
	end
end

-- Helper para sanitizar nombres de hechizos en nombres de atributos legales en Roblox (sin dos puntos)
function MagicConfig.GetSpellAttributeName(spellName)
	-- Mapeo de compatibilidad para datos antiguos
	if spellName == "Fuego: Bola de Fuego" or spellName == "Fuego" then
		spellName = "Fuego_BolaDeFuego"
	elseif spellName == "Hielo: Lanza de Hielo" or spellName == "Hielo" then
		spellName = "Hielo_LanzaDeHielo"
	elseif spellName == "Tierra: Fisura" or spellName == "Tierra" then
		spellName = "Tierra_Fisura"
	end
	
	local clean = spellName:gsub(":", "_"):gsub(" ", "_")
	return "SpellUnlocked_" .. clean
end

-- Corrector dinámico de atributos de MagicSkillsGui en el cliente
if game:GetService("RunService"):IsClient() then
	task.spawn(function()
		local player = game:GetService("Players").LocalPlayer
		local playerGui = player:WaitForChild("PlayerGui", 15)
		if playerGui then
			local magicSkillsGui = playerGui:WaitForChild("MagicSkillsGui", 10)
			if magicSkillsGui then
				local container = magicSkillsGui:WaitForChild("SkillsContainer", 10)
				if container then
					local mappings = {
						["Slot_Z"] = "Fuego_BolaDeFuego",
						["Slot_X"] = "Hielo_LanzaDeHielo",
						["Slot_C"] = "Tierra_Fisura"
					}
					for slotName, correctName in pairs(mappings) do
						local slot = container:FindFirstChild(slotName)
						if slot then
							slot:SetAttribute("SpellName", correctName)
						end
					end
				end
			end
		end
	end)
end

return MagicConfig