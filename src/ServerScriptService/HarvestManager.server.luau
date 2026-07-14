local Workspace = game:GetService("Workspace")
local HarvestModule = require(game.ServerScriptService.ServerModules.HarvestModule)

-- Función para inicializar objetos existentes y nuevos
local function initializeHarvestable(inst)
    if inst:IsA("BasePart") then 
        HarvestModule.AttachPromptToTrigo(inst) 
    end
end

-- Esperar un momento a que el mapa cargue inicialmente (evita fallos en el arranque)
task.wait(1)

-- Escanear lo que ya está en el Workspace
for _, inst in ipairs(Workspace:GetDescendants()) do
	initializeHarvestable(inst)
end

-- Escuchar por nuevos objetos (StreamingEnabled o spawns dinámicos)
Workspace.DescendantAdded:Connect(initializeHarvestable)

print("🛡️ HarvestManager: Inicialización completada y monitoreando.")
