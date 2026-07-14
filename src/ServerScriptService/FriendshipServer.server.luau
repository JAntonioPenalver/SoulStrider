local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)

-- pendingRequests[targetUserId] = { sender = Player, senderName = "Name LastName", time = number }
local pendingRequests = {}

local function cleanRequests()
	local now = os.time()
	for targetId, req in pairs(pendingRequests) do
		if now - req.time > 30 then
			pendingRequests[targetId] = nil
		end
	end
end

local function cleanName(nameStr)
	if not nameStr then return "" end
	-- Eliminar puntuación común al final del nombre (como puntos, exclamaciones, comas)
	nameStr = string.gsub(nameStr, "[%.%!%,%?]+%s*$", "")
	-- Reemplazar múltiples espacios por uno solo
	nameStr = string.gsub(nameStr, "%s+", " ")
	-- Quitar espacios al inicio y al final
	return nameStr:match("^%s*(.-)%s*$") or ""
end

local function handleChat(player, message)
	cleanRequests()
	
	local lowerMsg = string.lower(message)
	
	-- 1. Detectar solicitud: "¿Quieres ser mi amigo [Nombre] [Apellido]?"
	-- Soporta cualquier tipo de caracteres (acentos, ñ, espacios, guiones, etc.)
	local matchRequest = string.match(lowerMsg, "^%s*¿?%s*quieres%s+ser%s+mi%s+amigo%s+(.-)%??%s*$")
	if matchRequest then
		-- Limpiar y normalizar el nombre buscado
		local targetNameClean = cleanName(matchRequest)
		if #targetNameClean > 0 then
			local senderName = (player:FindFirstChild("LoreFirstName") and player.LoreFirstName.Value or "") .. " " .. (player:FindFirstChild("LoreLastName") and player.LoreLastName.Value or "")
			
			-- Buscar al jugador objetivo por su nombre de rol
			local targetPlayer = nil
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player then
					local pName = (p:FindFirstChild("LoreFirstName") and p.LoreFirstName.Value or "") .. " " .. (p:FindFirstChild("LoreLastName") and p.LoreLastName.Value or "")
					if string.lower(pName) == string.lower(targetNameClean) then
						targetPlayer = p
						break
					end
				end
			end
			
			if targetPlayer then
				-- Verificar distancia (máximo 20 studs)
				if player.Character and targetPlayer.Character then
					local root1 = player.Character:FindFirstChild("HumanoidRootPart")
					local root2 = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
					if root1 and root2 then
						local dist = (root1.Position - root2.Position).Magnitude
						if dist <= 20 then
							pendingRequests[targetPlayer.UserId] = {
								sender = player,
								senderName = senderName,
								time = os.time()
							}
						else
							print("[FriendshipSystem] Demasiado lejos (" .. math.floor(dist) .. " studs)")
						end
					end
				end
			end
		end
		return
	end
	
	-- 2. Detectar respuesta: "Si, [Nombre] [Apellido]"
	-- Soporta cualquier tipo de caracteres (acentos, ñ, etc.)
	local matchReply = string.match(lowerMsg, "^%s*si%s*,?%s+(.-)%s*$")
	if matchReply then
		local targetNameClean = cleanName(matchReply)
		local req = pendingRequests[player.UserId]
		if req and os.time() - req.time <= 30 then
			-- Verificar si coincide con el nombre del solicitante
			if string.lower(targetNameClean) == string.lower(req.senderName) then
				-- Verificar distancia (máximo 20 studs)
				if player.Character and req.sender.Character then
					local root1 = player.Character:FindFirstChild("HumanoidRootPart")
					local root2 = req.sender.Character:FindFirstChild("HumanoidRootPart")
					if root1 and root2 then
						local dist = (root1.Position - root2.Position).Magnitude
						if dist <= 20 then
							local friendsFolder = player:FindFirstChild("Friends")
							local friendsFolder2 = req.sender:FindFirstChild("Friends")
							
							if friendsFolder and friendsFolder2 then
								-- Verificar si ya son amigos
								if friendsFolder:FindFirstChild(tostring(req.sender.UserId)) then
									pendingRequests[player.UserId] = nil
									return
								end
								
								-- Crear amistad para jugador 1
								local f1 = Instance.new("StringValue")
								f1.Name = tostring(req.sender.UserId)
								f1.Value = req.senderName
								f1.Parent = friendsFolder
								
								-- Crear amistad para jugador 2
								local replierName = (player:FindFirstChild("LoreFirstName") and player.LoreFirstName.Value or "") .. " " .. (player:FindFirstChild("LoreLastName") and player.LoreLastName.Value or "")
								local f2 = Instance.new("StringValue")
								f2.Name = tostring(player.UserId)
								f2.Value = replierName
								f2.Parent = friendsFolder2
								
								-- Guardar datos de inmediato
								LoreModule.SaveAllData(player)
								LoreModule.SaveAllData(req.sender)
								
								-- Notificar a ambos jugadores mediante NarrateEvent (modo instantáneo con fade)
								local NarrateEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
								if NarrateEvent then
									NarrateEvent:FireClient(player, "Ahora eres amigo de " .. req.senderName, true)
									NarrateEvent:FireClient(req.sender, "Ahora eres amigo de " .. replierName, true)
								end
								
								-- Limpiar solicitud
								pendingRequests[player.UserId] = nil
								print("[FriendshipSystem] ¡Amistad establecida con éxito entre " .. player.Name .. " y " .. req.sender.Name .. "!")
							end
						else
							print("[FriendshipSystem] Demasiado lejos para aceptar (" .. math.floor(dist) .. " studs)")
						end
					end
				end
			end
		end
		return
	end

	-- 3. Detectar presentación: "Soy, [Nombre] [Apellido]" o "Soy [Nombre] [Apellido]" o "Me llamo [Nombre] [Apellido]" o "Mi nombre es [Nombre] [Apellido]"
	local matchIntro = string.match(lowerMsg, "^%s*soy%s*,?%s+(.-)%s*$")
		or string.match(lowerMsg, "^%s*me%s+llamo%s+(.-)%s*$")
		or string.match(lowerMsg, "^%s*mi%s+nombre%s+es%s+(.-)%s*$")
	
	if matchIntro then
		local introNameClean = cleanName(matchIntro)
		if #introNameClean > 0 then
			local myFirstName = player:FindFirstChild("LoreFirstName") and player.LoreFirstName.Value or ""
			local myLastName = player:FindFirstChild("LoreLastName") and player.LoreLastName.Value or ""
			local myRealName = myFirstName .. " " .. myLastName
			
			if string.lower(myRealName) == string.lower(introNameClean) then
				if player.Character then
					local root1 = player.Character:FindFirstChild("HumanoidRootPart")
					if root1 then
						local NarrateEvent = ReplicatedStorage:FindFirstChild("NarrateEvent")
						for _, otherPlayer in ipairs(Players:GetPlayers()) do
							if otherPlayer ~= player and otherPlayer.Character then
								local root2 = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
								if root2 then
									local dist = (root1.Position - root2.Position).Magnitude
									if dist <= 20 then
										local knownFolder = otherPlayer:FindFirstChild("Known")
										if knownFolder then
											if not knownFolder:FindFirstChild(tostring(player.UserId)) then
												local kVal = Instance.new("StringValue")
												kVal.Name = tostring(player.UserId)
												kVal.Value = myRealName
												kVal.Parent = knownFolder
												
												-- Guardar los datos del otro jugador de inmediato para persistencia
												LoreModule.SaveAllData(otherPlayer)
												
												-- Notificar al otro jugador de que ahora lo conoce
												if NarrateEvent then
													NarrateEvent:FireClient(otherPlayer, "Ahora conoces a " .. myRealName, true)
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
		return
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		handleChat(player, msg)
	end)
end)

for _, p in ipairs(Players:GetPlayers()) do
	p.Chatted:Connect(function(msg)
		handleChat(p, msg)
	end)
end
