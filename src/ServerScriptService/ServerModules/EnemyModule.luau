local EnemyModule = {}
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local CombatModule = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatModule"))

function EnemyModule.Setup(npc, config)
	local humanoid = npc:WaitForChild("Humanoid")
	local rootPart = npc:WaitForChild("HumanoidRootPart")
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	-- Network Ownership y Colisiones Internas: CRÍTICO para suavidad
	for _, part in pairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Deshabilitar colisiones internas para evitar "jitter" físico
			if part.Name ~= "HumanoidRootPart" then
				part.CanCollide = false
			end

			-- Establecer el servidor como dueño para evitar tirones por latencia de red
			-- Nota: En un entorno de un solo jugador, ponerlo al jugador es más suave,
			-- pero en multijugador 'nil' (el servidor) es lo más estable.
			if part.CanCollide then
				pcall(function()
					part:SetNetworkOwner(nil)
				end)
			end
		end
	end

	-- Configuración por defecto
	config = config or {}
	local CHASE_RANGE = config.ChaseRange or 100
	local ATTACK_RANGE = config.AttackRange or 4
	local DAMAGE = config.Damage or 15
	local ATTACK_COOLDOWN = config.AttackCooldown or 1.2
	local ATTACK_DELAY = config.AttackDelay or 0.4
	local MAX_HEALTH = config.MaxHealth or 100
	local WALK_SPEED = config.WalkSpeed or 18 -- Aumentado para que sean rápidos
	local DIRECT_CHASE_RANGE = 35 -- Aumentado el rango de persecución directa

	-- Configurar Humanoid
	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	humanoid.WalkSpeed = WALK_SPEED

	-- Fix para "tirones" físicos (HipHeight y CollisionGroups)
	-- Se mantiene en 0 para que sea automático según el Rig
	humanoid.HipHeight = 0

	-- Animaciones
	local walkTrack, attackTrack
	if config.Animations then
		if config.Animations.Walk then
			local anim = Instance.new("Animation")
			anim.AnimationId = config.Animations.Walk
			walkTrack = animator:LoadAnimation(anim)
			walkTrack.Looped = true
			walkTrack.Priority = Enum.AnimationPriority.Movement
		end
		if config.Animations.Attack then
			local anim = Instance.new("Animation")
			anim.AnimationId = config.Animations.Attack
			attackTrack = animator:LoadAnimation(anim)
			attackTrack.Priority = Enum.AnimationPriority.Action
		end
	end

	local target = nil
	local lastAttack = 0
	local lastPathCompute = 0
	local path = PathfindingService:CreatePath({
		AgentRadius = 3,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = false,
		Costs = {
			Water = 20
		}
	})

	local function findNearestPlayer()
		local closestPlayer = nil
		local shortestDistance = CHASE_RANGE

		for _, player in pairs(Players:GetPlayers()) do
			if player:GetAttribute("IgnoredByNPCs") ~= true then
				local character = player.Character
				if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
					local distance = (rootPart.Position - character.HumanoidRootPart.Position).Magnitude
					if distance < shortestDistance then
						shortestDistance = distance
						closestPlayer = character
					end
				end
			end
		end
		return closestPlayer
	end

	local function attack()
		if npc:GetAttribute("CannotAttack") then return end
		if tick() - lastAttack < ATTACK_COOLDOWN then return end
		lastAttack = tick()

		if attackTrack then
			attackTrack:Play()
		end

		task.delay(ATTACK_DELAY, function()
			if npc and npc.Parent and humanoid and humanoid.Health > 0 then
				CombatModule.CreateHitbox(npc, ATTACK_RANGE + 2, DAMAGE, 1, "Golpe2")
			end
		end)
	end

	local function hasLineOfSight(dest)
		local origin = rootPart.Position
		local direction = (dest - origin)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {npc}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local result = workspace:Raycast(origin, direction, raycastParams)
		if result then
			if result.Instance:IsDescendantOf(target) then
				return true
			end
		end
		return false
	end

	local currentWaypoints = {}
	local currentWaypointIndex = 1

	local lastTargetPos = Vector3.new(0,0,0)
	local function moveNPC(destination)
		local distance = (rootPart.Position - destination).Magnitude

		-- Si está en rango de persecución directa y hay visión, ir directo (MUCHO más suave)
		if distance < DIRECT_CHASE_RANGE and hasLineOfSight(destination) then
			currentWaypoints = {} 
			humanoid:MoveTo(destination)
		else
			-- OPTIMIZACIÓN: Solo recalcular si el destino ha cambiado significativamente
			-- o si ha pasado mucho tiempo
			local targetMoved = (destination - lastTargetPos).Magnitude
			local timeSinceLast = tick() - lastPathCompute

			if (targetMoved > 10 and timeSinceLast > 1) or (timeSinceLast > 3) then 
				lastPathCompute = tick()
				lastTargetPos = destination

				local success, err = pcall(function()
					path:ComputeAsync(rootPart.Position, destination)
				end)

				if success and path.Status == Enum.PathStatus.Success then
					currentWaypoints = path:GetWaypoints()
					currentWaypointIndex = 2 
				else
					humanoid:MoveTo(destination)
					currentWaypoints = {}
				end
			end

			-- Seguir waypoints de forma continua
			if currentWaypoints and #currentWaypoints >= currentWaypointIndex then
				local nextPoint = currentWaypoints[currentWaypointIndex]
				humanoid:MoveTo(nextPoint.Position)

				if (rootPart.Position - nextPoint.Position).Magnitude < 4 then
					currentWaypointIndex += 1
					if currentWaypoints[currentWaypointIndex] and currentWaypoints[currentWaypointIndex].Action == Enum.PathWaypointAction.Jump then
						humanoid.Jump = true
					end
				end
			else
				humanoid:MoveTo(destination)
			end
		end
	end

	-- Control de Animación de Caminar (El método más robusto)
	humanoid.Running:Connect(function(speed)
		if walkTrack then
			if speed > 0.5 then
				if not walkTrack.IsPlaying then 
					walkTrack:Play(0.2) 
				end
				walkTrack:AdjustSpeed(speed / 16)
			else
				if walkTrack.IsPlaying then 
					walkTrack:Stop(0.2) 
				end
			end
		end
	end)

	humanoid.Died:Connect(function()
		local creatorTag = humanoid:FindFirstChild("creator")
		if creatorTag and creatorTag.Value then
			local killer = creatorTag.Value
			local pveKills = killer:FindFirstChild("PveKills")
			if pveKills then
				pveKills.Value = pveKills.Value + 1
			end
			
			-- Otorgar experiencia de Combate
			local LoreModule = require(game.ServerScriptService.ServerModules.LoreModule)
			LoreModule.AddMasteryXP(killer, "Combate", 1)
		end
	end)

	-- Bucle principal de la IA (Solo lógica de decisión y ataque)
	local runLoop = true
	task.spawn(function()
		local waitTime = 0.1
		while runLoop and npc and npc.Parent and humanoid.Health > 0 do
			task.wait(waitTime) 

			target = findNearestPlayer()

			if target then
				local targetRoot = target:FindFirstChild("HumanoidRootPart")
				if not targetRoot then continue end

				local distance = (rootPart.Position - targetRoot.Position).Magnitude

				-- OPTIMIZACIÓN AI LoD: Si está lejos, procesar menos veces
				if distance > 150 then
					waitTime = 1.0 -- Procesar cada 1 segundo
					currentWaypoints = {}
					humanoid:MoveTo(rootPart.Position) -- Se queda quieto si está muy lejos
					continue
				elseif distance > 60 then
					waitTime = 0.3 -- Persecución relajada
				else
					waitTime = 0.1 -- Combate activo
				end

				if distance <= ATTACK_RANGE then
					-- Ataque (Solo si no está stuneado)
					local isStunned = npc:GetAttribute("CannotAttack") or npc:FindFirstChild("Stun") ~= nil
					if not isStunned then
						attack()
					end
				else
					-- Persecución suave y continua
					moveNPC(targetRoot.Position)
				end
			else
				-- Idle / No hay jugadores cerca
				waitTime = 1.5 
				humanoid:MoveTo(rootPart.Position)
				currentWaypoints = {}
			end
		end
	end)

	return {
		Stop = function()
			runLoop = false
		end
	}
end

return EnemyModule

