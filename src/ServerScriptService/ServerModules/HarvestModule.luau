local HarvestModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dar cualquier Tool del ReplicatedStorage al inventario del jugador (acumulando Cantidad si ya existe)
function HarvestModule.GiveItem(player, templateName)
	local template = ReplicatedStorage:FindFirstChild(templateName)
	if not template or not template:IsA("Tool") then
		warn("[HarvestModule] Template '" .. tostring(templateName) .. "' no es una Tool válida en ReplicatedStorage")
		return false
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false end

	local char = player.Character
	local existing = backpack:FindFirstChild(template.Name) or (char and char:FindFirstChild(template.Name))

	if existing and existing:IsA("Tool") then
		local current = existing:GetAttribute("Cantidad") or 1
		existing:SetAttribute("Cantidad", current + 1)
	else
		local item = template:Clone()
		item:SetAttribute("Cantidad", 1)
		item.Parent = backpack
	end
	return true
end

-- Compatibilidad con sistema de Trigo
function HarvestModule.GetWheatTemplate()
	return ReplicatedStorage:FindFirstChild("WheatToolTemplate") or ReplicatedStorage:FindFirstChild("Wheat")
end

function HarvestModule.GiveWheat(player)
	return HarvestModule.GiveItem(player, "WheatToolTemplate")
end

function HarvestModule.AttachPromptToTrigo(part)
	if not part:IsA("BasePart") then return end
	if string.lower(part.Name) ~= "trigo" then return end

	local prompt = part:FindFirstChild("TrigoPickupPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TrigoPickupPrompt"
		prompt.ObjectText = "Trigo"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 5
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end

	if prompt:GetAttribute("Connected") == true then return end
	prompt:SetAttribute("Connected", true)

	prompt.Triggered:Connect(function(player)
		if not player or not part or not part.Parent then return end
		if HarvestModule.GiveWheat(player) then
			part:Destroy()
		end
	end)
end

return HarvestModule
