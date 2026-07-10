-- Inimigos com VIDA POR JOGADOR.
--
-- O boneco no mundo e compartilhado e nunca some de verdade. O que e privado e
-- a vida: cada jogador tem o proprio HP em cada inimigo, e o proprio registro de
-- quem ja morreu. Assim ninguem rouba kill de ninguem, e um jogador forte nao
-- deixa os iniciantes sem nada para bater.
--
-- Quando VOCE mata, so o SEU cliente esconde o boneco (evento EnemyDefeated).
-- Para os outros ele continua intacto — e continua perseguindo, porque quem
-- persegue e o corpo compartilhado (ver EnemyAI).
--
-- Morte e PERMANENTE ate voce pegar a vitoria no pad daquele estagio. Nao existe
-- timer de respawn: quem devolve os inimigos e StageService, chamando
-- RespawnStage. Por isso a cota do estagio e o total de inimigos dele.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)
local CurrencyService = require(script.Parent.CurrencyService)

local Remotes = ReplicatedStorage.Remotes

local EnemyService = {}

-- [model] = { stageIndex, maxHp, home = Vector3, speed, damage }
local enemies = {}

-- [player] = { [model] = hp }
local hpByPlayer = {}
-- [player] = { [model] = true } — morto PARA ESTE JOGADOR, ate a proxima vitoria
local deadByPlayer = {}

local killedEvent = Instance.new("BindableEvent")
EnemyService.Killed = killedEvent.Event -- (player, stageIndex, model)

-- ---------------------------------------------------------------------------
-- Estado por jogador
-- ---------------------------------------------------------------------------

local function ensurePlayerTables(player: Player)
	if not hpByPlayer[player] then
		hpByPlayer[player] = {}
		deadByPlayer[player] = {}
	end
end

function EnemyService.IsAlive(player: Player, model: Model): boolean
	local dead = deadByPlayer[player]
	return not (dead and dead[model])
end

-- Vida atual do jogador contra este inimigo. Zero se ja morreu para ele.
function EnemyService.GetHp(player: Player, model: Model): number
	local info = enemies[model]
	if not info then
		return 0
	end
	ensurePlayerTables(player)

	if not EnemyService.IsAlive(player, model) then
		return 0
	end

	local hp = hpByPlayer[player][model]
	if hp == nil then
		hp = info.maxHp
		hpByPlayer[player][model] = hp
	end
	return hp
end

function EnemyService.GetMaxHp(model: Model): number
	local info = enemies[model]
	return info and info.maxHp or 0
end

-- Dados que a IA precisa: onde nasceu, quao rapido anda, quanto machuca.
function EnemyService.GetInfo(model: Model)
	return enemies[model]
end

-- ---------------------------------------------------------------------------
-- Dano
-- ---------------------------------------------------------------------------

-- Retorna: killed (boolean), reward (number), hpRestante (number)
function EnemyService.ApplyDamage(player: Player, model: Model, damage: number)
	local info = enemies[model]
	if not info then
		return false, 0, 0
	end
	local data = DataManager.Get(player)
	if not data then
		return false, 0, 0
	end
	if not EnemyService.IsAlive(player, model) then
		return false, 0, 0
	end

	damage = math.max(0, math.floor(damage))
	if damage <= 0 then
		return false, 0, EnemyService.GetHp(player, model)
	end

	local hp = EnemyService.GetHp(player, model) - damage

	if hp > 0 then
		hpByPlayer[player][model] = hp
		Remotes.EnemyHpChanged:FireClient(player, model, hp, info.maxHp)
		return false, 0, hp
	end

	-- Morreu (para este jogador). Fica morto ate a vitoria.
	hpByPlayer[player][model] = 0
	deadByPlayer[player][model] = true

	local reward = GameConfig.GetKillReward(info.stageIndex, data)
	CurrencyService.AddMoney(player, reward)

	Remotes.EnemyDefeated:FireClient(player, model, reward)
	killedEvent:Fire(player, info.stageIndex, model)

	return true, reward, 0
end

-- ---------------------------------------------------------------------------
-- Respawn (so pela vitoria)
-- ---------------------------------------------------------------------------

-- Devolve todos os inimigos de um estagio a este jogador, cheios de vida, e
-- manda cada um de volta para o ponto onde nasceu.
function EnemyService.RespawnStage(player: Player, stageIndex: number)
	ensurePlayerTables(player)

	for model, info in pairs(enemies) do
		if info.stageIndex == stageIndex then
			deadByPlayer[player][model] = nil
			hpByPlayer[player][model] = info.maxHp
		end
	end

	Remotes.EnemyRespawned:FireClient(player, stageIndex)
end

-- Quantos inimigos deste estagio ainda estao de pe para este jogador.
function EnemyService.CountAlive(player: Player, stageIndex: number): number
	local count = 0
	for model, info in pairs(enemies) do
		if info.stageIndex == stageIndex and EnemyService.IsAlive(player, model) then
			count += 1
		end
	end
	return count
end

-- ---------------------------------------------------------------------------
-- Busca
-- ---------------------------------------------------------------------------

-- Inimigo vivo mais proximo do jogador, dentro do alcance, num estagio que ele
-- ja destravou. O filtro de estagio e defesa em profundidade: a distancia ja
-- separa os estagios, mas nao queremos depender disso.
function EnemyService.FindNearest(player: Player, position: Vector3, maxDistance: number): Model?
	local data = DataManager.Get(player)
	if not data then
		return nil
	end

	local best, bestDistance = nil, maxDistance
	for model, info in pairs(enemies) do
		if info.stageIndex <= data.stage and EnemyService.IsAlive(player, model) then
			local primary = model.PrimaryPart
			if primary then
				local distance = (primary.Position - position).Magnitude
				if distance <= bestDistance then
					best, bestDistance = model, distance
				end
			end
		end
	end
	return best
end

function EnemyService.GetAll()
	return enemies
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function EnemyService.Init()
	local map = workspace:WaitForChild("Map")
	local count = 0

	for stageIndex = 1, GameConfig.MaxStage do
		local stageCfg = GameConfig.Stages[stageIndex]
		local stageFolder = map:FindFirstChild("Stage" .. stageIndex)
		if stageFolder then
			local folder = stageFolder:FindFirstChild("Enemies")
			if folder then
				for _, model in ipairs(folder:GetChildren()) do
					if model:IsA("Model") and model.PrimaryPart then
						enemies[model] = {
							stageIndex = stageIndex,
							maxHp = model:GetAttribute("MaxHp") or stageCfg.enemyHp,
							-- Lido uma vez, no boot. A IA move o boneco, entao depois
							-- daqui a posicao atual nao serve mais como referencia.
							home = model.PrimaryPart.Position,
							speed = stageCfg.enemySpeed,
							damage = stageCfg.enemyDamage,
						}
						count += 1
					end
				end
			end
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		hpByPlayer[player] = nil
		deadByPlayer[player] = nil
	end)

	print(("[EnemyService] %d inimigos registrados."):format(count))
end

return EnemyService
