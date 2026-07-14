local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for ScreenGui (replicated from StarterGui to PlayerGui at runtime)
local screenGui = playerGui:WaitForChild("ItemNotificationGui")
local container = screenGui:WaitForChild("NotificationContainer")
local template = container:WaitForChild("ItemNotificationTemplate")

-- Force UI containers to be active at runtime, even if hidden in Roblox Studio edit mode
screenGui.Enabled = true
container.Visible = true

-- Hide template
template.Visible = false

-- Create Sound instance inside the module
local sound = Instance.new("Sound")
sound.Name = "NotificationSound"
sound.SoundId = "rbxassetid://118144738910720" -- Modern digital chime
sound.Volume = 0.4
sound.Parent = script

local function playNotificationSound()
	local soundClone = sound:Clone()
	soundClone.Parent = SoundService
	soundClone:Play()
	soundClone.Ended:Connect(function()
		soundClone:Destroy()
	end)
end

-- Active notifications tracking dictionary
local activeNotifications = {}

local ItemNotification = {}

function ItemNotification.Notify(itemName, quantity)
	playNotificationSound()
	
	local active = activeNotifications[itemName]
	if active then
		-- Item already has an active notification! Increment quantity
		active.quantity = active.quantity + quantity
		active.card.Quantity.Text = "x" .. tostring(active.quantity)
		
		-- High-end Pulse/Flash border animation on update
		local stroke = active.card:FindFirstChild("UIStroke")
		if stroke then
			local flashIn = TweenService:Create(stroke, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = Color3.fromRGB(220, 220, 220),
				Thickness = 1.5
			})
			flashIn:Play()
			task.delay(0.08, function()
				local flashOut = TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Color = Color3.fromRGB(60, 60, 60),
					Thickness = 1
				})
				flashOut:Play()
			end)
		end
		
		-- Reset expiration timer using session counter
		active.session = active.session + 1
		local currentSession = active.session
		
		task.delay(2.0, function()
			if active.session == currentSession then
				activeNotifications[itemName] = nil
				
				local slideOutTime = 0.3
				local slideOutTween = TweenService:Create(active.card, TweenInfo.new(slideOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(1.5, 0, 0, 0)
				})
				slideOutTween:Play()
				slideOutTween.Completed:Wait()
				
				local heightCloseTween = TweenService:Create(active.clone, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.new(1, 0, 0, 0)
				})
				heightCloseTween:Play()
				heightCloseTween.Completed:Wait()
				
				active.clone:Destroy()
			end
		end)
		
		return
	end
	
	-- If it's a new notification:
	local clone = template:Clone()
	clone.Name = "Notification_" .. itemName
	clone.Visible = true
	clone.Size = UDim2.new(1, 0, 0, 0)
	clone.Parent = container
	
	local card = clone:WaitForChild("Card")
	card.Position = UDim2.new(1.5, 0, 0, 0)
	
	card.ItemName.Text = itemName
	card.Quantity.Text = "x" .. tostring(quantity)
	
	local newActive = {
		clone = clone,
		card = card,
		quantity = quantity,
		session = 1
	}
	activeNotifications[itemName] = newActive
	
	local slideInTime = 0.4
	local displayTime = 2.0
	
	local heightTween = TweenService:Create(clone, TweenInfo.new(slideInTime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 0.22, 0)
	})
	
	local slideInTween = TweenService:Create(card, TweenInfo.new(slideInTime + 0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	})
	
	heightTween:Play()
	slideInTween:Play()
	
	local currentSession = 1
	task.delay(displayTime + slideInTime, function()
		if newActive.session == currentSession then
			activeNotifications[itemName] = nil
			
			local slideOutTime = 0.3
			local slideOutTween = TweenService:Create(card, TweenInfo.new(slideOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(1.5, 0, 0, 0)
			})
			slideOutTween:Play()
			slideOutTween.Completed:Wait()
			
			local heightCloseTween = TweenService:Create(clone, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, 0, 0, 0)
			})
			heightCloseTween:Play()
			heightCloseTween.Completed:Wait()
			
			clone:Destroy()
		end
	end)
end

-- Expose as a global function for backward compatibility
_G.NotifyItemObtained = ItemNotification.Notify

return ItemNotification