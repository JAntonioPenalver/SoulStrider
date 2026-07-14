local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local EnemyModule = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("EnemyModule"))

local goblin = script.Parent.Parent

-- Configuración específica del Goblin
local config = {
	MaxHealth = 150,
	ChaseRange = 100,
	AttackRange = 4,
	Damage = 15,
	AttackCooldown = 1.2,
	AttackDelay = 0.4,
	Animations = {
		Walk = "rbxassetid://120014114953581",
		Attack = "rbxassetid://90383429571650"
	}
}

-- Inicializar IA modular
EnemyModule.Setup(goblin, config)
