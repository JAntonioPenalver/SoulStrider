local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipesConfig = require(ReplicatedStorage.Modules.RecipesConfig)

local CraftItemEvent = ReplicatedStorage:WaitForChild("CraftItemEvent")
local CookItemEvent = ReplicatedStorage:WaitForChild("CookItemEvent")

local function removeIngredients(player, needed)
	local backpack = player:FindFirstChild("Backpack")
	local char = player.Character
	
	local tools = {}
	local function collect(folder)
		if not folder then return end
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Tool") and needed[child.Name] then
				table.insert(tools, child)
			end
		end
	end
	collect(backpack)
	collect(char)
	
	local available = {}
	for _, tool in ipairs(tools) do
		local qty = tool:GetAttribute("Cantidad") or 1
		available[tool.Name] = (available[tool.Name] or 0) + qty
	end
	
	for name, req in pairs(needed) do
		if (available[name] or 0) < req then
			return false
		end
	end
	
	local removed = {}
	for name, req in pairs(needed) do
		removed[name] = 0
	end
	
	for _, tool in ipairs(tools) do
		local name = tool.Name
		local req = needed[name]
		local rem = removed[name]
		if rem < req then
			local qty = tool:GetAttribute("Cantidad") or 1
			local toRemove = math.min(qty, req - rem)
			if qty - toRemove <= 0 then
				tool:Destroy()
			else
				tool:SetAttribute("Cantidad", qty - toRemove)
			end
			removed[name] = rem + toRemove
		end
	end
	
	return true
end

local function giveItem(player, itemName, amount)
	local template = game.ServerStorage:FindFirstChild(itemName) or game.ReplicatedStorage:FindFirstChild(itemName)
	if not template or not template:IsA("Tool") then
		for _, child in ipairs(game.ServerStorage:GetDescendants()) do
			if child:IsA("Tool") and child.Name == itemName then
				template = child
				break
			end
		end
		if not template then
			for _, child in ipairs(game.ReplicatedStorage:GetDescendants()) do
				if child:IsA("Tool") and child.Name == itemName then
					template = child
					break
				end
			end
		end
	end
	
	if not template then return false end
	
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return false end
	
	local existing = backpack:FindFirstChild(itemName)
	if existing and existing:IsA("Tool") then
		local current = existing:GetAttribute("Cantidad") or 1
		existing:SetAttribute("Cantidad", current + amount)
	else
		local clone = template:Clone()
		clone:SetAttribute("Cantidad", amount)
		clone.Parent = backpack
	end
	
	return true
end

-- Crafting Event
CraftItemEvent.OnServerEvent:Connect(function(player, gridData)
	-- Match recipe
	local matchedRecipe = nil
	for _, recipe in ipairs(RecipesConfig.Crafting) do
		local match = true
		for i = 1, 9 do
			local expected = recipe.Pattern[i]
			local actual = gridData[i]
			if expected ~= actual then
				match = false
				break
			end
		end
		if match then
			matchedRecipe = recipe
			break
		end
	end
	
	if not matchedRecipe then
		return
	end
	
	-- Count required ingredients
	local needed = {}
	for i = 1, 9 do
		local item = matchedRecipe.Pattern[i]
		if item then
			needed[item] = (needed[item] or 0) + 1
		end
	end
	
	-- Verify and remove ingredients
	if removeIngredients(player, needed) then
		local timeToCraft = matchedRecipe.Time or 3
		local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
		if notify then
			notify:FireClient(player, "Sistema", "Crafteando " .. matchedRecipe.Name .. "... (" .. timeToCraft .. "s)")
		end
		
		task.wait(timeToCraft)
		
		giveItem(player, matchedRecipe.Result, matchedRecipe.Amount)
		if notify then
			notify:FireClient(player, "Sistema", "¡Objeto crafteado: " .. matchedRecipe.Name .. "!")
		end
	end
end)

-- Cooking Event
CookItemEvent.OnServerEvent:Connect(function(player, ingredients)
	-- Match cooking recipe
	local matchedRecipe = nil
	for _, recipe in ipairs(RecipesConfig.Cooking) do
		-- Cooking ingredients match if counts of item types are identical (order-independent)
		local recipeCounts = {}
		for _, ing in ipairs(recipe.Ingredients) do
			recipeCounts[ing] = (recipeCounts[ing] or 0) + 1
		end
		
		local actualCounts = {}
		for _, ing in ipairs(ingredients) do
			if ing then
				actualCounts[ing] = (actualCounts[ing] or 0) + 1
			end
		end
		
		local match = true
		for ing, count in pairs(recipeCounts) do
			if (actualCounts[ing] or 0) ~= count then
				match = false
				break
			end
		end
		
		-- Check extra ingredients not in recipe
		for ing, count in pairs(actualCounts) do
			if (recipeCounts[ing] or 0) ~= count then
				match = false
				break
			end
		end
		
		if match then
			matchedRecipe = recipe
			break
		end
	end
	
	if not matchedRecipe then
		return
	end
	
	-- Count ingredients needed
	local needed = {}
	for _, ing in ipairs(matchedRecipe.Ingredients) do
		needed[ing] = (needed[ing] or 0) + 1
	end
	
	-- Verify and remove
	if removeIngredients(player, needed) then
		-- Notify start of cooking and progress bar
		local notify = ReplicatedStorage:FindFirstChild("NotifyPlayerEvent")
		if notify then
			notify:FireClient(player, "Cocina", "Cocinando " .. matchedRecipe.Name .. "... (" .. matchedRecipe.Time .. "s)")
		end
		
		task.wait(matchedRecipe.Time)
		
		-- Give final item
		giveItem(player, matchedRecipe.Result, 1)
		
		if notify then
			notify:FireClient(player, "Cocina", "¡Comida lista: " .. matchedRecipe.Name .. "!")
		end
	end
end)
