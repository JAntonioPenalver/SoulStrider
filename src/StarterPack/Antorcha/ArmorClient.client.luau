local tool = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArmorEvent = ReplicatedStorage:WaitForChild("ArmorEvent")

local lastClick = 0
local DOUBLE_CLICK_TIME = 0.4

tool.Activated:Connect(function()
	local now = tick()
	if now - lastClick < DOUBLE_CLICK_TIME then
		-- Doble click detectado
		local armorName = tool:GetAttribute("ArmorName")
		if armorName then
			ArmorEvent:FireServer("Toggle", armorName)
		end
		lastClick = 0 -- Resetear para evitar triple click
	else
		lastClick = now
	end
end)
