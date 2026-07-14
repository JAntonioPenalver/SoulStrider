local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local chestEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ChestEvent")
local InventoryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("InventoryConfig"))

-- maps player -> chestModel (each player can have one chest open at a time)
local activeChests = {}
local initializedChests = {} -- tracks which chests already have prompt setup

-- Helper to count how many players have a given chest open
local function countViewers(chestModel)
	local count = 0
	for _, openChest in pairs(activeChests) do
		if openChest == chestModel then
			count = count + 1
		end
	end
	return count
end

-- Helper to safely get the prompt of a chest
local function getPrompt(chestModel)
	local main = chestModel:FindFirstChild("Main")
	return main and main:FindFirstChildWhichIsA("ProximityPrompt")
end

-- Helper to play a sound on the chest
local function playSound(chestModel, soundName)
	local main = chestModel:FindFirstChild("Main")
	local sound = main and main:FindFirstChild(soundName)
	if sound then
		sound:Play()
	end
end

-- Close the chest UI for a specific player only
local function closeChestForPlayer(player)
	local chestModel = activeChests[player]
	if not chestModel then return end

	activeChests[player] = nil
	chestEvent:FireClient(player, "Close")

	-- Only play the close sound if nobody else has it open
	if countViewers(chestModel) == 0 then
		playSound(chestModel, "Close")
	end
end

-- Initialize ProximityPrompt on ANY chest model (regardless of depth in Workspace)
local function setupChest(chestModel)
	if not chestModel:IsA("Model") then return end
	if initializedChests[chestModel] then return end -- already set up

	local main = chestModel:FindFirstChild("Main")
	if not main then return end

	initializedChests[chestModel] = true

	-- Create or reuse ProximityPrompt
	local prompt = main:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = main
	end

	prompt.ObjectText = "Cofre"
	prompt.ActionText = "Abrir"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true

	prompt.Triggered:Connect(function(player)
		-- Close any OTHER chest this player already had open
		if activeChests[player] and activeChests[player] ~= chestModel then
			closeChestForPlayer(player)
		end

		-- If this player already has THIS chest open, ignore
		if activeChests[player] == chestModel then return end

		activeChests[player] = chestModel

		-- Ensure ChestInventory folder exists
		local chestInv = chestModel:FindFirstChild("ChestInventory")
		if not chestInv then
			chestInv = Instance.new("Folder")
			chestInv.Name = "ChestInventory"
			chestInv.Parent = chestModel
		end

		-- Only play open sound if this is the FIRST viewer
		if countViewers(chestModel) == 1 then
			playSound(chestModel, "Open")
		end
		chestEvent:FireClient(player, "Open", chestModel)
	end)

	-- Cleanup when chest is removed from workspace
	chestModel.AncestryChanged:Connect(function(_, newParent)
		if newParent == nil or not chestModel:IsDescendantOf(Workspace) then
			-- Close for ALL players who have this chest open
			for player, openChest in pairs(activeChests) do
				if openChest == chestModel then
					closeChestForPlayer(player)
				end
			end
			initializedChests[chestModel] = nil
		end
	end)
end

-- Setup all existing Cofre models ANYWHERE in Workspace (at any depth)
local function scanForChests(parent)
	for _, obj in ipairs(parent:GetDescendants()) do
		if obj.Name == "Cofre" and obj:IsA("Model") then
			setupChest(obj)
		end
	end
end

scanForChests(Workspace)

-- Watch for NEW Cofre models added anywhere in Workspace (nested too!)
Workspace.DescendantAdded:Connect(function(child)
	if child.Name == "Cofre" and child:IsA("Model") then
		-- Small delay to let the full model finish loading (e.g. Main part, etc)
		task.defer(function()
			setupChest(child)
		end)
	end
end)

-- Listen to Client events
chestEvent.OnServerEvent:Connect(function(player, action, itemName, chestModel)
	if action == "Close" then
		closeChestForPlayer(player)
		return
	end

	if not chestModel or activeChests[player] ~= chestModel then return end

	local chestInv = chestModel:FindFirstChild("ChestInventory")
	if not chestInv then return end

	if action == "Deposit" then
		local backpack = player:FindFirstChild("Backpack")
		local char = player.Character
		local tool = nil

		if backpack then
			tool = backpack:FindFirstChild(itemName)
		end
		if not tool and char then
			tool = char:FindFirstChild(itemName)
		end

		if not tool or not tool:IsA("Tool") or InventoryConfig.IsBlacklisted(itemName) then return end

		if InventoryConfig.IsStackable(itemName) then
			local qty = tool:GetAttribute("Cantidad") or 1
			local maxStack = InventoryConfig.GetMaxStack(itemName)
			
			local existingChestTools = {}
			for _, child in ipairs(chestInv:GetChildren()) do
				if child:IsA("Tool") and child.Name == itemName then
					table.insert(existingChestTools, child)
				end
			end
			
			local amountToDeposit = qty
			for _, cTool in ipairs(existingChestTools) do
				if amountToDeposit <= 0 then break end
				local currentQty = cTool:GetAttribute("Cantidad") or 1
				if currentQty < maxStack then
					local space = maxStack - currentQty
					local toAdd = math.min(space, amountToDeposit)
					cTool:SetAttribute("Cantidad", currentQty + toAdd)
					amountToDeposit = amountToDeposit - toAdd
				end
			end
			
			while amountToDeposit > 0 do
				local toAdd = math.min(amountToDeposit, maxStack)
				local newTool = tool:Clone()
				newTool:SetAttribute("Cantidad", toAdd)
				newTool.Parent = chestInv
				amountToDeposit = amountToDeposit - toAdd
			end
			
			tool:Destroy()
		else
			tool.Parent = chestInv
		end

	elseif action == "Withdraw" then
		local tool = chestInv:FindFirstChild(itemName)
		if not tool or not tool:IsA("Tool") then return end

		local backpack = player:FindFirstChild("Backpack")
		if not backpack then return end
		local char = player.Character

		if InventoryConfig.IsStackable(itemName) then
			local qty = tool:GetAttribute("Cantidad") or 1
			local maxStack = InventoryConfig.GetMaxStack(itemName)
			
			local existingBPTools = {}
			for _, child in ipairs(backpack:GetChildren()) do
				if child:IsA("Tool") and child.Name == itemName then
					table.insert(existingBPTools, child)
				end
			end
			if char then
				for _, child in ipairs(char:GetChildren()) do
					if child:IsA("Tool") and child.Name == itemName then
						table.insert(existingBPTools, child)
					end
				end
			end
			
			local amountToWithdraw = qty
			for _, bpTool in ipairs(existingBPTools) do
				if amountToWithdraw <= 0 then break end
				local currentQty = bpTool:GetAttribute("Cantidad") or 1
				if currentQty < maxStack then
					local space = maxStack - currentQty
					local toAdd = math.min(space, amountToWithdraw)
					bpTool:SetAttribute("Cantidad", currentQty + toAdd)
					amountToWithdraw = amountToWithdraw - toAdd
				end
			end
			
			while amountToWithdraw > 0 do
				local toAdd = math.min(amountToWithdraw, maxStack)
				local newTool = tool:Clone()
				newTool:SetAttribute("Cantidad", toAdd)
				newTool.Parent = backpack
				amountToWithdraw = amountToWithdraw - toAdd
			end
			
			tool:Destroy()
		else
			tool.Parent = backpack
		end

	elseif action == "Close" then
		closeChestForPlayer(player)
	end
end)

-- Distance check & Player cleanup loop
task.spawn(function()
	while true do
		task.wait(0.5)
		for player, chestModel in pairs(activeChests) do
			if not player or not player.Parent or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
				closeChestForPlayer(player)
			else
				local main = chestModel:FindFirstChild("Main")
				if main then
					local dist = (player.Character.HumanoidRootPart.Position - main.Position).Magnitude
					if dist > 10 then -- Límite de distancia ajustado a 10 studs como fallback
						closeChestForPlayer(player)
					end
				else
					closeChestForPlayer(player)
				end
			end
		end
	end
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	if activeChests[player] then
		closeChestForPlayer(player)
	end
end)
