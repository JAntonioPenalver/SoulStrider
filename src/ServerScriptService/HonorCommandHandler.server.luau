local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Utils = require(game.ServerScriptService.ServerModules.UtilsModule)
local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)

local function handleHonorCommand(player, message)
	local lowerMsg = string.lower(message)
	if string.sub(lowerMsg, 1, 6) == "/honor" then
		
		-- Bypass de admin para Studio o para BYjoselitoYT
		if not Utils.isAdmin(player) and not RunService:IsStudio() and player.Name ~= "BYjoselitoYT" then
			print("[HonorCommandHandler] Bloqueado: El jugador no es admin")
			return
		end
		
		local args = string.split(message, " ")
		if #args < 3 then 
			print("[HonorCommandHandler] Argumentos insuficientes: " .. #args)
			return 
		end
		
		local targetQuery = args[2]
		local amount = tonumber(args[3])
		
		if not amount then 
			print("[HonorCommandHandler] Cantidad invalida: " .. tostring(args[3]))
			return 
		end
		
		local targets = {}
		if targetQuery:lower() == "all" then
			targets = Players:GetPlayers()
		else
			targets = Utils.findPlayersByPrefix(targetQuery)
		end
				
		for _, t in ipairs(targets) do
			t:SetAttribute("MaxHonor", 100)
			t:SetAttribute("Honor", math.clamp(amount, 0, 100))			
			LoreModule.SaveAllData(t)
			
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		handleHonorCommand(player, msg)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(msg)
		handleHonorCommand(player, msg)
	end)
end
