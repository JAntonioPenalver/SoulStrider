local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local modules = ReplicatedStorage:WaitForChild("Modules")
local TitleConfig = require(modules:WaitForChild("TitleConfig"))
local equipEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("EquipTitleEvent")

local TitleDataStore = nil
pcall(function()
	TitleDataStore = DataStoreService:GetDataStore("PlayerEquippedTitles_V1")
end)

-- Helper to collect player stats for title evaluation
local function getPlayerData(player)
	return {
		pveKills = player:FindFirstChild("PveKills") and player.PveKills.Value or 0,
		pvpKills = player:FindFirstChild("PvpKills") and player.PvpKills.Value or 0,
		heals = player:FindFirstChild("Heals") and player.Heals.Value or 0, -- Fallback to 0
	}
end

-- Validate and Equip a Title
local function equipTitle(player, titleId)
	if not titleId or titleId == "" then
		player:SetAttribute("EquippedTitle", "")
		
		-- Save unequipped state to DataStore
		if TitleDataStore then
			pcall(function()
				TitleDataStore:SetAsync(tostring(player.UserId), "")
			end)
		end
		return true, "Title unequipped successfully"
	end
	
	-- Find title in config
	local selectedTitle = nil
	for _, title in ipairs(TitleConfig.Titles) do
		if title.Id == titleId then
			selectedTitle = title
			break
		end
	end
	
	if not selectedTitle then
		return false, "Title not found in config"
	end
	
	-- Verify unlock criteria
	local playerData = getPlayerData(player)
	local unlocked = selectedTitle.CheckUnlock(playerData)
	
	if unlocked then
		player:SetAttribute("EquippedTitle", selectedTitle.DisplayName)
		
		-- Save equipped title to DataStore
		if TitleDataStore then
			pcall(function()
				TitleDataStore:SetAsync(tostring(player.UserId), titleId)
			end)
		end
		return true, "Title equipped: " .. selectedTitle.DisplayName
	else
		return false, "Requirements not met for this title"
	end
end

-- Load equipped title on join
local function onPlayerAdded(player)
	player:SetAttribute("EquippedTitle", "") -- Default empty
	
	if TitleDataStore then
		local ok, savedTitleId = pcall(function()
			return TitleDataStore:GetAsync(tostring(player.UserId))
		end)
		
		if ok and savedTitleId and savedTitleId ~= "" then
			-- Find matching title
			for _, title in ipairs(TitleConfig.Titles) do
				if title.Id == savedTitleId then
					player:SetAttribute("EquippedTitle", title.DisplayName)
					break
				end
			end
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

-- Listen to equip requests from client
equipEvent.OnServerEvent:Connect(function(player, titleId)
	local success, msg = equipTitle(player, titleId)
	-- Print or communicate results
end)