local Players           = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")
local CombatModule  = require(ServerScriptService.ServerModules.CombatModule)
local RagdollModule = require(ServerScriptService.ServerModules.RagdollModule)

local WALK_ANIM     = "rbxassetid://125824094807485"
local GRAB_ANIM     = "rbxassetid://123765630680972"
local HEADBUTT_ANIM = "rbxassetid://91712443826531"
local BASIC_ATTACK_ANIM = "rbxassetid://90383429571650"

local ATTACK_RANGE    = 5
local GRAB_RANGE      = 9
local CHASE_RANGE     = 120
local DAMAGE_GRAB     = 8
local DAMAGE_HEADBUTT = 30
local DAMAGE_BASIC    = 12
local ATTACK_COOLDOWN = 1.5
local GRAB_COOLDOWN   = 8
local GRAB_CHANCE     = 0.30
local DIRECT_RANGE    = 35

local function setupMahkred(npc)
    if npc:GetAttribute("AI_Initialized") then return end
    npc:SetAttribute("AI_Initialized", true)

    print("MahkredAI: Setup iniciado para NPC:", npc:GetFullName())

    local humanoid = npc:WaitForChild("Humanoid", 10)
    local rootPart = npc:WaitForChild("HumanoidRootPart", 10)
    if not humanoid or not rootPart then
        warn("MahkredAI: Falta Humanoid o HumanoidRootPart en:", npc:GetFullName())
        return
    end

    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

    for _, part in ipairs(npc:GetDescendants()) do
        if part:IsA("BasePart") then
            if part.Name ~= "HumanoidRootPart" then part.CanCollide = false end
            pcall(function() part:SetNetworkOwner(nil) end)
        end
    end

    humanoid.MaxHealth = 150
    humanoid.Health    = 150
    humanoid.WalkSpeed = 16
    humanoid.HipHeight = 0

    local function loadAnim(id, looped, priority)
        local a = Instance.new("Animation")
        a.AnimationId = id
        local t = animator:LoadAnimation(a)
        t.Looped   = looped
        t.Priority = priority
        return t
    end

    local walkTrack     = loadAnim(WALK_ANIM,     true,  Enum.AnimationPriority.Movement)
    local grabTrack     = loadAnim(GRAB_ANIM,     false, Enum.AnimationPriority.Action4)
    local headbuttTrack = loadAnim(HEADBUTT_ANIM, false, Enum.AnimationPriority.Action4)
    local attackTrack   = loadAnim(BASIC_ATTACK_ANIM, false, Enum.AnimationPriority.Action)

    -- Highlight tipo /glow rojo de aviso
    local highlight = Instance.new("Highlight")
    highlight.Name = "GrabWarning"
    highlight.FillTransparency = 1
    highlight.OutlineColor = Color3.fromRGB(255, 30, 30)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = npc
    highlight.Enabled = false

    local path = PathfindingService:CreatePath({ AgentRadius = 3, AgentHeight = 5, AgentCanJump = true })
    local lastPathCompute  = 0
    local lastTargetPos    = Vector3.new()
    local currentWaypoints = {}
    local waypointIndex    = 1

    local function findTarget()
        local best, bestDist = nil, CHASE_RANGE
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr:GetAttribute("IgnoredByNPCs") ~= true then
                local char = plr.Character
                if char and char:FindFirstChild("HumanoidRootPart") and
                   char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                    local d = (rootPart.Position - char.HumanoidRootPart.Position).Magnitude
                    if d < bestDist then bestDist = d; best = char end
                end
            end
        end
        return best
    end

    local function hasLOS(dest)
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = {npc}
        rp.FilterType = Enum.RaycastFilterType.Exclude
        return not workspace:Raycast(rootPart.Position, dest - rootPart.Position, rp)
    end

    local function moveNPC(dest)
        local dist = (rootPart.Position - dest).Magnitude
        if dist < DIRECT_RANGE and hasLOS(dest) then
            currentWaypoints = {}; humanoid:MoveTo(dest)
        else
            local moved = (dest - lastTargetPos).Magnitude
            local elapsed = tick() - lastPathCompute
            if (moved > 10 and elapsed > 1) or elapsed > 3 then
                lastPathCompute = tick(); lastTargetPos = dest
                local ok = pcall(function() path:ComputeAsync(rootPart.Position, dest) end)
                if ok and path.Status == Enum.PathStatus.Success then
                    currentWaypoints = path:GetWaypoints(); waypointIndex = 2
                else
                    humanoid:MoveTo(dest); currentWaypoints = {}
                end
            end
            if currentWaypoints and #currentWaypoints >= waypointIndex then
                local wp = currentWaypoints[waypointIndex]
                humanoid:MoveTo(wp.Position)
                if (rootPart.Position - wp.Position).Magnitude < 4 then
                    waypointIndex += 1
                    if currentWaypoints[waypointIndex] and
                       currentWaypoints[waypointIndex].Action == Enum.PathWaypointAction.Jump then
                        humanoid.Jump = true
                    end
                end
            else
                humanoid:MoveTo(dest)
            end
        end
    end

    humanoid.Running:Connect(function(speed)
        if speed > 0.5 then
            if not walkTrack.IsPlaying then walkTrack:Play(0.2) end
            walkTrack:AdjustSpeed(speed / 16)
        else
            if walkTrack.IsPlaying then walkTrack:Stop(0.2) end
        end
    end)

    local isGrabbing = false
    local lastGrab   = -GRAB_COOLDOWN
    local lastAttack = 0

    local function performGrab(targetChar)
        if isGrabbing then return end
        isGrabbing = true
        lastGrab   = tick()
        npc:SetAttribute("CannotAttack", true)
        humanoid.WalkSpeed = 0

        highlight.Enabled = true
        grabTrack:Play()

        task.wait(1.0)
        highlight.Enabled = false

        if not (npc and npc.Parent and humanoid.Health > 0) then
            isGrabbing = false
            humanoid.WalkSpeed = 16
            npc:SetAttribute("CannotAttack", false)
            return
        end

        local tRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        local tHum  = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
        local dist  = tRoot and (rootPart.Position - tRoot.Position).Magnitude or 999

        local grabWeld = nil

        if dist <= GRAB_RANGE and tRoot and tHum and tHum.Health > 0 then
            local tHumD = tHum
            tHumD:TakeDamage(DAMAGE_GRAB)

            grabWeld = Instance.new("WeldConstraint")
            grabWeld.Name = "MahkredGrabWeld"
            grabWeld.Part0 = rootPart
            grabWeld.Part1 = tRoot
            grabWeld.Parent = rootPart

            tHum.PlatformStand = true

            grabTrack:Stop()
            headbuttTrack:Play()
            task.wait(0.6)

            if tHum and tHum.Health > 0 and tHum.Parent then
                tHum:TakeDamage(DAMAGE_HEADBUTT)
            end

            if grabWeld and grabWeld.Parent then grabWeld:Destroy() end
            tHum.PlatformStand = false

            local isRag = targetChar:FindFirstChild("IsRagdoll")
            if isRag then
                isRag.Value = true
            end

            local impulseDir = (tRoot.Position - rootPart.Position).Unit
            tRoot:ApplyImpulse((impulseDir + Vector3.new(0, 1, 0)).Unit * 60)

            task.delay(2.5, function()
                if isRag and isRag.Parent then
                    isRag.Value = false
                end
            end)

            task.wait(math.max(headbuttTrack.Length - 0.6, 0.4))
        else
            grabTrack:Stop()
            npc:SetAttribute("IsFalling", true)
            humanoid.PlatformStand = true
            rootPart:ApplyImpulse(Vector3.new(math.random(-1,1)*20, -15, math.random(-1,1)*20))
            task.wait(2)
            if npc and npc.Parent then
                humanoid.PlatformStand = false
                npc:SetAttribute("IsFalling", false)
            end
        end

        isGrabbing = false
        humanoid.WalkSpeed = 16
        if npc and npc.Parent then npc:SetAttribute("CannotAttack", false) end
    end

    local function basicAttack(targetChar)
        if npc:GetAttribute("CannotAttack") then return end
        if tick() - lastAttack < ATTACK_COOLDOWN then return end
        lastAttack = tick()

        local grabReady = (tick() - lastGrab) >= GRAB_COOLDOWN
        if grabReady and math.random() < GRAB_CHANCE then
            task.spawn(performGrab, targetChar)
        else
            npc:SetAttribute("CannotAttack", true)
            if attackTrack then
                attackTrack:Play()
            end
            task.delay(0.4, function()
                if npc and npc.Parent and humanoid.Health > 0 then
                    CombatModule.CreateHitbox(npc, ATTACK_RANGE + 2, DAMAGE_BASIC, 1, "Golpe2")
                end
            end)
            task.delay(ATTACK_COOLDOWN, function()
                if npc and npc.Parent then npc:SetAttribute("CannotAttack", false) end
            end)
        end
    end

    humanoid.Died:Connect(function()
        local weld = rootPart:FindFirstChild("MahkredGrabWeld")
        if weld then weld:Destroy() end
        for _, plr in ipairs(Players:GetPlayers()) do
            local char = plr.Character
            if char then
                local isRag = char:FindFirstChild("IsRagdoll")
                if isRag and isRag.Value then isRag.Value = false end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.PlatformStand = false end
            end
        end
        local tag = humanoid:FindFirstChild("creator")
        if tag and tag.Value then
            local killer = tag.Value
            local pve = killer:FindFirstChild("PveKills")
            if pve then pve.Value += 1 end
            pcall(function()
                local LM = require(game.ServerScriptService.ServerModules.LoreModule)
                LM.AddMasteryXP(killer, "Combate", 2)
            end)
        end
        task.delay(5, function() if npc and npc.Parent then npc:Destroy() end end)
    end)

        local isFleeingState = false
    task.spawn(function()
        local waitTime = 0.1
        local lastPrint = 0
        while npc and npc.Parent and humanoid.Health > 0 do
            task.wait(waitTime)
            local tgt = findTarget()
            if tgt then
                local tRoot = tgt:FindFirstChild("HumanoidRootPart")
                if not tRoot then continue end
                local d = (rootPart.Position - tRoot.Position).Magnitude
                if d > 150 then waitTime = 1.0; humanoid:MoveTo(rootPart.Position); continue
                elseif d > 60 then waitTime = 0.3
                else waitTime = 0.1 end

                                                -- DETECCION DE ANTORCHA (Solo si esta equipada como Accesorio en la espalda/cuerpo)
                local hasTorch = false
                for _, child in ipairs(tgt:GetChildren()) do
                    if child.Name == "Antorcha" and child:IsA("Accessory") then
                        hasTorch = true
                        break
                    end
                end
                local inTorchRadius = hasTorch and d < 22

                if inTorchRadius and not isGrabbing then
                    if not isFleeingState then
                        isFleeingState = true
                        lastPathCompute = 0 -- Forzar recalculacion de camino inmediata
                        currentWaypoints = {}
                    end
                    if tick() - lastPrint > 2 then
                        lastPrint = tick()
                        print("MahkredAI: NPC huyendo por antorcha activa de", tgt.Name, "Dist:", d)
                    end
                    local dir = (rootPart.Position - tRoot.Position).Unit
                    local flatDir = Vector3.new(dir.X, 0, dir.Z)
                    if flatDir.Magnitude == 0 then
                        flatDir = Vector3.new(1, 0, 0)
                    else
                        flatDir = flatDir.Unit
                    end
                    local retreatPos = rootPart.Position + flatDir * 18
                    moveNPC(retreatPos)
                else
                    if isFleeingState then
                        isFleeingState = false
                        lastPathCompute = 0 -- Forzar recalculacion de camino inmediata
                        currentWaypoints = {}
                    end
                    if d <= ATTACK_RANGE and not isGrabbing then
                        if not npc:GetAttribute("CannotAttack") and not npc:FindFirstChild("Stun") then
                            basicAttack(tgt)
                        end
                    elseif not isGrabbing then
                        moveNPC(tRoot.Position)
                    end
                end
            else
                waitTime = 1.5
                humanoid:MoveTo(rootPart.Position)
                currentWaypoints = {}
            end
        end
    end)
end

-- Buscar e inicializar robustamente cualquier modelo que contenga "mahkred" en el nombre
local function onDescendantAdded(descendant)
    if descendant:IsA("Model") then
        local nameLower = descendant.Name:lower()
        if string.find(nameLower, "mahkred") then
            task.spawn(setupMahkred, descendant)
        end
    end
end

game.Workspace.DescendantAdded:Connect(onDescendantAdded)

for _, descendant in ipairs(game.Workspace:GetDescendants()) do
    onDescendantAdded(descendant)
end