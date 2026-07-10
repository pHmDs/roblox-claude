-- Pets: obtidos abrindo um ovo aleatorio (dinheiro), equipados um por vez.
--
-- Todo botao so PEDE. Quem decide preco, saldo, sorteio e posse e o
-- servidor — mesmo principio de CharacterService/UpgradeService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)
local CurrencyService = require(script.Parent.CurrencyService)

local Remotes = ReplicatedStorage.Remotes

local PetService = {}

local function owns(data, petId: string): boolean
	return table.find(data.pets, petId) ~= nil
end

-- Retorna: sucesso (boolean), petId ou motivo (string), foiDuplicata (boolean?)
function PetService.OpenEgg(player: Player)
	local data = DataManager.Get(player)
	if not data then
		return false, "dados ainda carregando"
	end

	if not CurrencyService.TrySpendMoney(player, GameConfig.PetEgg.cost) then
		return false, "dinheiro insuficiente"
	end

	local petId = GameConfig.RollPet()
	local wasDuplicate = owns(data, petId)

	if wasDuplicate then
		-- Pet repetido nunca e uma acao sem efeito: devolve parte do custo.
		local refund = math.floor(GameConfig.PetEgg.cost * GameConfig.PetEgg.duplicateRefundFraction)
		CurrencyService.AddMoney(player, refund)
	else
		table.insert(data.pets, petId)
		DataManager.PushState(player)
	end

	return true, petId, wasDuplicate
end

-- Retorna: sucesso (boolean), motivo (string?)
function PetService.Equip(player: Player, petId: unknown)
	if type(petId) ~= "string" then
		return false, "id invalido"
	end
	if not GameConfig.Pets[petId] then
		return false, "pet inexistente"
	end

	local data = DataManager.Get(player)
	if not data then
		return false, "dados ainda carregando"
	end
	if not owns(data, petId) then
		return false, "voce nao tem esse pet"
	end

	data.equippedPet = petId
	DataManager.PushState(player)
	return true
end

function PetService.Init()
	Remotes.OpenPetEgg.OnServerInvoke = function(player: Player)
		return PetService.OpenEgg(player)
	end
	Remotes.EquipPet.OnServerInvoke = function(player: Player, petId: unknown)
		return PetService.Equip(player, petId)
	end
	print("[PetService] pronto.")
end

return PetService
