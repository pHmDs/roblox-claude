-- Loja de upgrades (dinheiro). A loja de personagens virou fisica, nos
-- pedestais do Lobby — ver CharacterShopController.lua.
--
-- Todo botao so PEDE. Quem decide preco, saldo e posse e o servidor, via
-- RemoteFunction. Se a resposta for negativa, mostramos o motivo que ele deu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

local ShopController = {}

local state = nil
local rows = { upgrades = {} }
local statusLabel = nil
local panel = nil

local function formatNumber(value: number): string
	local formatted = tostring(math.floor(value))
	local k
	repeat
		formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
	until k == 0
	return formatted
end

-- Dicionario -> lista ordenada pelo campo `order`.
local function sortedIds(source)
	local ids = {}
	for id in pairs(source) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return source[a].order < source[b].order
	end)
	return ids
end

local function setStatus(text: string, isError: boolean)
	if not statusLabel then
		return
	end
	statusLabel.Text = text
	statusLabel.TextColor3 = if isError then Theme.Colors.danger else Theme.Colors.safe
	task.delay(2.5, function()
		if statusLabel and statusLabel.Text == text then
			statusLabel.Text = ""
		end
	end)
end

local function makeRow(parent: Instance, order: number)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Theme.Colors.surface
	row.BorderSizePixel = 0
	row.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -140, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(235, 235, 245)
	title.Parent = row

	local subtitle = Instance.new("TextLabel")
	subtitle.Position = UDim2.fromOffset(12, 28)
	subtitle.Size = UDim2.new(1, -140, 0, 20)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 13
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = Color3.fromRGB(160, 168, 190)
	subtitle.Parent = row

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(112, 36)
	button.BackgroundColor3 = Theme.Colors.safe
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Parent = row

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button

	return { row = row, title = title, subtitle = subtitle, button = button }
end

local function refresh()
	if not state then
		return
	end

	for id, entry in pairs(rows.upgrades) do
		local cfg = GameConfig.Upgrades[id]
		local level = state.upgrades[id] or 0
		local maxed = level >= cfg.maxLevel
		local cost = GameConfig.GetUpgradeCost(id, level)

		entry.title.Text = ("%s  (nivel %d)"):format(cfg.displayName, level)
		entry.subtitle.Text = cfg.description

		if maxed then
			entry.button.Text = "MAXIMO"
			entry.button.BackgroundColor3 = Theme.Colors.surfaceRaised
			entry.button.AutoButtonColor = false
		else
			local canAfford = state.money >= cost
			entry.button.Text = ("R$ %s"):format(formatNumber(cost))
			entry.button.BackgroundColor3 = if canAfford then Theme.Colors.safe else Theme.WithAlpha(Theme.Colors.danger, 0.55)
			entry.button.AutoButtonColor = canAfford
		end
	end
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.AnchorPoint = Vector2.new(0, 1)
	toggle.Position = UDim2.new(0, 16, 1, -16)
	toggle.Size = UDim2.fromOffset(140, 46)
	toggle.BackgroundColor3 = Theme.Colors.gold
	toggle.BorderSizePixel = 0
	toggle.Font = Enum.Font.FredokaOne
	toggle.TextSize = 20
	toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggle.Text = "UPGRADES"
	toggle.Parent = gui

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 10)
	toggleCorner.Parent = toggle

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Active = true -- consome o clique: abrir a loja nao ataca inimigo
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(460, 300)
	panel.BackgroundColor3 = Theme.Colors.background
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = panel

	local header = Instance.new("TextLabel")
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.FredokaOne
	header.TextSize = 24
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Theme.Colors.gold
	header.Text = "UPGRADES"
	header.Parent = panel

	local order = 2
	for _, id in ipairs(sortedIds(GameConfig.Upgrades)) do
		local entry = makeRow(panel, order)
		order += 1
		rows.upgrades[id] = entry
		entry.button.Activated:Connect(function()
			local ok, err = Remotes.BuyUpgrade:InvokeServer(id)
			if ok then
				setStatus(("%s comprado!"):format(GameConfig.Upgrades[id].displayName), false)
			else
				setStatus(tostring(err), true)
			end
		end)
	end

	statusLabel = Instance.new("TextLabel")
	statusLabel.LayoutOrder = order
	statusLabel.Size = UDim2.new(1, 0, 0, 22)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 14
	statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	statusLabel.Text = ""
	statusLabel.Parent = panel

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refresh()
	end)
end

function ShopController.Init()
	build()
	Remotes.StateChanged.OnClientEvent:Connect(function(newState)
		state = newState
		refresh()
	end)

	task.spawn(function()
		local initial = Remotes.GetState:InvokeServer()
		if initial and not state then
			state = initial
			refresh()
		end
	end)
end

return ShopController
