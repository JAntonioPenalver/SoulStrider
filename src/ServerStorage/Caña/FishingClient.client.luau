local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local tool = script.Parent
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local fishingEvent = ReplicatedStorage:WaitForChild("FishingEvent")

local isEquipped = false
local isFishing = false
local isMinigameActive = false
local castAnim = nil
local castAnimTrack = nil
local CAST_ANIM_ID = "rbxassetid://86295377408002"

local gui = player:WaitForChild("PlayerGui"):WaitForChild("FishingGui")
local minigameFrame = gui:WaitForChild("MinigameFrame")
local fishDot = minigameFrame:WaitForChild("FishDot")
local safeZone = minigameFrame:WaitForChild("SafeZone")
local clicksLabel = minigameFrame:WaitForChild("ClicksLabel")

-- Minigame Variables
local dotPos = Vector2.new(150, 150) -- Center of 300x300
local dotVelocity = Vector2.new(0, 0)
local clicksHitted = 0
local lastClickTime = 0
local requiredClicks = 5

local MAX_RADIUS = 150 - 15 -- Radius of frame (150) minus dot radius (15)
local SAFE_RADIUS = 60 -- SafeZone size is 120, so radius 60

local WASD_SPEED = 140 -- Pixels per second
local currentFishSpeed = 80 -- Will vary randomly
local timeUntilDirectionChange = 0
local currentFishDirection = Vector2.new(0,0)

local renderConn

local function sinkInput()
    return Enum.ContextActionResult.Sink
end

local function stopMinigame(won)
    isMinigameActive = false
    gui.Enabled = false
    ContextActionService:UnbindAction("FishingSinkMovement")
    if renderConn then
        renderConn:Disconnect()
        renderConn = nil
    end
    
    if won then
        fishingEvent:FireServer("Caught")
    end
    
    isFishing = false
end

local function startMinigame()
    isMinigameActive = true
    clicksHitted = 0
    clicksLabel.Text = "0 / " .. requiredClicks
    
    dotPos = Vector2.new(150, 150)
    fishDot.Position = UDim2.new(0, dotPos.X - 15, 0, dotPos.Y - 15)
    
    gui.Enabled = true
    timeUntilDirectionChange = 0
    
    ContextActionService:BindAction("FishingSinkMovement", sinkInput, false, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space)
    
    renderConn = RunService.RenderStepped:Connect(function(dt)
        if not isMinigameActive then return end
        
        -- Fish AI (Change direction randomly)
        timeUntilDirectionChange = timeUntilDirectionChange - dt
        if timeUntilDirectionChange <= 0 then
            timeUntilDirectionChange = math.random(2, 6) / 10 -- 0.2 to 0.6 seconds (Very chaotic)
            local angle = math.random() * math.pi * 2
            currentFishDirection = Vector2.new(math.cos(angle), math.sin(angle))
            currentFishSpeed = math.random(90, 180) -- Spikes of speed
        end
        
        -- Apply fish movement
        dotVelocity = currentFishDirection * currentFishSpeed
        
        -- Player Input (WASD)
        local inputVec = Vector2.new(0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then inputVec = inputVec + Vector2.new(0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then inputVec = inputVec + Vector2.new(0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then inputVec = inputVec + Vector2.new(-1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then inputVec = inputVec + Vector2.new(1, 0) end
        
        if inputVec.Magnitude > 0 then
            inputVec = inputVec.Unit
            dotVelocity = dotVelocity + (inputVec * WASD_SPEED)
        end
        
        dotPos = dotPos + (dotVelocity * dt)
        
        -- Distance from center
        local center = Vector2.new(150, 150)
        local distFromCenter = (dotPos - center).Magnitude
        
        -- Check if fish escaped (Lost)
        if distFromCenter > MAX_RADIUS then
            stopMinigame(false) -- Lost
            return
        end
        
        fishDot.Position = UDim2.new(0, dotPos.X - 15, 0, dotPos.Y - 15)
    end)
end

tool.Equipped:Connect(function()
    isEquipped = true
end)

tool.Unequipped:Connect(function()
    isEquipped = false
    isFishing = false
    if isMinigameActive then
        stopMinigame(false)
    end
end)

tool.Activated:Connect(function()
    print("Caña Activated! isFishing:", isFishing, "isMinigameActive:", isMinigameActive)
    if isFishing or isMinigameActive then return end
    
    local target = mouse.Target
    print("Clicked target:", target and target.Name or "nil", target and "Parent: " .. (target.Parent and target.Parent.Name or "nil") or "")
    
    if target and (target.Name == "AguaPescar" or (target.Parent and target.Parent.Name == "AguaPescar")) then
        print("AguaPescar detected! Starting fishing wait...")
        isFishing = true
        
        -- Wait random time for bite
        local waitTime = math.random(2, 5)
        task.delay(waitTime, function()
            print("Fish biting! isEquipped:", isEquipped, "isFishing:", isFishing)
            if isEquipped and isFishing then
                startMinigame()
            end
        end)
    end
end)

-- Click detection for Minigame
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not isMinigameActive then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local center = Vector2.new(150, 150)
        local distFromCenter = (dotPos - center).Magnitude
        
        -- Check if dot is inside the safe zone (radius 60)
        if distFromCenter <= SAFE_RADIUS then
            clicksHitted = clicksHitted + 1
            clicksLabel.Text = clicksHitted .. " / " .. requiredClicks
            
            if clicksHitted >= requiredClicks then
                stopMinigame(true) -- Won
            end
        end
    end
end)
