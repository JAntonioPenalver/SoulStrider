local BossHealthbarModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local event = ReplicatedStorage:WaitForChild("BossHealthbarEvent")

BossHealthbarModule.CurrentTarget = nil
BossHealthbarModule.CustomTitle = nil
local healthConn = nil
local maxHealthConn = nil
local charConn = nil

function BossHealthbarModule.DisconnectConns()
	if healthConn then healthConn:Disconnect(); healthConn = nil end
	if maxHealthConn then maxHealthConn:Disconnect(); maxHealthConn = nil end
	if charConn then charConn:Disconnect(); charConn = nil end
end

function BossHealthbarModule.BroadcastHide()
	event:FireAllClients("Hide")
end

function BossHealthbarModule.BroadcastUpdate(target, customTitle)
	local char = target.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		BossHealthbarModule.BroadcastHide()
		return
	end
	local title = customTitle
	if not title or title == "" then
		title = target.DisplayName
		if target.DisplayName ~= target.Name then title = target.DisplayName .. " (" .. target.Name .. ")" end
	end
	event:FireAllClients("Show", {title = title, health = hum.Health, maxHealth = hum.MaxHealth, userId = target.UserId})
end

function BossHealthbarModule.TrackTarget(target, customTitle)
	BossHealthbarModule.DisconnectConns()
	BossHealthbarModule.CurrentTarget = target
	BossHealthbarModule.CustomTitle = customTitle
	if not target then
		BossHealthbarModule.BroadcastHide()
		return
	end

	local function bindHumanoid()
		local char = target.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then
			BossHealthbarModule.BroadcastHide()
			return
		end

		BossHealthbarModule.BroadcastUpdate(target, customTitle)
		healthConn = hum.HealthChanged:Connect(function()
			if BossHealthbarModule.CurrentTarget ~= target then return end
			BossHealthbarModule.BroadcastUpdate(target, customTitle)
		end)
		
		maxHealthConn = hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
			if BossHealthbarModule.CurrentTarget ~= target then return end
			BossHealthbarModule.BroadcastUpdate(target, customTitle)
		end)
	end

	bindHumanoid()
	charConn = target.CharacterAdded:Connect(function()
		task.wait(0.1)
		if BossHealthbarModule.CurrentTarget ~= target then return end
		BossHealthbarModule.TrackTarget(target, customTitle)
	end)
end

return BossHealthbarModule
