local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MagicConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MagicConfig"))
local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)

-- Ensure Events folder and RemoteFunction exist
local Events = ReplicatedStorage:WaitForChild("Events")
local TryLearnSpellbookEvent = Events:FindFirstChild("TryLearnSpellbookEvent")
if not TryLearnSpellbookEvent then
	TryLearnSpellbookEvent = Instance.new("RemoteFunction")
	TryLearnSpellbookEvent.Name = "TryLearnSpellbookEvent"
	TryLearnSpellbookEvent.Parent = Events
end

-- Helper to consume one item (matches quantity attributes)
local function consumeOne(tool)
	local qty = tool:GetAttribute("Cantidad") or 1
	if qty > 1 then
		tool:SetAttribute("Cantidad", qty - 1)
	else
		tool:Destroy()
	end
end

-- Reset daily attempts if needed
local function updateDailyAttempts(player)
	local currentDate = os.date("!%Y-%m-%d")
	local lastAttemptDate = player:GetAttribute("MagicLastAttemptDate") or "1970-01-01"
	
	if lastAttemptDate ~= currentDate then
		player:SetAttribute("MagicAttemptsRemaining", 3)
		player:SetAttribute("MagicLastAttemptDate", currentDate)
	end
end

local function hasCompletedLevel(player, lvl)
	local levelMinigames = MagicConfig.Minigames[lvl]
	if not levelMinigames then return true end
	for _, sub in ipairs(levelMinigames) do
		if player:GetAttribute(MagicConfig.GetSpellAttributeName(sub.Spell)) ~= true then
			return false
		end
	end
	return true
end

TryLearnSpellbookEvent.OnServerInvoke = function(player, bookInstance, submittedAnswers, subMinigameIndex)
	if not player or not bookInstance or not bookInstance.Parent or type(submittedAnswers) ~= "table" or not subMinigameIndex then
		return false, "Solicitud inválida."
	end
	
	-- Verify equipped
	if bookInstance.Parent ~= player.Character then
		return false, "Debes tener el libro equipado en tus manos."
	end
	
	local bookLevel = bookInstance:GetAttribute("MagicBookLevel")
	if not bookLevel then
		return false, "Este objeto no es un libro de magia válido."
	end
	
	-- Check attempts
	updateDailyAttempts(player)
	local attempts = player:GetAttribute("MagicAttemptsRemaining") or 3
	if attempts <= 0 then
		return false, "No te quedan intentos para hoy. Vuelve mañana."
	end
	
	-- Check level progression: to learn level L, must have completed level L-1
	if bookLevel > 1 then
		if not hasCompletedLevel(player, bookLevel - 1) then
			return false, "Debes desbloquear todos los hechizos del nivel anterior primero."
		end
	end
	
	-- Fetch minigame configurations
	local levelMinigames = MagicConfig.Minigames[bookLevel]
	if not levelMinigames then
		return false, "Configuración de minijuego no encontrada."
	end
	
	local activeMinigame = levelMinigames[subMinigameIndex]
	if not activeMinigame then
		return false, "Configuración del hechizo no encontrada."
	end
	
	-- Check if already unlocked
	if player:GetAttribute(MagicConfig.GetSpellAttributeName(activeMinigame.Spell)) == true then
		return false, "Ya dominas este hechizo."
	end
	
	-- Deduct 1 attempt
	local remaining = math.max(0, attempts - 1)
	player:SetAttribute("MagicAttemptsRemaining", remaining)
	
	-- Validate answers
	local correct = true
	if #submittedAnswers ~= #activeMinigame.Slots then
		correct = false
	else
		for i = 1, #activeMinigame.Slots do
			if tostring(submittedAnswers[i]):lower() ~= tostring(activeMinigame.Slots[i]):lower() then
				correct = false
				break
			end
		end
	end
	
	if correct then
		-- Consume book
		consumeOne(bookInstance)
		
		-- Unlock spell
		player:SetAttribute(MagicConfig.GetSpellAttributeName(activeMinigame.Spell), true)
		
		-- Set MagicLevel to bookLevel if player has completed all spells of this level
		if hasCompletedLevel(player, bookLevel) then
			player:SetAttribute("MagicLevel", bookLevel)
		end
		
		-- Guardar progreso inmediatamente para evitar pérdidas de datos
		pcall(function()
			LoreModule.SaveAllData(player)
		end)
		
		-- Give visual feedback or narration
		local NarrateEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
		if NarrateEvent then
			NarrateEvent:FireClient(player, "¡He canalizado la magia del libro! He aprendido el hechizo: " .. activeMinigame.Type .. ".", true)
		end
		
		return true, "¡Has aprendido el hechizo: " .. activeMinigame.Type .. "!"
	else
		-- Guardar progreso inmediatamente para registrar la pérdida del intento
		pcall(function()
			LoreModule.SaveAllData(player)
		end)
		
		return false, "La incantación falló. Intentos restantes para hoy: " .. remaining
	end
end

-- Initialize players joining in case game started
local function onPlayerAdded(player)
	player:SetAttribute("MagicLevel", player:GetAttribute("MagicLevel") or 0)
	updateDailyAttempts(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

-- Test Commands for Development
pcall(function()
	local CommandRegistry = require(game.ServerScriptService.ServerModules.CommandRegistry)
	local Utils = require(game.ServerScriptService.ServerModules.UtilsModule)
	
	-- Command to give all magic books
	CommandRegistry.Register("/libros", function(player, msg)
		local args = string.split(msg or "", " ")
		local targetQuery = (args[1] and args[1] ~= "") and args[1] or "me"
		
		local targets
		if targetQuery:lower() == "me" then
			targets = {player}
		else
			targets = Utils.findPlayersByPrefix(targetQuery)
		end
		
		local ServerStorage = game:GetService("ServerStorage")
		local bookNames = {
			"Libro_Principiante",
			"Libro_Intermedio",
			"Libro_Avanzado",
			"Libro_Sagrado",
			"Libro_Divino"
		}
		
		for _, t in ipairs(targets) do
			for _, name in ipairs(bookNames) do
				local template = ServerStorage:FindFirstChild(name)
				if template then
					local clone = template:Clone()
					clone.Parent = t.Backpack
					print("[MagicService] Otorgado " .. name .. " a " .. t.Name)
				end
			end
		end
	end)
	
	-- Command to easily set player magic level
	CommandRegistry.Register("/setmagiclevel", function(player, msg)
		local args = string.split(msg or "", " ")
		local targetQuery = args[1]
		local lvl = tonumber(args[2])
		
		if not targetQuery or targetQuery == "" or not lvl then
			print("[MagicService] Formato incorrecto. Uso: /setmagiclevel [jugador] [nivel]")
			return
		end
		
		local targets
		if targetQuery:lower() == "me" then
			targets = {player}
		else
			targets = Utils.findPlayersByPrefix(targetQuery)
		end
		
		if #targets > 0 then
			for _, t in ipairs(targets) do
				if lvl >= 0 and lvl <= 5 then
					t:SetAttribute("MagicLevel", lvl)
					-- Unlock or lock spells up to this level
					for i = 1, 5 do
						local levelMinigames = MagicConfig.Minigames[i]
						if levelMinigames then
							for _, sub in ipairs(levelMinigames) do
								t:SetAttribute(MagicConfig.GetSpellAttributeName(sub.Spell), i <= lvl)
							end
						end
					end
					
					-- Guardar progreso inmediatamente
					pcall(function()
						LoreModule.SaveAllData(t)
					end)
					
					print("[MagicService] Nivel de magia de " .. t.Name .. " establecido a: " .. lvl)
				end
			end
		else
			print("[MagicService] Jugador no encontrado: " .. tostring(targetQuery))
		end
	end)
end)