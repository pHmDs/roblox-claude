-- Perseguicao e dano por contato. Roda so no servidor: o cliente nunca decide
-- onde um inimigo esta nem quanto ele machuca.
--
-- Por que mover com PivotTo em vez de Humanoid:
-- o corpo do inimigo e COMPARTILHADO entre os jogadores, mas a morte e privada.
-- Se voce matou e seu vizinho nao, o boneco continua no mundo, invisivel so para
-- voce. Com fisica de verdade voce esbarraria nele. Ancorado, sem colisao e
-- movido por CFrame, ele atravessa quem ja o matou e nunca prende ninguem.
--
-- Consequencia aceita: um corpo so persegue um alvo. Se ele esta vivo para dois
-- jogadores, persegue o mais proximo dos dois.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local EnemyService = require(script.Parent.EnemyService)

local EnemyAI = {}

local CFG = GameConfig.Enemy

-- [model] = Player — recalculado a cada aiStepSeconds, nao a cada frame
local targets = {}
-- [model] = { [player] = os.clock() do proximo golpe permitido }
local nextHit = {}
-- [player] = os.clock() ate quando ele nao pode levar dano (acabou de renascer)
local graceUntil = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Humanoid vivo do jogador, ou nil.
local function livingHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return humanoid
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- ---------------------------------------------------------------------------
-- Escolha de alvo
-- ---------------------------------------------------------------------------

-- O jogador mais proximo, entre os que ainda NAO mataram este inimigo, pisando
-- no mesmo estagio que ele. O raio de aggro cobre a plataforma inteira, entao
-- na pratica todos os inimigos do estagio vem atras de voce ao mesmo tempo.
local function pickTarget(model: Model, info): Player?
	local primary = model.PrimaryPart
	if not primary then
		return nil
	end
	local origin = flat(primary.Position)

	local best, bestDistance = nil, CFG.aggroRangeStuds
	for _, player in ipairs(Players:GetPlayers()) do
		if EnemyService.IsAlive(player, model) and livingHumanoid(player) then
			local root = rootOf(player)
			-- O lobby arredonda para o estagio 1 em GetStageAtPosition; sem este
			-- teste os inimigos do estagio 1 tentariam te alcancar la dentro.
			if root and not GameConfig.IsInLobby(root.Position)
				and GameConfig.GetStageAtPosition(root.Position) == info.stageIndex then
				local distance = (flat(root.Position) - origin).Magnitude
				if distance <= bestDistance then
					best, bestDistance = player, distance
				end
			end
		end
	end
	return best
end

local function refreshTargets()
	for model, info in pairs(EnemyService.GetAll()) do
		targets[model] = pickTarget(model, info)
	end
end

-- ---------------------------------------------------------------------------
-- Passo de movimento
-- ---------------------------------------------------------------------------

-- Mantem o ponto dentro da plataforma do estagio, com uma margem para o inimigo
-- nao andar ate a beirada e ficar boiando sobre o vao.
local function clampToPlatform(point: Vector3, stageIndex: number): Vector3
	local origin = GameConfig.GetStageOrigin(stageIndex)
	local halfX = GameConfig.Map.platformSize.X / 2 - CFG.platformMarginStuds
	local halfZ = GameConfig.Map.platformSize.Z / 2 - CFG.platformMarginStuds
	return Vector3.new(
		math.clamp(point.X, origin.X - halfX, origin.X + halfX),
		0,
		math.clamp(point.Z, origin.Z - halfZ, origin.Z + halfZ)
	)
end

local function isInSafeBubble(position: Vector3, stageIndex: number): boolean
	local center = flat(GameConfig.GetStageSpawnPoint(stageIndex))
	return (flat(position) - center).Magnitude < CFG.spawnSafeRadiusStuds
end

-- Empurra o ponto para FORA da bolha segura do spawn. O inimigo persegue voce
-- ate a borda dela e para ali: dentro da bolha voce esta a salvo.
local function pushOutOfSafeBubble(point: Vector3, stageIndex: number, fallback: Vector3): Vector3
	local center = flat(GameConfig.GetStageSpawnPoint(stageIndex))
	local offset = point - center
	local radius = CFG.spawnSafeRadiusStuds
	if offset.Magnitude >= radius then
		return point
	end

	-- Jogador exatamente no centro: aproxima pelo lado de onde o inimigo veio.
	local direction = if offset.Magnitude > 0.01 then offset.Unit else (fallback - center).Unit
	return center + direction * radius
end

-- Para onde este inimigo quer ir. Persegue de qualquer distancia dentro do
-- estagio, mas nunca sai da plataforma nem entra na bolha do spawn.
local function goalFor(info, target: Player?): (Vector3, boolean)
	local home = flat(info.home)

	if not target then
		return home, false
	end
	local root = rootOf(target)
	if not root then
		return home, false
	end

	local goal = clampToPlatform(flat(root.Position), info.stageIndex)
	goal = pushOutOfSafeBubble(goal, info.stageIndex, home)
	return goal, true
end

local function step(model: Model, info, dt: number)
	local primary = model.PrimaryPart
	if not primary then
		return
	end

	local target = targets[model]
	local goal, chasing = goalFor(info, target)

	local position = flat(primary.Position)
	local offset = goal - position
	local distance = offset.Magnitude

	-- Perseguindo: para a uma encostada de distancia, senao fica tremendo em cima
	-- do jogador. Voltando para casa: encosta no ponto exato.
	local stopAt = if chasing then CFG.touchRangeStuds * 0.6 else 0.2
	if distance <= stopAt then
		return
	end

	local direction = offset.Unit
	local speed = info.speed * (if chasing then 1 else CFG.returnSpeedMultiplier)
	local travel = math.min(speed * dt, distance - stopAt)
	local nextPosition = position + direction * travel

	-- A altura nunca muda: o inimigo anda no plano da plataforma onde nasceu.
	local final = Vector3.new(nextPosition.X, info.home.Y, nextPosition.Z)
	model:PivotTo(CFrame.lookAt(final, final + direction))
end

-- ---------------------------------------------------------------------------
-- Dano por contato
-- ---------------------------------------------------------------------------

local function tryHit(model: Model, info, now: number)
	local target = targets[model]
	if not target then
		return
	end
	if now < (graceUntil[target] or 0) then
		return
	end

	local humanoid = livingHumanoid(target)
	local root = rootOf(target)
	local primary = model.PrimaryPart
	if not humanoid or not root or not primary then
		return
	end

	-- Parar na borda da bolha nao basta: encostado nela por dentro, o jogador
	-- ainda estaria ao alcance. Dentro da bolha nao se leva dano, ponto.
	if isInSafeBubble(root.Position, info.stageIndex) then
		return
	end

	if (flat(root.Position) - flat(primary.Position)).Magnitude > CFG.touchRangeStuds then
		return
	end

	local schedule = nextHit[model]
	if not schedule then
		schedule = {}
		nextHit[model] = schedule
	end
	if now < (schedule[target] or 0) then
		return
	end

	schedule[target] = now + CFG.touchCooldownSeconds
	humanoid:TakeDamage(info.damage)
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function EnemyAI.Init()
	local function onCharacterAdded(player: Player)
		-- Renasceu: alguns segundos sem levar dano, e ninguem mais o persegue ate
		-- o proximo refreshTargets.
		graceUntil[player] = os.clock() + GameConfig.Player.respawnGraceSeconds
		for _, schedule in pairs(nextHit) do
			schedule[player] = nil
		end
	end

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacterAdded(player)
		end)
		if player.Character then
			onCharacterAdded(player)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		graceUntil[player] = nil
		for model, chosen in pairs(targets) do
			if chosen == player then
				targets[model] = nil
			end
		end
		for _, schedule in pairs(nextHit) do
			schedule[player] = nil
		end
	end)

	-- Alvo recalculado a cada aiStepSeconds; passo e dano a cada frame. Rastrear
	-- o alvo todo frame nao mudaria nada visivel e custaria uma varredura de
	-- jogadores por inimigo por frame.
	local sinceRetarget = 0
	RunService.Heartbeat:Connect(function(dt: number)
		sinceRetarget += dt
		if sinceRetarget >= CFG.aiStepSeconds then
			sinceRetarget = 0
			refreshTargets()
		end

		local now = os.clock()
		for model, info in pairs(EnemyService.GetAll()) do
			step(model, info, dt)
			tryHit(model, info, now)
		end
	end)

	print("[EnemyAI] pronto.")
end

return EnemyAI
