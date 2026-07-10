-- Pets: abrir ovo e fisico (ninho no Lobby, ProximityPrompt), mas equipar um
-- pet ja possuido fica num painel de HUD — igual upgrades, a posse aqui e
-- so binaria (tem ou nao tem, sem preco por unidade), entao um pedestal por
-- pet ficaria com a maioria vazia/bloqueada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

local PetShopController = {}

local state = nil
local eggPrompt = nil
local rows = {}
local panel = nil

local function notify(text: string, isError: boolean)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Pets",
			Text = text,
			Duration = 3,
		})
	end)
	if isError then
		warn("[PetShopController] " .. text)
	end
end

-- Dicionario -> lista ordenada pelo campo `order` (mesmo criterio de ShopController).
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

-- ---------------------------------------------------------------------------
-- Mundo: ninho de ovo
-- ---------------------------------------------------------------------------

local function refreshEggPrompt()
	if not eggPrompt then
		return
	end
	eggPrompt.ActionText = ("Abrir ovo (R$ %d)"):format(GameConfig.PetEgg.cost)
end

local function onEggTriggered()
	local ok, petIdOrErr, wasDuplicate = Remotes.OpenPetEgg:InvokeServer()
	if ok then
		local cfg = GameConfig.Pets[petIdOrErr]
		if wasDuplicate then
			notify(("Ja tinha %s — parte do dinheiro devolvida."):format(cfg.displayName), false)
		else
			notify(("Voce ganhou: %s!"):format(cfg.displayName), false)
		end
	else
		notify(tostring(petIdOrErr), true)
	end
end

local function bindNest()
	local shop = Workspace:WaitForChild("Map"):WaitForChild("Lobby"):WaitForChild("PetShop")
	local nest = shop:WaitForChild("Nest")
	eggPrompt = nest:FindFirstChildOfClass("ProximityPrompt")
	if not eggPrompt then
		return
	end
	eggPrompt.Triggered:Connect(function(playerWhoTriggered: Player)
		if playerWhoTriggered ~= player then
			return
		end
		onEggTriggered()
	end)
end

-- ---------------------------------------------------------------------------
-- HUD: equipar pet ja possuido
-- ---------------------------------------------------------------------------

local function makeRow(parent: Instance, order: number)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
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
	button.BackgroundColor3 = Color3.fromRGB(50, 150, 80)
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

local function bonusText(cfg): string
	local kind = if cfg.bonusType == "money" then "dinheiro" else "dano"
	return ("+%d%% de %s"):format(math.floor((cfg.bonusMultiplier - 1) * 100), kind)
end

local function refreshPanel()
	if not state then
		return
	end

	for id, entry in pairs(rows) do
		local cfg = GameConfig.Pets[id]
		local owned = table.find(state.pets, id) ~= nil
		local equipped = state.equippedPet == id

		entry.title.Text = cfg.displayName
		entry.subtitle.Text = bonusText(cfg)

		if not owned then
			entry.button.Text = "BLOQUEADO"
			entry.button.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
			entry.button.AutoButtonColor = false
		elseif equipped then
			entry.button.Text = "EQUIPADO"
			entry.button.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
			entry.button.AutoButtonColor = false
		else
			entry.button.Text = "EQUIPAR"
			entry.button.BackgroundColor3 = Color3.fromRGB(50, 150, 80)
			entry.button.AutoButtonColor = true
		end
	end
end

local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PetShop"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.AnchorPoint = Vector2.new(0, 1)
	toggle.Position = UDim2.new(0, 166, 1, -16)
	toggle.Size = UDim2.fromOffset(140, 46)
	toggle.BackgroundColor3 = Color3.fromRGB(90, 150, 180)
	toggle.BorderSizePixel = 0
	toggle.Font = Enum.Font.FredokaOne
	toggle.TextSize = 20
	toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggle.Text = "PETS"
	toggle.Parent = gui

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 10)
	toggleCorner.Parent = toggle

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Active = true
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(460, 260)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
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
	header.TextColor3 = Color3.fromRGB(255, 215, 80)
	header.Text = "PETS"
	header.Parent = panel

	local order = 2
	for _, id in ipairs(sortedIds(GameConfig.Pets)) do
		local entry = makeRow(panel, order)
		order += 1
		rows[id] = entry
		entry.button.Activated:Connect(function()
			local ok, err = Remotes.EquipPet:InvokeServer(id)
			if ok then
				notify(("%s equipado!"):format(GameConfig.Pets[id].displayName), false)
			else
				notify(tostring(err), true)
			end
		end)
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refreshPanel()
	end)
end

function PetShopController.Init()
	bindNest()
	refreshEggPrompt()
	buildHud()

	Remotes.StateChanged.OnClientEvent:Connect(function(newState)
		state = newState
		refreshPanel()
	end)

	task.spawn(function()
		local initial = Remotes.GetState:InvokeServer()
		if initial and not state then
			state = initial
			refreshPanel()
		end
	end)
end

return PetShopController
