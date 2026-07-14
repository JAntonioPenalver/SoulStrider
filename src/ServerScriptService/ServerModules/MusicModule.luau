local MusicModule = {}
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local TARGET_VOLUME = 0.5
local TRANSITION_TIME = 1.2 -- Tiempo de la transición en segundos

local globalSound = SoundService:FindFirstChild("GlobalMusic")
if not globalSound then
    globalSound = Instance.new("Sound")
    globalSound.Name = "GlobalMusic"
    globalSound.Looped = true
    globalSound.Volume = 0
    globalSound.Parent = SoundService
end

function MusicModule.Play(id)
    if not id then return end
    
    local soundId = tostring(id)
    if not string.find(soundId, "rbxassetid://") then
        soundId = "rbxassetid://" .. soundId
    end

    -- Si ya está sonando la misma canción, no hacemos nada
    if globalSound.SoundId == soundId and globalSound.IsPlaying then return end

    task.spawn(function()
        -- 1. Fade Out de la canción actual (si hay alguna)
        if globalSound.IsPlaying then
            local fadeOut = TweenService:Create(globalSound, TweenInfo.new(TRANSITION_TIME/2, Enum.EasingStyle.Linear), {Volume = 0})
            fadeOut:Play()
            fadeOut.Completed:Wait()
        end

        -- 2. Cambiar canción y preparar
        globalSound:Stop()
        globalSound.SoundId = soundId
        globalSound.Volume = 0
        globalSound:Play()

        -- 3. Fade In de la nueva canción
        local fadeIn = TweenService:Create(globalSound, TweenInfo.new(TRANSITION_TIME/2, Enum.EasingStyle.Linear), {Volume = TARGET_VOLUME})
        fadeIn:Play()
    end)
end

function MusicModule.Stop()
    local fadeOut = TweenService:Create(globalSound, TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Linear), {Volume = 0})
    fadeOut:Play()
    fadeOut.Completed:Connect(function()
        globalSound:Stop()
    end)
end

return MusicModule
