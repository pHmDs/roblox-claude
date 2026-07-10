--!strict
-- Todo o balanceamento do jogo vive aqui. Nenhum outro arquivo deve conter
-- numeros de custo, dano, vida ou recompensa.

local GameConfig = {}

-- ---------------------------------------------------------------------------
-- Estagios
-- ---------------------------------------------------------------------------
-- winsRequired e o que a barreira DE ENTRADA deste estagio exige.
--
-- Nao existe "quota" como numero solto: o inimigo morto so renasce quando voce
-- pega a vitoria, entao a cota E o numero de inimigos (ver GameConfig.GetQuota).
-- Um numero separado maior que enemyCount deixaria o estagio impossivel.

GameConfig.Stages = {
	[1] = {
		displayName = "Estagio 1 — Banheiro",
		enemyName = "Skibidi Toilet",
		enemyHp = 20,
		reward = 8,
		enemyColor = Color3.fromRGB(200, 200, 205),
		enemyCount = 3, -- e tambem a cota: limpar o estagio acende o pad
		enemySpeed = 9, -- studs/s. O jogador anda a 16: da para fugir.
		enemyDamage = 8, -- por encostada
		winsRequired = 0,
	},
	[2] = {
		displayName = "Estagio 2 — Mar",
		enemyName = "Tralalero Tralala",
		enemyHp = 400,
		reward = 100,
		enemyColor = Color3.fromRGB(60, 110, 200),
		enemyCount = 6,
		enemySpeed = 13,
		enemyDamage = 20,
		winsRequired = 3,
	},
}

GameConfig.MaxStage = 2

-- ---------------------------------------------------------------------------
-- Upgrades (comprados com DINHEIRO)
-- ---------------------------------------------------------------------------

GameConfig.Upgrades = {
	clickDamage = {
		displayName = "Dano por Clique",
		description = "+2 de dano a cada nivel",
		baseCost = 100,
		growth = 1.35,
		perLevel = 2,
		maxLevel = 50,
		order = 1,
	},
	autoDamage = {
		displayName = "Dano Automatico",
		description = "+2 de dano por segundo, sem clicar",
		baseCost = 2500,
		growth = 1.5,
		perLevel = 2,
		maxLevel = 20,
		order = 2,
	},
	moneyMult = {
		displayName = "Multiplicador de Dinheiro",
		description = "+50% de dinheiro por kill",
		baseCost = 10000,
		growth = 2,
		perLevel = 0.5,
		maxLevel = 5,
		order = 3,
	},
}

-- ---------------------------------------------------------------------------
-- Personagens (comprados com VITORIAS)
-- ---------------------------------------------------------------------------

GameConfig.Characters = {
	Skibidi = {
		displayName = "Skibidi",
		cost = 0,
		multiplier = 1,
		color = Color3.fromRGB(210, 210, 215),
		order = 1,
	},
	Tralalero = {
		displayName = "Tralalero Tralala",
		cost = 5,
		multiplier = 2.5,
		color = Color3.fromRGB(70, 130, 220),
		order = 2,
	},
}

GameConfig.StarterCharacter = "Skibidi"

-- ---------------------------------------------------------------------------
-- Regras do clique e dos inimigos
-- ---------------------------------------------------------------------------

GameConfig.Click = {
	maxPerSecond = 20, -- teto sustentado do rate limit no servidor
	burst = 25, -- quantos cliques o balde acumula (permite rajada curta)
	rangeStuds = 40, -- distancia maxima do personagem ate o inimigo
}

-- O inimigo persegue, encosta e machuca. Morto, fica morto: so renasce quando
-- voce pisa no pad de vitoria daquele estagio.
GameConfig.Enemy = {
	-- Maior que a plataforma inteira: TODOS os inimigos do estagio vem atras de
	-- voce, nao so os da fileira da frente. Quem os segura e a plataforma.
	aggroRangeStuds = 400,
	touchRangeStuds = 5, -- a que distancia a encostada conta como dano
	touchCooldownSeconds = 1, -- intervalo minimo entre duas encostadas NO MESMO jogador
	aiStepSeconds = 0.1, -- de quanto em quanto o servidor recalcula alvo e passo
	-- Bolha em volta do ponto de nascimento do estagio onde o inimigo nao entra.
	-- Sem ela, com todos perseguindo, voce renasce cercado e morre de novo.
	-- A fileira mais proxima nasce a 30 studs do spawn, entao 16 deixa folga.
	spawnSafeRadiusStuds = 16,
	platformMarginStuds = 3, -- o quanto ele para antes da beirada, para nao cair
	returnSpeedMultiplier = 1.4, -- volta para casa um pouco mais rapido do que persegue
}

GameConfig.Player = {
	-- Carencia depois de renascer. O teleporte para o spawn ja tira voce do
	-- alcance, mas se voce correr de volta a carencia evita levar dano no passo 1.
	respawnGraceSeconds = 2,
}

GameConfig.Data = {
	storeName = "PlayerData_v1",
	autosaveSeconds = 120,
}

GameConfig.Stage = {
	barrierCheckSeconds = 2, -- de quanto em quanto o servidor varre posicoes
	winPadCooldownSeconds = 2,
}

-- ---------------------------------------------------------------------------
-- Geometria do mapa (lida pelo gerador do mapa)
-- ---------------------------------------------------------------------------

-- Os numeros aqui sao amarrados uns aos outros. Mexer em platformSize.Z ou em
-- stageSpacing obriga a refazer barrierOffset.Z, que precisa cair no MEIO do vao
-- entre duas plataformas:
--   vao = stageSpacing - platformSize.Z          (160 - 120 = 40)
--   barrierOffset.Z = platformSize.Z/2 + vao/2   (60 + 20 = 80)
-- E spawnOffset.Z e winPadOffset.Z precisam caber dentro de platformSize.Z/2.
GameConfig.Map = {
	stageSpacing = 160, -- distancia em Z entre a origem de um estagio e o proximo
	platformSize = Vector3.new(80, 4, 120),
	spawnOffset = Vector3.new(0, 4, -45), -- onde o jogador nasce/retorna, relativo a origem
	winPadOffset = Vector3.new(0, 0.6, 48),
	barrierOffset = Vector3.new(0, 9, 80),
	barrierSize = Vector3.new(80, 18, 2),
	wallHeight = 18, -- muros laterais: sem eles da para contornar a barreira pela grama
	wallThickness = 2,
	enemySpreadZ = 15, -- as duas fileiras de inimigos, em -15 e +15 relativo a origem
	enemySpreadX = 20, -- as tres colunas, em -20, 0 e +20
	-- Tamanho do boneco. O inimigo nasce com o centro do corpo em
	-- (topo da plataforma + enemyBodySize.Y / 2).
	enemyBodySize = Vector3.new(3, 4.5, 3),
	enemyHeadSize = 2.2,
}

-- ---------------------------------------------------------------------------
-- Lobby: area de chegada, atras do estagio 1. E onde voce renasce ao morrer
-- (o SpawnLocation vive aqui), e nenhum inimigo entra nele.
-- ---------------------------------------------------------------------------

-- A largura precisa acompanhar Map.platformSize.X: os muros do corredor sao
-- construidos a partir dela e passam rente ao lobby.
GameConfig.Lobby = {
	centerZ = -120, -- a plataforma do estagio 1 termina em z = -60
	size = Vector3.new(80, 4, 60), -- frente em z = -90, fundo em z = -150
	spawnOffsetZ = -18, -- onde voce nasce, relativo ao centro do lobby
	gateWidth = 18, -- vao da entrada para o estagio 1
	gateHeight = 12,
}

-- ---------------------------------------------------------------------------
-- Loja de personagens: pedestais fisicos no Lobby, um por personagem
-- compravel. Fica ENTRE o pad de spawn e o portao, fora da faixa central
-- (X perto de 0) por onde se anda do spawn ao portao — ver tools/BuildMap.lua.
-- ---------------------------------------------------------------------------
GameConfig.CharacterShop = {
	rowOffsetZ = 6, -- relativo a Lobby.centerZ; entre o pad (-18) e o portao (+30)
	columnOffsetX = 18, -- afasta os pedestais da faixa central por onde se caminha
	pairSpacingZ = 12, -- distancia em Z entre pares consecutivos, se houver mais personagens
	pedestalSize = Vector3.new(4, 2, 4),
	-- Boneco vitrine: menor que o inimigo (Map.enemyBodySize) de proposito —
	-- aqui e so exposicao, nao precisa intimidar.
	figureBodySize = Vector3.new(2.4, 3.6, 2.4),
	figureHeadSize = 1.8,
	promptHoldSeconds = 1, -- segurar por 1s: rapido, mas evita compra encostando de raspao
	promptMaxActivationDistance = 10, -- precisa chegar perto do pedestal, nao da pra comprar de longe
}

-- ---------------------------------------------------------------------------
-- Renascer: reseta dinheiro/upgrades/estagio por um multiplicador permanente.
-- Vitorias NUNCA se gastam, entao a exigencia cresce a cada renascida —
-- senao, depois da primeira, toda renascida seguinte seria de graca.
-- ---------------------------------------------------------------------------
GameConfig.Rebirth = {
	baseWinsRequired = 25, -- vitorias exigidas pra 1a renascida
	growth = 2, -- cada renascida seguinte exige o dobro da anterior
	bonusPerRebirth = 0.25, -- +25% de poder permanente por renascida
}

-- Altar fisico no Lobby: entre o pad de spawn (-18) e a loja de personagens
-- (+6), um unico objeto (nao um por item, como a loja de personagens).
GameConfig.RebirthAltar = {
	offsetZ = -6, -- relativo a Lobby.centerZ
	baseSize = Vector3.new(8, 1.5, 8),
	obeliskSize = Vector3.new(3, 12, 3), -- coluna alta e fina: identidade visual distinta dos pedestais
	promptHoldSeconds = 1.5, -- reset e mais "serio" que uma compra normal
	promptMaxActivationDistance = 12,
}

-- ---------------------------------------------------------------------------
-- Pets: obtidos abrindo um ovo aleatorio (comprado com dinheiro). So um
-- equipado por vez, igual personagem — sem coleção que empilha bonus.
-- ---------------------------------------------------------------------------
GameConfig.Pets = {
	TungTungSahur = {
		displayName = "Tung Tung Tung Sahur",
		weight = 70, -- comum
		bonusType = "damage",
		bonusMultiplier = 1.10,
		color = Color3.fromRGB(150, 110, 70),
		order = 1,
	},
	LiriliLarila = {
		displayName = "Lirili Larila",
		weight = 25, -- incomum
		bonusType = "money",
		bonusMultiplier = 1.25,
		color = Color3.fromRGB(90, 200, 170),
		order = 2,
	},
	BombardiroCrocodilo = {
		displayName = "Bombardiro Crocodilo",
		weight = 5, -- raro
		bonusType = "damage",
		bonusMultiplier = 1.50,
		color = Color3.fromRGB(60, 140, 60),
		order = 3,
	},
}

GameConfig.PetEgg = {
	cost = 500, -- em dinheiro
	duplicateRefundFraction = 0.5, -- pet repetido devolve metade do custo, nunca e uma acao sem efeito
}

-- Ninho fisico no Lobby, fora das colunas da loja de personagens (+-18),
-- dentro dos muros (+-40). Um unico objeto: a posse e aleatoria, entao um
-- pedestal por pet ficaria com a maioria vazia/bloqueada.
GameConfig.PetShop = {
	offsetX = 30,
	offsetZ = 12, -- relativo a Lobby.centerZ
	nestSize = Vector3.new(6, 1.5, 6),
	eggSize = Vector3.new(3, 4, 3),
	promptHoldSeconds = 1,
	promptMaxActivationDistance = 10,
}

function GameConfig.GetLobbySpawn(): Vector3
	local top = GameConfig.Lobby.size.Y / 2
	return Vector3.new(0, top + 3, GameConfig.Lobby.centerZ + GameConfig.Lobby.spawnOffsetZ)
end

-- Onde a plataforma do lobby termina e comeca a ponte para o estagio 1.
function GameConfig.GetLobbyFrontZ(): number
	return GameConfig.Lobby.centerZ + GameConfig.Lobby.size.Z / 2
end

-- GetStageAtPosition arredonda o lobby para o estagio 1. Quem precisa saber se
-- voce esta de fato no lobby (a IA, o HUD) pergunta aqui.
function GameConfig.IsInLobby(position: Vector3): boolean
	return position.Z <= GameConfig.GetLobbyFrontZ()
end

function GameConfig.GetStageOrigin(stageIndex: number): Vector3
	return Vector3.new(0, 0, (stageIndex - 1) * GameConfig.Map.stageSpacing)
end

-- Centro da bolha segura de um estagio: o ponto onde o jogador nasce/retorna.
function GameConfig.GetStageSpawnPoint(stageIndex: number): Vector3
	return GameConfig.GetStageOrigin(stageIndex) + Vector3.new(0, 0, GameConfig.Map.spawnOffset.Z)
end

-- Em qual estagio esta esta posicao. Note que isto e a posicao FISICA — pode
-- diferir de data.stage, que e o maior estagio ja destravado.
function GameConfig.GetStageAtPosition(position: Vector3): number
	local index = math.round(position.Z / GameConfig.Map.stageSpacing) + 1
	return math.clamp(index, 1, GameConfig.MaxStage)
end

-- ---------------------------------------------------------------------------
-- Formulas
-- ---------------------------------------------------------------------------

-- Quantos inimigos limpar para acender o pad. E o estagio inteiro, sempre:
-- como eles nao renascem sozinhos, nao ha como matar mais do que existe.
function GameConfig.GetQuota(stageIndex: number): number
	local stage = GameConfig.Stages[stageIndex]
	return stage and stage.enemyCount or 0
end

-- Custo do PROXIMO nivel, dado o nivel atual (0 = nunca comprou).
function GameConfig.GetUpgradeCost(upgradeId: string, currentLevel: number): number
	local cfg = GameConfig.Upgrades[upgradeId]
	if not cfg then
		return math.huge
	end
	return math.floor(cfg.baseCost * (cfg.growth ^ currentLevel))
end

function GameConfig.GetCharacterMultiplier(characterId: string?): number
	local cfg = characterId and GameConfig.Characters[characterId]
	return cfg and cfg.multiplier or 1
end

-- Vitorias exigidas para a PROXIMA renascida, dado quantas ja foram feitas.
-- Cresce geometricamente pelo mesmo motivo do custo de upgrade (ver
-- GetUpgradeCost): sem crescer, toda renascida depois da primeira seria de
-- graca, ja que vitoria nunca se gasta.
function GameConfig.GetRebirthRequirement(rebirths: number): number
	return math.floor(GameConfig.Rebirth.baseWinsRequired * (GameConfig.Rebirth.growth ^ rebirths))
end

-- Multiplicador permanente de renascida. Ao contrario do personagem (que so
-- premia o clique ativo), e um bonus de poder geral: entra em clique,
-- automatico e dinheiro por igual.
function GameConfig.GetRebirthMultiplier(data): number
	return 1 + (data.rebirths or 0) * GameConfig.Rebirth.bonusPerRebirth
end

-- Bonus do pet equipado, se o tipo dele bater com `kind` ("damage" ou
-- "money"). Igual a renascida, se aplica de forma ampla (nao so ao clique).
function GameConfig.GetPetMultiplier(data, kind: string): number
	local cfg = data.equippedPet and GameConfig.Pets[data.equippedPet]
	if cfg and cfg.bonusType == kind then
		return cfg.bonusMultiplier
	end
	return 1
end

-- Sorteio ponderado pelos pesos em GameConfig.Pets.
function GameConfig.RollPet(): string
	local total = 0
	for _, cfg in pairs(GameConfig.Pets) do
		total += cfg.weight
	end
	local roll = math.random() * total
	local cursor = 0
	for id, cfg in pairs(GameConfig.Pets) do
		cursor += cfg.weight
		if roll <= cursor then
			return id
		end
	end
	return (next(GameConfig.Pets)) -- guarda-chuva de ponto flutuante
end

-- Dano de um clique = (1 + nivel * 2) * multiplicador do personagem equipado
-- * multiplicador de renascida * bonus de dano do pet equipado.
function GameConfig.GetClickDamage(data): number
	local level = data.upgrades.clickDamage or 0
	local base = 1 + level * GameConfig.Upgrades.clickDamage.perLevel
	return base * GameConfig.GetCharacterMultiplier(data.equipped)
		* GameConfig.GetRebirthMultiplier(data) * GameConfig.GetPetMultiplier(data, "damage")
end

-- Dano automatico por segundo. Nao escala com personagem (de proposito:
-- o personagem premia o clique ativo, nao o AFK) — mas renascida e pet
-- entram, porque sao bonus de poder geral, nao premio de habilidade.
function GameConfig.GetAutoDamage(data): number
	local level = data.upgrades.autoDamage or 0
	return level * GameConfig.Upgrades.autoDamage.perLevel
		* GameConfig.GetRebirthMultiplier(data) * GameConfig.GetPetMultiplier(data, "damage")
end

function GameConfig.GetMoneyMultiplier(data): number
	local level = data.upgrades.moneyMult or 0
	return (1 + level * GameConfig.Upgrades.moneyMult.perLevel)
		* GameConfig.GetRebirthMultiplier(data) * GameConfig.GetPetMultiplier(data, "money")
end

function GameConfig.GetKillReward(stageIndex: number, data): number
	local stage = GameConfig.Stages[stageIndex]
	if not stage then
		return 0
	end
	return math.floor(stage.reward * GameConfig.GetMoneyMultiplier(data))
end

-- ---------------------------------------------------------------------------
-- Dado inicial de um jogador novo. Retorna uma tabela FRESCA a cada chamada —
-- nunca compartilhe a mesma referencia entre jogadores.
-- ---------------------------------------------------------------------------

function GameConfig.DefaultData()
	return {
		money = 0,
		wins = 0,
		stage = 1,
		upgrades = {
			clickDamage = 0,
			autoDamage = 0,
			moneyMult = 0,
		},
		characters = { GameConfig.StarterCharacter },
		equipped = GameConfig.StarterCharacter,
		-- Chaves STRING de proposito: o DataStore rejeita array esparso
		-- (um jogador so no estagio 2 geraria {[2]=5}, que nao serializa).
		stageProgress = { ["1"] = 0 },
		rebirths = 0,
		pets = {},
		equippedPet = nil,
	}
end

-- Nomes dos remotes, para nao escrever string solta em dois lugares.
GameConfig.Remotes = {
	ClickAttack = "ClickAttack",
	StateChanged = "StateChanged",
	EnemyHpChanged = "EnemyHpChanged",
	EnemyDefeated = "EnemyDefeated",
	-- Os inimigos de um estagio voltaram a existir PARA VOCE (pegou a vitoria).
	EnemyRespawned = "EnemyRespawned",
	WinAwarded = "WinAwarded",
	StageChoice = "StageChoice",
	BuyUpgrade = "BuyUpgrade",
	BuyCharacter = "BuyCharacter",
	EquipCharacter = "EquipCharacter",
	Rebirth = "Rebirth",
	OpenPetEgg = "OpenPetEgg",
	EquipPet = "EquipPet",
	-- O cliente puxa o estado inicial. O StateChanged que o servidor dispara no
	-- PlayerAdded pode chegar antes de os controllers conectarem, e se perde.
	GetState = "GetState",
}

return GameConfig
