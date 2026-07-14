local ArmorModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArmorAssets = ReplicatedStorage:WaitForChild("ArmorAssets")

-- Configuración de Slots y Vida
local SLOTS = {
	["ChestPlate Armor"] = "Chest",
	["Waist Armor"] = "Waist",
	["Left Arm Armor"] = "LeftArm",
	["Right Arm Armor"] = "RightArm",
	["Antorcha"] = "Back"
}

local HEALTH_BONUSES = {
	["ChestPlate Armor"] = 30,
	["Waist Armor"] = 20,
	["Left Arm Armor"] = 15,
	["Right Arm Armor"] = 15,
	["Antorcha"] = 0
}

local BASE_HEALTH = 100

function ArmorModule.UpdateStats(player)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
    -- Calcular vida base según Resistencia (Stats)
    local resStat = player:FindFirstChild("Resistencia")
    local currentBaseHealth = 100 + (resStat and resStat.Value or 0) * 10
    
	local totalBonus = 0
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and child:GetAttribute("ArmorSlot") then
			local bonus = HEALTH_BONUSES[child.Name] or 0
			totalBonus += bonus
		end
	end
	
	local newMaxHealth = currentBaseHealth + totalBonus
	local oldMaxHealth = humanoid.MaxHealth
	
	humanoid.MaxHealth = newMaxHealth
	
	-- Si la vida máxima aumentó, curamos la diferencia proporcionalmente o por el bono
	if newMaxHealth > oldMaxHealth then
		humanoid.Health += (newMaxHealth - oldMaxHealth)
	end
	
	-- Asegurar que la vida no exceda el nuevo máximo
	if humanoid.Health > newMaxHealth then
		humanoid.Health = newMaxHealth
	end
end

function ArmorModule.Equip(player, armorName)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local armorTemplate = ArmorAssets:FindFirstChild(armorName)
	if not armorTemplate then 
		warn("Armor template not found: " .. tostring(armorName))
		return 
	end
	
	local slot = SLOTS[armorName]
	if not slot then
		warn("No slot defined for armor: " .. armorName)
		return
	end
	
	-- Desequipar lo que haya en ese slot primero
	ArmorModule.Unequip(player, slot)
	
	local armorClone = armorTemplate:Clone()
	armorClone:SetAttribute("ArmorSlot", slot)
	
	-- Usar AddAccessory para que Roblox maneje los welds automáticamente
	humanoid:AddAccessory(armorClone)
	
	-- Actualizar stats
	ArmorModule.UpdateStats(player)
end

function ArmorModule.Toggle(player, armorName)
	local character = player.Character
	if not character then return end
	
	local slot = SLOTS[armorName]
	if not slot then return end
	
	-- Verificar si ya tiene ESTA armadura específica equipada
	local alreadyEquipped = false
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and child.Name == armorName then
			alreadyEquipped = true
			break
		end
	end
	
	if alreadyEquipped then
		-- Si ya la tiene, la quitamos
		ArmorModule.Unequip(player, slot)
	else
		-- Si no la tiene (o tiene otra en ese slot), la equipamos
		ArmorModule.Equip(player, armorName)
	end
end

function ArmorModule.Unequip(player, slot)
	local character = player.Character
	if not character then return end
	
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and child:GetAttribute("ArmorSlot") == slot then
			child:Destroy()
		end
	end
	
	-- Actualizar stats después de destruir
	task.defer(function()
		ArmorModule.UpdateStats(player)
	end)
end

return ArmorModule
