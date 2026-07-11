--!strict
-- Paleta e materiais compartilhados entre o gerador de mapa (tools/BuildMap.lua)
-- e o HUD/UI (src/client/*Controller.lua). Um sistema = uma cor, sempre:
-- muda a cor aqui, muda em todo lugar que usa esse token.
--
-- Nao contem numeros de balanceamento (isso e GameConfig) nem geometria
-- (isso e GameConfig.Map/Lobby/etc) — so aparencia.

local Theme = {}

-- Base neutra: pedra escura pontuada por acentos neon. Cada acento e o
-- "sistema" que ele representa em todo o jogo (mapa E hud).
-- Paleta "playground": plastico brilhante e cores saturadas, sem pedra/mármore
-- realista. O HUD continua escuro/translucido por legibilidade (texto branco
-- em cima de painel escuro sempre le melhor), mas o MUNDO 3D e todo colorido.
Theme.Colors = {
	background = Color3.fromRGB(24, 20, 40), -- fundo dos paineis de HUD (translucido, so pra contraste de texto)
	surface = Color3.fromRGB(40, 34, 62), -- paineis/linhas dentro do HUD
	surfaceRaised = Color3.fromRGB(56, 48, 84), -- hover/destaque dentro de paineis
	stone = Color3.fromRGB(250, 250, 255), -- base das plataformas: quase branco, deixa a cor do estagio dominar
	stoneDark = Color3.fromRGB(190, 205, 245), -- muros/pilares/pontes: periwinkle claro, nao cinza-pedra

	textPrimary = Color3.fromRGB(255, 255, 255),
	textMuted = Color3.fromRGB(200, 195, 220),

	safe = Color3.fromRGB(90, 220, 120), -- spawn/pads seguros
	danger = Color3.fromRGB(255, 90, 90), -- barreiras/perigo
	rebirth = Color3.fromRGB(190, 110, 255), -- altar/renascida
	gold = Color3.fromRGB(255, 200, 40), -- personagens/dinheiro/upgrades
	pet = Color3.fromRGB(60, 220, 200), -- ninho/pets
}

-- Trim neon fino (bordas de plataforma, aneis de pedestal etc). Mesma cor do
-- sistema, sempre em Neon — e o que da o efeito "arena" sem precisar de mesh.
Theme.TrimThickness = 0.4

function Theme.WithAlpha(color: Color3, mixWithBlack: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), mixWithBlack)
end

return Theme
