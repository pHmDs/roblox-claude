-- Anima os "bonecos" do jogo: giro/flutuacao nos personagens da loja, respiro
-- (squash-stretch) e brilho pulsante no olho dos inimigos, balanco no ovo de
-- pet. Tudo puramente visual e local.
--
-- Inimigo tem posicao/rotacao dona do SERVIDOR (EnemyAI move o Model inteiro
-- via PivotTo todo frame — ver EnemyAI.lua). Por isso este script NUNCA toca
-- CFrame/Position/Orientation de inimigo: mexer nisso brigaria com a
-- replicacao e criaria tremedeira. Size e Transparency sao propriedades que o
-- servidor nunca escreve, entao sao seguras pra animar aqui.
--
-- Personagens da loja e o ovo de pet nao tem dono nenhum no servidor (so
-- existem parados no mapa), entao esses recebem CFrame completo local.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FigureAnimator = {}

local floaters = {} -- { part, baseCFrame, phase, bobHeight, spinSpeed }
local breathers = {} -- { part, baseSize, eyes, phase }

-- WaitForChild de proposito, nao FindFirstChild: este script roda cedo no
-- boot do cliente (ver ClientMain.client.lua), e o mapa pode ainda nao ter
-- replicado — FindFirstChild devolveria nil e a lista de bonecos ficaria
-- vazia pra sempre (mesmo erro que EnemyVisuals.lua ja documenta evitar).
local function trackStallFigures()
	local map = Workspace:WaitForChild("Map", 10)
	local shop = map and map:WaitForChild("Lobby", 10):WaitForChild("CharacterShop", 10)
	if not shop then
		return
	end
	for _, stall in ipairs(shop:GetChildren()) do
		local body = stall:FindFirstChild("Body")
		if body then
			table.insert(floaters, {
				part = body,
				baseCFrame = body.CFrame,
				phase = math.random() * math.pi * 2,
				bobHeight = 0.6,
				spinSpeed = 0.7,
			})
		end
	end
end

local function trackPetEgg()
	local map = Workspace:WaitForChild("Map", 10)
	local lobby = map and map:WaitForChild("Lobby", 10)
	local nest = lobby and lobby:WaitForChild("PetShop", 10)
	local egg = nest and nest:WaitForChild("Egg", 10)
	if egg then
		table.insert(floaters, {
			part = egg,
			baseCFrame = egg.CFrame,
			phase = math.random() * math.pi * 2,
			bobHeight = 0.35,
			spinSpeed = 0.4,
		})
	end
end

local function trackEnemyFigures()
	local map = Workspace:WaitForChild("Map", 10)
	if not map then
		return
	end
	local stageIndex = 1
	while true do
		local stageFolder = map:FindFirstChild("Stage" .. stageIndex)
		if not stageFolder then
			break
		end
		local enemies = stageFolder:FindFirstChild("Enemies")
		if enemies then
			for _, model in ipairs(enemies:GetChildren()) do
				local body = model:FindFirstChild("Body")
				if body then
					table.insert(breathers, {
						part = body,
						baseSize = body.Size,
						eyes = model:FindFirstChild("Eyes"),
						phase = math.random() * math.pi * 2,
						lastPosition = body.Position,
					})
				end
			end
		end
		stageIndex += 1
	end
end

function FigureAnimator.Init()
	trackStallFigures()
	trackPetEgg()
	trackEnemyFigures()

	-- Heartbeat, nao RenderStepped: RenderStepped so dispara quando o cliente
	-- de fato desenha um frame (trava se a janela nao estiver renderizando).
	-- Heartbeat acompanha o passo de simulacao, independente disso.
	RunService.Heartbeat:Connect(function(dt: number)
		local t = os.clock()

		for _, entry in ipairs(floaters) do
			local bob = math.sin(t * 1.6 + entry.phase) * entry.bobHeight
			local spin = CFrame.Angles(0, t * entry.spinSpeed + entry.phase, 0)
			entry.part.CFrame = entry.baseCFrame * CFrame.new(0, bob, 0) * spin
		end

		for _, entry in ipairs(breathers) do
			-- Inimigo morto fica com Transparency=1 (EnemyVisuals.setHidden) ate a
			-- vitoria. Pular a animacao nesse estado evita o olho "piscando" num
			-- boneco que deveria estar invisivel.
			if entry.part.Transparency < 0.5 then
				-- Anda ou esta parado? So LEMOS a posicao (nunca escrevemos) — quem
				-- move de verdade e o servidor (EnemyAI, via PivotTo). Comparar
				-- posicao entre frames e o unico jeito seguro de saber sem brigar
				-- com a replicacao.
				local currentPosition = entry.part.Position
				local speed = if dt > 0 then (currentPosition - entry.lastPosition).Magnitude / dt else 0
				entry.lastPosition = currentPosition
				local walking = speed > 1

				if walking then
					-- Pulo mais rapido e assimetrico: estica na subida, esmaga na
					-- descida — a mesma linguagem visual de slime pulando, so que
					-- sem mexer em CFrame.
					local hop = math.sin(t * 9 + entry.phase)
					local stretchY = 1 + hop * 0.14
					local squishXZ = 1 - hop * 0.09
					entry.part.Size = Vector3.new(
						entry.baseSize.X * squishXZ,
						entry.baseSize.Y * stretchY,
						entry.baseSize.Z * squishXZ
					)
				else
					local pulse = 1 + math.sin(t * 3 + entry.phase) * 0.05
					entry.part.Size = entry.baseSize * pulse
				end

				if entry.eyes then
					entry.eyes.Transparency = 0.15 + math.abs(math.sin(t * 4 + entry.phase)) * 0.5
				end
			end
		end
	end)
end

return FigureAnimator
