-- Gerador do mapa. Rodar em modo Edit (execute_luau) — o resultado fica salvo
-- no place. Destroi e recria Workspace.Map, entao e seguro rodar de novo depois
-- de mexer no GameConfig.
--
-- Convencao de altura: cada estagio tem uma plataforma cujo TOPO e a referencia
-- (top). Tudo que fica em cima e posicionado como `top + algo`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Theme = require(ReplicatedStorage.Shared.Theme)

-- Meshes gerados (generate_mesh) vivem como templates em ReplicatedStorage.Assets,
-- criados uma vez fora deste script. Scripts de ferramenta nao tem permissao
-- pra ESCREVER MeshId direto num MeshPart novo (capability NotAccessible) —
-- por isso aqui SEMPRE se clona o template em vez de criar do zero.
local Assets = ReplicatedStorage:WaitForChild("Assets")

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

-- Clona o MeshPart-template (ver Assets acima) em vez de criar um novo e
-- escrever MeshId — essa escrita e bloqueada pra scripts de ferramenta.
local function newMeshPart(templateName: string, props)
	local template = Assets:WaitForChild(templateName)
	local part = template:Clone()
	part.Anchored = true
	-- O template guarda a orientacao de onde foi gerado (nao necessariamente
	-- "de frente"). Zera antes de aplicar props, pra Position nao herdar giro
	-- nenhum — quem quiser girar de proposito passa Orientation em props.
	part.Orientation = Vector3.new(0, 0, 0)
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

-- Pad fino sob um objeto (pedestal/altar/ninho). Mesma linguagem visual dos
-- pads de spawn/vitoria, so que marcando qual SISTEMA aquele objeto pertence
-- (ver Theme.lua) em vez de estado de jogo. SmoothPlastic, nao Neon — Neon em
-- tudo quanto e bloco decorativo deixava a cena "lavada" de brilho.
local function addAccentPad(parent: Instance, center: Vector3, footprint: Vector3, color: Color3)
	local pad = newPart({
		Name = "AccentPad",
		Size = Vector3.new(footprint.X + 1.5, 0.3, footprint.Z + 1.5),
		Position = center + Vector3.new(0, 0.15, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	pad.Parent = parent
end

-- Moldura fina nas bordas de uma plataforma — da a leitura de "arena" sem
-- precisar de mesh nenhum, so 4 tiras finas encostadas na borda. SmoothPlastic
-- de proposito (ver addAccentPad acima): so o essencial continua em Neon.
local function addEdgeTrim(parent: Instance, center: Vector3, size: Vector3, topY: number, color: Color3)
	local t = Theme.TrimThickness
	local halfX, halfZ = size.X / 2, size.Z / 2
	local specs = {
		{ name = "TrimFront", pos = Vector3.new(center.X, topY, center.Z + halfZ - t / 2), sz = Vector3.new(size.X, 0.2, t) },
		{ name = "TrimBack", pos = Vector3.new(center.X, topY, center.Z - halfZ + t / 2), sz = Vector3.new(size.X, 0.2, t) },
		{ name = "TrimLeft", pos = Vector3.new(center.X - halfX + t / 2, topY, center.Z), sz = Vector3.new(t, 0.2, size.Z) },
		{ name = "TrimRight", pos = Vector3.new(center.X + halfX - t / 2, topY, center.Z), sz = Vector3.new(t, 0.2, size.Z) },
	}
	for _, spec in ipairs(specs) do
		local trim = newPart({
			Name = spec.name,
			Size = spec.sz,
			Position = spec.pos,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		trim.Parent = parent
	end
end

-- ---------------------------------------------------------------------------
-- Meshes gerados (generate_mesh). Um mesh por IDENTIDADE, reaproveitado em
-- todo lugar que essa identidade aparece — o Skibidi Toilet e o mesmo mesh no
-- pedestal da loja E no inimigo do Estagio 1, o Tralalero idem no Estagio 2.
-- baseSize e o bounding box que o gerador devolveu; scaledMeshSize usa isso
-- pra escalar mantendo a proporcao, em vez de esticar o mesh fora de forma.
-- ---------------------------------------------------------------------------

local CHARACTER_MESHES = {
	Skibidi = {
		template = "SkibidiMesh",
		baseSize = Vector3.new(3, 3.2599472999572754, 1.849306344985962),
	},
	Tralalero = {
		template = "TralaleroMesh",
		baseSize = Vector3.new(2.9090068340301514, 4.407373428344727, 3),
	},
}

-- Que personagem cada estagio "e", visualmente: o inimigo do Estagio 1 e o
-- Skibidi, o do Estagio 2 e o Tralalero — os mesmos dois personagens
-- compraveis na loja (GameConfig.Characters). Por isso reaproveitam o mesmo
-- mesh em vez de cada lugar ter o seu.
local STAGE_CHARACTER_ID = {
	[1] = "Skibidi",
	[2] = "Tralalero",
}

local PET_EGG_MESH = {
	template = "PetEggMesh",
	baseSize = Vector3.new(2.994830846786499, 4, 2.9738121032714844),
}

-- Terreno decorativo que emoldura o corredor (ver "Ponte + muros" mais
-- abaixo): penhasco em blocos, estilo voxel — igual ao jogo de referencia do
-- usuario, nao montanha lisa. Ver buildBlockyRidge.
local RIDGE = {
	voxel = 6, -- tamanho do "cubo" base — tudo se alinha nesse grid
	colorsLow = { Color3.fromRGB(120, 45, 42), Color3.fromRGB(150, 62, 52) }, -- terra/rocha em duas tonalidades, alternadas por coluna
	grass = Color3.fromRGB(95, 195, 75),
	trunkColor = Color3.fromRGB(110, 75, 45),
	leafColor = Color3.fromRGB(70, 175, 70),
}

local function scaledMeshSize(meshCfg, targetHeight: number): Vector3
	local scale = targetHeight / meshCfg.baseSize.Y
	return meshCfg.baseSize * scale
end

-- O inimigo persegue e machuca (ver EnemyAI), mas continua ancorado e sem
-- colisao: quem o move e o servidor, por CFrame, nao a fisica.
-- CanCollide=false de proposito — quando voce mata, o SEU cliente esconde o
-- boneco, e um jogador nao pode ficar preso dentro de um inimigo invisivel.
local function buildEnemy(stageIndex: number, index: number, position: Vector3, stageCfg)
	local model = Instance.new("Model")
	model.Name = ("Enemy_%d_%d"):format(stageIndex, index)

	local characterId = STAGE_CHARACTER_ID[stageIndex]
	local meshCfg = characterId and CHARACTER_MESHES[characterId]
	assert(meshCfg, ("Estagio %d sem mesh de personagem associado em STAGE_CHARACTER_ID"):format(stageIndex))

	local figureSize = scaledMeshSize(meshCfg, MAP.enemyBodySize.Y + MAP.enemyHeadSize)
	local bodyY = position.Y + figureSize.Y / 2
	local topY = position.Y + figureSize.Y

	local body = newMeshPart(meshCfg.template, {
		Name = "Body",
		Size = figureSize,
		Position = Vector3.new(position.X, bodyY, position.Z),
		CanCollide = false,
	})
	body.Parent = model

	-- Ancora invisivel: EnemyVisuals.lua (cliente) espera um filho chamado
	-- "Head" pra pendurar a nameplate/barra de vida. O visual de verdade
	-- agora e o mesh inteiro em Body — Head so marca "onde fica a placa".
	local head = newPart({
		Name = "Head",
		Size = Vector3.new(0.4, 0.4, 0.4),
		Position = Vector3.new(position.X, topY + 0.3, position.Z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	head.Parent = model

	-- "Eyes" nao sao mais literalmente olhos: agora e um brilho de acento perto
	-- do topo do mesh. O nome fica por compatibilidade — EnemyVisuals espera
	-- ALGUM filho com esse nome logo na criacao, senao trava 5s antes de
	-- desenhar a barra de vida (WaitForChild com timeout).
	local glow = newPart({
		Name = "Eyes",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.5, 0.5, 0.5),
		Position = Vector3.new(position.X, topY - figureSize.Y * 0.16, position.Z),
		Color = Theme.Colors.danger,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	})
	glow.Parent = model

	model.PrimaryPart = body

	local nameplate = Instance.new("BillboardGui")
	nameplate.Name = "Nameplate"
	nameplate.Size = UDim2.fromOffset(140, 38)
	nameplate.StudsOffsetWorldSpace = Vector3.new(0, 0.6, 0)
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
		Color = Theme.Colors.stone:Lerp(stageCfg.enemyColor, 0.55),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
	})
	platform.Parent = stageFolder

	-- Moldura neon com a cor do inimigo do estagio: identidade visual clara
	-- de longe, mesmo antes de ver o boneco.
	addEdgeTrim(stageFolder, origin, MAP.platformSize, top + 0.03, stageCfg.enemyColor)

	-- Ponto de nascimento / retorno deste estagio.
	local spawnPos = Vector3.new(origin.X, top + 3, origin.Z + MAP.spawnOffset.Z)
	local spawnPad = newPart({
		Name = "SpawnPad",
		Size = Vector3.new(14, 1, 14),
		Position = spawnPos - Vector3.new(0, 2.5, 0),
		Color = Theme.Colors.safe,
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

	-- Pad de vitoria: apagado ate voce bater a cota do estagio. A cor real
	-- (cinza -> dourado) e controlada ao vivo por StageController.lua; isto
	-- aqui e so o estado inicial "apagado".
	local winPad = newPart({
		Name = "WinPad",
		Size = Vector3.new(14, 1, 14),
		Position = Vector3.new(origin.X, top + 0.5, origin.Z + MAP.winPadOffset.Z),
		Color = Theme.Colors.stoneDark,
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

	-- Barreira de SAIDA: guarda a entrada do proximo estagio. A cor real
	-- (vermelho -> verde) tambem e controlada ao vivo por StageController.lua.
	local nextStage = GameConfig.Stages[stageIndex + 1]
	if nextStage then
		local barrier = newPart({
			Name = "Barrier",
			Size = MAP.barrierSize,
			Position = Vector3.new(origin.X, top + MAP.barrierOffset.Y, origin.Z + MAP.barrierOffset.Z),
			Color = Theme.Colors.danger,
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
	Color = Theme.Colors.stone,
	Material = Enum.Material.SmoothPlastic,
	CanCollide = true,
})
lobbyPlatform.Parent = lobbyFolder

-- O lobby e o "hub": moldura dourada, a mesma cor da loja de personagens e
-- do altar/ninho — marca ele como o lugar onde os sistemas de progressao
-- vivem, em vez de arena de combate.
addEdgeTrim(lobbyFolder, Vector3.new(0, 0, LOBBY.centerZ), LOBBY.size, lobbyTop + 0.03, Theme.Colors.gold)

local lobbySpawn = GameConfig.GetLobbySpawn()
local lobbyPad = newPart({
	Name = "SpawnPad",
	Size = Vector3.new(12, 1, 12),
	Position = lobbySpawn - Vector3.new(0, 2.5, 0),
	Color = Theme.Colors.safe,
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
		Color = Theme.Colors.stoneDark,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
	})
	pillar.Parent = lobbyFolder
end

local lintel = newPart({
	Name = "GateLintel",
	Size = Vector3.new(LOBBY.size.X, 3, 4),
	Position = Vector3.new(0, lobbyTop + LOBBY.gateHeight + 1.5, lobbyFrontZ),
	Color = Theme.Colors.stoneDark,
	Material = Enum.Material.SmoothPlastic,
	CanCollide = true,
})
lintel.Parent = lobbyFolder

-- Tira por baixo da viga marcando a passagem. Dourada, igual a moldura do
-- lobby — o portao e transicao do hub pra arena, nao perigo em si (quem marca
-- perigo e a barreira vermelha la na frente). SmoothPlastic, nao Neon.
local lintelGlow = newPart({
	Name = "GateGlow",
	Size = Vector3.new(LOBBY.gateWidth, 0.2, 0.6),
	Position = Vector3.new(0, lobbyTop + LOBBY.gateHeight - 0.1, lobbyFrontZ - 1.7),
	Color = Theme.Colors.gold,
	Material = Enum.Material.SmoothPlastic,
	CanCollide = false,
})
lintelGlow.Parent = lobbyFolder

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

	addAccentPad(model, position, SHOP.pedestalSize, Theme.Colors.gold)

	local pedestal = newPart({
		Name = "Pedestal",
		Size = SHOP.pedestalSize,
		Position = position + Vector3.new(0, SHOP.pedestalSize.Y / 2, 0),
		Color = Theme.Colors.stoneDark:Lerp(Theme.Colors.gold, 0.5),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
	})
	pedestal.Parent = model

	local meshCfg = CHARACTER_MESHES[id]
	assert(meshCfg, ("Personagem %s sem mesh associado em CHARACTER_MESHES"):format(id))
	local figureSize = scaledMeshSize(meshCfg, SHOP.figureBodySize.Y + SHOP.figureHeadSize)
	local figureBaseY = position.Y + SHOP.pedestalSize.Y
	local bodyY = figureBaseY + figureSize.Y / 2

	local body = newMeshPart(meshCfg.template, {
		Name = "Body",
		Size = figureSize,
		Position = Vector3.new(position.X, bodyY, position.Z),
		CanCollide = false,
	})
	body.Parent = model

	model.PrimaryPart = pedestal

	local nameplate = Instance.new("BillboardGui")
	nameplate.Name = "Nameplate"
	nameplate.Size = UDim2.fromOffset(160, 30)
	nameplate.StudsOffsetWorldSpace = Vector3.new(0, (figureBaseY - position.Y) + figureSize.Y + 1.2, 0)
	nameplate.AlwaysOnTop = true
	nameplate.MaxDistance = 90
	nameplate.Parent = pedestal

	local label = Instance.new("TextLabel")
	label.Name = "CharacterName"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Theme.Colors.gold
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
-- Altar de renascimento: objeto unico no Lobby (nao um por item, como a
-- loja de personagens), entre o pad de spawn e a loja de personagens.
-- ---------------------------------------------------------------------------

local ALTAR = GameConfig.RebirthAltar

local function buildRebirthAltar(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "RebirthAltar"

	addAccentPad(model, position, ALTAR.baseSize, Theme.Colors.rebirth)

	local base = newPart({
		Name = "Base",
		Size = ALTAR.baseSize,
		Position = position + Vector3.new(0, ALTAR.baseSize.Y / 2, 0),
		Color = Theme.Colors.stoneDark:Lerp(Theme.Colors.rebirth, 0.55),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
	})
	base.Parent = model

	local obeliskY = position.Y + ALTAR.baseSize.Y + ALTAR.obeliskSize.Y / 2
	local obelisk = newPart({
		Name = "Obelisk",
		Size = ALTAR.obeliskSize,
		Position = Vector3.new(position.X, obeliskY, position.Z),
		Color = Theme.Colors.rebirth,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	obelisk.Parent = model

	local light = Instance.new("PointLight")
	light.Color = Theme.Colors.rebirth
	light.Range = 16
	light.Brightness = 1.5
	light.Parent = obelisk

	model.PrimaryPart = base

	local nameplate = Instance.new("BillboardGui")
	nameplate.Name = "Nameplate"
	nameplate.Size = UDim2.fromOffset(220, 30)
	nameplate.StudsOffsetWorldSpace = Vector3.new(0, ALTAR.baseSize.Y + ALTAR.obeliskSize.Y + 2, 0)
	nameplate.AlwaysOnTop = true
	nameplate.MaxDistance = 110
	nameplate.Parent = base

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(230, 210, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = "Altar de Renascimento"
	label.Parent = nameplate

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RebirthPrompt"
	prompt.HoldDuration = ALTAR.promptHoldSeconds
	prompt.MaxActivationDistance = ALTAR.promptMaxActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.ObjectText = "Altar de Renascimento"
	prompt.ActionText = "Interagir"
	prompt.Parent = base

	return model
end

local altarPosition = Vector3.new(0, lobbyTop, LOBBY.centerZ + ALTAR.offsetZ)
buildRebirthAltar(altarPosition).Parent = lobbyFolder

table.insert(created, ("Altar de renascimento: z=%d"):format(altarPosition.Z))

-- ---------------------------------------------------------------------------
-- Ninho de pets: objeto unico no Lobby, fora das colunas da loja de
-- personagens, dentro dos muros. Posse e aleatoria, entao um pedestal por
-- pet ficaria com a maioria vazia/bloqueada.
-- ---------------------------------------------------------------------------

local PETSHOP = GameConfig.PetShop

local function buildPetNest(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "PetShop"

	addAccentPad(model, position, PETSHOP.nestSize, Theme.Colors.pet)

	local nest = newPart({
		Name = "Nest",
		Size = PETSHOP.nestSize,
		Position = position + Vector3.new(0, PETSHOP.nestSize.Y / 2, 0),
		Color = Color3.fromRGB(210, 150, 90), -- ninho de brinquedo, madeira clara e quente
		Material = Enum.Material.Wood,
		CanCollide = true,
	})
	nest.Parent = model

	local eggSize = scaledMeshSize(PET_EGG_MESH, PETSHOP.eggSize.Y)
	local eggY = position.Y + PETSHOP.nestSize.Y + eggSize.Y / 2
	local egg = newMeshPart(PET_EGG_MESH.template, {
		Name = "Egg",
		Size = eggSize,
		Position = Vector3.new(position.X, eggY, position.Z),
		CanCollide = false,
	})
	egg.Parent = model

	local light = Instance.new("PointLight")
	light.Color = Theme.Colors.pet
	light.Range = 12
	light.Brightness = 1.2
	light.Parent = egg

	model.PrimaryPart = nest

	local nameplate = Instance.new("BillboardGui")
	nameplate.Name = "Nameplate"
	nameplate.Size = UDim2.fromOffset(180, 30)
	nameplate.StudsOffsetWorldSpace = Vector3.new(0, PETSHOP.nestSize.Y + eggSize.Y + 1.5, 0)
	nameplate.AlwaysOnTop = true
	nameplate.MaxDistance = 90
	nameplate.Parent = nest

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 240, 210)
	label.TextStrokeTransparency = 0.2
	label.Text = "Ovo de Pet"
	label.Parent = nameplate

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EggPrompt"
	prompt.HoldDuration = PETSHOP.promptHoldSeconds
	prompt.MaxActivationDistance = PETSHOP.promptMaxActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.ObjectText = "Ovo de Pet"
	prompt.ActionText = "Interagir"
	prompt.Parent = nest

	return model
end

local petShopPosition = Vector3.new(PETSHOP.offsetX, lobbyTop, LOBBY.centerZ + PETSHOP.offsetZ)
buildPetNest(petShopPosition).Parent = lobbyFolder

table.insert(created, ("Ninho de pets: x=%d, z=%d"):format(petShopPosition.X, petShopPosition.Z))

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
	Color = Theme.Colors.stoneDark,
	Material = Enum.Material.SmoothPlastic,
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
		Color = Theme.Colors.stoneDark,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
	})
	bridge.Parent = structure
end

-- As paredes retas viraram colisao invisivel: quem faz o corredor "parecer"
-- fechado agora sao as montanhas decorativas logo abaixo. Sem isto o
-- container de colisao teria que reproduzir a silhueta irregular das
-- montanhas — mais simples manter a caixa reta, so que sem mostrar ela.
local wallY = top + MAP.wallHeight / 2
for _, side in ipairs({ -1, 1 }) do
	local wall = newPart({
		Name = if side < 0 then "CollisionWallLeft" else "CollisionWallRight",
		Size = Vector3.new(MAP.wallThickness, MAP.wallHeight, corridorLength),
		Position = Vector3.new(side * (halfWidth + MAP.wallThickness / 2), wallY, corridorCenterZ),
		Transparency = 1,
		CanCollide = true,
	})
	wall.Parent = structure
end

for _, cap in ipairs({ { name = "CollisionWallBack", z = firstZ - MAP.wallThickness / 2 }, { name = "CollisionWallFront", z = lastZ + MAP.wallThickness / 2 } }) do
	local wall = newPart({
		Name = cap.name,
		Size = Vector3.new(MAP.platformSize.X + MAP.wallThickness * 2, MAP.wallHeight, MAP.wallThickness),
		Position = Vector3.new(0, wallY, cap.z),
		Transparency = 1,
		CanCollide = true,
	})
	wall.Parent = structure
end

-- ---------------------------------------------------------------------------
-- Penhasco em blocos: moldura do corredor, estilo voxel (referencia visual
-- que o usuario mandou — blocos vermelho-terrosos empilhados com grama por
-- cima, nao montanha lisa). Cada "coluna" comeca ENCOSTADA no muro de colisao
-- e cresce pra FORA do corredor, entao geometricamente nao tem como invadir
-- o caminho — ao contrario do mesh redondo de antes, que precisava de conta
-- fina de raio pra nao vazar.
--
-- CanCollide=true nos blocos (diferente da versao em mesh): sao solidos por
-- natureza, e colidir de verdade reforça a leitura de "parede", nao so
-- CollisionWall* preexistente.
-- ---------------------------------------------------------------------------

local function buildRidgeColumn(folder, name, innerX, sideSign, z, width)
	local voxel = RIDGE.voxel
	local depth = voxel * (1 + math.random(0, 2)) -- 1x, 2x ou 3x o voxel: face irregular, nao uma parede lisa
	local layers = math.random(3, 11) -- altura em "andares" de voxel
	local bodyHeight = math.max((layers - 1) * voxel, voxel)
	local centerX = innerX + sideSign * (depth / 2)

	local body = newPart({
		Name = name .. "_Body",
		Size = Vector3.new(depth, bodyHeight, width),
		Position = Vector3.new(centerX, bodyHeight / 2, z),
		Color = RIDGE.colorsLow[math.random(1, #RIDGE.colorsLow)],
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
	})
	body.Parent = folder

	local top = newPart({
		Name = name .. "_Top",
		Size = Vector3.new(depth, voxel, width),
		Position = Vector3.new(centerX, bodyHeight + voxel / 2, z),
		Color = RIDGE.grass,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
	})
	top.Parent = folder

	-- Arvore ocasional em cima do bloco: tronco fino + copa em cubo,
	-- bem Minecraft. So nas colunas mais altas, pra nao poluir a silhueta.
	if layers >= 5 and math.random() < 0.3 then
		local trunkHeight = voxel * 0.9
		local trunkY = bodyHeight + voxel + trunkHeight / 2
		local trunk = newPart({
			Name = name .. "_Trunk",
			Size = Vector3.new(voxel * 0.35, trunkHeight, voxel * 0.35),
			Position = Vector3.new(centerX, trunkY, z),
			Color = RIDGE.trunkColor,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		trunk.Parent = folder

		local leaves = newPart({
			Name = name .. "_Leaves",
			Size = Vector3.new(voxel * 1.3, voxel * 1.1, voxel * 1.3),
			Position = Vector3.new(centerX, trunkY + trunkHeight / 2 + voxel * 0.5, z),
			Color = RIDGE.leafColor,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		leaves.Parent = folder
	end
end

local function buildBlockyRidge()
	local rangeFolder = Instance.new("Folder")
	rangeFolder.Name = "Ridge"
	rangeFolder.Parent = structure

	local voxel = RIDGE.voxel
	local startZ = corridorCenterZ - corridorLength / 2 - voxel
	local endZ = corridorCenterZ + corridorLength / 2 + voxel
	local innerX = halfWidth + MAP.wallThickness / 2 -- encosta exatamente no muro de colisao

	local planted = 0
	for _, side in ipairs({ -1, 1 }) do
		local z = startZ
		local index = 0
		while z < endZ do
			buildRidgeColumn(rangeFolder, ("Ridge_%d_%d"):format(side, index), side * innerX, side, z, voxel)
			z += voxel
			index += 1
			planted += 1
		end
	end

	return planted
end

local ridgePlanted = buildBlockyRidge()
table.insert(created, ("Penhasco: %d colunas de blocos ao longo do corredor"):format(ridgePlanted))

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
