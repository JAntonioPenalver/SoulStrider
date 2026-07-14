local WeatherModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Move Nieve to ReplicatedStorage at startup so it can be cloned by clients
local template = Workspace:FindFirstChild("Nieve")
if template then
    template.Parent = ReplicatedStorage
end

function WeatherModule.SetWeather(weatherType)
    local WeatherSoundEvent = ReplicatedStorage:WaitForChild("WeatherSoundEvent")
    
    workspace:SetAttribute("WeatherType", weatherType)
    
    if weatherType == "rain" then
        workspace:SetAttribute("WeatherActive", true)
        WeatherSoundEvent:FireAllClients("rain")
    elseif weatherType == "nieve" then
        workspace:SetAttribute("WeatherActive", true)
        WeatherSoundEvent:FireAllClients("nieve")
    elseif weatherType == "niebla" then
        workspace:SetAttribute("WeatherActive", true)
        WeatherSoundEvent:FireAllClients("niebla")
    elseif weatherType == "clear" then
        workspace:SetAttribute("WeatherActive", false)
        WeatherSoundEvent:FireAllClients("clear")
    end
end

return WeatherModule
