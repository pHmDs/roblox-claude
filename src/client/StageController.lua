-- Barreira, brilho do pad e a escolha depois da vitoria.
--
-- A colisao da barreira e desligada aqui, no cliente, porque a colisao do
-- proprio personagem e simulada no cliente. Isso e conveniencia, nao seguranca:
-- quem realmente segura a barreira e a varredura de posicao no StageService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

local StageController = {}

local state = nil
local popup = nil

-- ---------------------------------------------------------------------------
-- Barreiras e pads
-- ---------------------------------------------------------------------------

local function refreshWorld()
	if not state then
		return
	end
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end

	for stageIndex = 1, GameConfig.MaxStage do
		local stageFolder = map:FindFirstChild("Stage" .. stageIndex)
		if stageFolder then
			local barrier = stageFolder:FindFirstChild("Barrier")
			if barrier then
				local unlocks = barrier:GetAttribute("UnlocksStage") or math.huge
				local open = state.stage >= unlocks
				barrier.CanCollide = not open
				barrier.Transparency = if open then 0.9 else 0.5
				barrier.Color = if open then Theme.Colors.safe else Theme.Colors.danger

				local label = barrier:FindFirstChild("BarrierLabel")
				local text = label and label:FindFirstChild("Text")
				if text then
					local nextStage = GameConfig.Stages[unlocks]
					text.Text = if open
						then ("%s — liberado"):format(nextStage.displayName)
						else ("%s — precisa de %d vitorias"):format(nextStage.displayName, nextStage.winsRequired)
				end
			end

			-- O pad so acende quando a cota daquele estagio esta cheia.
			local pad = stageFolder:FindFirstChild("WinPad")
			if pad then
				local quota = GameConfig.GetQuota(stageIndex)
				local progress = state.stageProgress[tostring(stageIndex)] or 0
				local ready = progress >= quota
				pad.Color = if ready then Theme.Colors.gold else Theme.Colors.stoneDark

				local padLabel = pad:FindFirstChild("PadLabel")
				local text = padLabel and padLabel:FindFirstChild("Text")
				if text then
					text.Text = if ready
						then "PISE AQUI — +1 VITORIA"
						else ("Cota: %d / %d"):format(progress, quota)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Popup de vitoria
-- ---------------------------------------------------------------------------

local function makeButton(parent: Instance, text: string, order: number, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 44)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

local function closePopup()
	if popup then
		popup:Destroy()
		popup = nil
	end
end

local function showPopup(info)
	closePopup()

	local gui = Instance.new("ScreenGui")
	gui.Name = "WinPopup"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	popup = gui

	local panel = Instance.new("Frame")
	panel.Active = true -- consome o clique: nao vira ataque
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(340, 230)
	panel.BackgroundColor3 = Theme.Colors.background
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = panel

	local title = Instance.new("TextLabel")
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 30
	title.TextColor3 = Theme.Colors.gold
	title.Text = "+1 VITORIA!"
	title.Parent = panel

	local subtitle = Instance.new("TextLabel")
	subtitle.LayoutOrder = 2
	subtitle.Size = UDim2.new(1, 0, 0, 24)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 15
	subtitle.TextColor3 = Theme.Colors.textMuted
	subtitle.Text = ("Total: %d vitorias"):format(info.wins)
	subtitle.Parent = panel

	local back = makeButton(panel, "Voltar ao inicio", 3, Color3.fromRGB(60, 90, 160))
	back.Activated:Connect(function()
		Remotes.StageChoice:FireServer("back")
		closePopup()
	end)

	if info.hasNextStage then
		local forward = makeButton(
			panel,
			if info.canAdvance then "Avancar para o proximo estagio" else ("Precisa de %d vitorias"):format(info.winsRequired),
			4,
			if info.canAdvance then Theme.Colors.safe else Theme.Colors.surfaceRaised
		)
		forward.AutoButtonColor = info.canAdvance
		forward.Activated:Connect(function()
			if not info.canAdvance then
				return
			end
			Remotes.StageChoice:FireServer("forward")
			closePopup()
		end)
	end
end

function StageController.Init()
	Remotes.StateChanged.OnClientEvent:Connect(function(newState)
		state = newState
		refreshWorld()
	end)

	Remotes.WinAwarded.OnClientEvent:Connect(showPopup)

	task.spawn(function()
		local initial = Remotes.GetState:InvokeServer()
		if initial and not state then
			state = initial
			refreshWorld()
		end
	end)

	-- O mapa pode terminar de replicar depois do primeiro StateChanged.
	task.spawn(function()
		while true do
			task.wait(0.5)
			refreshWorld()
		end
	end)
end

return StageController
