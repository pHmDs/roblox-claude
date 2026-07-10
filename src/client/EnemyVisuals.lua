-- Tudo que voce ve num inimigo e LOCAL: a barra de vida mostra a SUA vida
-- contra ele, e o sumico na morte acontece so na sua tela. O boneco no mundo
-- nunca muda — para os outros jogadores ele continua intacto, e continua se
-- movendo (o servidor e quem anda com ele).
--
-- Quem voce matou fica escondido ate a vitoria: quem devolve os inimigos e o
-- servidor, pelo evento EnemyRespawned. Nao existe timer aqui.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

local EnemyVisuals = {}

-- [model] = { hp, maxHp, fill, text, parts = { [part] = transparenciaOriginal } }
local tracked = {}

local function buildBar(model: Model)
	local head = model:FindFirstChild("Head")
	local nameplate = head and head:FindFirstChild("Nameplate")
	local slot = nameplate and nameplate:FindFirstChild("HealthBarSlot")
	if not slot then
		return nil
	end

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	back.BorderSizePixel = 0
	back.Parent = slot

	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 4)
	backCorner.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 210, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 10 -- a placa encolheu; 12 estourava a barra
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0.4
	text.Parent = back

	return { back = back, fill = fill, text = text }
end

local function updateBar(entry)
	local ratio = if entry.maxHp > 0 then entry.hp / entry.maxHp else 0
	ratio = math.clamp(ratio, 0, 1)
	entry.bar.fill.Size = UDim2.fromScale(ratio, 1)
	entry.bar.fill.BackgroundColor3 = Color3.fromRGB(210, 70, 70):Lerp(Color3.fromRGB(90, 210, 110), ratio)
	entry.bar.text.Text = ("%d / %d"):format(entry.hp, entry.maxHp)
end

-- Numero voando: nasce na cabeca, sobe e some.
local function popNumber(model: Model, text: string, color: Color3)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.StudsOffsetWorldSpace = Vector3.new(math.random(-15, 15) / 10, 2, 0)
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui

	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	Debris:AddItem(gui, 0.9)
end

local function setHidden(entry, hidden: boolean)
	for part, originalTransparency in pairs(entry.parts) do
		part.Transparency = if hidden then 1 else originalTransparency
	end
	entry.bar.back.Visible = not hidden
	local head = entry.model:FindFirstChild("Head")
	local nameplate = head and head:FindFirstChild("Nameplate")
	if nameplate then
		local name = nameplate:FindFirstChild("EnemyName")
		if name then
			name.Visible = not hidden
		end
	end
end

-- Assincrono de proposito. Quando o cliente roda, a pasta Enemies pode ja
-- existir sem que os modelos dentro dela tenham replicado — GetChildren()
-- devolveria uma lista vazia e nenhum inimigo ganharia barra de vida.
local function track(model: Model, stageIndex: number)
	task.spawn(function()
		local body = model:WaitForChild("Body", 10)
		local head = model:WaitForChild("Head", 10)
		if not body or not head then
			warn(("[EnemyVisuals] %s nao replicou a tempo."):format(model.Name))
			return
		end
		model:WaitForChild("Eyes", 5)

		local bar = buildBar(model)
		if not bar then
			return
		end

		local parts = {}
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				parts[descendant] = descendant.Transparency
			end
		end

		-- Do config, nao do atributo: atributos podem nao ter replicado ainda.
		local maxHp = GameConfig.Stages[stageIndex].enemyHp
		local entry = {
			model = model,
			stageIndex = stageIndex,
			hp = maxHp,
			maxHp = maxHp,
			bar = bar,
			parts = parts,
		}
		tracked[model] = entry
		updateBar(entry)
	end)
end

function EnemyVisuals.Init()
	local map = workspace:WaitForChild("Map")
	for stageIndex = 1, GameConfig.MaxStage do
		local stageFolder = map:WaitForChild("Stage" .. stageIndex)
		local enemies = stageFolder:WaitForChild("Enemies")
		for _, model in ipairs(enemies:GetChildren()) do
			if model:IsA("Model") then
				track(model, stageIndex)
			end
		end
		enemies.ChildAdded:Connect(function(model)
			if model:IsA("Model") then
				track(model, stageIndex)
			end
		end)
	end

	Remotes.EnemyHpChanged.OnClientEvent:Connect(function(model: Model, hp: number, maxHp: number)
		local entry = tracked[model]
		if not entry then
			return
		end
		local damage = entry.hp - hp
		entry.hp = hp
		entry.maxHp = maxHp
		updateBar(entry)
		if damage > 0 then
			popNumber(model, ("-%d"):format(damage), Color3.fromRGB(255, 235, 120))
		end
	end)

	Remotes.EnemyDefeated.OnClientEvent:Connect(function(model: Model, reward: number)
		local entry = tracked[model]
		if not entry then
			return
		end

		if entry.hp > 0 then
			popNumber(model, ("-%d"):format(entry.hp), Color3.fromRGB(255, 235, 120))
		end
		popNumber(model, ("+R$ %d"):format(reward), Color3.fromRGB(120, 235, 130))

		entry.hp = 0
		updateBar(entry)
		setHidden(entry, true) -- ate a vitoria
	end)

	Remotes.EnemyRespawned.OnClientEvent:Connect(function(stageIndex: number)
		for _, entry in pairs(tracked) do
			if entry.stageIndex == stageIndex and entry.model.Parent then
				entry.hp = entry.maxHp
				updateBar(entry)
				setHidden(entry, false)
			end
		end
	end)
end

return EnemyVisuals
