-- Dono unico dos dados do jogador em memoria, e da replicacao deles ao cliente.
-- Nenhum outro modulo le ou escreve o DataStore.
--
-- Regra de seguranca central: se o CARREGAMENTO falhar, o jogador joga com
-- dados padrao mas o SALVAMENTO fica bloqueado. Sem isso, uma falha de rede no
-- login apagaria o progresso real do jogador no logout.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = ReplicatedStorage.Remotes

local DataManager = {}

local LOAD_ATTEMPTS = 4
local SAVE_ATTEMPTS = 4

local store = nil
local storeAvailable = false

-- [player] = { data = {...}, canSave = boolean }
local profiles = {}

local loadedEvent = Instance.new("BindableEvent")
DataManager.PlayerLoaded = loadedEvent.Event

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

-- Preenche campos que o template tem e o dado salvo nao — assim adicionar um
-- upgrade novo no GameConfig nao quebra saves antigos.
local function reconcile(data, template)
	for key, templateValue in pairs(template) do
		if data[key] == nil then
			if type(templateValue) == "table" then
				data[key] = table.clone(templateValue)
			else
				data[key] = templateValue
			end
		elseif type(templateValue) == "table" and type(data[key]) == "table" then
			reconcile(data[key], templateValue)
		end
	end
	return data
end

local function retry(attempts: number, fn)
	local lastErr
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < attempts then
			task.wait(2 ^ attempt) -- backoff: 2s, 4s, 8s
		end
	end
	return false, lastErr
end

-- ---------------------------------------------------------------------------
-- Replicacao
-- ---------------------------------------------------------------------------

-- Snapshot completo do estado. E barato (tabela pequena) e evita bugs sutis de
-- estado parcial no cliente.
function DataManager.GetSnapshot(player: Player)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local data = profile.data
	return {
		money = data.money,
		wins = data.wins,
		stage = data.stage,
		upgrades = table.clone(data.upgrades),
		characters = table.clone(data.characters),
		equipped = data.equipped,
		stageProgress = table.clone(data.stageProgress),
	}
end

function DataManager.PushState(player: Player)
	local snapshot = DataManager.GetSnapshot(player)
	if snapshot then
		Remotes.StateChanged:FireClient(player, snapshot)
	end
end

-- ---------------------------------------------------------------------------
-- Leitura
-- ---------------------------------------------------------------------------

function DataManager.Get(player: Player)
	local profile = profiles[player]
	return profile and profile.data or nil
end

function DataManager.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- stageProgress usa chave string (ver GameConfig.DefaultData).
function DataManager.GetStageProgress(data, stageIndex: number): number
	return data.stageProgress[tostring(stageIndex)] or 0
end

function DataManager.SetStageProgress(data, stageIndex: number, value: number)
	data.stageProgress[tostring(stageIndex)] = value
end

-- ---------------------------------------------------------------------------
-- Carregar / salvar
-- ---------------------------------------------------------------------------

local function loadProfile(player: Player)
	local template = GameConfig.DefaultData()

	if not storeAvailable then
		profiles[player] = { data = template, canSave = false }
		return
	end

	local ok, saved = retry(LOAD_ATTEMPTS, function()
		return store:GetAsync(keyFor(player))
	end)

	if not ok then
		warn(("[DataManager] Falha ao carregar %s: %s — SALVAMENTO BLOQUEADO para este jogador."):format(player.Name, tostring(saved)))
		profiles[player] = { data = template, canSave = false }
		return
	end

	local data = if type(saved) == "table" then reconcile(saved, template) else template
	profiles[player] = { data = data, canSave = true }
end

function DataManager.Save(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	if not profile.canSave then
		return false -- carregamento falhou; nunca sobrescrever
	end
	if not storeAvailable then
		return false
	end

	local data = profile.data
	local ok, err = retry(SAVE_ATTEMPTS, function()
		-- UpdateAsync (e nao SetAsync) para nao pisar em cima de uma escrita
		-- concorrente de outro servidor.
		return store:UpdateAsync(keyFor(player), function()
			return data
		end)
	end)

	if not ok then
		warn(("[DataManager] Falha ao salvar %s: %s"):format(player.Name, tostring(err)))
	end
	return ok
end

local function releaseProfile(player: Player)
	if profiles[player] then
		DataManager.Save(player)
		profiles[player] = nil
	end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function DataManager.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.Data.storeName)
	end)

	if ok then
		store = result
		-- GetDataStore nao falha sem acesso a API; a primeira chamada de rede e
		-- que falha. Fazemos uma leitura sonda para descobrir agora, e nao no
		-- meio do primeiro login.
		local probeOk, probeErr = pcall(function()
			store:GetAsync("__probe")
		end)
		storeAvailable = probeOk
		if not probeOk then
			warn("[DataManager] DataStore indisponivel: " .. tostring(probeErr))
			if RunService:IsStudio() then
				warn("[DataManager] No Studio, ligue Game Settings > Security > Enable Studio Access to API Services para testar a persistencia.")
			end
		end
	else
		storeAvailable = false
		warn("[DataManager] GetDataStore falhou: " .. tostring(result))
	end

	print(("[DataManager] storeAvailable=%s"):format(tostring(storeAvailable)))

	-- O cliente pede o estado quando estiver pronto. Se os dados ainda estiverem
	-- carregando, seguramos a resposta em vez de devolver nil — o cliente nao
	-- tem como saber a diferenca entre "sem dados" e "ainda nao chegou".
	Remotes.GetState.OnServerInvoke = function(player: Player)
		local deadline = os.clock() + 30
		while not profiles[player] and os.clock() < deadline do
			task.wait(0.1)
		end
		return DataManager.GetSnapshot(player)
	end

	local function onPlayerAdded(player: Player)
		loadProfile(player)
		DataManager.PushState(player)
		loadedEvent:Fire(player)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(releaseProfile)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(GameConfig.Data.autosaveSeconds)
			for player in pairs(profiles) do
				task.spawn(DataManager.Save, player)
			end
		end
	end)

	-- Desligamento do servidor: salvar todo mundo antes de morrer.
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				DataManager.Save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataManager
