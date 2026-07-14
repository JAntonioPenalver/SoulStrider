local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local CondicionesModule = require(ServerScriptService.ServerModules.CondicionesModule)
local LoreModule = require(ServerScriptService.ServerModules.LoreModule)
local InventoryConfig = require(ReplicatedStorage.Modules.InventoryConfig)

-- ─────────────────────────────────────────────────────────────────────────
-- Helper: Aplica pérdida del 50% del inventario al recibir PK
-- (ignora items de la blacklist como Puños, herramientas internas)
-- ─────────────────────────────────────────────────────────────────────────
local function applyPKInventoryLoss(player)
	local backpack = player:FindFirstChild("Backpack")
	local char     = player.Character
	local lostItems = {}

	local function processContainer(container)
		if not container then return end
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") and not InventoryConfig.IsBlacklisted(item.Name) then
				local qty = item:GetAttribute("Cantidad") or 1
				local loss = math.floor(qty / 2)
				if loss > 0 then
					local newQty = qty - loss
					if newQty <= 0 then
						table.insert(lostItems, {name = item.Name, amount = qty})
						item:Destroy()
					else
						item:SetAttribute("Cantidad", newQty)
						table.insert(lostItems, {name = item.Name, amount = loss})
					end
				end
			end
		end
	end

	processContainer(backpack)
	processContainer(char)
	return lostItems
end

local NAMES_ES = {
	esquizofrenia = "Esquizofrenia",
	perdidaojo = "Pérdida de ojo",
	piernorota = "Fractura de pierna",
	brazoroto = "Fractura de brazo",
	concusion = "Concusión cerebral",
	ciego = "Ceguera total",
	extremidad = "Pérdida de extremidad"
}

local function wipeAllStores(userId)
	local loreStore = DataStoreService:GetDataStore("PlayerLore_V1")
	local hungerStore = DataStoreService:GetDataStore("PlayerHunger_V1")
	local thirstStore = DataStoreService:GetDataStore("PlayerThirst_V1")
	local titleStore = DataStoreService:GetDataStore("PlayerEquippedTitles_V1")
	
	pcall(function() loreStore:RemoveAsync("Lore_" .. userId) end)
	pcall(function() hungerStore:RemoveAsync("Hunger_" .. userId) end)
	pcall(function() thirstStore:RemoveAsync("Thirst_" .. userId) end)
	pcall(function() titleStore:RemoveAsync(tostring(userId)) end)
end

local function onPlayerDied(player)
	if player:GetAttribute("Wiped") == true then return end
	
	-- Comprobar si la muerte permanente (PD) está activa
	local PermadeathModule = require(game.ServerScriptService.ServerModules.PermadeathModule)
	if not PermadeathModule.Active then return end
	
	local livesVal = player:FindFirstChild("Lives")
	if not livesVal then return end
	
	local currentLives = livesVal.Value
	local fullName = player:FindFirstChild("LoreFirstName") and (player.LoreFirstName.Value .. " " .. (player:FindFirstChild("LoreLastName") and player.LoreLastName.Value or "")) or player.Name
	local username = player.Name
	local userId = player.UserId
	
	if currentLives > 1 then
		-- ==========================================
		-- PLAYER KILL (PK): Descontar vida y herida
		-- ==========================================
		livesVal.Value = currentLives - 1
		
		-- Buscar qué heridas permanentes no tiene el jugador
		local pool = {"esquizofrenia", "perdidaojo", "piernorota", "brazoroto", "concusion", "extremidad"}
		local available = {}
		for _, c in ipairs(pool) do
			if not CondicionesModule.HasCondicion(player, c) then
				table.insert(available, c)
			end
		end
		
		local appliedLimbName = ""
		if #available > 0 then
			local chosen = available[math.random(1, #available)]
			CondicionesModule.Apply(player, chosen)
			appliedLimbName = NAMES_ES[chosen]
		else
			appliedLimbName = "Ninguna (ya posee todas las secuelas)"
		end
		
		-- Guardar cambios inmediatamente para evitar desconexiones accidentales
		LoreModule.SaveAllData(player)

		-- Aplicar pérdida de inventario (50% de cada item no blacklisteado)
		local lostItems = applyPKInventoryLoss(player)

		-- Construir resumen de pérdidas para la notificación
		local lostSummary = ""
		if #lostItems > 0 then
			local parts = {}
			for _, entry in ipairs(lostItems) do
				table.insert(parts, string.format("%s x%d", entry.name, entry.amount))
			end
			lostSummary = "\nObjetos perdidos: " .. table.concat(parts, ", ")
		else
			lostSummary = "\nNo tenías objetos que perder."
		end
		
		-- Notificar al jugador de su PK mediante Narración de entorno
		task.spawn(function()
			task.wait(1.5) -- esperar un poco para que cargue la interfaz
			local narEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
			if narEvent then
				local text = string.format("He sufrido una herida devastadora en combate (PK). Vidas restantes: %d/3. Secuela: %s. %s", livesVal.Value, appliedLimbName, lostSummary)
				narEvent:FireClient(player, text, true)
			end
		end)
		
	elseif currentLives == 1 then
		-- ==========================================
		-- CHARACTER KILL (CK): Muerte permanente y Wipe
		-- ==========================================
		livesVal.Value = 0
		player:SetAttribute("Wiped", true)
		
		-- Expulsar al jugador de inmediato con un mensaje dramático de fin de historia
		player:Kick(
			"\n========================================\n" ..
			"💀 CHARACTER KILL (CK) 💀\n" ..
			"========================================\n\n" ..
			"Tus vidas se han agotado por completo (0/3).\n\n" ..
			"Tu personaje ha muerto de forma permanente en el lore. Sus estadísticas, talentos, maestrías, inventarios y todo su progreso han sido borrados de los registros del juego.\n\n" ..
			"¡Tu historia ha llegado a su fin! Crea un nuevo personaje para escribir un nuevo destino."
		)
		
		-- Esperar que se procese la desconexión para no re-escribir datos viejos
		task.wait(0.5)
		
		-- Erradicar todas las bases de datos
		wipeAllStores(userId)
		
		-- Anuncio narrativo server-wide
		local narEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
		if narEvent then
			narEvent:FireAllClients(string.format("El personaje %s (@%s) ha sufrido un Character Kill (CK) permanente. Su historia ha terminado.", fullName, username), true)
		end
	end
end

local function trackPlayer(player)
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 15)
		if hum then
			local diedConn
			diedConn = hum.Died:Connect(function()
				diedConn:Disconnect()
				task.wait(0.5) -- Esperar a que se procese el ragdoll
				onPlayerDied(player)
			end)
		end
	end)
	
	if player.Character then
		local hum = player.Character:FindFirstChild("Humanoid")
		if hum then
			local diedConn
			diedConn = hum.Died:Connect(function()
				diedConn:Disconnect()
				task.wait(0.5)
				onPlayerDied(player)
			end)
		end
	end
end

Players.PlayerAdded:Connect(trackPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(trackPlayer, p)
end

-- =================================────────────────────────────────────────
-- Health and Durability Check Event Handler (Immersive J Keypress)
-- =================================────────────────────────────────────────
local HealthCheckEvent = ReplicatedStorage:FindFirstChild("HealthCheckEvent")
if not HealthCheckEvent then
	HealthCheckEvent = Instance.new("RemoteEvent")
	HealthCheckEvent.Name = "HealthCheckEvent"
	HealthCheckEvent.Parent = ReplicatedStorage
end

local function getHealthStatusText(hum)
	local pct = (hum.Health / hum.MaxHealth) * 100
	if pct >= 100 then
		return "Estoy en perfectas condiciones"
	elseif pct >= 70 then
		return "Tengo algunos rasguños"
	elseif pct >= 40 then
		return "Tengo algunas heridas graves"
	elseif pct >= 10 then
		return "Tengo heridas muy graves"
	else
		return "ESTOY EN LA MIERDA"
	end
end

HealthCheckEvent.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	
	-- 1. Obtener estado de salud
	local healthText = getHealthStatusText(hum)
	
	-- 2. Obtener estado de durabilidad del arma/herramienta equipada
	local toolText = ""
	local tool = char:FindFirstChildOfClass("Tool")
	if tool and tool.Name ~= "Puños" and tool.Name ~= "StrongRight" then
		local maxD = tool:GetAttribute("MaxDurability") or 100
		local currentD = tool:GetAttribute("Durability") or maxD
		
		-- Auto-inicializar si no posee los atributos
		if not tool:GetAttribute("MaxDurability") then
			tool:SetAttribute("MaxDurability", 100)
			tool:SetAttribute("Durability", 100)
			maxD = 100
			currentD = 100
		end
		
		local pct = math.floor((currentD / maxD) * 100)
		toolText = string.format(" y la durabilidad de mi **[%s]** está al **%d%%**", tool.Name, pct)
	end
	
	-- 3. Crear mensaje de rol descriptivo y disparar NarrateEvent privado
	local finalMessage = string.format("*%s%s*", healthText, toolText)
	local NarrateEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
	if NarrateEvent then
		NarrateEvent:FireClient(player, finalMessage, true, 4, 1.5)
	end
end)

print("LifeManager initialized successfully with HealthCheckEvent!")