-- Recebe o clique do cliente. O cliente NUNCA manda dano nem alvo — so avisa
-- que clicou. O servidor decide o alvo (mais proximo, no alcance) e o dano
-- (dos upgrades salvos). Nao existe numero vindo do cliente neste caminho.
--
-- Rate limit: balde de tokens. Enche a `maxPerSecond` por segundo ate `burst`.
-- Cada clique gasta 1 token. Sem token, o clique e descartado em silencio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)
local EnemyService = require(script.Parent.EnemyService)

local Remotes = ReplicatedStorage.Remotes

local ClickService = {}

-- [player] = { tokens = n, lastRefill = os.clock(), accepted = n, dropped = n }
local buckets = {}

local function bucketFor(player: Player)
	local bucket = buckets[player]
	if not bucket then
		bucket = {
			tokens = GameConfig.Click.burst,
			lastRefill = os.clock(),
			accepted = 0,
			dropped = 0,
		}
		buckets[player] = bucket
	end
	return bucket
end

-- Quantos tokens o balde teria agora, sem consumir nenhum.
local function peekTokens(bucket, now: number): number
	return math.min(
		GameConfig.Click.burst,
		bucket.tokens + (now - bucket.lastRefill) * GameConfig.Click.maxPerSecond
	)
end

local function takeToken(player: Player): boolean
	local bucket = bucketFor(player)
	local now = os.clock()

	bucket.tokens = peekTokens(bucket, now)
	bucket.lastRefill = now

	if bucket.tokens < 1 then
		bucket.dropped += 1
		return false
	end

	bucket.tokens -= 1
	bucket.accepted += 1
	return true
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Aplica um golpe do jogador no inimigo mais proximo. Usado pelo clique e pelo
-- dano automatico.
local function strike(player: Player, damage: number)
	if damage <= 0 then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local target = EnemyService.FindNearest(player, root.Position, GameConfig.Click.rangeStuds)
	if not target then
		return
	end
	EnemyService.ApplyDamage(player, target, damage)
end

function ClickService.GetStats(player: Player)
	local bucket = bucketFor(player)
	-- peekTokens, e nao bucket.tokens: o campo cru so e atualizado quando um
	-- clique chega, entao ler direto reportaria o balde vazio mesmo depois de
	-- segundos parado.
	return {
		tokens = peekTokens(bucket, os.clock()),
		accepted = bucket.accepted,
		dropped = bucket.dropped,
	}
end

function ClickService.ResetStats(player: Player)
	local bucket = bucketFor(player)
	bucket.accepted = 0
	bucket.dropped = 0
end

function ClickService.Init()
	Remotes.ClickAttack.OnServerEvent:Connect(function(player: Player)
		local data = DataManager.Get(player)
		if not data then
			return -- ainda carregando; ignorar
		end
		if not takeToken(player) then
			return
		end
		strike(player, GameConfig.GetClickDamage(data))
	end)

	-- Dano automatico: uma pancada por segundo, no inimigo mais proximo.
	-- Nao escala com o personagem — o personagem premia o clique ativo.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataManager.Get(player)
				if data then
					local auto = GameConfig.GetAutoDamage(data)
					if auto > 0 then
						strike(player, auto)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)

	print("[ClickService] pronto.")
end

return ClickService
