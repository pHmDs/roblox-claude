-- Ponte de depuracao para o Studio.
--
-- Por que existe: a ferramenta execute_luau do MCP roda num contexto Luau
-- isolado, com cache de require e _G proprios. Um `require(DataManager)` de la
-- devolve uma COPIA morta do modulo, nao o estado do servidor rodando. Uma
-- BindableFunction e uma Instance, e Instances sao compartilhadas — invocar
-- daqui executa o handler DENTRO do contexto do servidor real.
--
-- So existe no Studio. Em producao, nunca e criada.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DebugBridge = {}

local actions = {}

-- Copia profunda para atravessar a fronteira da BindableFunction sem entregar
-- referencias vivas ao estado do servidor.
local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

function DebugBridge.Register(name: string, handler)
	actions[name] = handler
end

function DebugBridge.Init()
	if not RunService:IsStudio() then
		return
	end

	local existing = ServerStorage:FindFirstChild("DebugBridge")
	if existing then
		existing:Destroy()
	end

	local bindable = Instance.new("BindableFunction")
	bindable.Name = "DebugBridge"
	bindable.Parent = ServerStorage

	bindable.OnInvoke = function(action: string, ...)
		local handler = actions[action]
		if not handler then
			local known = {}
			for name in pairs(actions) do
				table.insert(known, name)
			end
			table.sort(known)
			return { ok = false, err = ("acao desconhecida '%s'; conhecidas: %s"):format(tostring(action), table.concat(known, ", ")) }
		end

		local ok, result = pcall(handler, ...)
		if not ok then
			return { ok = false, err = tostring(result) }
		end
		return { ok = true, result = deepCopy(result) }
	end

	print("[DebugBridge] pronto em ServerStorage.DebugBridge")
end

return DebugBridge
