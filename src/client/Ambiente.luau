-- Iluminação e pós-processamento: acampamento com visual mágico e vivo (luz de dia suave, cores
-- saturadas, névoa clara); masmorra escura, com tochas fortes, névoa do tema e brilho forte. Também faz as chamas tremularem e os objetos girarem.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ambiente = {}

local function obter(classe: string, nome: string): any
	local existente = Lighting:FindFirstChild(nome)
	if existente then
		return existente
	end
	local novo = Instance.new(classe)
	novo.Name = nome
	novo.Parent = Lighting
	return novo
end

local atmosfera = obter("Atmosphere", "AtmosferaJogo")
local bloom = obter("BloomEffect", "BrilhoJogo")
local cores = obter("ColorCorrectionEffect", "CoresJogo")
local raiosDeSol = obter("SunRaysEffect", "RaiosJogo")
-- profundidade de campo: o personagem e a sala ficam nítidos e o fundo distante desfoca de leve
local foco = obter("DepthOfFieldEffect", "FocoJogo")

local function animar(objeto: Instance, duracao: number, propriedades)
	TweenService:Create(objeto, TweenInfo.new(duracao, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), propriedades):Play()
end

-- Visual "mágico" (estilo desenho animado vivo): luz de dia suave e sem sombras escuras, cores
-- bem saturadas, névoa clara ao fundo e brilho macio nas partes claras.
local SATURACAO = 0.38
local CONTRASTE = 0.1
local SATURACAO_MASMORRA = 0.3
local CONTRASTE_MASMORRA = 0.26
local masmorraAtiva = false

function Ambiente.lobby()
	masmorraAtiva = false
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(150, 150, 160)
	Lighting.OutdoorAmbient = Color3.fromRGB(175, 170, 165)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.ExposureCompensation = 0.1
	Lighting.ShadowSoftness = 0.6
	atmosfera.Density = 0.28
	atmosfera.Offset = 0.15
	atmosfera.Color = Color3.fromRGB(210, 228, 255)
	atmosfera.Decay = Color3.fromRGB(150, 175, 220)
	atmosfera.Glare = 0.2
	atmosfera.Haze = 1.6
	bloom.Intensity = 0.6
	bloom.Size = 40
	bloom.Threshold = 1.05
	cores.Brightness = 0.03
	cores.Contrast = CONTRASTE
	cores.Saturation = SATURACAO
	cores.TintColor = Color3.fromRGB(255, 250, 240)
	raiosDeSol.Intensity = 0.06
	raiosDeSol.Spread = 0.8
	foco.FocusDistance = 30
	foco.InFocusRadius = 45
	foco.FarIntensity = 0.12
	foco.NearIntensity = 0
end

-- Masmorra: escura (noite, salas sem teto), mas com luz de qualidade: tochas fortes com sombras
-- marcadas, névoa colorida do tema, cores vivas e brilho forte em tudo que acende (tochas,
-- magias, efeitos). A luz ambiente é baixa, só o suficiente para enxergar a sala.

function Ambiente.masmorra(tema)
	masmorraAtiva = true
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.6
	Lighting.Ambient = tema.ambiente:Lerp(tema.luz, 0.15)
	Lighting.OutdoorAmbient = tema.ambiente:Lerp(Color3.new(0, 0, 0), 0.1)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.ExposureCompensation = 0
	Lighting.ShadowSoftness = 0.25
	atmosfera.Density = 0.4
	atmosfera.Offset = 0
	atmosfera.Color = tema.nevoa:Lerp(Color3.new(1, 1, 1), 0.15)
	atmosfera.Decay = tema.nevoa
	atmosfera.Glare = 0
	atmosfera.Haze = 2.6
	bloom.Intensity = 1.2
	bloom.Size = 32
	bloom.Threshold = 0.8
	cores.Brightness = -0.02
	cores.Contrast = CONTRASTE_MASMORRA
	cores.Saturation = SATURACAO_MASMORRA
	cores.TintColor = tema.tinta
	raiosDeSol.Intensity = 0
	foco.FocusDistance = 30
	foco.InFocusRadius = 38
	foco.FarIntensity = 0.2
	foco.NearIntensity = 0
end

-- Tela sem cor enquanto o jogador está caído
function Ambiente.caido(ligar: boolean)
	local saturacao = if masmorraAtiva then SATURACAO_MASMORRA else SATURACAO
	local contraste = if masmorraAtiva then CONTRASTE_MASMORRA else CONTRASTE
	animar(cores, 0.5, { Saturation = if ligar then -0.85 else saturacao, Contrast = if ligar then 0.3 else contraste })
end

------------------------------------------------------------------------
-- Chamas tremulando e objetos girando (só no computador do jogador)
------------------------------------------------------------------------

local chamas = {} -- [PointLight] = { brilho, semente }
local giratorios = {} -- [Model] = pivô original

local function adicionarChama(luz: Instance)
	if luz:IsA("PointLight") and not chamas[luz] then
		-- tochas mais fortes, alcançando mais longe e com sombra: poças de luz quente no escuro
		luz.Range *= 1.25
		luz.Shadows = true
		chamas[luz] = { brilho = luz.Brightness * 1.35, semente = math.random() * 100 }
	end
end

local function adicionarGiratorio(modelo: Instance)
	if modelo:IsA("Model") then
		giratorios[modelo] = modelo:GetPivot()
	end
end

function Ambiente.iniciar()
	Ambiente.lobby()
	for _, luz in CollectionService:GetTagged("Chama") do
		adicionarChama(luz)
	end
	CollectionService:GetInstanceAddedSignal("Chama"):Connect(adicionarChama)
	CollectionService:GetInstanceRemovedSignal("Chama"):Connect(function(luz)
		chamas[luz] = nil
	end)
	for _, modelo in CollectionService:GetTagged("Girar") do
		adicionarGiratorio(modelo)
	end
	CollectionService:GetInstanceAddedSignal("Girar"):Connect(adicionarGiratorio)
	CollectionService:GetInstanceRemovedSignal("Girar"):Connect(function(modelo)
		giratorios[modelo] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for luz, info in chamas do
			if luz.Parent then
				luz.Brightness = info.brilho * (0.78 + 0.32 * math.noise(t * 7, info.semente))
			else
				chamas[luz] = nil
			end
		end
		for modelo, pivo in giratorios do
			if modelo.Parent then
				local giro = (modelo:GetAttribute("Giro") or 1) * t
				local flutuar = modelo:GetAttribute("Flutuar") or 0
				local deslocamento = CFrame.new(0, math.sin(t * 1.6) * flutuar, 0)
				if modelo:GetAttribute("EixoGiro") == "X" then
					modelo:PivotTo(pivo * deslocamento * CFrame.Angles(giro, 0, 0))
				else
					-- gira em volta do eixo vertical do mundo, mantendo a inclinação original
					modelo:PivotTo(deslocamento * CFrame.new(pivo.Position) * CFrame.Angles(0, giro, 0) * pivo.Rotation)
				end
			else
				giratorios[modelo] = nil
			end
		end
	end)
end

return Ambiente
