-- Unico ponto do servidor que soma ou gasta dinheiro e vitorias.
-- Todo gasto passa por TrySpend*, que so debita se houver saldo — assim nao
-- existe caminho de codigo capaz de deixar saldo negativo.

local DataManager = require(script.Parent.DataManager)

local CurrencyService = {}

local function sanitize(amount: number): number
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge then
		return 0
	end
	return math.max(0, math.floor(amount))
end

-- ---------------------------------------------------------------------------
-- Dinheiro
-- ---------------------------------------------------------------------------

function CurrencyService.AddMoney(player: Player, amount: number)
	local data = DataManager.Get(player)
	if not data then
		return
	end
	amount = sanitize(amount)
	if amount == 0 then
		return
	end
	data.money += amount
	DataManager.PushState(player)
end

function CurrencyService.TrySpendMoney(player: Player, amount: number): boolean
	local data = DataManager.Get(player)
	if not data then
		return false
	end
	amount = sanitize(amount)
	if data.money < amount then
		return false
	end
	data.money -= amount
	DataManager.PushState(player)
	return true
end

-- ---------------------------------------------------------------------------
-- Vitorias
-- ---------------------------------------------------------------------------

function CurrencyService.AddWins(player: Player, amount: number)
	local data = DataManager.Get(player)
	if not data then
		return
	end
	amount = sanitize(amount)
	if amount == 0 then
		return
	end
	data.wins += amount
	DataManager.PushState(player)
end

function CurrencyService.TrySpendWins(player: Player, amount: number): boolean
	local data = DataManager.Get(player)
	if not data then
		return false
	end
	amount = sanitize(amount)
	if data.wins < amount then
		return false
	end
	data.wins -= amount
	DataManager.PushState(player)
	return true
end

return CurrencyService
