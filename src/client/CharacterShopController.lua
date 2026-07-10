-- Loja de personagens fisica: pedestais no Lobby, um ProximityPrompt por
-- personagem. Segurar E pede compra/equipar, igual aos botoes que existiam
-- no HUD — so quem decide preco, saldo e posse continua sendo o servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

local CharacterShopController = {}

local state = nil
local prompts = {} -- [characterId] = ProximityPrompt

local function notify(text: string, isError: boolean)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Loja de Personagens",
			Text = text,
			Duration = 3,
		})
	end)
	if isError then
		warn("[CharacterShopController] " .. text)
	end
end

local function refresh()
	if not state then
		return
	end

	for id, prompt in pairs(prompts) do
		local cfg = GameConfig.Characters[id]
		local owned = table.find(state.characters, id) ~= nil
		local equipped = state.equipped == id

		prompt.ObjectText = cfg.displayName
		if equipped then
			prompt.ActionText = "Equipado"
		elseif owned then
			prompt.ActionText = "Equipar"
		else
			prompt.ActionText = ("Comprar (%d vitorias)"):format(cfg.cost)
		end
	end
end

local function onTriggered(id: string)
	local owned = state and table.find(state.characters, id) ~= nil
	if state and state.equipped == id then
		return -- ja equipado: nao ha o que pedir
	end

	local cfg = GameConfig.Characters[id]
	local remote = if owned then Remotes.EquipCharacter else Remotes.BuyCharacter
	local ok, err = remote:InvokeServer(id)
	if ok then
		notify(if owned then "Equipado!" else ("%s comprado!"):format(cfg.displayName), false)
	else
		notify(tostring(err), true)
	end
end

local function bindStalls()
	local shopFolder = Workspace:WaitForChild("Map"):WaitForChild("Lobby"):WaitForChild("CharacterShop")
	for _, stall in ipairs(shopFolder:GetChildren()) do
		local pedestal = stall:FindFirstChild("Pedestal")
		local prompt = pedestal and pedestal:FindFirstChildOfClass("ProximityPrompt")
		local id = prompt and prompt:GetAttribute("CharacterId")
		if prompt and type(id) == "string" then
			prompts[id] = prompt
			prompt.Triggered:Connect(function(playerWhoTriggered: Player)
				if playerWhoTriggered ~= player then
					return
				end
				onTriggered(id)
			end)
		end
	end
end

function CharacterShopController.Init()
	bindStalls()
	refresh()

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

return CharacterShopController
