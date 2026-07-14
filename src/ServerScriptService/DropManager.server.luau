local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Workspace         = game:GetService("Workspace")
local StarterPack       = game:GetService("StarterPack")

local DropItemEvent = ReplicatedStorage:WaitForChild("DropItemEvent")
local DropBagTemplate = ServerStorage:WaitForChild("DropBag")

-- ─────────────────────────────────────────────────────────────
-- Helper: Busca items por nombre y resta cantidad
-- ─────────────────────────────────────────────────────────────
local function processDrop(player, itemName, amountToDrop)
    local backpack = player:FindFirstChild("Backpack")
    local char     = player.Character
    if not backpack then return false end
    
    local foundItems = {}
    local totalHas = 0
    
    local function collect(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and item.Name == itemName then
                table.insert(foundItems, item)
                totalHas = totalHas + (item:GetAttribute("Cantidad") or 1)
            end
        end
    end
    
    collect(backpack)
    collect(char)
    
    if totalHas < amountToDrop then 
        amountToDrop = totalHas -- Drop all if they ask for more than they have
    end
    
    local remainingToDrop = amountToDrop
    
    for _, item in ipairs(foundItems) do
        if remainingToDrop <= 0 then break end
        
        local itemQty = item:GetAttribute("Cantidad") or 1
        if itemQty <= remainingToDrop then
            remainingToDrop = remainingToDrop - itemQty
            item:Destroy()
        else
            item:SetAttribute("Cantidad", itemQty - remainingToDrop)
            remainingToDrop = 0
        end
    end
    
    return true, amountToDrop
end

-- ─────────────────────────────────────────────────────────────
-- Crea la bolsa física en el mundo
-- ─────────────────────────────────────────────────────────────
local function createPhysicalDrop(player, itemName, amount)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local newBag = DropBagTemplate:Clone()
    newBag.Name = "Dropped_" .. itemName
    
    -- Raycast profundo para colocar la bolsa exactamente en el suelo real (evitando hojas y objetos)
    local spawnPos = root.Position + root.CFrame.LookVector * 4
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {char}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = Workspace:Raycast(spawnPos + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), rayParams)
    
    local finalCFrame = CFrame.new(spawnPos - Vector3.new(0, 2.5, 0)) -- Fallback
    if result then
        finalCFrame = CFrame.new(result.Position + Vector3.new(0, newBag.Size.Y * 0.4, 0))
    else
        -- Fallback raycast desde el root position directamente hacia el suelo
        local fallbackResult = Workspace:Raycast(root.Position, Vector3.new(0, -50, 0), rayParams)
        if fallbackResult then
            finalCFrame = CFrame.new(fallbackResult.Position + Vector3.new(0, newBag.Size.Y * 0.4, 0))
        end
    end
    
    newBag.CFrame = finalCFrame
    newBag:SetAttribute("ItemName", itemName)
    newBag:SetAttribute("Amount", amount)
    newBag.Parent = Workspace
    
    -- 1. Activamos físicas inicialmente para que caiga al suelo de forma natural
    newBag.Anchored = false
    newBag.CanCollide = true
    newBag.CanTouch = true
    
    -- 2. Creamos una zona de detección invisible y generosa (TouchArea) welded a la bolsa
    local touchArea = Instance.new("Part")
    touchArea.Name = "TouchArea"
    touchArea.Shape = Enum.PartType.Ball
    touchArea.Size = Vector3.new(5, 5, 5) -- Esfera invisible de 5 studs de radio de recojo!
    touchArea.Position = newBag.Position
    touchArea.Transparency = 1
    touchArea.CanCollide = false
    touchArea.CanTouch = true
    touchArea.Parent = newBag
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = newBag
    weld.Part1 = touchArea
    weld.Parent = newBag
    
    -- 3. Auto-Estabilización física: tras 1.5s la bolsa se ancla y desactiva colisión para evitar empujarla
    task.spawn(function()
        task.wait(1.5)
        if newBag and newBag.Parent then
            newBag.Anchored = true
            newBag.CanCollide = false
        end
    end)
    
    -- Añadir Texto Flotante (BillboardGui)
    local bbg = Instance.new("BillboardGui", newBag)
    bbg.Name = "InfoLabel"
    bbg.Size = UDim2.new(0, 200, 0, 50)
    bbg.Adornee = newBag
    bbg.StudsOffset = Vector3.new(0, 2, 0)
    bbg.AlwaysOnTop = false
	bbg.MaxDistance = 60
    
    local label = Instance.new("TextLabel", bbg)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "x" .. amount .. " " .. itemName
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.Garamond
    label.TextSize = 20
    label.RichText = true
    label.Text = "<i>" .. label.Text .. "</i>"

    -- ─────────────────────────────────────────────────────────────
    -- Lógica de Recojo (Pickup) vinculada a la TouchArea generosa
    -- ─────────────────────────────────────────────────────────────
    local pickingUp = false
    touchArea.Touched:Connect(function(hit)
        if pickingUp then return end
        local char = hit.Parent
        local p = Players:GetPlayerFromCharacter(char)
        
        if p and p.Character == char then
            pickingUp = true
            local backpack = p:FindFirstChild("Backpack")
            if not backpack then pickingUp = false; return end
            
            local iName = newBag:GetAttribute("ItemName")
            local iAmt  = newBag:GetAttribute("Amount")
            
            -- Buscar si ya tiene el item para sumar cantidad
            local existing = backpack:FindFirstChild(iName) or char:FindFirstChild(iName)
            
            if existing and existing:IsA("Tool") then
                local current = existing:GetAttribute("Cantidad") or 1
                existing:SetAttribute("Cantidad", current + iAmt)
                newBag:Destroy()
            else
                -- Dar item nuevo (buscar template en ServerStorage, ReplicatedStorage o StarterPack)
                local template = ServerStorage:FindFirstChild(iName) or ReplicatedStorage:FindFirstChild(iName) or StarterPack:FindFirstChild(iName)
                if template and template:IsA("Tool") then
                    local clone = template:Clone()
                    clone:SetAttribute("Cantidad", iAmt)
                    clone.Parent = backpack
                    newBag:Destroy()
                else
                    warn("[DropManager] No se encontró la plantilla para dar el objeto: " .. tostring(iName))
                    pickingUp = false
                end
            end
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- Listener del Evento
-- ─────────────────────────────────────────────────────────────
DropItemEvent.OnServerEvent:Connect(function(player, itemName, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then 
        return 
    end
    
    local success, actualAmount = processDrop(player, itemName, amount)
    if success and actualAmount > 0 then
        createPhysicalDrop(player, itemName, actualAmount)
    else
        return
    end
end)