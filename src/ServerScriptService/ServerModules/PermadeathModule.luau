local PermadeathModule = {}
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1496241312410894537/6pPrRPoqa_t5uodM4blT7Mz2H7zJmzJjJTvxZpbDybLVOTUeM-Rj-_wbT-KAEqaqY8aH"

PermadeathModule.Active = false
PermadeathModule.Registry = {}

function PermadeathModule.GetFullName(p)
	local fn = p:FindFirstChild("LoreFirstName")
	local ln = p:FindFirstChild("LoreLastName")
	if fn and fn.Value ~= "" then return fn.Value .. " " .. (ln and ln.Value or "") end
	return p.Name
end

local function postWebhook(data)
	pcall(function()
		HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(data))
	end)
end

function PermadeathModule.PostEmbed(title, description, color, fields)
	local data = {
		embeds = {{
			title = title,
			description = description,
			color = color or 16753920, -- Gold
			fields = fields,
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
		}}
	}
	postWebhook(data)
end

function PermadeathModule.OnPlayerDied(p, humanoid)
	if not PermadeathModule.Active then return end
	if not PermadeathModule.Registry[p.UserId] then return end
	if PermadeathModule.Registry[p.UserId].died then return end -- Avoid double execution
	
	PermadeathModule.Registry[p.UserId].died = true
	
	-- Determine killer
	local killerName = "Entorno / NPC"
	local creatorTag = humanoid:FindFirstChild("creator")
	if creatorTag and creatorTag.Value and creatorTag.Value:IsA("Player") then
		killerName = PermadeathModule.GetFullName(creatorTag.Value) .. " (@" .. creatorTag.Value.Name .. ")"
	end
	
	local victimFullName = PermadeathModule.GetFullName(p)
	local title = "💀 BAJA EN MUERTE PERMANENTE"
	local description = string.format("El personaje **%s** (@%s) ha caído en combate.", victimFullName, p.Name)
	local fields = {
		{name = "Víctima", value = victimFullName .. " (@" .. p.Name .. ")", inline = true},
		{name = "Causa de Muerte / Asesino", value = killerName, inline = true}
	}
	
	PermadeathModule.PostEmbed(title, description, 13369344, fields) -- Red/Crimson
end

function PermadeathModule.SendWebhook(player)
	local survivors = {}
	local victims = {}
	
	for uid, data in pairs(PermadeathModule.Registry) do
		local p = Players:GetPlayerByUserId(uid)
		local dead = data.died
		
		-- Double check character health
		if not dead and p and p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health <= 0 then
				dead = true
			end
		end
		
		local statusStr = string.format("• **%s** (@%s)", data.name, data.username or tostring(uid))
		if dead then
			table.insert(victims, statusStr)
		else
			table.insert(survivors, statusStr)
		end
	end
	
	local pName = player and PermadeathModule.GetFullName(player) or "System"
	if player then
		pName = string.format("%s\n**Usuario**: @%s\n**ID**: %d", pName, player.Name, player.UserId)
	end
	local description = "El modo de muerte permanente (Permadeath) ha sido **DESACTIVADO**."
	
	local fields = {
		{name = "Finalizado por", value = pName, inline = true},
		{name = "Supervivientes:", value = #survivors > 0 and table.concat(survivors, "\n") or "*Ninguno*", inline = false},
		{name = "Muertes:", value = #victims > 0 and table.concat(victims, "\n") or "*Ninguna*", inline = false}
	}
	
	PermadeathModule.PostEmbed("🟢 EVENTO MUERTE PERMANENTE FINALIZADO", description, 65280, fields)
end

function PermadeathModule.TrackPlayer(p)
	p.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			hum.Died:Connect(function()
				PermadeathModule.OnPlayerDied(p, hum)
			end)
		end
	end)
	if p.Character then
		local hum = p.Character:FindFirstChild("Humanoid")
		if hum then
			hum.Died:Connect(function()
				PermadeathModule.OnPlayerDied(p, hum)
			end)
		end
	end
end

function PermadeathModule.SetState(active, player)
    PermadeathModule.Active = active
    if active then
        PermadeathModule.Registry = {}
        local participantNames = {}
        for _, p in pairs(Players:GetPlayers()) do
            local fullName = PermadeathModule.GetFullName(p)
            PermadeathModule.Registry[p.UserId] = {name = fullName, username = p.Name, died = false}
            table.insert(participantNames, string.format("• **%s** (@%s)", fullName, p.Name))
        end
        
        local pName = player and PermadeathModule.GetFullName(player) or "System"
        if player then
            pName = string.format("%s\n**Usuario**: @%s\n**ID**: %d", pName, player.Name, player.UserId)
        end
        local description = "El modo de muerte permanente (Permadeath) ha sido **ACTIVADO**. Las muertes registradas durante este evento serán definitivas en el lore del personaje."
        local fields = {
            {name = "Iniciado por", value = pName, inline = true},
            {name = "Total Participantes", value = tostring(#participantNames), inline = true},
            {name = "Lista de Participantes", value = #participantNames > 0 and table.concat(participantNames, "\n") or "*Ninguno*", inline = false}
        }
        PermadeathModule.PostEmbed("🔴 EVENTO MUERTE PERMANENTE INICIADO", description, 16711680, fields)
    else
        PermadeathModule.SendWebhook(player)
    end
end

return PermadeathModule
