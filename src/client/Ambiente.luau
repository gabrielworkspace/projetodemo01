-- Iluminação e pós-processamento: fim de tarde dourado no acampamento, escuridão com
-- névoa colorida na masmorra. Também faz as chamas tremularem e os objetos girarem.

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

local function animar(objeto: Instance, duracao: number, propriedades)
	TweenService:Create(objeto, TweenInfo.new(duracao, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), propriedades):Play()
end

function Ambiente.lobby()
	Lighting.ClockTime = 17.2
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(96, 84, 96)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 132, 126)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	atmosfera.Density = 0.3
	atmosfera.Offset = 0.25
	atmosfera.Color = Color3.fromRGB(255, 212, 168)
	atmosfera.Decay = Color3.fromRGB(122, 92, 112)
	atmosfera.Glare = 0.35
	atmosfera.Haze = 1.6
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.4
	cores.Brightness = 0.02
	cores.Contrast = 0.12
	cores.Saturation = 0.14
	cores.TintColor = Color3.fromRGB(255, 244, 230)
	raiosDeSol.Intensity = 0.06
	raiosDeSol.Spread = 0.6
end

function Ambiente.masmorra(tema)
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.8
	Lighting.Ambient = tema.ambiente
	Lighting.OutdoorAmbient = tema.ambiente:Lerp(Color3.new(0, 0, 0), 0.2)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.6
	atmosfera.Density = 0.42
	atmosfera.Offset = 0
	atmosfera.Color = tema.nevoa:Lerp(Color3.new(1, 1, 1), 0.12)
	atmosfera.Decay = tema.nevoa
	atmosfera.Glare = 0
	atmosfera.Haze = 2.4
	bloom.Intensity = 1.1
	bloom.Size = 24
	bloom.Threshold = 0.9
	cores.Brightness = 0
	cores.Contrast = 0.18
	cores.Saturation = 0.06
	cores.TintColor = tema.tinta
	raiosDeSol.Intensity = 0
end

-- Tela sem cor enquanto o jogador está caído
function Ambiente.caido(ligar: boolean)
	animar(cores, 0.5, { Saturation = if ligar then -0.85 else 0.06, Contrast = if ligar then 0.3 else 0.18 })
end

------------------------------------------------------------------------
-- Chamas tremulando e objetos girando (só no computador do jogador)
------------------------------------------------------------------------

local chamas = {} -- [PointLight] = { brilho, semente }
local giratorios = {} -- [Model] = pivô original

local function adicionarChama(luz: Instance)
	if luz:IsA("PointLight") then
		chamas[luz] = { brilho = luz.Brightness, semente = math.random() * 100 }
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
