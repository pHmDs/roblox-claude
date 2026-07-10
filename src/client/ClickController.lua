-- Clique em qualquer lugar da tela. So avisa o servidor que clicou — nenhum
-- dano, nenhum alvo, nenhum numero sai daqui.
--
-- O cooldown local existe para nao gastar rede a toa: o servidor ja tem o rate
-- limit de verdade, e cliques acima do teto seriam descartados de qualquer jeito.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = ReplicatedStorage.Remotes

local ClickController = {}

local MIN_INTERVAL = 1 / GameConfig.Click.maxPerSecond

local lastClick = 0

local function tryClick()
	local now = os.clock()
	if now - lastClick < MIN_INTERVAL then
		return
	end
	lastClick = now
	Remotes.ClickAttack:FireServer()
end

function ClickController.Init()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return -- clique consumido pela UI (loja, botao); nao vira ataque
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tryClick()
		end
	end)
end

return ClickController
