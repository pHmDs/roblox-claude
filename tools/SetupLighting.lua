-- Configura iluminacao/atmosfera do jogo. Rodar em modo Edit (execute_luau) —
-- o resultado fica salvo no place, mesma logica do BuildMap.lua. Seguro
-- rodar de novo: so seta propriedades e recria os post-effects (destroi e
-- cria de novo em vez de editar, pra nao acumular duplicata a cada run).
--
-- Objetivo: dia claro e colorido, sem climao noturno — mas sem estourar o
-- brilho. A primeira versao (Brightness=3, bloom forte) ficou "lavada",
-- ofuscando as cores em vez de realca-las. Aqui e um brilho mais contido:
-- ve-se bem, mas as cores dos blocos continuam sendo o que chama atencao,
-- nao o glow.

local Lighting = game:GetService("Lighting")

-- Lighting.Technology (Future daria o melhor bloom/glow pros Neon) fica de
-- fora de proposito: escrever essa propriedade exige capability RobloxScript,
-- que scripts de plugin/ferramenta nao tem. Ajustar manual pelo painel
-- Properties no Studio se quiser Future; o bloom abaixo ja funciona sem ele.

Lighting.ClockTime = 13 -- sol a pino, sem sombra longa nem climao de entardecer
Lighting.GeographicLatitude = 20
Lighting.Brightness = 2
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.35
Lighting.Ambient = Color3.fromRGB(110, 112, 125) -- sombra visivel, sem lavar as cores
Lighting.OutdoorAmbient = Color3.fromRGB(140, 148, 168)
Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
Lighting.ShadowSoftness = 0.5
Lighting.GlobalShadows = true

for _, className in ipairs({ "Atmosphere", "BloomEffect", "ColorCorrectionEffect" }) do
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		existing:Destroy()
	end
end

-- Atmosfera bem leve, so pra dar profundidade ao horizonte.
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.12
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(230, 240, 255)
atmosphere.Decay = Color3.fromRGB(200, 220, 255)
atmosphere.Glare = 0.05
atmosphere.Haze = 0.2
atmosphere.Parent = Lighting

-- Bloom bem mais contido: threshold alto, so o que e MESMO muito brilhante
-- (pad de vitoria pronto, obelisco) brilha — os blocos decorativos normais
-- (SmoothPlastic colorido) nao acendem mais sozinhos.
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.35
bloom.Size = 12
bloom.Threshold = 1.7
bloom.Parent = Lighting

-- Saturacao moderada: colorido ainda le como "brinquedo", mas sem lavar tudo
-- pra quase-branco.
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Brightness = -0.02
colorCorrection.Contrast = 0.03
colorCorrection.Saturation = 0.2
colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
colorCorrection.Parent = Lighting

return "Iluminacao diurna ajustada: mais contida, cores no lugar do glow."
