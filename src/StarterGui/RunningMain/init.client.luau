local UIS = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local DefaultFOV = 70
 
local lastTime = tick()
local player = game.Players.LocalPlayer
 
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local run = false
local Track1 
local Track2
	
local runs = char:WaitForChild("Running")

local function sinkSpaceAction()
	return Enum.ContextActionResult.Sink
end

-- Strict Stun Client-side enforcement
local playerConns = {}
local function setupCharacter(newChar)
	char = newChar
	hum = char:WaitForChild("Humanoid")
	runs = char:WaitForChild("Running")

	if not hum:GetAttribute("BaseJumpPower") then
		hum:SetAttribute("BaseJumpPower", hum.JumpPower >= 50 and hum.JumpPower or 50)
	end
	if not hum:GetAttribute("BaseJumpHeight") then
		hum:SetAttribute("BaseJumpHeight", hum.JumpHeight > 0 and hum.JumpHeight or 7.2)
	end

	local function onCannotAttackChanged()
		local hasNoJump = char:GetAttribute("NoJump") == true or char:FindFirstChild("NoJump") ~= nil
		if char:GetAttribute("CannotAttack") == true or hasNoJump then
			player:SetAttribute("IsRunning", false)
			run = false
			if Track1 then Track1:Stop() end
			runs.Value = false
			
			hum.JumpPower = 0
			hum.JumpHeight = 0
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			
			-- Desactivar tecla Espacio para evitar saltos del ControlModule
			ContextActionService:BindAction("DisableSpace", sinkSpaceAction, false, Enum.KeyCode.Space)
		else
			local baseJump = hum:GetAttribute("BaseJumpPower") or 50
			if baseJump < 1 then baseJump = 50 end
			hum.JumpPower = baseJump
			
			local baseHeight = hum:GetAttribute("BaseJumpHeight") or 7.2
			hum.JumpHeight = baseHeight
			
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			
			-- Reactivar tecla Espacio
			ContextActionService:UnbindAction("DisableSpace")
		end
	end

	-- Clean up old player/character connections to prevent duplicates
	for _, conn in ipairs(playerConns) do
		conn:Disconnect()
	end
	table.clear(playerConns)

	-- Asegurar que se libere la tecla espacio al reaparecer
	ContextActionService:UnbindAction("DisableSpace")

	table.insert(playerConns, char:GetAttributeChangedSignal("CannotAttack"):Connect(onCannotAttackChanged))
	table.insert(playerConns, char:GetAttributeChangedSignal("NoJump"):Connect(onCannotAttackChanged))
	
	table.insert(playerConns, char.ChildAdded:Connect(function(child)
		if child.Name == "NoJump" then onCannotAttackChanged() end
	end))
	table.insert(playerConns, char.ChildRemoved:Connect(function(child)
		if child.Name == "NoJump" then onCannotAttackChanged() end
	end))

	onCannotAttackChanged()
end

setupCharacter(char)
player.CharacterAdded:Connect(setupCharacter)
UIS.InputBegan:Connect(function(input,gameprocessed)
	if input.KeyCode == Enum.KeyCode.W then
		if char:FindFirstChild("Ragdoll") then return end
		if char:GetAttribute("CannotAttack") == true then return end
		local now = tick()
		local difference = (now - lastTime)
		
		if difference <= 0.5 then
			local player = game.Players.LocalPlayer
			local currentStamina = player:GetAttribute("Stamina")
			if currentStamina ~= nil and currentStamina < 5 then return end
			player:SetAttribute("IsRunning", true)
			
	
			run = true
				
				Track1 = game.Players.LocalPlayer.Character.Humanoid:LoadAnimation(script.Run)
			
			
				
					Track1:Play()
			
			
			
				hum.WalkSpeed = 24.5
				runs.Value = true
				local properties = {FieldOfView = DefaultFOV + 15}
				local Info = TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,0.1)
				local T = game:GetService("TweenService"):Create(game.Workspace.CurrentCamera,Info,properties)
				T:Play()
			
			
				
			
			end
			

		lastTime = tick()
	end
end)
 
UIS.InputEnded:Connect(function(input,gameprocessed)
	if input.KeyCode == Enum.KeyCode.W then
		game.Players.LocalPlayer:SetAttribute("IsRunning", false)
		run = false
	if Track1 then	
			Track1:Stop()
		end	
	
		hum.WalkSpeed = 16
		runs.Value = false
		local properties = {FieldOfView = DefaultFOV}
		local Info = TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,0.1)
		local T = game:GetService("TweenService"):Create(game.Workspace.CurrentCamera,Info,properties)
		T:Play()
 
	end
 
end)

game.Players.LocalPlayer:GetAttributeChangedSignal("IsRunning"):Connect(function()
	if game.Players.LocalPlayer:GetAttribute("IsRunning") == false and run == true then
		run = false
		if Track1 then	
			Track1:Stop()
		end	
		hum.WalkSpeed = 16
		runs.Value = false
		local properties = {FieldOfView = DefaultFOV}
		local Info = TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,0.1)
		local T = game:GetService("TweenService"):Create(game.Workspace.CurrentCamera,Info,properties)
		T:Play()
	end
end)
 