-- Compra de upgrades com DINHEIRO.
--
-- O cliente manda so o id do upgrade. O preco vem do GameConfig, calculado a
-- partir do nivel que o SERVIDOR tem salvo — nunca do que o cliente afirma.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)
local CurrencyService = require(script.Parent.CurrencyService)

local Remotes = ReplicatedStorage.Remotes

local UpgradeService = {}

-- Retorna: sucesso (boolean), motivo (string?)
function UpgradeService.Buy(player: Player, upgradeId: unknown)
	if type(upgradeId) ~= "string" then
		return false, "id invalido"
	end

	local cfg = GameConfig.Upgrades[upgradeId]
	if not cfg then
		return false, "upgrade inexistente"
	end

	local data = DataManager.Get(player)
	if not data then
		return false, "dados ainda carregando"
	end

	local level = data.upgrades[upgradeId] or 0
	if level >= cfg.maxLevel then
		return false, "nivel maximo"
	end

	local cost = GameConfig.GetUpgradeCost(upgradeId, level)
	if not CurrencyService.TrySpendMoney(player, cost) then
		return false, "dinheiro insuficiente"
	end

	data.upgrades[upgradeId] = level + 1
	DataManager.PushState(player)
	return true
end

function UpgradeService.Init()
	Remotes.BuyUpgrade.OnServerInvoke = function(player: Player, upgradeId: unknown)
		return UpgradeService.Buy(player, upgradeId)
	end
	print("[UpgradeService] pronto.")
end

return UpgradeService
