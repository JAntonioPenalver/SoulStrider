local CondicionesModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Utils = require(script.Parent.UtilsModule)

-- Crear RemoteEvents necesarios al cargar
local function getOrCreate(name, className)
	local obj = ReplicatedStorage:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = ReplicatedStorage
	end
	return obj
end

local CondicionEvent  = getOrCreate("CondicionEvent",  "RemoteEvent")
local CondicionRemove = getOrCreate("CondicionRemove", "RemoteEvent")

-- Sonidos
local SOUND_BONE     = "rbxassetid://114844647575480"
local SOUND_LIMB     = "rbxassetid://140325083438865"

-- Miembros que se pueden perder (nombre en el modelo R6)
local LIMB_PARTS = {
	{"Left Arm",  "LeftArm"},
	{"Right Arm", "RightArm"},
	{"Left Leg",  "LeftLeg"},
	{"Right Leg", "RightLeg"},
}

local function playOnCharacter(player, soundId)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = 2.5
	s.Parent = root
	s:Play()
	game.Debris:AddItem(s, 4)
end

-- Estado de condiciones activas por jugador
CondicionesModule.PlayerCondiciones = {}

function CondicionesModule.InitPlayer(player)
	CondicionesModule.PlayerCondiciones[player] = {}
end

function CondicionesModule.ClearPlayer(player)
	CondicionesModule.PlayerCondiciones[player] = nil
end

-- ============================================================
-- APPLY
-- ============================================================
function CondicionesModule.Apply(player, condicion, silent)
	local data = CondicionesModule.PlayerCondiciones[player]
	if not data then return end

	condicion = string.lower(condicion)
	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")

	if condicion == "piernorota" then
		data.piernaRota = true
		if hum then
			hum.WalkSpeed = 4
			hum.JumpPower = 0
		end
		if not silent then playOnCharacter(player, SOUND_BONE) end

	elseif condicion == "brazoroto" then
		data.brazoRoto = true
		if not silent then playOnCharacter(player, SOUND_BONE) end

	elseif condicion == "extremidad" then
		data.perdidaExtremidad = true
		if not silent then playOnCharacter(player, SOUND_LIMB) end
		-- Usar miembro previamente guardado o escoger uno nuevo
		if char then
			local partName = data.lostLimbPart
			if not partName or not char:FindFirstChild(partName) then
				local limb = LIMB_PARTS[math.random(1, #LIMB_PARTS)]
				partName = limb[1]
				data.lostLimbPart = partName
			end
			local part = char:FindFirstChild(partName)
			if part then
				part.Transparency = 1
				-- Quitar meshes/decales dentro
				for _, child in ipairs(part:GetChildren()) do
					if child:IsA("SpecialMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
						child.Parent = nil
					end
				end
				-- Si es pierna, tambien penalizar velocidad
				if partName:find("Leg") and hum then
					hum.WalkSpeed = math.max((hum.WalkSpeed or 16) - 6, 2)
				end

				-- SOLTAR PARTÍCULAS SANGREEXTREMIDAD
				if not silent then
					local bloodPart = workspace:FindFirstChild("SangreExtremidad")
					if bloodPart then
						local mainAtt = bloodPart:FindFirstChild("Main")
						if mainAtt then
							local attClone = mainAtt:Clone()
							attClone.Name = "SangreExtremidadAttachment"
							attClone.Parent = part
							game.Debris:AddItem(attClone, 1) -- Sangra por 1 segundo
						end
					end
				end
			end
		end

	elseif condicion == "ciego" then
		data.ciego = true

	elseif condicion == "perdidaojo" then
		data.perdidaOjo = true

	elseif condicion == "concusion" then
		data.concusion = true

	elseif condicion == "esquizofrenia" then
		data.esquizofrenia = true
	end

	CondicionEvent:FireClient(player, condicion, true)
end

-- ============================================================
-- REMOVE
-- ============================================================
function CondicionesModule.Remove(player, condicion)
	local data = CondicionesModule.PlayerCondiciones[player]
	if not data then return end

	condicion = string.lower(condicion)
	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")

	if condicion == "piernorota" then
		data.piernaRota = nil
		if hum then
			hum.WalkSpeed = 16
			hum.JumpPower = 50
		end

	elseif condicion == "brazoroto" then
		data.brazoRoto = nil

	elseif condicion == "extremidad" then
		-- Restaurar el miembro si aun esta en el personaje
		if data.lostLimbPart and char then
			local part = char:FindFirstChild(data.lostLimbPart)
			if part then part.Transparency = 0 end
		end
		data.perdidaExtremidad = nil
		data.lostLimbPart = nil
		if hum then hum.WalkSpeed = 16 end

	elseif condicion == "ciego" then
		data.ciego = nil

	elseif condicion == "perdidaojo" then
		data.perdidaOjo = nil

	elseif condicion == "concusion" then
		data.concusion = nil

	elseif condicion == "esquizofrenia" then
		data.esquizofrenia = nil
	end

	CondicionRemove:FireClient(player, condicion)
end

-- ============================================================
-- TICK: mantener penalizaciones activas cada segundo
-- (llamado desde AdvancedInjuryServer)
-- ============================================================
function CondicionesModule.UpdateTick()
	for player, data in pairs(CondicionesModule.PlayerCondiciones) do
		if not player.Parent then continue end
		local char = player.Character
		local hum = char and char:FindFirstChild("Humanoid")
		if not hum or hum.Health <= 0 then continue end

		-- Pierna rota: mantener velocidad baja
		if data.piernaRota then
			if hum.WalkSpeed ~= 4 then hum.WalkSpeed = 4 end
			if hum.JumpPower ~= 0 then hum.JumpPower = 0 end
		end

		-- Extremidad (pierna perdida): mantener velocidad baja
		if data.perdidaExtremidad and data.lostLimbPart and data.lostLimbPart:find("Leg") then
			local expectedSpeed = 10 -- WalkSpeed default 16 - 6 = 10
			if hum.WalkSpeed > expectedSpeed then
				hum.WalkSpeed = expectedSpeed
			end
		end
	end
end

function CondicionesModule.HasLostLeg(player)
	local data = CondicionesModule.PlayerCondiciones[player]
	if not data then return false end
	return data.perdidaExtremidad == true and data.lostLimbPart and data.lostLimbPart:find("Leg") and true or false
end

function CondicionesModule.HasCondicion(player, condicion)
	local data = CondicionesModule.PlayerCondiciones[player]
	if not data then return false end
	local key = {
		piernorota   = "piernaRota",
		piernarota   = "piernaRota",
		brazoroto    = "brazoRoto",
		extremidad   = "perdidaExtremidad",
		ciego        = "ciego",
		perdidaojo   = "perdidaOjo",
		concusion    = "concusion",
		esquizofrenia = "esquizofrenia",
	}
	local k = key[condicion]
	return k and data[k] == true or false
end

return CondicionesModule