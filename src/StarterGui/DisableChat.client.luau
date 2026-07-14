local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local function disableChat()
    -- Desactivar Chat Legacy
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
    end)
    
    -- Desactivar TextChatService (Sistema Nuevo)
    pcall(function()
        TextChatService.ChatWindowConfiguration.Enabled = false
        TextChatService.ChatInputBarConfiguration.Enabled = false
    end)
    
    return true
end

-- Ejecutar inmediatamente y al reaparecer
disableChat()
script.Parent.ChildAdded:Connect(disableChat) -- Por si acaso
