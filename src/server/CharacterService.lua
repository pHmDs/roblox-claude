-- Compra e equipamento de personagens, pagos com VITORIAS.
--
-- Comprar GASTA vitorias. Isso nao tranca estagios que voce ja abriu: quem
-- guarda o acesso e data.stage (o maior estagio destravado), nao o saldo de
-- vitorias. Ver StageService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)
local CurrencyService = require(script.Parent.CurrencyService)

local Remotes = ReplicatedStorage.Remotes

local CharacterService = {}

local function owns(data, characterId: string): boolean
	return table.find(data.characters, characterId) ~= nil
end

-- Retorna: sucesso (boolean), motivo (string?)
function CharacterService.Buy(player: Player, characterId: unknown)
	if type(characterId) ~= "string" then
		return false, "id invalido"
	end

	local cfg = GameConfig.Characters[characterId]
	if not cfg then
		return false, "personagem inexistente"
	end

	local data = DataManager.Get(player)
	if not data then
		return false, "dados ainda carregando"
	end

	if owns(data, characterId) then
		return false, "voce ja tem esse personagem"
	end

	if not CurrencyService.TrySpendWins(player, cfg.cost) then
		return false, "vitorias insuficientes"
	end

	table.insert(data.characters, characterId)
	DataManager.PushState(player)
	return true
end

function CharacterService.Equip(player: Player, characterId: unknown)
	if type(characterId) ~= "string" then
		return false, "id invalido"
	end
	if not GameConfig.Characters[characterId] then
		return false, "personagem inexistente"
	end

	local data = DataManager.Get(player)
	if not data then
		return false, "dados ainda carregando"
	end
	if not owns(data, characterId) then
		return false, "voce nao tem esse personagem"
	end

	data.equipped = characterId
	DataManager.PushState(player)
	return true
end

function CharacterService.Init()
	Remotes.BuyCharacter.OnServerInvoke = function(player: Player, characterId: unknown)
		return CharacterService.Buy(player, characterId)
	end
	Remotes.EquipCharacter.OnServerInvoke = function(player: Player, characterId: unknown)
		return CharacterService.Equip(player, characterId)
	end
	print("[CharacterService] pronto.")
end

return CharacterService
