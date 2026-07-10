-- Gerador do mapa. Rodar em modo Edit (execute_luau) — o resultado fica salvo
-- no place. Destroi e recria Workspace.Map, entao e seguro rodar de novo depois
-- de mexer no GameConfig.
--
-- Convencao de altura: cada estagio tem uma plataforma cujo TOPO e a referencia
-- (top). Tudo que fica em cima e posicionado como `top + algo`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local MAP = GameConfig.Map

local existing = workspace:FindFirstChild("Map")
if existing then
	existing:Destroy()
end

local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

-- O inimigo persegue e machuca (ver EnemyAI), mas continua ancorado e sem
-- colisao: quem o move e o servidor, por CFrame, nao a fisica.
-- CanCollide=false de proposito — quando voce mata, o SEU cliente esconde o
-- boneco, e um jogador nao pode ficar preso dentro de um inimigo invisivel.
local function buildEnemy(stageIndex: number, index: number, position: Vector3, stageCfg)
	local model = Instance.new("Model")
	model.Name = ("Enemy_%d_%d"):format(stageIndex, index)

	-- A cabeca se apoia no topo do corpo; os olhos, na frente dela. Tudo derivado
	-- do tamanho, para o boneco continuar inteiro se ele encolher de novo.
	local bodySize = MAP.enemyBodySize
	local headSize = MAP.enemyHeadSize
	local headY = bodySize.Y / 2 + headSize / 2

	local body = newPart({
		Name = "Body",
		Size = bodySize,
		Position = position,
		Color = stageCfg.enemyColor,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	body.Parent = model

	local head = newPart({
		Name = "Head",
		Size = Vector3.new(headSize, headSize, headSize),
		Position = position + Vector3.new(0, headY, 0),
		Color = stageCfg.enemyColor,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	head.Parent = model

	local eyes = newPart({
		Name = "Eyes",
		Size = Vector3.new(headSize * 0.72, 0.45, 0.2),
		Position = position + Vector3.new(0, headY + 0.4, -(headSize / 2 + 0.1)),
		Color = Color3.fromRGB(20, 20, 20),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	eyes.Parent = model

	model.PrimaryPart = body

	local nameplate = Instance.new("BillboardGui")
	nameplate.Name = "Nameplate"
	nameplate.Size = UDim2.fromOffset(140, 38)
	nameplate.StudsOffsetWorldSpace = Vector3.new(0, headY - 0.6, 0)
	nameplate.AlwaysOnTop = true
	nameplate.MaxDistance = 90
	nameplate.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "EnemyName"
	label.Size = UDim2.new(1, 0, 0, 14)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	-- TextSize fixo, nao TextScaled: escalado, o nome enche a placa inteira.
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = stageCfg.enemyName
	label.Parent = nameplate

	-- O cliente preenche a barra de vida aqui dentro (a vida e por jogador).
	local barSlot = Instance.new("Frame")
	barSlot.Name = "HealthBarSlot"
	barSlot.Position = UDim2.new(0, 0, 0, 17)
	barSlot.Size = UDim2.new(1, 0, 0, 10)
	barSlot.BackgroundTransparency = 1
	barSlot.Parent = nameplate

	model:SetAttribute("StageIndex", stageIndex)
	model:SetAttribute("MaxHp", stageCfg.enemyHp)
	return model
end

local created = {}

for stageIndex = 1, GameConfig.MaxStage do
	local stageCfg = GameConfig.Stages[stageIndex]
	local origin = GameConfig.GetStageOrigin(stageIndex)
	local top = origin.Y + MAP.platformSize.Y / 2

	local stageFolder = Instance.new("Folder")
	stageFolder.Name = "Stage" .. stageIndex
	stageFolder.Parent = map

	local platform = newPart({
		Name = "Platform",
		Size = MAP.platformSize,
		Position = origin,
		Color = stageCfg.enemyColor:Lerp(Color3.fromRGB(40, 40, 45), 0.7),
		Material = Enum.Material.Slate,
		CanCollide = true,
	})
	platform.Parent = stageFolder

	-- Ponto de nascimento / retorno deste estagio.
	local spawnPos = Vector3.new(origin.X, top + 3, origin.Z + MAP.spawnOffset.Z)
	local spawnPad = newPart({
		Name = "SpawnPad",
		Size = Vector3.new(14, 1, 14),
		Position = spawnPos - Vector3.new(0, 2.5, 0),
		Color = Color3.fromRGB(90, 200, 120),
		Material = Enum.Material.Neon,
		CanCollide = true,
	})
	spawnPad.Parent = stageFolder
	stageFolder:SetAttribute("SpawnPosition", spawnPos)

	-- Inimigos: 3 colunas x 2 fileiras.
	local enemies = Instance.new("Folder")
	enemies.Name = "Enemies"
	enemies.Parent = stageFolder

	local columns = { -MAP.enemySpreadX, 0, MAP.enemySpreadX }
	local rows = { -MAP.enemySpreadZ, MAP.enemySpreadZ }
	local enemyY = top + MAP.enemyBodySize.Y / 2
	local index = 0
	for _, rowZ in ipairs(rows) do
		for _, colX in ipairs(columns) do
			index += 1
			if index > stageCfg.enemyCount then
				break
			end
			local pos = Vector3.new(origin.X + colX, enemyY, origin.Z + rowZ)
			buildEnemy(stageIndex, index, pos, stageCfg).Parent = enemies
		end
	end

	-- Pad de vitoria: apagado ate voce bater a cota do estagio.
	local winPad = newPart({
		Name = "WinPad",
		Size = Vector3.new(14, 1, 14),
		Position = Vector3.new(origin.X, top + 0.5, origin.Z + MAP.winPadOffset.Z),
		Color = Color3.fromRGB(70, 70, 80),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	winPad.Parent = stageFolder

	local padGui = Instance.new("BillboardGui")
	padGui.Name = "PadLabel"
	padGui.Size = UDim2.fromOffset(200, 34)
	padGui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	padGui.AlwaysOnTop = true
	padGui.MaxDistance = 200
	padGui.Parent = winPad

	local padText = Instance.new("TextLabel")
	padText.Name = "Text"
	padText.Size = UDim2.fromScale(1, 1)
	padText.BackgroundTransparency = 1
	padText.Font = Enum.Font.GothamBold
	padText.TextSize = 15
	padText.TextColor3 = Color3.fromRGB(255, 255, 255)
	padText.TextStrokeTransparency = 0.2
	padText.Text = "PAD DE VITORIA"
	padText.Parent = padGui

	-- Barreira de SAIDA: guarda a entrada do proximo estagio.
	local nextStage = GameConfig.Stages[stageIndex + 1]
	if nextStage then
		local barrier = newPart({
			Name = "Barrier",
			Size = MAP.barrierSize,
			Position = Vector3.new(origin.X, top + MAP.barrierOffset.Y, origin.Z + MAP.barrierOffset.Z),
			Color = Color3.fromRGB(220, 60, 60),
			Material = Enum.Material.ForceField,
			CanCollide = true,
			Transparency = 0.5,
		})
		barrier:SetAttribute("UnlocksStage", stageIndex + 1)
		barrier:SetAttribute("WinsRequired", nextStage.winsRequired)
		barrier.Parent = stageFolder

		local barrierGui = Instance.new("BillboardGui")
		barrierGui.Name = "BarrierLabel"
		barrierGui.Size = UDim2.fromOffset(260, 34)
		barrierGui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
		barrierGui.AlwaysOnTop = true
		barrierGui.MaxDistance = 250
		barrierGui.Parent = barrier

		local barrierText = Instance.new("TextLabel")
		barrierText.Name = "Text"
		barrierText.Size = UDim2.fromScale(1, 1)
		barrierText.BackgroundTransparency = 1
		barrierText.Font = Enum.Font.GothamBold
		barrierText.TextSize = 15
		barrierText.TextColor3 = Color3.fromRGB(255, 220, 220)
		barrierText.TextStrokeTransparency = 0.2
		barrierText.Text = ("%s — precisa de %d vitorias"):format(nextStage.displayName, nextStage.winsRequired)
		barrierText.Parent = barrierGui
	end

	table.insert(created, ("Stage%d: plataforma em z=%d, %d inimigos, pad z=%d%s"):format(
		stageIndex,
		origin.Z,
		math.min(stageCfg.enemyCount, 6),
		origin.Z + MAP.winPadOffset.Z,
		nextStage and (", barreira z=" .. (origin.Z + MAP.barrierOffset.Z)) or " (ultimo estagio)"
	))
end

-- ---------------------------------------------------------------------------
-- Lobby: plataforma de chegada atras do estagio 1, com um portao servindo de
-- entrada. O SpawnLocation mora aqui, entao e para ca que se volta ao morrer.
-- ---------------------------------------------------------------------------

local LOBBY = GameConfig.Lobby
local lobbyTop = LOBBY.size.Y / 2
local lobbyFrontZ = GameConfig.GetLobbyFrontZ()

local lobbyFolder = Instance.new("Folder")
lobbyFolder.Name = "Lobby"
lobbyFolder.Parent = map

local lobbyPlatform = newPart({
	Name = "Platform",
	Size = LOBBY.size,
	Position = Vector3.new(0, 0, LOBBY.centerZ),
	Color = Color3.fromRGB(48, 50, 60),
	Material = Enum.Material.Slate,
	CanCollide = true,
})
lobbyPlatform.Parent = lobbyFolder

local lobbySpawn = GameConfig.GetLobbySpawn()
local lobbyPad = newPart({
	Name = "SpawnPad",
	Size = Vector3.new(12, 1, 12),
	Position = lobbySpawn - Vector3.new(0, 2.5, 0),
	Color = Color3.fromRGB(90, 200, 120),
	Material = Enum.Material.Neon,
	CanCollide = true,
})
lobbyPad.Parent = lobbyFolder
lobbyFolder:SetAttribute("SpawnPosition", lobbySpawn)

-- Portao: dois pilares deixando um vao no meio, e uma viga por cima.
local halfGate = LOBBY.gateWidth / 2
local halfLobbyWidth = LOBBY.size.X / 2
local pillarWidth = halfLobbyWidth - halfGate

for _, side in ipairs({ -1, 1 }) do
	local pillar = newPart({
		Name = if side < 0 then "GatePillarLeft" else "GatePillarRight",
		Size = Vector3.new(pillarWidth, LOBBY.gateHeight, 4),
		Position = Vector3.new(side * (halfGate + pillarWidth / 2), lobbyTop + LOBBY.gateHeight / 2, lobbyFrontZ),
		Color = Color3.fromRGB(70, 72, 84),
		Material = Enum.Material.Slate,
		CanCollide = true,
	})
	pillar.Parent = lobbyFolder
end

local lintel = newPart({
	Name = "GateLintel",
	Size = Vector3.new(LOBBY.size.X, 3, 4),
	Position = Vector3.new(0, lobbyTop + LOBBY.gateHeight + 1.5, lobbyFrontZ),
	Color = Color3.fromRGB(85, 88, 102),
	Material = Enum.Material.Slate,
	CanCollide = true,
})
lintel.Parent = lobbyFolder

local gateGui = Instance.new("BillboardGui")
gateGui.Name = "GateLabel"
gateGui.Size = UDim2.fromOffset(200, 30)
gateGui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
gateGui.AlwaysOnTop = true
gateGui.MaxDistance = 160
gateGui.Parent = lintel

local gateText = Instance.new("TextLabel")
gateText.Name = "Text"
gateText.Size = UDim2.fromScale(1, 1)
gateText.BackgroundTransparency = 1
gateText.Font = Enum.Font.GothamBold
gateText.TextSize = 14
gateText.TextColor3 = Color3.fromRGB(230, 230, 240)
gateText.TextStrokeTransparency = 0.3
gateText.Text = "ENTRADA — " .. GameConfig.Stages[1].displayName
gateText.Parent = gateGui

table.insert(created, ("Lobby: plataforma em z=%d, spawn z=%d, portao z=%d")
	:format(LOBBY.centerZ, lobbySpawn.Z, lobbyFrontZ))

-- ---------------------------------------------------------------------------
-- Loja de personagens: um pedestal com boneco-vitrine por personagem
-- compravel, entre o pad de spawn e o portao (ver GameConfig.CharacterShop).
-- ---------------------------------------------------------------------------

local SHOP = GameConfig.CharacterShop

-- Dicionario -> lista ordenada pelo campo `order` (mesmo criterio usado em
-- ShopController.lua; duplicado aqui porque este script roda isolado, sem
-- um modulo utilitario compartilhado).
local function sortedCharacterIds()
	local ids = {}
	for id in pairs(GameConfig.Characters) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return GameConfig.Characters[a].order < GameConfig.Characters[b].order
	end)
	return ids
end

local function buildCharacterStall(id: string, cfg, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Stall_" .. id
	model:SetAttribute("CharacterId", id)

	local pedestal = newPart({
		Name = "Pedestal",
		Size = SHOP.pedestalSize,
		Position = position + Vector3.new(0, SHOP.pedestalSize.Y / 2, 0),
		Color = Color3.fromRGB(90, 90, 100),
		Material = Enum.Material.Marble,
		CanCollide = true,
	})
	pedestal.Parent = model

	local bodySize = SHOP.figureBodySize
	local headSize = SHOP.figureHeadSize
	local figureBaseY = position.Y + SHOP.pedestalSize.Y
	local bodyY = figureBaseY + bodySize.Y / 2
	local headY = figureBaseY + bodySize.Y + headSize / 2

	local body = newPart({
		Name = "Body",
		Size = bodySize,
		Position = Vector3.new(position.X, bodyY, position.Z),
		Color = cfg.color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	body.Parent = model

	local head = newPart({
		Name = "Head",
		Size = Vector3.new(headSize, headSize, headSize),
		Position = Vector3.new(position.X, headY, position.Z),
		Color = cfg.color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	head.Parent = model

	local eyes = newPart({
		Name = "Eyes",
		Size = Vector3.new(headSize * 0.72, 0.4, 0.2),
		Position = Vector3.new(position.X, headY + 0.3, position.Z - (headSize / 2 + 0.1)),
		Color = Color3.fromRGB(20, 20, 20),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	eyes.Parent = model

	model.PrimaryPart = pedestal

	local nameplate = Instance.new("BillboardGui")
	nameplate.Name = "Nameplate"
	nameplate.Size = UDim2.fromOffset(160, 30)
	nameplate.StudsOffsetWorldSpace = Vector3.new(0, headY - position.Y + 1.2, 0)
	nameplate.AlwaysOnTop = true
	nameplate.MaxDistance = 90
	nameplate.Parent = pedestal

	local label = Instance.new("TextLabel")
	label.Name = "CharacterName"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = cfg.displayName
	label.Parent = nameplate

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.HoldDuration = SHOP.promptHoldSeconds
	prompt.MaxActivationDistance = SHOP.promptMaxActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.ObjectText = cfg.displayName
	prompt.ActionText = "Interagir"
	prompt:SetAttribute("CharacterId", id)
	prompt.Parent = pedestal

	return model
end

local shopFolder = Instance.new("Folder")
shopFolder.Name = "CharacterShop"
shopFolder.Parent = lobbyFolder

local stallIds = sortedCharacterIds()
for index, id in ipairs(stallIds) do
	local pairIndex = math.floor((index - 1) / 2)
	local column = if (index - 1) % 2 == 0 then -SHOP.columnOffsetX else SHOP.columnOffsetX
	local stallZ = LOBBY.centerZ + SHOP.rowOffsetZ + pairIndex * SHOP.pairSpacingZ
	local stallPosition = Vector3.new(column, lobbyTop, stallZ)
	buildCharacterStall(id, GameConfig.Characters[id], stallPosition).Parent = shopFolder
end

table.insert(created, ("Loja de personagens: %d pedestais no lobby, z~=%d"):format(#stallIds, LOBBY.centerZ + SHOP.rowOffsetZ))

-- ---------------------------------------------------------------------------
-- Ponte + muros.
--
-- Sem isto o mapa tem um buraco de design: as plataformas ficam a 40 studs uma
-- da outra e o Baseplate de grama se estende por 2048 studs em volta, entao o
-- jogador desce na grama e CONTORNA a barreira a pe. A barreira so significa
-- alguma coisa se o corredor for fechado.
-- ---------------------------------------------------------------------------

local structure = Instance.new("Folder")
structure.Name = "Structure"
structure.Parent = map

local halfLength = MAP.platformSize.Z / 2
-- O corredor comeca no FUNDO DO LOBBY, nao no estagio 1: senao o jogador nasce
-- fora dos muros e contorna o mapa inteiro pela grama.
local firstZ = LOBBY.centerZ - LOBBY.size.Z / 2
local lastZ = GameConfig.GetStageOrigin(GameConfig.MaxStage).Z + halfLength
local corridorLength = lastZ - firstZ
local corridorCenterZ = (firstZ + lastZ) / 2
local top = MAP.platformSize.Y / 2
local halfWidth = MAP.platformSize.X / 2

-- Ponte do lobby ate o estagio 1, passando por baixo do portao.
local lobbyBridge = newPart({
	Name = "BridgeLobby",
	Size = Vector3.new(MAP.platformSize.X, MAP.platformSize.Y, (GameConfig.GetStageOrigin(1).Z - halfLength) - lobbyFrontZ),
	Position = Vector3.new(0, 0, (lobbyFrontZ + (GameConfig.GetStageOrigin(1).Z - halfLength)) / 2),
	Color = Color3.fromRGB(70, 70, 78),
	Material = Enum.Material.Slate,
	CanCollide = true,
})
lobbyBridge.Parent = structure

-- Pontes preenchendo o vao entre plataformas consecutivas.
for stageIndex = 1, GameConfig.MaxStage - 1 do
	local gapStart = GameConfig.GetStageOrigin(stageIndex).Z + halfLength
	local gapEnd = GameConfig.GetStageOrigin(stageIndex + 1).Z - halfLength
	local bridge = newPart({
		Name = "Bridge" .. stageIndex,
		Size = Vector3.new(MAP.platformSize.X, MAP.platformSize.Y, gapEnd - gapStart),
		Position = Vector3.new(0, 0, (gapStart + gapEnd) / 2),
		Color = Color3.fromRGB(70, 70, 78),
		Material = Enum.Material.Slate,
		CanCollide = true,
	})
	bridge.Parent = structure
end

local wallY = top + MAP.wallHeight / 2
for _, side in ipairs({ -1, 1 }) do
	local wall = newPart({
		Name = if side < 0 then "WallLeft" else "WallRight",
		Size = Vector3.new(MAP.wallThickness, MAP.wallHeight, corridorLength),
		Position = Vector3.new(side * (halfWidth + MAP.wallThickness / 2), wallY, corridorCenterZ),
		Color = Color3.fromRGB(55, 55, 62),
		Material = Enum.Material.Slate,
		CanCollide = true,
	})
	wall.Parent = structure
end

for _, cap in ipairs({ { name = "WallBack", z = firstZ - MAP.wallThickness / 2 }, { name = "WallFront", z = lastZ + MAP.wallThickness / 2 } }) do
	local wall = newPart({
		Name = cap.name,
		Size = Vector3.new(MAP.platformSize.X + MAP.wallThickness * 2, MAP.wallHeight, MAP.wallThickness),
		Position = Vector3.new(0, wallY, cap.z),
		Color = Color3.fromRGB(55, 55, 62),
		Material = Enum.Material.Slate,
		CanCollide = true,
	})
	wall.Parent = structure
end

-- O SpawnLocation vive no LOBBY. E ele, e nao codigo de servidor, que faz toda
-- morte devolver o jogador para la.
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if not spawn then
	spawn = Instance.new("SpawnLocation")
	spawn.Parent = workspace
end
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Size = Vector3.new(10, 1, 10)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Position = lobbySpawn - Vector3.new(0, 2.5, 0)

return table.concat(created, "\n")
