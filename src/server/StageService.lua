-- Cota, pad de vitoria, barreiras e destravamento de estagio.
--
-- Duas nocoes distintas de "estagio", e confundi-las gera bug:
--   data.stage       = maior estagio DESTRAVADO (permanente, nunca regride)
--   posicao do player = estagio onde ele esta PISANDO agora
--
-- Comprar personagem gasta vitorias, entao o saldo de vitorias NAO pode ser o
-- que guarda a barreira: voce perderia o acesso ao estagio 2 ao comprar algo.
-- A barreira consulta data.stage. Destravar exige as vitorias, mas nao as gasta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)
local CurrencyService = require(script.Parent.CurrencyService)
local EnemyService = require(script.Parent.EnemyService)

local Remotes = ReplicatedStorage.Remotes

local StageService = {}

-- [player] = os.clock() do ultimo toque no pad
local lastPadTouch = {}

local function spawnPositionOf(stageIndex: number): Vector3
	local stageFolder = workspace.Map:FindFirstChild("Stage" .. stageIndex)
	if stageFolder then
		local attribute = stageFolder:GetAttribute("SpawnPosition")
		if attribute then
			return attribute
		end
	end
	local origin = GameConfig.GetStageOrigin(stageIndex)
	return origin + Vector3.new(0, 7, GameConfig.Map.spawnOffset.Z)
end

function StageService.Teleport(player: Player, stageIndex: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = CFrame.new(spawnPositionOf(stageIndex))
end

-- ---------------------------------------------------------------------------
-- Pad de vitoria
-- ---------------------------------------------------------------------------

local function onPadTouched(player: Player, stageIndex: number)
	local data = DataManager.Get(player)
	if not data then
		return
	end

	local now = os.clock()
	local last = lastPadTouch[player]
	if last and now - last < GameConfig.Stage.winPadCooldownSeconds then
		return
	end

	local progress = DataManager.GetStageProgress(data, stageIndex)
	if progress < GameConfig.GetQuota(stageIndex) then
		return -- pad apagado: a cota e o que impede farmar vitoria andando em cima
	end

	lastPadTouch[player] = now

	DataManager.SetStageProgress(data, stageIndex, 0)
	CurrencyService.AddWins(player, 1)

	-- Zerar o progresso sem devolver os inimigos deixaria o estagio impossivel:
	-- eles so renascem aqui. As duas coisas andam juntas, sempre.
	EnemyService.RespawnStage(player, stageIndex)

	local nextStage = GameConfig.Stages[stageIndex + 1]
	local canAdvance = nextStage ~= nil and data.wins >= nextStage.winsRequired

	Remotes.WinAwarded:FireClient(player, {
		wins = data.wins,
		stage = stageIndex,
		hasNextStage = nextStage ~= nil,
		canAdvance = canAdvance,
		winsRequired = nextStage and nextStage.winsRequired or 0,
	})
end

-- ---------------------------------------------------------------------------
-- Escolha apos a vitoria: voltar ao inicio ou avancar
-- ---------------------------------------------------------------------------

local function onStageChoice(player: Player, choice: unknown)
	local data = DataManager.Get(player)
	if not data then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local currentStage = GameConfig.GetStageAtPosition(root.Position)

	-- "Voltar ao inicio" e o inicio DESTE estagio, nao do jogo: os inimigos daqui
	-- acabaram de renascer no pad, e a ideia e limpar tudo de novo.
	if choice == "back" then
		StageService.Teleport(player, currentStage)
		return
	end

	if choice ~= "forward" then
		return
	end

	local nextIndex = currentStage + 1
	local nextStage = GameConfig.Stages[nextIndex]
	if not nextStage then
		return
	end
	if data.wins < nextStage.winsRequired then
		return -- servidor decide; o botao desabilitado no cliente e so cortesia
	end

	-- Destrava de forma permanente. Gastar vitorias depois nao fecha de novo.
	if nextIndex > data.stage then
		data.stage = nextIndex
		if data.stageProgress[tostring(nextIndex)] == nil then
			DataManager.SetStageProgress(data, nextIndex, 0)
		end
		DataManager.PushState(player)
	end

	StageService.Teleport(player, nextIndex)
end

-- ---------------------------------------------------------------------------
-- Barreiras
-- ---------------------------------------------------------------------------

-- A colisao da barreira e desligada LOCALMENTE pelo cliente quando ele tem o
-- estagio destravado (a colisao do proprio personagem e simulada no cliente).
-- Isto aqui e a rede de seguranca: quem estiver num estagio que nao destravou
-- volta para o inicio, tenha atravessado como for.
local function enforceBarriers()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataManager.Get(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if data and root then
			local physicalStage = GameConfig.GetStageAtPosition(root.Position)
			if physicalStage > data.stage and not GameConfig.IsInLobby(root.Position) then
				StageService.Teleport(player, data.stage)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function StageService.Init()
	-- Cada kill conta para a cota do estagio onde o inimigo vive.
	EnemyService.Killed:Connect(function(player: Player, stageIndex: number)
		local data = DataManager.Get(player)
		if not data then
			return
		end
		local progress = DataManager.GetStageProgress(data, stageIndex)
		if progress >= GameConfig.GetQuota(stageIndex) then
			return -- cota ja batida; espera voce pisar no pad
		end
		DataManager.SetStageProgress(data, stageIndex, progress + 1)
		DataManager.PushState(player)
	end)

	local map = workspace:WaitForChild("Map")
	for stageIndex = 1, GameConfig.MaxStage do
		local stageFolder = map:WaitForChild("Stage" .. stageIndex)

		local pad = stageFolder:FindFirstChild("WinPad")
		if pad then
			pad.Touched:Connect(function(hit: BasePart)
				local character = hit.Parent
				local player = character and Players:GetPlayerFromCharacter(character)
				if player then
					onPadTouched(player, stageIndex)
				end
			end)
		end
	end

	Remotes.StageChoice.OnServerEvent:Connect(onStageChoice)

	-- Nao ha handler de morte aqui: o SpawnLocation vive no lobby, entao toda
	-- morte ja devolve o jogador para la, sem progresso perdido.

	Players.PlayerRemoving:Connect(function(player)
		lastPadTouch[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.Stage.barrierCheckSeconds)
			enforceBarriers()
		end
	end)

	print("[StageService] pronto.")
end

return StageService
