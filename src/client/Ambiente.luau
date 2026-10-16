-- Iluminação e pós-processamento: acampamento com visual mágico e vivo (luz de dia suave, cores
-- saturadas, névoa clara); masmorra escura, com tochas fortes, névoa do tema e brilho forte. Também faz as chamas tremularem e os objetos girarem.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

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
local SATURACAO = 0.15 -- (o cenário do lobby já é colorido)
local CONTRASTE = 0.1
local SATURACAO_MASMORRA = 0.3
local CONTRASTE_MASMORRA = 0.26
local masmorraAtiva = false

-- Música do acampamento (Config.MUSICA_LOBBY): entra devagar no lobby e some na masmorra
local musica = Instance.new("Sound")
musica.Name = "MusicaLobby"
musica.SoundId = Config.MUSICA_LOBBY or ""
musica.Looped = true
musica.Volume = 0
musica.Parent = SoundService
local vezMusica = 0

local function musicaDoLobby(ligar: boolean)
	if musica.SoundId == "" then
		return
	end
	vezMusica += 1
	local minhaVez = vezMusica
	if ligar then
		if not musica.IsPlaying then
			musica:Resume()
		end
		animar(musica, 2.5, { Volume = Config.VOLUME_MUSICA_LOBBY or 0.4 })
	else
		animar(musica, 1.2, { Volume = 0 })
		task.delay(1.3, function()
			if vezMusica == minhaVez then
				musica:Pause()
			end
		end)
	end
end

function Ambiente.lobby()
	-- acampamento de fantasia (estilo desenho): sol de fim de tarde, mais baixo e quente, que faz
	-- as árvores e as construções jogarem sombras compridas e bem marcadas no chão. A luz do céu
	-- (ambiente) é baixa para não apagar as sombras, e o brilho (bloom) é fraco: só o que é muito
	-- claro brilha um pouco.
	masmorraAtiva = false
	Lighting.ClockTime = 16.3
	Lighting.Brightness = 3.4
	Lighting.Ambient = Color3.fromRGB(96, 96, 118)
	Lighting.OutdoorAmbient = Color3.fromRGB(124, 128, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 222, 176)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.ExposureCompensation = 0.1
	Lighting.ShadowSoftness = 0.12
	atmosfera.Density = 0.24
	atmosfera.Offset = 0.1
	atmosfera.Color = Color3.fromRGB(214, 226, 255)
	atmosfera.Decay = Color3.fromRGB(150, 180, 255)
	atmosfera.Glare = 0
	atmosfera.Haze = 0.2
	bloom.Intensity = 0.15
	bloom.Size = 16
	bloom.Threshold = 2.2
	cores.Brightness = 0
	cores.Contrast = CONTRASTE
	cores.Saturation = SATURACAO
	cores.TintColor = Color3.fromRGB(255, 248, 236)
	raiosDeSol.Intensity = 0.07
	raiosDeSol.Spread = 0.5
	foco.FocusDistance = 30
	foco.InFocusRadius = 50
	foco.FarIntensity = 0.08
	foco.NearIntensity = 0
	musicaDoLobby(true)
end

-- Masmorra: escura (noite, salas sem teto), mas com luz de qualidade: tochas fortes com sombras
-- marcadas, névoa colorida do tema, cores vivas e brilho forte em tudo que acende (tochas,
-- magias, efeitos). A luz ambiente é baixa, só o suficiente para enxergar a sala.

function Ambiente.masmorra(tema)
	masmorraAtiva = true
	musicaDoLobby(false)
	Lighting.ClockTime = 0
	Lighting.Brightness = tema.brilho or 0.6
	Lighting.ColorShift_Top = Color3.new(0, 0, 0) -- (o tom quente é só do acampamento)
	Lighting.Ambient = tema.ambiente:Lerp(tema.luz, 0.15)
	Lighting.OutdoorAmbient = tema.ambiente:Lerp(Color3.new(0, 0, 0), 0.1)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.ExposureCompensation = 0
	Lighting.ShadowSoftness = 0.25
	atmosfera.Density = tema.densidade or 0.4
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
