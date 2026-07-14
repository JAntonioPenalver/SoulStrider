local tool = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local relicEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RelicEvent")

local lastClick = 0
local DOUBLE_CLICK_TIME = 0.4

tool.Activated:Connect(function()
	local now = tick()
	if now - lastClick < DOUBLE_CLICK_TIME then
		-- Doble click detectado: equipar/desequipar reliquia
		relicEvent:FireServer("Toggle", tool.Name)
		lastClick = 0 -- Reset
	else
		lastClick = now
	end
end)
