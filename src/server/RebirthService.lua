-- Renascer: reseta dinheiro/upgrades/estagio por um multiplicador
-- permanente. Vitorias e personagens NAO sao tocados de proposito (ver
-- GameConfig.Rebirth para o motivo da exigencia crescer a cada renascida).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)
local StageService = require(script.Parent.StageService)
local EnemyService = require(script.Parent.EnemyService)

local Remotes = ReplicatedStorage.Remotes

local RebirthService = {}

-- Retorna: sucesso (boolean), motivo (string?)
function RebirthService.Rebirth(player: Player)
	local data = DataManager.Get(player)
	if not data then
		return false, "dados ainda carregando"
	end

	local required = GameConfig.GetRebirthRequirement(data.rebirths)
	if data.wins < required then
		return false, "vitorias insuficientes"
	end

	data.money = 0
	data.upgrades = { clickDamage = 0, autoDamage = 0, moneyMult = 0 }
	data.stage = 1
	data.stageProgress = { ["1"] = 0 }
	data.rebirths += 1

	DataManager.PushState(player)

	StageService.Teleport(player, 1)
	-- Sem isto o jogador voltaria pro estagio 1 com os inimigos ja mortos
	-- (do progresso anterior), sem como progredir de novo.
	for stageIndex = 1, GameConfig.MaxStage do
		EnemyService.RespawnStage(player, stageIndex)
	end

	return true
end

function RebirthService.Init()
	Remotes.Rebirth.OnServerInvoke = function(player: Player)
		return RebirthService.Rebirth(player)
	end
	print("[RebirthService] pronto.")
end

return RebirthService
