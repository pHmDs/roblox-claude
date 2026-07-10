-- Altar de renascimento fisico no Lobby: um unico ProximityPrompt. Segurar E
-- pede o reset — quem decide se pode (vitorias suficientes) e o servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

local RebirthController = {}

local state = nil
local prompt = nil

local function notify(text: string, isError: boolean)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Renascer",
			Text = text,
			Duration = 3,
		})
	end)
	if isError then
		warn("[RebirthController] " .. text)
	end
end

local function refresh()
	if not state or not prompt then
		return
	end

	local required = GameConfig.GetRebirthRequirement(state.rebirths)
	if state.wins >= required then
		prompt.ActionText = ("RENASCER (Rebirth %d -> %d)"):format(state.rebirths, state.rebirths + 1)
	else
		prompt.ActionText = ("Renascer (%d/%d vitorias)"):format(state.wins, required)
	end
end

local function onTriggered()
	local ok, err = Remotes.Rebirth:InvokeServer()
	if ok then
		notify("Voce renasceu! Poder permanente aumentado.", false)
	else
		notify(tostring(err), true)
	end
end

local function bindAltar()
	local altar = Workspace:WaitForChild("Map"):WaitForChild("Lobby"):WaitForChild("RebirthAltar")
	local base = altar:WaitForChild("Base")
	prompt = base:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(playerWhoTriggered: Player)
		if playerWhoTriggered ~= player then
			return
		end
		onTriggered()
	end)
end

function RebirthController.Init()
	bindAltar()
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

return RebirthController
