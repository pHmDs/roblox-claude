-- HUD: barra de dinheiro embaixo no centro, vitorias e dano no canto direito,
-- nome do estagio em cima no centro.
--
-- Toda a informacao vem do snapshot StateChanged. O cliente nunca calcula nada
-- que valha dinheiro — so exibe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

local HudController = {}

local state = nil
local ui = {}

-- 1234567 -> "1.234.567"
local function formatNumber(value: number): string
	local formatted = tostring(math.floor(value))
	local k
	repeat
		formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
	until k == 0
	return formatted
end

-- O upgrade mais barato que ainda da para subir de nivel. E a meta que a barra
-- de dinheiro persegue. Devolve nil quando tudo esta no nivel maximo.
local function nextUpgradeCost(): number?
	local best = nil
	for upgradeId, cfg in pairs(GameConfig.Upgrades) do
		local level = state.upgrades[upgradeId] or 0
		if level < cfg.maxLevel then
			local cost = GameConfig.GetUpgradeCost(upgradeId, level)
			if not best or cost < best then
				best = cost
			end
		end
	end
	return best
end

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

-- ---------------------------------------------------------------------------
-- Construcao
-- ---------------------------------------------------------------------------

local function buildStageLabel(gui: ScreenGui)
	local label = Instance.new("TextLabel")
	label.Name = "Stage"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 14)
	label.Size = UDim2.fromOffset(320, 26)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 17
	label.TextColor3 = Color3.fromRGB(235, 235, 245)
	label.TextStrokeTransparency = 0.5
	label.Text = ""
	label.Parent = gui
	ui.stage = label
end

local function buildRightCorner(gui: ScreenGui)
	local panel = Instance.new("Frame")
	panel.Name = "Right"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -16, 0, 14)
	panel.Size = UDim2.fromOffset(190, 96)
	panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	panel.BackgroundTransparency = 0.3
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, 10)

	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 8)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 2)
	layout.Parent = panel

	local wins = Instance.new("TextLabel")
	wins.LayoutOrder = 1
	wins.Size = UDim2.new(1, 0, 0, 26)
	wins.BackgroundTransparency = 1
	wins.Font = Enum.Font.FredokaOne
	wins.TextSize = 22
	wins.TextXAlignment = Enum.TextXAlignment.Right
	wins.TextColor3 = Color3.fromRGB(255, 210, 90)
	wins.TextStrokeTransparency = 0.6
	wins.Parent = panel
	ui.wins = wins

	local damage = Instance.new("TextLabel")
	damage.LayoutOrder = 2
	damage.Size = UDim2.new(1, 0, 0, 18)
	damage.BackgroundTransparency = 1
	damage.Font = Enum.Font.Gotham
	damage.TextSize = 13
	damage.TextXAlignment = Enum.TextXAlignment.Right
	damage.TextColor3 = Color3.fromRGB(255, 150, 150)
	damage.TextStrokeTransparency = 0.7
	damage.Parent = panel
	ui.damage = damage

	local rebirth = Instance.new("TextLabel")
	rebirth.LayoutOrder = 3
	rebirth.Size = UDim2.new(1, 0, 0, 16)
	rebirth.BackgroundTransparency = 1
	rebirth.Font = Enum.Font.Gotham
	rebirth.TextSize = 12
	rebirth.TextXAlignment = Enum.TextXAlignment.Right
	rebirth.TextColor3 = Color3.fromRGB(200, 150, 255)
	rebirth.TextStrokeTransparency = 0.7
	rebirth.Parent = panel
	ui.rebirth = rebirth

	local pet = Instance.new("TextLabel")
	pet.LayoutOrder = 4
	pet.Size = UDim2.new(1, 0, 0, 16)
	pet.BackgroundTransparency = 1
	pet.Font = Enum.Font.Gotham
	pet.TextSize = 12
	pet.TextXAlignment = Enum.TextXAlignment.Right
	pet.TextColor3 = Color3.fromRGB(120, 220, 200)
	pet.TextStrokeTransparency = 0.7
	pet.Parent = panel
	ui.pet = pet
end

-- A barra enche ate o proximo upgrade. Dinheiro nao tem teto, entao sem uma meta
-- concreta a barra nao significaria nada.
local function buildMoneyBar(gui: ScreenGui)
	local back = Instance.new("Frame")
	back.Name = "MoneyBar"
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, -22)
	back.Size = UDim2.fromOffset(420, 44)
	back.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
	back.BackgroundTransparency = 0.15
	back.BorderSizePixel = 0
	back.Parent = gui
	corner(back, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 74)
	stroke.Thickness = 1
	stroke.Parent = back

	-- ClipsDescendants para o preenchimento respeitar o canto arredondado.
	local clip = Instance.new("Frame")
	clip.Name = "Clip"
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Parent = back
	corner(clip, 12)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(70, 180, 95)
	fill.BackgroundTransparency = 0.35
	fill.BorderSizePixel = 0
	fill.Parent = clip
	ui.fill = fill

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 20
	text.TextColor3 = Color3.fromRGB(235, 255, 240)
	text.TextStrokeTransparency = 0.3
	text.Text = ""
	text.Parent = back
	ui.money = text
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	buildStageLabel(gui)
	buildRightCorner(gui)
	buildMoneyBar(gui)
end

-- ---------------------------------------------------------------------------
-- Atualizacao
-- ---------------------------------------------------------------------------

local function currentPlaceName(): string
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return "Lobby"
	end
	if GameConfig.IsInLobby(root.Position) then
		return "Lobby"
	end
	return GameConfig.Stages[GameConfig.GetStageAtPosition(root.Position)].displayName
end

local function refresh()
	if not state then
		return
	end

	ui.stage.Text = currentPlaceName()
	ui.wins.Text = ("%s vitorias"):format(formatNumber(state.wins))
	ui.damage.Text = ("%s de dano por clique"):format(formatNumber(GameConfig.GetClickDamage(state)))
	ui.rebirth.Text = ("Rebirth %d"):format(state.rebirths)
	ui.pet.Text = if state.equippedPet then ("Pet: %s"):format(GameConfig.Pets[state.equippedPet].displayName) else "Pet: nenhum"

	local goal = nextUpgradeCost()
	if goal then
		ui.fill.Size = UDim2.fromScale(math.clamp(state.money / goal, 0, 1), 1)
		ui.money.Text = ("R$ %s / %s"):format(formatNumber(state.money), formatNumber(goal))
	else
		ui.fill.Size = UDim2.fromScale(1, 1)
		ui.money.Text = ("R$ %s"):format(formatNumber(state.money))
	end
end

function HudController.Init()
	build()

	Remotes.StateChanged.OnClientEvent:Connect(function(newState)
		state = newState
		refresh()
	end)

	-- Puxa o estado inicial: o StateChanged do PlayerAdded pode ter sido
	-- disparado antes deste Connect existir.
	task.spawn(function()
		local initial = Remotes.GetState:InvokeServer()
		if initial and not state then
			state = initial
			refresh()
		end
	end)

	-- O lugar onde o jogador esta muda com o andar, sem evento nenhum.
	-- 4x por segundo basta e nao custa nada.
	task.spawn(function()
		while true do
			task.wait(0.25)
			refresh()
		end
	end)
end

return HudController
