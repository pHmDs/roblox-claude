-- Bootstrap do servidor. A ordem importa: DataManager primeiro (todo mundo
-- depende dele), EnemyService antes de StageService (que escuta EnemyService.Killed).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local DataManager = require(script.Parent.DataManager)
local CurrencyService = require(script.Parent.CurrencyService)
local EnemyService = require(script.Parent.EnemyService)
local EnemyAI = require(script.Parent.EnemyAI)
local ClickService = require(script.Parent.ClickService)
local UpgradeService = require(script.Parent.UpgradeService)
local CharacterService = require(script.Parent.CharacterService)
local StageService = require(script.Parent.StageService)
local DebugBridge = require(script.Parent.DebugBridge)

DataManager.Init()
EnemyService.Init()
EnemyAI.Init() -- depois de EnemyService: precisa dos inimigos ja registrados
ClickService.Init()
UpgradeService.Init()
CharacterService.Init()
StageService.Init()

-- ---------------------------------------------------------------------------
-- Acoes de teste, so no Studio (DebugBridge nao se instala em producao).
-- ---------------------------------------------------------------------------

DebugBridge.Register("state", function(player: Player)
	return DataManager.Get(player)
end)
DebugBridge.Register("addMoney", function(player: Player, amount: number)
	CurrencyService.AddMoney(player, amount)
	return DataManager.Get(player).money
end)
DebugBridge.Register("spendMoney", function(player: Player, amount: number)
	return CurrencyService.TrySpendMoney(player, amount)
end)
DebugBridge.Register("addWins", function(player: Player, amount: number)
	CurrencyService.AddWins(player, amount)
	return DataManager.Get(player).wins
end)
DebugBridge.Register("spendWins", function(player: Player, amount: number)
	return CurrencyService.TrySpendWins(player, amount)
end)
DebugBridge.Register("setStageProgress", function(player: Player, stage: number, value: number)
	DataManager.SetStageProgress(DataManager.Get(player), stage, value)
	return DataManager.GetStageProgress(DataManager.Get(player), stage)
end)
DebugBridge.Register("setStage", function(player: Player, stage: number)
	DataManager.Get(player).stage = stage
	DataManager.PushState(player)
	return DataManager.Get(player).stage
end)
DebugBridge.Register("save", function(player: Player)
	return DataManager.Save(player)
end)

DebugBridge.Register("enemy", function(player: Player, model: Model)
	return {
		hp = EnemyService.GetHp(player, model),
		maxHp = EnemyService.GetMaxHp(model),
		alive = EnemyService.IsAlive(player, model),
	}
end)
DebugBridge.Register("damage", function(player: Player, model: Model, amount: number)
	local killed, reward, hp = EnemyService.ApplyDamage(player, model, amount)
	return { killed = killed, reward = reward, hp = hp }
end)
DebugBridge.Register("aliveCount", function(player: Player, stage: number)
	return EnemyService.CountAlive(player, stage)
end)
DebugBridge.Register("respawnStage", function(player: Player, stage: number)
	EnemyService.RespawnStage(player, stage)
	return EnemyService.CountAlive(player, stage)
end)
DebugBridge.Register("nearest", function(player: Player, maxDistance: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return "sem personagem"
	end
	local model = EnemyService.FindNearest(player, root.Position, maxDistance)
	return model and model.Name or "nenhum no alcance"
end)

DebugBridge.Register("clickStats", function(player: Player)
	return ClickService.GetStats(player)
end)
DebugBridge.Register("resetClickStats", function(player: Player)
	ClickService.ResetStats(player)
	return true
end)

DebugBridge.Register("buyUpgrade", function(player: Player, upgradeId: string)
	local ok, err = UpgradeService.Buy(player, upgradeId)
	return { ok = ok, err = err }
end)
DebugBridge.Register("buyCharacter", function(player: Player, characterId: string)
	local ok, err = CharacterService.Buy(player, characterId)
	return { ok = ok, err = err }
end)
DebugBridge.Register("equipCharacter", function(player: Player, characterId: string)
	local ok, err = CharacterService.Equip(player, characterId)
	return { ok = ok, err = err }
end)
DebugBridge.Register("clickDamage", function(player: Player)
	return GameConfig.GetClickDamage(DataManager.Get(player))
end)
DebugBridge.Register("position", function(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return "sem personagem"
	end
	return {
		z = root.Position.Z,
		physicalStage = GameConfig.GetStageAtPosition(root.Position),
	}
end)

DebugBridge.Init()

print("[Main] Servidor pronto.")
