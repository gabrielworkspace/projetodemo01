-- Efeitos visuais desenhados no computador do jogador: cortes, projéteis, explosões,
-- avisos de ataque no chão, números de dano, moedas e tremor da câmera.
-- O servidor manda { t = "tipo", ... } e Vfx.receber chama a função certa.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local UI = require(script.Parent.UI)
local Sons = require(script.Parent.Sons)
local VfxKit = require(script.Parent.VfxKit)
local soltar = VfxKit.soltar

local Vfx = {}
Vfx.extras = {} -- outros módulos podem registrar efeitos aqui (ex.: salto dos inimigos)
Vfx.aoDanoLocal = nil :: ((number) -> ())?
Vfx.aoJogadorAtingido = nil :: ((any) -> ())?

local jogador = Players.LocalPlayer
local terreno = workspace.Terrain
local pasta = Instance.new("Folder")
pasta.Name = "EfeitosLocais"
pasta.Parent = workspace

local EM_PE = CFrame.Angles(0, 0, math.rad(90))
local BRANCO = Color3.new(1, 1, 1)
local VERMELHO = Color3.fromRGB(255, 60, 50)
local FOGO = Color3.fromRGB(255, 130, 40)

------------------------------------------------------------------------
-- Ajudantes
------------------------------------------------------------------------

local function animar(objeto: Instance, duracao: number, propriedades, estilo: Enum.EasingStyle?, direcao: Enum.EasingDirection?)
	local tween = TweenService:Create(objeto, TweenInfo.new(duracao, estilo or Enum.EasingStyle.Quad, direcao or Enum.EasingDirection.Out), propriedades)
	tween:Play()
	return tween
end

local function parte(tamanho: Vector3, cframe: CFrame, cor: Color3, transparencia: number?, formato: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Neon
	p.Shape = formato or Enum.PartType.Block
	p.Size = tamanho
	p.CFrame = cframe
	p.Color = cor
	p.Transparency = transparencia or 0
	p.Parent = pasta
	return p
end

local function sequencia(pontos): NumberSequence
	local chaves = {}
	for _, ponto in pontos do
		table.insert(chaves, NumberSequenceKeypoint.new(ponto[1], ponto[2]))
	end
	return NumberSequence.new(chaves)
end

local function ancora(posicao: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = posicao
	a.Parent = terreno
	return a
end

--[[ Explosão de partículas num ponto. opcoes: cor, cor2, quantidade, tamanho, velocidade,
	vida, espalhar, gravidade, arrasto ]]
local function particulas(posicao: Vector3, opcoes)
	local a = ancora(posicao)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(opcoes.cor or BRANCO, opcoes.cor2 or opcoes.cor or BRANCO)
	e.LightEmission = opcoes.luz or 1
	e.LightInfluence = 0
	e.Size = sequencia({ { 0, opcoes.tamanho or 0.5 }, { 1, 0 } })
	e.Transparency = sequencia({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } })
	local vida = opcoes.vida or 0.5
	e.Lifetime = NumberRange.new(vida * 0.6, vida)
	local velocidade = opcoes.velocidade or 15
	e.Speed = NumberRange.new(velocidade * 0.5, velocidade)
	e.SpreadAngle = opcoes.espalhar or Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -(opcoes.gravidade or 0), 0)
	e.Drag = opcoes.arrasto or 3
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Rate = 0
	e.EmissionDirection = opcoes.direcao or Enum.NormalId.Top
	e.Parent = a
	e:Emit(opcoes.quantidade or 12)
	Debris:AddItem(a, vida + 0.2)
end

local function clarao(posicao: Vector3, cor: Color3, alcance: number, duracao: number, brilho: number?)
	local a = ancora(posicao)
	local l = Instance.new("PointLight")
	l.Color = cor
	l.Range = alcance
	l.Brightness = brilho or 4
	l.Parent = a
	animar(l, duracao, { Brightness = 0 })
	Debris:AddItem(a, duracao + 0.1)
end

-- Disco deitado no chão
local function disco(centro: Vector3, diametro: number, cor: Color3, transparencia: number, espessura: number?): Part
	return parte(Vector3.new(espessura or 0.15, diametro, diametro), CFrame.new(centro) * EM_PE, cor, transparencia, Enum.PartType.Cylinder)
end

-- Anel feito de segmentos (um círculo vazado)
local function anel(centro: Vector3, raio: number, cor: Color3, transparencia: number, segmentos: number?, largura: number?): { BasePart }
	local lista: { BasePart } = {}
	local n = segmentos or 24
	local comprimento = 2 * math.pi * raio / n * 1.05
	for i = 1, n do
		local angulo = i / n * math.pi * 2
		local pos = centro + Vector3.new(math.cos(angulo) * raio, 0, math.sin(angulo) * raio)
		local p = parte(Vector3.new(largura or 0.35, 0.16, comprimento), CFrame.lookAt(pos, centro) * CFrame.Angles(0, math.rad(90), 0), cor, transparencia)
		table.insert(lista, p)
	end
	return lista
end

local function sumir(partes: { BasePart }, duracao: number, depois: number?)
	task.delay(depois or 0, function()
		for _, p in partes do
			if p.Parent then
				animar(p, duracao, { Transparency = 1 })
				Debris:AddItem(p, duracao + 0.05)
			end
		end
	end)
end

local function raizDoJogador(player: any): BasePart?
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return nil
	end
	local personagem = player.Character
	return personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
end

------------------------------------------------------------------------
-- Tremor da câmera
------------------------------------------------------------------------

local tremorForca, tremorFim, tremorDuracao = 0, 0, 1

function Vfx.tremer(forca: number, duracao: number)
	local agora = os.clock()
	local restante = if agora < tremorFim then tremorForca * (tremorFim - agora) / tremorDuracao else 0
	if forca >= restante then
		tremorForca = forca
		tremorDuracao = duracao
		tremorFim = agora + duracao
	end
end

-- Tremor que enfraquece com a distância
function Vfx.tremerEm(posicao: Vector3, forca: number, duracao: number)
	local raiz = raizDoJogador(jogador)
	if not raiz then
		return
	end
	local distancia = (raiz.Position - posicao).Magnitude
	local fator = math.clamp(1 - distancia / 70, 0, 1)
	if fator > 0 then
		Vfx.tremer(forca * fator, duracao)
	end
end

RunService:BindToRenderStep("TremorDaCamera", Enum.RenderPriority.Camera.Value + 1, function()
	local agora = os.clock()
	if agora >= tremorFim then
		return
	end
	local camera = workspace.CurrentCamera
	local i = tremorForca * (tremorFim - agora) / tremorDuracao
	local function r()
		return (math.random() - 0.5) * 2
	end
	camera.CFrame *= CFrame.new(r() * i * 0.12, r() * i * 0.12, 0) * CFrame.Angles(r() * i * 0.006, r() * i * 0.006, r() * i * 0.004)
end)

------------------------------------------------------------------------
-- Corte de espada: um arco curvo (Beam) que "varre" da esquerda para a direita
------------------------------------------------------------------------

local function transparenciaDeVarredura(cabeca: number, cauda: number, minima: number): NumberSequence
	local chaves = {}
	for i = 0, 9 do
		local x = i / 9
		local valor = 1
		if x <= cabeca and x >= cabeca - cauda then
			valor = minima + (1 - minima) * ((cabeca - x) / cauda)
		end
		table.insert(chaves, NumberSequenceKeypoint.new(x, math.clamp(valor, 0, 1)))
	end
	return NumberSequence.new(chaves)
end

-- Posiciona dois Attachments para que um Beam entre eles desenhe um arco de círculo
local function posicionarArco(a0: Attachment, a1: Attachment, feixes: { Beam }, origem: CFrame, raio: number, arcoGraus: number)
	local meio = math.rad(arcoGraus) / 2
	local function ponto(phi: number)
		local local_ = Vector3.new(-raio * math.sin(phi), 0, -raio * math.cos(phi))
		local tangente = Vector3.new(math.cos(phi), 0, -math.sin(phi))
		return origem:PointToWorldSpace(local_), origem:VectorToWorldSpace(tangente)
	end
	local p0, t0 = ponto(meio)
	local p1, t1 = ponto(-meio)
	a0.WorldCFrame = CFrame.fromMatrix(p0, t0, Vector3.yAxis)
	a1.WorldCFrame = CFrame.fromMatrix(p1, t1, Vector3.yAxis)
	local controle = 4 / 3 * math.tan(math.rad(arcoGraus) / 4) * raio
	for _, feixe in feixes do
		feixe.CurveSize0 = controle
		feixe.CurveSize1 = controle
	end
end

local function novoFeixe(a0: Attachment, a1: Attachment, cor: Color3, largura: number): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(cor)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 24
	b.Width0 = largura
	b.Width1 = largura
	b.Transparency = NumberSequence.new(1)
	b.Parent = a0
	return b
end

--[[ origem: CFrame na altura do peito, olhando para onde o golpe vai
	opcoes: espessura, duracao, reverso (varre da direita para a esquerda) ]]
local function arcoDeCorte(origem: CFrame, raio: number, arcoGraus: number, cor: Color3, opcoes)
	opcoes = opcoes or {}
	local espessura = opcoes.espessura or 1
	local duracao = opcoes.duracao or 0.16
	if opcoes.reverso then
		origem = origem * CFrame.Angles(0, 0, math.pi) -- espelha o arco
	end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent = terreno
	a1.Parent = terreno
	local nucleo = novoFeixe(a0, a1, cor:Lerp(BRANCO, 0.55), 0.7 * espessura)
	local aura = novoFeixe(a0, a1, cor, 2.4 * espessura)
	-- bordas suaves: parece energia, não uma faixa sólida
	aura.TextureMode = Enum.TextureMode.Stretch
	VfxKit.texturaFeixe(aura, "rastro", VfxKit.TEX.luz)
	local brilhoExterno = novoFeixe(a0, a1, cor, 4.2 * espessura)
	brilhoExterno.TextureMode = Enum.TextureMode.Stretch
	VfxKit.texturaFeixe(brilhoExterno, "rastro", VfxKit.TEX.luz)
	posicionarArco(a0, a1, { nucleo, aura }, origem, raio, arcoGraus)

	local inicio = os.clock()
	local conexao
	conexao = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - inicio) / duracao
		local cabeca = t * 1.45
		nucleo.Transparency = transparenciaDeVarredura(cabeca, 0.45, 0)
		aura.Transparency = transparenciaDeVarredura(cabeca, 0.55, 0.3)
		brilhoExterno.Transparency = transparenciaDeVarredura(cabeca, 0.7, 0.7)
		if cabeca > 1.6 then
			conexao:Disconnect()
			a0:Destroy()
			a1:Destroy()
		end
	end)
	-- faíscas na ponta do arco
	local fim = origem:PointToWorldSpace(Vector3.new(raio * math.sin(math.rad(arcoGraus) / 2), 0, -raio * math.cos(math.rad(arcoGraus) / 2)))
	task.delay(duracao * 0.6, function()
		soltar(fim, "faiscas", { cor = cor, quantidade = math.floor(10 * espessura), escala = 0.7 })
		local meio = origem:PointToWorldSpace(Vector3.new(0, 0, -raio * 0.85))
		soltar(meio, "corte", { cor = cor, quantidade = 1, escala = raio / 6 * espessura })
		soltar(fim, "brasas", { cor = cor, quantidade = 6, escala = 0.6 })
	end)
end

------------------------------------------------------------------------
-- Efeitos prontos montados no Studio (plugin VFX Studio ou qualquer outro)
------------------------------------------------------------------------
--[[ Coloque o efeito em ReplicatedStorage > EfeitosVFX com um destes nomes e ele toca sozinho
	na hora certa (veja "Efeitos do plugin" em COMO_USAR.md):
	  CorteCavaleiro, CorteGiratorio, Tornado, CargaCavaleiro, EscudoErguido, DefesaPerfeita, Julgamento
	  (a lista completa de cada classe está em vfx/LEIA-ME.md)
	Pode ser uma Part, um Model ou um Attachment com ParticleEmitters, Beams e Trails dentro.
	Atributos opcionais:
	  no efeito:            Duracao (segundos), Substituir (true = esconde o efeito feito por código)
	  em cada ParticleEmitter: EmitCount (solta essa quantidade de uma vez) e EmitDelay (espera antes);
	                        sem EmitCount, o emissor fica ligado enquanto o efeito durar ]]

local function prefabDe(nome: string): Instance?
	local efeitos = ReplicatedStorage:FindFirstChild("EfeitosVFX")
	return if efeitos then efeitos:FindFirstChild(nome) else nil
end

-- Existe um efeito pronto com esse nome que substitui o feito por código?
function Vfx.temPrefab(nome: string): boolean
	local modelo = prefabDe(nome)
	return modelo ~= nil and modelo:GetAttribute("Substituir") == true
end

--[[ Toca um efeito pronto. "onde" é um CFrame fixo ou uma função que devolve o CFrame a cada
	quadro (para acompanhar algo; devolver nil termina o efeito). "duracao" 0 = até alguém parar.
	"escala" aumenta o tamanho das partículas (para combinar com o alcance do golpe).
	Devolve a função que para o efeito, ou nil se ele não existe. ]]
function Vfx.prefab(nome: string, onde: any, duracao: number?, escala: number?): (() -> ())?
	local modelo = prefabDe(nome)
	if not modelo then
		return nil
	end
	local seguir = if type(onde) == "function" then onde else nil
	local cframeInicial: CFrame? = if seguir then seguir() else onde
	if typeof(cframeInicial) ~= "CFrame" then
		return nil
	end
	local copia = modelo:Clone()
	local todos = copia:GetDescendants()
	table.insert(todos, copia)

	-- peças de dentro (ex.: rachadura no chão) acompanham a peça principal na mesma posição relativa
	local filhas = {}
	if copia:IsA("BasePart") then
		for _, objeto in todos do
			if objeto ~= copia and objeto:IsA("BasePart") then
				table.insert(filhas, { objeto, copia.CFrame:ToObjectSpace(objeto.CFrame) })
			end
		end
	end
	local function posicionar(cf: CFrame)
		if copia:IsA("Attachment") then
			copia.WorldCFrame = cf
		elseif copia:IsA("BasePart") then
			copia.CFrame = cf
			for _, filha in filhas do
				filha[1].CFrame = cf * filha[2]
			end
		elseif copia:IsA("Model") then
			copia:PivotTo(cf)
		end
	end

	local ligados = {}
	local maiorVida = 0
	for _, objeto in todos do
		if objeto:IsA("BasePart") then
			objeto.Anchored = true
			objeto.CanCollide = false
			objeto.CanQuery = false
			objeto.CanTouch = false
		elseif objeto:IsA("ParticleEmitter") then
			if escala and escala ~= 1 then
				local chaves = {}
				for _, chave in objeto.Size.Keypoints do
					table.insert(chaves, NumberSequenceKeypoint.new(chave.Time, chave.Value * escala, chave.Envelope * escala))
				end
				objeto.Size = NumberSequence.new(chaves)
				objeto.Speed = NumberRange.new(objeto.Speed.Min * escala, objeto.Speed.Max * escala)
			end
			maiorVida = math.max(maiorVida, objeto.Lifetime.Max)
			local quantidade = objeto:GetAttribute("EmitCount")
			local espera = objeto:GetAttribute("EmitDelay")
			local janela = objeto:GetAttribute("EmitDuration")
			espera = if type(espera) == "number" then espera else 0
			if type(janela) == "number" and janela > 0 then
				-- liga por um tempo e desliga
				objeto.Enabled = false
				task.delay(espera, function()
					if objeto.Parent then
						objeto.Enabled = true
						task.delay(janela, function()
							objeto.Enabled = false
						end)
					end
				end)
			elseif type(quantidade) == "number" then
				objeto.Enabled = false
				if quantidade > 0 then
					task.delay(espera, function()
						if objeto.Parent then
							objeto:Emit(quantidade)
						end
					end)
				end
			elseif objeto.Enabled then
				table.insert(ligados, objeto)
			end
		elseif objeto:IsA("Beam") or objeto:IsA("Trail") then
			table.insert(ligados, objeto)
		end
	end
	copia.Parent = if copia:IsA("Attachment") then terreno else pasta
	posicionar(cframeInicial :: CFrame)
	-- sons que vêm dentro do efeito (alguns pacotes trazem o próprio som) tocam junto
	for _, objeto in todos do
		if objeto:IsA("Sound") then
			objeto.SoundGroup = nil
			objeto:Play()
		end
	end

	local parado = false
	local function parar()
		if parado then
			return
		end
		parado = true
		for _, objeto in ligados do
			(objeto :: any).Enabled = false
		end
		Debris:AddItem(copia, maiorVida + 0.5)
	end
	if seguir then
		local conexao
		conexao = RunService.RenderStepped:Connect(function()
			if parado or not copia.Parent then
				conexao:Disconnect()
				return
			end
			local cf = seguir()
			if cf then
				posicionar(cf)
			else
				conexao:Disconnect()
				parar()
			end
		end)
	end
	local tempo = duracao or modelo:GetAttribute("Duracao") or 1.5
	if type(tempo) == "number" and tempo > 0 then
		task.delay(tempo, parar)
	end
	return parar
end

------------------------------------------------------------------------
-- Cavaleiro: cortes em meia-lua, giro de 360° e funil de vento
------------------------------------------------------------------------

local OURO = Color3.fromRGB(255, 214, 90)
local POEIRA = Color3.fromRGB(205, 190, 165)
local TEXTURA_FUMACA = "rbxasset://textures/particles/smoke_main.dds"

-- Altura do chão embaixo do personagem
local function chaoDe(raiz: BasePart, humanoid: Humanoid?): number
	local altura = if humanoid then humanoid.HipHeight + raiz.Size.Y / 2 else 3
	return raiz.Position.Y - altura
end

--[[ Funil de vento (tornado): faixas curvas em vários andares, mais largas em cima, cada uma
	girando numa velocidade, com a ponta grossa e brilhante na frente do giro.
	"atualizar(centro, t, escala)" põe o funil no lugar a cada quadro (centro = no chão). ]]
local function funil(raio: number, altura: number, cor: Color3, andares: number, transparencia: number, corExtra: Color3?)
	local faixas = {}
	for i = 1, andares do
		local k = if andares > 1 then (i - 1) / (andares - 1) else 0
		for lado = 0, 2 do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent = terreno
			a1.Parent = terreno
			local corFaixa = if lado == 0 then cor:Lerp(BRANCO, 0.6) elseif lado == 1 then cor else (corExtra or cor:Lerp(BRANCO, 0.25))
			local largura = (0.5 + 1.5 * k) * (if lado == 0 then 0.7 else 1.2)
			local feixe = novoFeixe(a0, a1, corFaixa, largura)
			feixe.Width0 = largura
			feixe.Width1 = largura * 0.15
			local base = transparencia + (if lado == 0 then 0 else 0.15)
			feixe.Transparency = sequencia({ { 0, base }, { 0.45, base + 0.15 }, { 1, 1 } })
			table.insert(faixas, {
				a0 = a0,
				a1 = a1,
				feixes = { feixe },
				raio = raio * (0.28 + 0.72 * k ^ 0.85),
				altura = altura * (0.04 + 0.96 * k),
				velocidade = 15 - 6 * k + lado * 0.7,
				fase = lado * math.pi * 2 / 3 + i * 1.3,
				arco = 150 - 40 * k,
				inclinacao = math.rad(if lado == 2 then -10 else 7),
			})
		end
	end
	local objeto = {}
	function objeto.atualizar(centro: Vector3, t: number, escala: number)
		for _, f in faixas do
			local origem = CFrame.new(centro + Vector3.new(0, f.altura * escala, 0))
				* CFrame.Angles(0, f.fase + t * f.velocidade, 0)
				* CFrame.Angles(f.inclinacao, 0, 0)
			posicionarArco(f.a0, f.a1, f.feixes, origem, math.max(0.3, f.raio * escala), f.arco)
		end
	end
	function objeto.parar(duracao: number)
		for _, f in faixas do
			for _, feixe in f.feixes do
				local inicio = feixe.Transparency
				local tempo = os.clock()
				local conexao
				conexao = RunService.RenderStepped:Connect(function()
					local k = math.clamp((os.clock() - tempo) / duracao, 0, 1)
					local chaves = {}
					for _, chave in inicio.Keypoints do
						table.insert(chaves, NumberSequenceKeypoint.new(chave.Time, chave.Value + (1 - chave.Value) * k))
					end
					feixe.Transparency = NumberSequence.new(chaves)
					if k >= 1 then
						conexao:Disconnect()
					end
				end)
			end
			Debris:AddItem(f.a0, duracao + 0.1)
			Debris:AddItem(f.a1, duracao + 0.1)
		end
	end
	return objeto
end

-- Riscos de faísca: partículas esticadas na direção em que voam
local function riscos(posicao: Vector3, cor: Color3, quantidade: number, velocidade: number, direcao: Vector3?)
	local a = ancora(posicao)
	if direcao and direcao.Magnitude > 0.01 then
		a.WorldCFrame = CFrame.lookAt(posicao, posicao + direcao) * CFrame.Angles(math.rad(-90), 0, 0)
	end
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(BRANCO, cor)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Squash = sequencia({ { 0, 2.6 }, { 1, 1.2 } })
	e.Size = sequencia({ { 0, 0.22 }, { 1, 0 } })
	e.Lifetime = NumberRange.new(0.18, 0.35)
	e.Speed = NumberRange.new(velocidade * 0.5, velocidade)
	e.SpreadAngle = if direcao then Vector2.new(35, 35) else Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.Parent = a
	e:Emit(quantidade)
	Debris:AddItem(a, 0.5)
end

-- Poeira subindo e se espalhando pelo chão (fumaça do próprio Roblox)
local function poeiraNoChao(posicao: Vector3, raio: number, quantidade: number)
	local a = ancora(posicao)
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEXTURA_FUMACA
	e.Color = ColorSequence.new(POEIRA)
	e.LightInfluence = 1
	e.Transparency = sequencia({ { 0, 0.45 }, { 1, 1 } })
	e.Size = sequencia({ { 0, raio * 0.25 }, { 1, raio * 0.55 } })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(raio * 1.5, raio * 2.6)
	e.Drag = 5
	e.SpreadAngle = Vector2.new(8, 180)
	e.EmissionDirection = Enum.NormalId.Right
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rate = 0
	e.Parent = a
	e:Emit(quantidade)
	Debris:AddItem(a, 1.1)
end

-- Meia-lua de corte: o arco é dividido em duas metades, finas nas pontas e grossas no meio,
-- com núcleo claro, corpo na cor da classe e um brilho largo por fora
local function crescente(origem: CFrame, raio: number, arcoGraus: number, cor: Color3, opcoes)
	opcoes = opcoes or {}
	local espessura = opcoes.espessura or 1
	local duracao = opcoes.duracao or 0.14
	if opcoes.reverso then
		origem = origem * CFrame.Angles(0, 0, math.pi)
	end
	local a0, am, a1 = Instance.new("Attachment"), Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent = terreno
	am.Parent = terreno
	a1.Parent = terreno
	local camadas = {
		{ cor = cor:Lerp(BRANCO, 0.8), largura = 0.8, minima = 0 },
		{ cor = cor:Lerp(BRANCO, 0.25), largura = 2.2, minima = 0.05 },
		{ cor = cor, largura = 4.6, minima = 0.45 },
	}
	local metade1, metade2 = {}, {}
	for _, c in camadas do
		local f1 = novoFeixe(a0, am, c.cor, c.largura * espessura)
		f1.Width0 = c.largura * espessura * 0.08
		local f2 = novoFeixe(am, a1, c.cor, c.largura * espessura)
		f2.Width1 = c.largura * espessura * 0.08
		table.insert(metade1, { f1, c.minima })
		table.insert(metade2, { f2, c.minima })
	end
	local quarto = math.rad(arcoGraus) / 4
	local function feixesDe(lista)
		local saida = {}
		for _, item in lista do
			table.insert(saida, item[1])
		end
		return saida
	end
	posicionarArco(a0, am, feixesDe(metade1), origem * CFrame.Angles(0, quarto, 0), raio, arcoGraus / 2)
	posicionarArco(am, a1, feixesDe(metade2), origem * CFrame.Angles(0, -quarto, 0), raio, arcoGraus / 2)

	local inicio = os.clock()
	local conexao
	conexao = RunService.RenderStepped:Connect(function()
		local cabeca = (os.clock() - inicio) / duracao * 1.5
		for _, item in metade1 do
			item[1].Transparency = transparenciaDeVarredura(cabeca * 2, 1.1, item[2])
		end
		for _, item in metade2 do
			item[1].Transparency = transparenciaDeVarredura(cabeca * 2 - 1, 1.1, item[2])
		end
		if cabeca > 1.75 then
			conexao:Disconnect()
			a0:Destroy()
			am:Destroy()
			a1:Destroy()
		end
	end)
	-- faíscas saindo da ponta do corte, na direção em que a lâmina ia
	local fimLocal = Vector3.new(raio * math.sin(math.rad(arcoGraus) / 2), 0, -raio * math.cos(math.rad(arcoGraus) / 2))
	local tangente = Vector3.new(math.cos(math.rad(arcoGraus) / 2), 0, math.sin(math.rad(arcoGraus) / 2))
	task.delay(duracao * 0.7, function()
		riscos(origem:PointToWorldSpace(fimLocal), cor, 8, 34, origem:VectorToWorldSpace(tangente))
	end)
end

-- Cortes 1 e 2 do Cavaleiro: meia-lua larga + eco por dentro + clarão na frente
local function corteCavaleiro(origem: CFrame, raio: number, arcoGraus: number, cor: Color3, reverso: boolean, fogo: boolean?)
	-- o corte do pacote, visto de cima, varre ao contrário do nosso arco: espelha no golpe que
	-- não é "reverso" para acompanhar a lâmina. Com poder de fogo, o corte é de fogo.
	local espelho = if reverso then CFrame.identity else CFrame.Angles(0, 0, math.pi)
	local nome = if fogo and Vfx.temPrefab("CorteCavaleiroFogo") then "CorteCavaleiroFogo" else "CorteCavaleiro"
	if fogo then
		cor = FOGO
	end
	local substituir = Vfx.temPrefab(nome)
	Vfx.prefab(nome, origem * espelho, nil, raio / 5)
	if substituir then
		return
	end
	crescente(origem, raio, arcoGraus, cor, { espessura = 1.6, duracao = 0.17, reverso = reverso })
	task.delay(0.03, function()
		crescente(origem * CFrame.new(0, -0.4, 0), raio * 0.72, arcoGraus * 0.85, cor, { espessura = 0.9, duracao = 0.19, reverso = reverso })
	end)
	clarao(origem.Position + origem.LookVector * raio * 0.6, cor, 12, 0.15, 3)
end

-- Golpe final do Cavaleiro: corte de 360° em quatro partes seguidas, onda no chão e poeira
local function corteGiratorio(base: Vector3, direcao: Vector3, raio: number, cor: Color3, chao: number, fogo: boolean?)
	Vfx.tremerEm(base, 0.9, 0.18)
	local nome = if fogo and Vfx.temPrefab("CorteGiratorioFogo") then "CorteGiratorioFogo" else "CorteGiratorio"
	if fogo then
		cor = FOGO
	end
	local substituir = Vfx.temPrefab(nome)
	Vfx.prefab(nome, CFrame.lookAt(base, base + direcao), nil, raio / 4)
	if substituir then
		return
	end
	local origem = CFrame.lookAt(base, base + direcao) * CFrame.Angles(0, 0, math.rad(-6))
	for k = 0, 3 do
		task.delay(k * 0.04, function()
			crescente(origem * CFrame.Angles(0, k * math.pi / 2, 0), raio, 105, cor, { espessura = 1.9, duracao = 0.11, reverso = true })
		end)
	end
	local centroChao = Vector3.new(base.X, chao + 0.15, base.Z)
	local onda = disco(centroChao, 2, cor:Lerp(BRANCO, 0.3), 0.35)
	animar(onda, 0.35, { Size = Vector3.new(0.12, raio * 2.3, raio * 2.3), Transparency = 1 })
	Debris:AddItem(onda, 0.4)
	poeiraNoChao(centroChao + Vector3.new(0, 0.4, 0), raio, 18)
	riscos(base, cor, 18, 40)
	clarao(base, cor, raio * 2.5, 0.3, 4)
end

function Vfx.corte(dados)
	local raiz = raizDoJogador(dados.jogador)
	local base = if raiz then raiz.Position else dados.pos
	local direcao = dados.dir
	local origem = CFrame.lookAt(base, base + direcao)
	local combo = dados.combo or 1
	local final = combo == 3
	local raio = dados.alcance * 0.8
	if dados.cavaleiro then
		if dados.giro then
			local chao = if raiz then raiz.Position.Y - 3 else base.Y - 3
			corteGiratorio(base, direcao, raio, dados.cor, chao, dados.fogo)
		else
			local inclinacao = if combo == 2 then CFrame.Angles(0, 0, math.rad(10)) else CFrame.Angles(0, 0, math.rad(-8))
			corteCavaleiro(origem * inclinacao, raio, dados.arco, dados.cor, combo ~= 2, dados.fogo)
		end
		if dados.jogador == jogador then
			Vfx.tremer(if dados.giro then 0.9 else 0.35, 0.1)
		end
	elseif dados.assassino and Vfx.temPrefab("CorteAdaga") then
		if final then
			-- X de cortes e faíscas no chão à frente, onde as duas adagas descem
			local chao = (if raiz then raiz.Position.Y else base.Y) - 2.6
			local frente = base + direcao * raio * 0.6
			Vfx.prefab("CorteFinalAdaga", CFrame.new(frente.X, chao + 0.3, frente.Z), nil, 0.45)
			Vfx.tremerEm(base, 0.6, 0.12)
		else
			-- rajada de cortes no ar, onde a adaga passou
			Vfx.prefab("CorteAdaga", CFrame.new(base + direcao * raio * 0.55 + Vector3.new(0, 0.3, 0)), nil, 0.55)
		end
	elseif final then
		arcoDeCorte(origem * CFrame.Angles(0, 0, math.rad(-12)), raio, dados.arco, dados.cor, { espessura = 1.6, duracao = 0.2 })
		arcoDeCorte(origem * CFrame.new(0, -0.6, 0), raio * 0.75, dados.arco, dados.cor, { espessura = 1, duracao = 0.22 })
		local frente = base + direcao * raio * 0.8
		particulas(frente, { cor = dados.cor, cor2 = BRANCO, quantidade = 16, tamanho = 0.6, velocidade = 22, vida = 0.4 })
		local onda = disco(Vector3.new(base.X, base.Y - 2.6, base.Z) + direcao * 3, 2, dados.cor, 0.4)
		animar(onda, 0.3, { Size = Vector3.new(0.15, raio * 2, raio * 2), Transparency = 1 })
		Debris:AddItem(onda, 0.35)
		Vfx.tremerEm(base, 0.8, 0.15)
	else
		local inclinacao = if combo == 2 then CFrame.Angles(0, 0, math.rad(18)) else CFrame.Angles(0, 0, math.rad(-8))
		arcoDeCorte(origem * inclinacao, raio, dados.arco, dados.cor, { reverso = combo == 2 })
	end
end

------------------------------------------------------------------------
-- Chefes com efeitos prontos dos pacotes (o servidor manda o "tipo" do chefe)
------------------------------------------------------------------------

local EFEITOS_CHEFE = {
	reiEsqueleto = { giro = "GiroRei", golpe = "GolpeRei", salto = "SaltoRei", invocacao = "TumuloRei", furia = "RugidoFuria" },
}

-- Chão logo abaixo de um ponto (ignora jogadores, inimigos e efeitos)
local function chaoAbaixo(posicao: Vector3): Vector3
	local parametros = RaycastParams.new()
	parametros.FilterType = Enum.RaycastFilterType.Exclude
	local ignorar: { Instance } = { pasta }
	local visuais = workspace:FindFirstChild("InimigosVisuais")
	if visuais then
		table.insert(ignorar, visuais)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignorar, player.Character)
		end
	end
	for _, inimigo in game:GetService("CollectionService"):GetTagged("Inimigo") do
		table.insert(ignorar, inimigo)
	end
	parametros.FilterDescendantsInstances = ignorar
	local acerto = workspace:Raycast(posicao + Vector3.new(0, 2, 0), Vector3.new(0, -25, 0), parametros)
	return if acerto then acerto.Position else posicao - Vector3.new(0, 3, 0)
end

-- Servos do chefe subindo: o chão racha e sobe névoa
function Vfx.invocacao(dados)
	local efeitos = EFEITOS_CHEFE[dados.tipo or ""]
	if efeitos and Vfx.temPrefab(efeitos.invocacao) then
		Vfx.prefab(efeitos.invocacao, CFrame.new(dados.pos), nil, 1.2)
		Sons.tocar("pouso", { pos = dados.pos, tom = 0.55, volume = 0.8 })
	end
end

function Vfx.golpeInimigo(dados)
	local efeitos = EFEITOS_CHEFE[dados.tipo or ""]
	if efeitos then
		if dados.arco >= 360 and Vfx.temPrefab(efeitos.giro) then
			-- giro com o espadão: anel de cortes em volta, rente ao chão
			local chao = chaoAbaixo(dados.pos)
			Vfx.prefab(efeitos.giro, CFrame.new(chao + Vector3.new(0, 1.5, 0)), nil, dados.alcance * 0.9)
			Sons.tocar("giro", { pos = dados.pos, tom = 0.7, volume = 1.2 })
			Vfx.tremerEm(dados.pos, 1.2, 0.15)
			return
		elseif dados.arco < 360 and Vfx.temPrefab(efeitos.golpe) then
			-- golpe de cima: onda de choque onde a lâmina bate no chão
			local chao = chaoAbaixo(dados.pos + dados.dir * dados.alcance * 0.6)
			Vfx.prefab(efeitos.golpe, CFrame.new(chao + Vector3.new(0, 0.2, 0)), nil, 0.55)
			Sons.tocar("espadaPesada", { pos = chao, tom = 0.6, volume = 1.3 })
			Vfx.tremerEm(chao, 1.8, 0.25)
			return
		end
	end
	local base = dados.pos
	soltar(base - Vector3.new(0, 1.5, 0), "poeira", { cor = Color3.fromRGB(160, 140, 120), quantidade = 8, escala = 0.8 })
	if dados.arco >= 360 then
		local chao = Vector3.new(base.X, base.Y - 1.5, base.Z)
		local onda = disco(chao, 2, dados.cor, 0.25)
		animar(onda, 0.35, { Size = Vector3.new(0.15, dados.alcance * 2, dados.alcance * 2), Transparency = 1 })
		Debris:AddItem(onda, 0.4)
		for _, p in anel(chao + Vector3.new(0, 0.2, 0), dados.alcance, dados.cor, 0.2, 20, 0.6) do
			animar(p, 0.4, { Transparency = 1 })
			Debris:AddItem(p, 0.45)
		end
		Vfx.tremerEm(base, 0.6, 0.2)
	else
		local origem = CFrame.lookAt(base, base + dados.dir)
		arcoDeCorte(origem, dados.alcance * 0.85, math.min(dados.arco, 170), dados.cor, { espessura = 1.3 })
	end
end


function Vfx.rajada(dados)
	local origem = CFrame.lookAt(dados.pos, dados.pos + dados.dir)
	for _ = 1, 9 do
		local inicio = origem * CFrame.Angles(0, math.rad(math.random(-28, 28)), 0)
		local bola = parte(Vector3.one * 1.6, inicio * CFrame.new(0, 0, -2), FOGO, 0.1, Enum.PartType.Ball)
		animar(bola, 0.32, { CFrame = inicio * CFrame.new(0, 0, -dados.alcance), Size = Vector3.one * 4, Transparency = 1 })
		Debris:AddItem(bola, 0.35)
	end
	particulas(dados.pos + dados.dir * 4, { cor = Color3.fromRGB(255, 220, 120), cor2 = FOGO, quantidade = 20, velocidade = 30, vida = 0.4, espalhar = Vector2.new(30, 30) })
end

------------------------------------------------------------------------
-- Projéteis (o servidor calcula; aqui só desenhamos)
------------------------------------------------------------------------

local projeteis = {} -- [id] = { parte, pos, dir, vel, alcance, percorrido, cor, tipo }

local ESTILOS_PROJETIL = {
	orbe = { cor = Color3.fromRGB(190, 110, 255), formato = "bola", tamanho = 1.3 },
	orbeGrande = { cor = Color3.fromRGB(215, 140, 255), formato = "bola", tamanho = 1.3 },
	flecha = { cor = Color3.fromRGB(150, 255, 160), formato = "flecha", tamanho = 1 },
	flechaGrande = { cor = Color3.fromRGB(200, 255, 140), formato = "flecha", tamanho = 1 },
	fantasma = { cor = Color3.fromRGB(140, 240, 255), formato = "flecha", tamanho = 1 },
	onda = { cor = Color3.fromRGB(140, 190, 255), formato = "onda", tamanho = 1 },
	flechaOssea = { cor = Color3.fromRGB(255, 90, 80), formato = "flecha", tamanho = 1 },
	veneno = { cor = Color3.fromRGB(130, 255, 80), formato = "bola", tamanho = 1.2 },
	gelo = { cor = Color3.fromRGB(140, 220, 255), formato = "cristal", tamanho = 1.3 },
	fogo = { cor = Color3.fromRGB(255, 120, 40), formato = "bola", tamanho = 1.4, fogo = true },
	orbeCarregado = { cor = Color3.fromRGB(225, 150, 255), formato = "bola", tamanho = 1.2 },
	flechaCarregada = { cor = Color3.fromRGB(120, 255, 150), formato = "flecha", tamanho = 1 },
	adaga = { cor = Color3.fromRGB(255, 90, 120), formato = "flecha", tamanho = 0.7 },
}

local function rastro(p: BasePart, cor: Color3, largura: number, duracao: number)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, largura / 2, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -largura / 2, 0)
	a1.Parent = p
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = ColorSequence.new(cor:Lerp(BRANCO, 0.5), cor)
	t.Transparency = sequencia({ { 0, 0.15 }, { 1, 1 } })
	t.WidthScale = sequencia({ { 0, 1 }, { 1, 0 } })
	t.Lifetime = duracao
	t.LightEmission = 1
	t.LightInfluence = 0
	t.FaceCamera = true
	t.Parent = p
end

local function criarVisualProjetil(tipo: string, tamanho: number): (BasePart, Color3)
	local estilo = ESTILOS_PROJETIL[tipo] or ESTILOS_PROJETIL.orbe
	local cor = estilo.cor
	local escala = estilo.tamanho * tamanho
	local p
	if estilo.formato == "flecha" then
		p = parte(Vector3.new(0.18 * escala, 0.18 * escala, 2.6 * escala), CFrame.new(), cor, 0, nil, Enum.Material.Neon)
		rastro(p, cor, 0.35 * escala, 0.18)
	elseif estilo.formato == "onda" then
		p = parte(Vector3.new(5.5, 0.6, 1), CFrame.new(), cor, 0.2)
		rastro(p, cor, 0.6, 0.25)
	elseif estilo.formato == "cristal" then
		p = parte(Vector3.new(0.8, 0.8, 2) * escala, CFrame.new(), cor, 0.05)
		rastro(p, cor, 0.6 * escala, 0.25)
	else
		p = parte(Vector3.one * escala, CFrame.new(), cor, 0, Enum.PartType.Ball)
		rastro(p, cor, 0.9 * escala, 0.22)
		local brilho = Instance.new("ParticleEmitter")
		brilho.Color = ColorSequence.new(cor:Lerp(BRANCO, 0.4), cor)
		brilho.LightEmission = 1
		brilho.LightInfluence = 0
		brilho.Size = sequencia({ { 0, 0.35 * escala }, { 1, 0 } })
		brilho.Lifetime = NumberRange.new(0.2, 0.4)
		brilho.Speed = NumberRange.new(0.5, 2)
		brilho.SpreadAngle = Vector2.new(180, 180)
		brilho.Rate = 40
		brilho.Parent = p
	end
	if estilo.fogo then
		local f = Instance.new("Fire")
		f.Size = 2
		f.Heat = 0
		f.Parent = p
	end
	local l = Instance.new("PointLight")
	l.Color = cor
	l.Range = 8 + 4 * escala
	l.Brightness = 1.5
	l.Parent = p
	return p, cor
end

------------------------------------------------------------------------
-- Magias com visual próprio: cada uma é um conjunto de peças que se mexem juntas.
-- O construtor devolve a peça principal, a cor e uma lista de "extras":
-- { parte = BasePart, cf = function(t) -> CFrame relativo à peça principal }.
------------------------------------------------------------------------

local function emissorEm(pai: Instance, propriedades)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for chave, valor in propriedades do
		(e :: any)[chave] = valor
	end
	e.Parent = pai
	return e
end

local function luzEm(pai: Instance, cor: Color3, alcance: number, brilho: number)
	local l = Instance.new("PointLight")
	l.Color = cor
	l.Range = alcance
	l.Brightness = brilho
	l.Parent = pai
end

local function anelDeMagia(raio: number, espessura: number, cor: Color3, transparencia: number): BasePart
	-- cilindro bem fino e largo: parece um anel de energia visto de lado
	return parte(Vector3.new(espessura, raio * 2, raio * 2), CFrame.new(), cor, transparencia, Enum.PartType.Cylinder)
end

local MAGIAS = {}

-- Dardo Arcano: núcleo branco-violeta, aura, dois anéis girando em volta do caminho e faíscas
MAGIAS.dardoArcano = function(escala: number)
	local cor = Color3.fromRGB(190, 110, 255)
	local nucleo = parte(Vector3.one * 0.7 * escala, CFrame.new(), cor:Lerp(BRANCO, 0.6), 0, Enum.PartType.Ball)
	VfxKit.continuo(nucleo, "brasas", 50, { cor = cor, escala = 0.6 * escala })
	VfxKit.continuo(nucleo, "clarao", 20, { cor = cor, escala = 0.35 * escala, extra = { LockedToPart = true, Lifetime = NumberRange.new(0.1, 0.12) } })
	local aura = parte(Vector3.one * 1.5 * escala, CFrame.new(), cor, 0.55, Enum.PartType.Ball)
	local anel1 = anelDeMagia(0.9 * escala, 0.08, cor:Lerp(BRANCO, 0.3), 0.2)
	local anel2 = anelDeMagia(0.7 * escala, 0.08, cor, 0.3)
	rastro(nucleo, cor, 0.8 * escala, 0.25)
	emissorEm(nucleo, {
		Color = ColorSequence.new(BRANCO, cor),
		LightEmission = 1,
		Size = sequencia({ { 0, 0.25 * escala }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 55,
	})
	luzEm(nucleo, cor, 12, 2)
	return nucleo, cor, {
		{ parte = aura, cf = function(t)
			return CFrame.new()
		end },
		{ parte = anel1, cf = function(t)
			return CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(t * 14, 0, 0) * CFrame.Angles(0, 0, math.rad(25))
		end },
		{ parte = anel2, cf = function(t)
			return CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(-t * 18, 0, 0) * CFrame.Angles(0, math.rad(35), 0)
		end },
	}
end

-- Lança de Gelo: cristal comprido girando, com cristais menores em volta e névoa gelada
MAGIAS.lancaGelo = function(escala: number)
	local cor = Color3.fromRGB(150, 225, 255)
	local lanca = parte(Vector3.new(0.55, 0.55, 2.8) * escala, CFrame.new(), cor:Lerp(BRANCO, 0.4), 0.1, nil, Enum.Material.Glass)
	VfxKit.continuo(lanca, "brasas", 45, { cor = cor, escala = 0.6 * escala, extra = { Acceleration = Vector3.new(0, -4, 0) } })
	local brilho = parte(Vector3.new(0.25, 0.25, 3.1) * escala, CFrame.new(), cor, 0, nil, Enum.Material.Neon)
	local extras = { { parte = brilho, cf = function()
		return CFrame.new()
	end } }
	for i = 1, 3 do
		local lasca = parte(Vector3.new(0.25, 0.25, 0.9) * escala, CFrame.new(), cor:Lerp(BRANCO, 0.5), 0.15, nil, Enum.Material.Glass)
		table.insert(extras, {
			parte = lasca,
			cf = function(t)
				local a = t * 9 + i * (math.pi * 2 / 3)
				return CFrame.new(math.cos(a) * 0.7 * escala, math.sin(a) * 0.7 * escala, 0.6 * escala)
			end,
		})
	end
	rastro(lanca, cor, 0.5 * escala, 0.3)
	emissorEm(lanca, {
		Color = ColorSequence.new(BRANCO, cor),
		LightEmission = 0.6,
		Transparency = sequencia({ { 0, 0.3 }, { 1, 1 } }),
		Size = sequencia({ { 0, 0.6 * escala }, { 1, 1.4 * escala } }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(0.5, 1.5),
		Drag = 4,
		SpreadAngle = Vector2.new(180, 180),
		Rate = 35,
	})
	luzEm(lanca, cor, 10, 1.6)
	return lanca, cor, extras, true
end

-- Bola de Fogo: núcleo amarelo, camada laranja pulsando, chamas, brasas e fumaça
MAGIAS.bolaFogo = function(escala: number)
	local cor = Color3.fromRGB(255, 130, 40)
	local nucleo = parte(Vector3.one * 1.3 * escala, CFrame.new(), Color3.fromRGB(255, 240, 160), 0, Enum.PartType.Ball)
	local camada = parte(Vector3.one * 2.2 * escala, CFrame.new(), cor, 0.35, Enum.PartType.Ball)
	VfxKit.continuo(nucleo, "fogo", 70, { cor = cor, escala = 0.9 * escala, extra = { Speed = NumberRange.new(1, 4) } })
	VfxKit.continuo(nucleo, "fumaca", 18, { cor = Color3.fromRGB(70, 60, 55), escala = 0.6 * escala, extra = { Speed = NumberRange.new(0.5, 2) } })
	local fogo = Instance.new("Fire")
	fogo.Size = 4 * escala
	fogo.Heat = 0
	fogo.Color = cor
	fogo.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fogo.Parent = nucleo
	emissorEm(nucleo, {
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20)),
		LightEmission = 1,
		Size = sequencia({ { 0, 0.4 * escala }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 6, 0),
		Rate = 60,
	})
	emissorEm(nucleo, {
		Color = ColorSequence.new(Color3.fromRGB(70, 60, 60)),
		LightEmission = 0,
		Transparency = sequencia({ { 0, 0.5 }, { 1, 1 } }),
		Size = sequencia({ { 0, 0.8 * escala }, { 1, 2.2 * escala } }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(0.5, 1.5),
		Acceleration = Vector3.new(0, 3, 0),
		Rate = 25,
	})
	rastro(nucleo, cor, 1.6 * escala, 0.3)
	luzEm(nucleo, cor, 18, 3)
	return nucleo, cor, {
		{ parte = camada, cf = function(t)
			return CFrame.Angles(t * 5, t * 7, 0)
		end, pulso = 2.2 * escala },
	}
end

-- Orbe do Vazio: núcleo escuro, borda violeta, três anéis em eixos diferentes e
-- partículas sendo sugadas para dentro
MAGIAS.orbeCarregado = function(escala: number)
	local cor = Color3.fromRGB(170, 70, 255)
	local nucleo = parte(Vector3.one * 1.4 * escala, CFrame.new(), Color3.fromRGB(18, 6, 30), 0, Enum.PartType.Ball, Enum.Material.SmoothPlastic)
	VfxKit.continuo(nucleo, "vortice", 14, { cor = cor, escala = 1.1 * escala, extra = { LockedToPart = true } })
	VfxKit.continuo(nucleo, "fumaca", 20, { cor = Color3.fromRGB(45, 15, 70), escala = 0.7 * escala, extra = { Speed = NumberRange.new(0.5, 2) } })
	local borda = parte(Vector3.one * 1.9 * escala, CFrame.new(), cor, 0.45, Enum.PartType.Ball, Enum.Material.ForceField)
	local extras = { { parte = borda, cf = function()
		return CFrame.new()
	end } }
	for i, giro in { Vector3.new(1, 0.3, 0), Vector3.new(0.2, 1, 0.4), Vector3.new(0.5, 0, 1) } do
		local anel = anelDeMagia((1.3 + i * 0.25) * escala, 0.1, cor:Lerp(BRANCO, 0.2 * i), 0.15)
		table.insert(extras, {
			parte = anel,
			cf = function(t)
				return CFrame.Angles(t * giro.X * 6, t * giro.Y * 6, t * giro.Z * 6)
			end,
		})
	end
	emissorEm(nucleo, {
		Color = ColorSequence.new(cor:Lerp(BRANCO, 0.5), cor),
		LightEmission = 1,
		Size = sequencia({ { 0, 0.35 * escala }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(5, 8),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 70,
	})
	rastro(nucleo, cor, 1.4 * escala, 0.35)
	luzEm(nucleo, cor, 20, 3)
	return nucleo, cor, extras
end

-- Flecha de verdade: haste de madeira, ponta de metal brilhante e penas atrás
local function construirFlecha(escala: number, corPonta: Color3, corPenas: Color3, brilhoForte: boolean?)
	local haste = parte(Vector3.new(0.14, 0.14, 2.6) * escala, CFrame.new(), Color3.fromRGB(150, 110, 70), 0, nil, Enum.Material.Wood)
	local ponta = parte(Vector3.new(0.32, 0.12, 0.5) * escala, CFrame.new(), corPonta, 0, nil, Enum.Material.Neon)
	local extras = {
		{ parte = ponta, cf = function()
			return CFrame.new(0, 0, -1.45 * escala) * CFrame.Angles(0, 0, math.rad(45))
		end },
	}
	for i = 0, 1 do
		local pena = parte(Vector3.new(0.04, 0.32, 0.6) * escala, CFrame.new(), corPenas, 0.05, nil, Enum.Material.Fabric)
		table.insert(extras, { parte = pena, cf = function()
			return CFrame.new(0, 0, 1.1 * escala) * CFrame.Angles(0, 0, math.rad(90 * i))
		end })
	end
	rastro(haste, corPonta, 0.3 * escala, if brilhoForte then 0.3 else 0.15)
	luzEm(haste, corPonta, if brilhoForte then 14 else 6, if brilhoForte then 2.5 else 1)
	return haste, extras
end

MAGIAS.flecha = function(escala: number)
	local cor = Color3.fromRGB(150, 255, 160)
	local haste, extras = construirFlecha(escala, cor, Color3.fromRGB(240, 240, 230))
	return haste, cor, extras
end

MAGIAS.flechaGrande = function(escala: number)
	local cor = Color3.fromRGB(200, 255, 140)
	local haste, extras = construirFlecha(escala, cor, cor, true)
	return haste, cor, extras
end

-- Flecha carregada: verde forte, com duas espirais de vento girando em volta (as espirais e as
-- partículas só aparecem sem o efeito pronto "FlechaCarregada")
MAGIAS.flechaCarregada = function(escala: number)
	local cor = Color3.fromRGB(120, 255, 150)
	local haste, extras = construirFlecha(escala, cor, cor, true)
	VfxKit.continuo(haste, "faiscas", 40, { cor = cor, escala = 0.5, extra = { Acceleration = Vector3.zero } })
	for i = 0, 1 do
		local espiral = anelDeMagia(0.7 * escala, 0.08, if i == 0 then BRANCO else cor, 0.25)
		table.insert(extras, { parte = espiral, efeito = true, cf = function(t)
			return CFrame.new(0, 0, (0.2 - i * 0.9) * escala) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles((t * 20) + i * math.pi, 0, 0)
		end })
	end
	emissorEm(haste, {
		Color = ColorSequence.new(BRANCO, cor),
		LightEmission = 1,
		Size = sequencia({ { 0, 0.3 * escala }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.2, 0.35),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 50,
	})
	return haste, cor, extras
end

-- Som de cada magia/projétil ao sair (um por leva; a Saraivada solta várias flechas juntas)
local SOM_DISPARO = {
	dardoArcano = { "dardoArcano" },
	lancaGelo = { "lancaGelo" },
	bolaFogo = { "bolaFogo" },
	orbeCarregado = { "bolaFogo", { tom = 0.55, volume = 1.2 } },
	flechaCarregada = { "arcoSoltar", { tom = 0.85, volume = 1.2 } },
	adaga = { "adaga" },
	onda = { "espada", { volume = 0.6 } },
	fogo = { "bolaFogo", { tom = 1.25, volume = 0.5 } },
	gelo = { "lancaGelo", { tom = 0.8, volume = 0.5 } },
	veneno = { "sangue", { tom = 0.6, volume = 0.5 } },
	flechaOssea = { "arcoSoltar", { tom = 0.8, volume = 0.5 } },
}

local COR_MAGIA = {
	dardoArcano = Color3.fromRGB(190, 110, 255),
	lancaGelo = Color3.fromRGB(150, 225, 255),
	bolaFogo = Color3.fromRGB(255, 130, 40),
	orbeCarregado = Color3.fromRGB(170, 70, 255),
}

local function somDeDisparo(lista)
	local primeiro = lista[1]
	if not primeiro then
		return
	end
	-- magias do Mago: um círculo mágico de pé aparece diante do cajado
	local corMagia = COR_MAGIA[primeiro.tipo]
	if corMagia then
		local grande = primeiro.tipo == "orbeCarregado" or primeiro.tipo == "bolaFogo"
		soltar(primeiro.pos, "circulo", {
			cor = corMagia,
			escala = if grande then 0.45 else 0.3,
			quantidade = 1,
			direcao = primeiro.dir,
			extra = { Lifetime = NumberRange.new(0.45, 0.45), RotSpeed = NumberRange.new(220, 220) },
		})
		soltar(primeiro.pos, "faiscas", { cor = corMagia, quantidade = 10, escala = 0.6, direcao = primeiro.dir, extra = { SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.zero } })
	end
	local info = SOM_DISPARO[primeiro.tipo]
	if info then
		local opcoes = table.clone(info[2] or {})
		opcoes.pos = primeiro.pos
		Sons.tocar(info[1], opcoes)
	elseif primeiro.tipo == "flecha" and #lista >= 6 then
		Sons.tocar("arcoSoltar", { pos = primeiro.pos, volume = 0.6 })
	end
end

-- Magias com efeito pronto do pacote de VFX (segue o projétil) e o tamanho de cada uma.
-- Nas flechas (corpo = true) a flecha de madeira continua aparecendo: o efeito pronto só
-- substitui o rastro feito por código. "fogo" é o efeito usado com a carta Flechas de Fogo.
local PROJETIL_PRONTO = {
	dardoArcano = { "ProjetilArcano", 0.35 },
	lancaGelo = { "ProjetilGelo", 0.35 },
	bolaFogo = { "ProjetilFogo", 0.55 },
	orbeCarregado = { "ProjetilVazio", 0.22 },
	flecha = { "FlechaVento", 1, corpo = true, fogo = "FlechaFogo" },
	flechaGrande = { "FlechaVento", 1.3, corpo = true, fogo = "FlechaFogo" },
	flechaCarregada = { "FlechaCarregada", 0.6, corpo = true, fogo = "FlechaCarregadaFogo" },
	fantasma = { "FlechaCarregada", 0.8, corpo = true },
}
local TIPOS_FLECHA = { flecha = true, flechaGrande = true, flechaCarregada = true, fantasma = true }

-- Flecha com efeito pronto: apaga só o rastro e as partículas feitas por código (a madeira, a
-- ponta e a luz ficam) e as peças extras marcadas como efeito
local function apagarRastro(visual: BasePart, extras)
	for _, objeto in visual:GetDescendants() do
		if objeto:IsA("ParticleEmitter") or objeto:IsA("Trail") or objeto:IsA("Beam") then
			(objeto :: any).Enabled = false
		end
	end
	for _, extra in extras or {} do
		if extra.efeito then
			extra.parte.Transparency = 1
		end
	end
end

-- Deixa o visual feito por código invisível (a luz continua) quando o efeito pronto o substitui
local function esconderVisual(visual: BasePart, extras)
	visual.Transparency = 1
	for _, objeto in visual:GetDescendants() do
		if objeto:IsA("BasePart") then
			objeto.Transparency = 1
		elseif objeto:IsA("ParticleEmitter") or objeto:IsA("Trail") or objeto:IsA("Beam") or objeto:IsA("Fire") then
			(objeto :: any).Enabled = false
		end
	end
	for _, extra in extras or {} do
		extra.parte.Transparency = 1
	end
end

function Vfx.projeteis(dados)
	somDeDisparo(dados.lista)
	for _, info in dados.lista do
		local construtor = MAGIAS[info.tipo]
		local visual, cor, extras, girar
		if construtor then
			visual, cor, extras, girar = construtor(info.tamanho or 1)
		else
			visual, cor = criarVisualProjetil(info.tipo, info.tamanho or 1)
		end
		visual.CFrame = CFrame.lookAt(info.pos, info.pos + info.dir)
		projeteis[info.id] = {
			extras = extras,
			nascimento = os.clock(),
			parte = visual,
			pos = info.pos,
			dir = info.dir,
			vel = info.vel,
			alcance = info.alcance,
			percorrido = 0,
			cor = cor,
			tipo = info.tipo,
			girar = info.tipo == "gelo" or girar == true,
		}
		local pronto = PROJETIL_PRONTO[info.tipo]
		if pronto then
			local nomePronto = if info.fogo and pronto.fogo and prefabDe(pronto.fogo) then pronto.fogo else pronto[1]
			if prefabDe(nomePronto) then
				if pronto.corpo then
					apagarRastro(visual, extras)
				elseif Vfx.temPrefab(nomePronto) then
					esconderVisual(visual, extras)
				end
			end
			if info.fogo and TIPOS_FLECHA[info.tipo] then
				-- ponta em brasa
				projeteis[info.id].cor = FOGO
				for _, extra in extras or {} do
					if not extra.efeito and extra.parte.Material == Enum.Material.Neon then
						extra.parte.Color = FOGO
					end
				end
				local luz = visual:FindFirstChildOfClass("PointLight")
				if luz then
					luz.Color = FOGO
				end
			end
			local id = info.id
			Vfx.prefab(nomePronto, function()
				local p = projeteis[id]
				return if p then CFrame.lookAt(p.pos, p.pos + p.dir) else nil
			end, 0, pronto[2] * (info.tamanho or 1))
		end
	end
end

local function removerProjetil(id: number, impacto: boolean, pos: Vector3?)
	local p = projeteis[id]
	if not p then
		return
	end
	projeteis[id] = nil
	local onde = pos or p.pos
	p.parte.Transparency = 1
	for _, desc in p.parte:GetDescendants() do
		if desc:IsA("ParticleEmitter") or desc:IsA("Fire") then
			desc.Enabled = false
		end
	end
	Debris:AddItem(p.parte, 0.6) -- deixa o rastro e as partículas terminarem
	for _, extra in p.extras or {} do
		animar(extra.parte, 0.12, { Transparency = 1 })
		Debris:AddItem(extra.parte, 0.15)
	end
	if impacto then
		local tipo = p.tipo or ""
		if tipo == "lancaGelo" then
			Sons.tocar("geloQuebra", { pos = onde })
		elseif string.find(tipo, "flecha") or tipo == "adaga" or tipo == "fantasma" then
			Sons.tocar("flechaImpacto", { pos = onde })
		end
		if TIPOS_FLECHA[tipo] and prefabDe("ImpactoFlecha") then
			return -- o impacto da flecha é o efeito pronto, que sai em Vfx.dano
		end
		if p.tipo == "lancaGelo" then
			-- o cristal estilhaça
			for _ = 1, 6 do
				local lasca = parte(Vector3.new(0.25, 0.25, 0.7), CFrame.new(onde) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), p.cor:Lerp(BRANCO, 0.4), 0.1, nil, Enum.Material.Glass)
				lasca.Anchored = false
				lasca.AssemblyLinearVelocity = Vector3.new(math.random(-14, 14), math.random(6, 18), math.random(-14, 14))
				sumir({ lasca }, 0.3, 0.35)
			end
			particulas(onde, { cor = BRANCO, cor2 = p.cor, quantidade = 14, tamanho = 0.5, velocidade = 12, vida = 0.5, arrasto = 6 })
		else
			particulas(onde, { cor = p.cor, cor2 = BRANCO, quantidade = 10, tamanho = 0.45, velocidade = 16, vida = 0.35 })
		end
		clarao(onde, p.cor, 10, 0.2, 2)
	end
end

function Vfx.projetilFim(dados)
	removerProjetil(dados.id, dados.impacto, dados.pos)
end

function Vfx.projetilDir(dados)
	local p = projeteis[dados.id]
	if p then
		p.pos = dados.pos
		p.dir = dados.dir
		particulas(dados.pos, { cor = p.cor, quantidade = 6, tamanho = 0.3, velocidade = 10, vida = 0.25 })
	end
end

RunService.RenderStepped:Connect(function(dt)
	for id, p in projeteis do
		local passo = p.vel * dt
		p.pos += p.dir * passo
		p.percorrido += passo
		if p.percorrido > p.alcance + 6 then
			removerProjetil(id, false)
		else
			local cf = CFrame.lookAt(p.pos, p.pos + p.dir)
			if p.girar then
				cf *= CFrame.Angles(0, 0, os.clock() * 12)
			end
			p.parte.CFrame = cf
			if p.extras then
				local t = os.clock() - p.nascimento
				for _, extra in p.extras do
					extra.parte.CFrame = cf * extra.cf(t)
					if extra.pulso then
						extra.parte.Size = Vector3.one * extra.pulso * (1 + math.sin(t * 18) * 0.12)
					end
				end
			end
		end
	end
end)

------------------------------------------------------------------------
-- Explosões e impactos
------------------------------------------------------------------------

function Vfx.explosao(dados)
	local pos, raio, cor = dados.pos, dados.raio or 6, dados.cor or FOGO
	local forte = dados.forte == true
	local leve = dados.leve == true
	if not VfxKit.custom("Explosao", CFrame.new(pos), raio / 6) then
		local e = raio / 6
		soltar(pos, "clarao", { cor = cor, escala = e * 1.5, quantidade = 1 })
		soltar(pos, "nucleo", { cor = cor, escala = e, quantidade = if leve then 3 else 7 })
		soltar(pos, "fogo", { cor = cor, escala = e, quantidade = if leve then 8 else 22 })
		soltar(pos, "faiscas", { cor = cor, escala = e * 1.2, quantidade = if leve then 12 else 34 })
		soltar(pos, "brasas", { cor = cor, escala = e, quantidade = if leve then 6 else 20 })
		if not leve then
			soltar(pos, "fumaca", { cor = Color3.fromRGB(70, 62, 60), escala = e, quantidade = if forte then 16 else 10 })
			soltar(pos - Vector3.new(0, 1.5, 0), "onda", { cor = cor, escala = e, quantidade = 1 })
			soltar(pos - Vector3.new(0, 1.5, 0), "poeira", { cor = Color3.fromRGB(150, 135, 115), escala = e, quantidade = 14 })
		end
	end
	Sons.tocar("explosao", { pos = pos, volume = if leve then 0.5 elseif forte then 1.15 else 0.9, tom = if leve then 1.3 else 1, alcance = 220 })
	-- magias do Mago: explosão pronta do pacote de VFX (arcana roxa ou de fogo)
	local pronta = if dados.magia == "dardoArcano" then "ExplosaoArcana" elseif dados.magia == "bolaFogo" then "ExplosaoFogo" else nil
	if pronta and Vfx.temPrefab(pronta) then
		Vfx.prefab(pronta, CFrame.new(pos), nil, raio / 12)
		Vfx.tremerEm(pos, if forte then 0.8 else 0.3, 0.15)
		return
	end
	local nucleo = parte(Vector3.one * 1.5, CFrame.new(pos), cor:Lerp(BRANCO, 0.5), 0, Enum.PartType.Ball)
	animar(nucleo, if leve then 0.22 else 0.35, { Size = Vector3.one * raio * 2, Transparency = 1, Color = cor })
	Debris:AddItem(nucleo, 0.4)
	local chao = Vector3.new(pos.X, pos.Y - (if leve then 1 else 0) , pos.Z)
	local onda = disco(chao, 2, cor, 0.2)
	animar(onda, 0.4, { Size = Vector3.new(0.15, raio * 2.6, raio * 2.6), Transparency = 1 })
	Debris:AddItem(onda, 0.45)
	particulas(pos, {
		cor = cor:Lerp(BRANCO, 0.3),
		cor2 = cor,
		quantidade = if leve then 10 else 28,
		tamanho = if leve then 0.5 else 0.9,
		velocidade = raio * 5,
		vida = 0.6,
		gravidade = 10,
	})
	clarao(pos, cor, raio * 4, 0.4, if forte then 6 else 3)
	if not leve then
		Vfx.tremerEm(pos, if forte then 2.2 else 1, 0.3)
	end
end

-- Orbe do Vazio: primeiro tudo é sugado para um ponto escuro, depois explode em violeta
function Vfx.vazio(dados)
	if not VfxKit.custom("Vazio", CFrame.new(dados.pos), (dados.raio or 8) / 6) then
		local roxo = Color3.fromRGB(170, 70, 255)
		local e = (dados.raio or 8) / 6
		soltar(dados.pos, "implosao", { cor = roxo, escala = e, quantidade = 3 })
		soltar(dados.pos, "vortice", { cor = roxo, escala = e * 1.5, quantidade = 3 })
		task.delay(0.18, function()
			soltar(dados.pos, "nucleo", { cor = roxo, escala = e, quantidade = 6 })
			soltar(dados.pos, "faiscas", { cor = roxo, escala = e * 1.3, quantidade = 36 })
			soltar(dados.pos, "fumaca", { cor = Color3.fromRGB(40, 15, 60), escala = e, quantidade = 14 })
			soltar(dados.pos - Vector3.new(0, 1.5, 0), "onda", { cor = roxo, escala = e, quantidade = 1 })
		end)
	end
	Sons.tocar("vazioExplode", { pos = dados.pos, alcance = 220 })
	local pos, raio = dados.pos, dados.raio or 8
	if Vfx.temPrefab("ExplosaoVazio") then
		Vfx.prefab("ExplosaoVazio", CFrame.new(pos), nil, raio / 10)
		Vfx.tremerEm(pos, 1.2, 0.25)
		return
	end
	local cor = Color3.fromRGB(170, 70, 255)
	local escuro = Color3.fromRGB(18, 6, 30)
	-- esfera que encolhe (implosão)
	local casca = parte(Vector3.one * raio * 2, CFrame.new(pos), cor, 0.6, Enum.PartType.Ball, Enum.Material.ForceField)
	animar(casca, 0.18, { Size = Vector3.one * 1.5, Transparency = 0.1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local nucleo = parte(Vector3.one * 1, CFrame.new(pos), escuro, 0, Enum.PartType.Ball, Enum.Material.SmoothPlastic)
	animar(nucleo, 0.18, { Size = Vector3.one * 3 })
	task.delay(0.18, function()
		casca:Destroy()
		nucleo:Destroy()
		-- explosão: bola violeta, anéis em vários ângulos e lascas escuras
		local bola = parte(Vector3.one * 2, CFrame.new(pos), cor:Lerp(BRANCO, 0.4), 0, Enum.PartType.Ball)
		animar(bola, 0.35, { Size = Vector3.one * raio * 2.2, Transparency = 1, Color = cor })
		Debris:AddItem(bola, 0.4)
		for i = 1, 3 do
			local anelVazio = parte(Vector3.new(0.3, 2, 2), CFrame.new(pos) * CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3), cor, 0.1, Enum.PartType.Cylinder)
			animar(anelVazio, 0.3 + i * 0.06, { Size = Vector3.new(0.05, raio * 2.6, raio * 2.6), Transparency = 1 })
			Debris:AddItem(anelVazio, 0.5)
		end
		local chao = disco(pos - Vector3.new(0, 1.5, 0), 2, escuro, 0.3)
		animar(chao, 0.5, { Size = Vector3.new(0.15, raio * 2.4, raio * 2.4), Transparency = 1 })
		Debris:AddItem(chao, 0.55)
		particulas(pos, { cor = cor:Lerp(BRANCO, 0.4), cor2 = escuro, quantidade = 34, tamanho = 0.8, velocidade = raio * 5, vida = 0.6, gravidade = 6 })
		clarao(pos, cor, raio * 4, 0.45, 6)
		Vfx.tremerEm(pos, 2, 0.3)
	end)
end

function Vfx.impacto(dados)
	local pos, raio = dados.pos, dados.raio or 6
	local efeitos = EFEITOS_CHEFE[dados.tipo or ""]
	if efeitos and Vfx.temPrefab(efeitos.salto) then
		-- chefe caindo do salto: pancada no chão e rachadura
		Vfx.prefab(efeitos.salto, CFrame.new(pos + Vector3.new(0, 0.2, 0)), nil, raio / 18)
		Sons.tocar("pouso", { pos = pos, tom = 0.5, volume = 1.5 })
		Vfx.tremerEm(pos, 2.8, 0.4)
		return
	end
	local poeira = disco(pos + Vector3.new(0, 0.2, 0), 2, Color3.fromRGB(200, 180, 160), 0.35)
	animar(poeira, 0.45, { Size = Vector3.new(0.15, raio * 2.4, raio * 2.4), Transparency = 1 })
	Debris:AddItem(poeira, 0.5)
	particulas(pos + Vector3.new(0, 0.5, 0), { cor = Color3.fromRGB(190, 170, 150), quantidade = 18, tamanho = 0.7, velocidade = 20, vida = 0.6, gravidade = 30, luz = 0, espalhar = Vector2.new(70, 70) })
	if dados.cor then
		clarao(pos, dados.cor, raio * 3, 0.3, 3)
	end
	Vfx.tremerEm(pos, if dados.forte then 2.5 else 1.2, 0.3)
end

function Vfx.impactoArea(dados)
	local pos, raio = dados.pos, dados.raio
	if dados.visual == "gelo" then
		for _ = 1, 7 do
			local p = pos + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * raio * 1.6
			local altura = math.random(3, 6)
			local espinho = parte(Vector3.new(0.9, 0.1, 0.9), CFrame.new(p) * CFrame.Angles(math.random() * 0.4, math.random() * 3, math.random() * 0.4), Color3.fromRGB(170, 230, 255), 0.15)
			animar(espinho, 0.12, { Size = Vector3.new(0.9, altura, 0.9), CFrame = espinho.CFrame * CFrame.new(0, altura / 2, 0) }, Enum.EasingStyle.Back)
			sumir({ espinho }, 0.5, 0.7)
		end
		particulas(pos + Vector3.new(0, 1, 0), { cor = Color3.fromRGB(220, 245, 255), quantidade = 20, velocidade = 14, vida = 0.6, gravidade = 10 })
		clarao(pos, Color3.fromRGB(150, 220, 255), raio * 3, 0.4)
	elseif dados.visual == "teia" then
		local teia = disco(pos + Vector3.new(0, 0.18, 0), raio * 2, Color3.fromRGB(235, 235, 235), 0.55, 0.1)
		teia.Material = Enum.Material.SmoothPlastic
		for i = 0, 3 do
			parte(Vector3.new(raio * 2, 0.12, 0.15), CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, i * math.pi / 4, 0), Color3.fromRGB(240, 240, 240), 0.3, nil, Enum.Material.SmoothPlastic).Parent = teia
		end
		sumir({ teia }, 0.8, 1.6)
		for _, filho in teia:GetChildren() do
			if filho:IsA("BasePart") then
				sumir({ filho }, 0.8, 1.6)
			end
		end
		particulas(pos + Vector3.new(0, 1, 0), { cor = Color3.fromRGB(150, 255, 110), quantidade = 14, velocidade = 12, vida = 0.5 })
	else
		Vfx.explosao({ pos = pos + Vector3.new(0, 1, 0), raio = raio, cor = if dados.visual == "meteoro" then FOGO else VERMELHO, forte = dados.visual == "meteoro" })
	end
end




local function zigueZague(de: Vector3, ate: Vector3, cor: Color3, espessura: number, desvio: number, segmentos: number)
	local pontos = { de }
	for i = 1, segmentos - 1 do
		local base = de:Lerp(ate, i / segmentos)
		table.insert(pontos, base + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * desvio)
	end
	table.insert(pontos, ate)
	local partes: { BasePart } = {}
	for i = 1, #pontos - 1 do
		local a, b = pontos[i], pontos[i + 1]
		table.insert(partes, parte(Vector3.new(espessura, espessura, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), cor, 0))
	end
	sumir(partes, 0.18, 0.04)
end

function Vfx.raio(dados)
	zigueZague(dados.de, dados.ate, Color3.fromRGB(255, 245, 140), 0.35, 2.5, 5)
	clarao(dados.ate, Color3.fromRGB(255, 240, 120), 12, 0.2, 3)
end


function Vfx.teleporte(dados)
	local cor = Color3.fromRGB(130, 80, 220)
	local esfera = parte(Vector3.one * 6, CFrame.new(dados.pos), cor, 0.3, Enum.PartType.Ball)
	animar(esfera, 0.35, { Size = Vector3.one * 0.5, Transparency = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	Debris:AddItem(esfera, 0.4)
	particulas(dados.pos, { cor = Color3.fromRGB(200, 160, 255), cor2 = cor, quantidade = 24, velocidade = 14, vida = 0.6 })
	clarao(dados.pos, cor, 18, 0.4, 3)
end

function Vfx.furia(dados)
	local efeitos = EFEITOS_CHEFE[dados.tipo or ""]
	if efeitos and Vfx.temPrefab(efeitos.furia) then
		-- o rugido vermelho sai do próprio chefe (VisualInimigos); aqui só o tremor
		Sons.tocar("supremo", { pos = dados.pos, tom = 0.6, alcance = 220 })
		Vfx.tremer(2.5, 0.6)
		return
	end
	local onda = disco(dados.pos - Vector3.new(0, 2, 0), 4, VERMELHO, 0.1)
	animar(onda, 0.7, { Size = Vector3.new(0.15, 70, 70), Transparency = 1 })
	Debris:AddItem(onda, 0.75)
	clarao(dados.pos, VERMELHO, 50, 0.8, 6)
	Vfx.tremer(2.5, 0.6)
end

------------------------------------------------------------------------
-- Avisos de ataque no chão (telegrafia)
------------------------------------------------------------------------

local function cunha(): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.CastShadow = false
	w.Material = Enum.Material.Neon
	w.Parent = pasta
	return w
end

-- Desenha um triângulo a-b-c usando duas cunhas (técnica clássica do Roblox)
local function triangulo(a: Vector3, b: Vector3, c: Vector3, cor: Color3, transparencia: number): { BasePart }
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local direita = ac:Cross(ab).Unit
	local cima = bc:Cross(direita).Unit
	local tras = bc.Unit
	local altura = math.abs(ab:Dot(cima))
	local w1 = cunha()
	w1.Size = Vector3.new(0.12, altura, math.abs(ab:Dot(tras)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, direita, cima, tras)
	local w2 = cunha()
	w2.Size = Vector3.new(0.12, altura, math.abs(ac:Dot(tras)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -direita, cima, -tras)
	for _, w in { w1, w2 } do
		w.Color = cor
		w.Transparency = transparencia
	end
	return { w1, w2 }
end

local function telegrafoCirculo(centro: Vector3, raio: number, duracao: number, cor: Color3)
	local partes = anel(centro + Vector3.new(0, 0.05, 0), raio, cor, 0.15, math.clamp(math.floor(raio * 3), 16, 40), 0.35)
	local fundo = disco(centro, raio * 2, cor, 0.82)
	local enchendo = disco(centro + Vector3.new(0, 0.02, 0), 0.3, cor, 0.5)
	animar(enchendo, duracao, { Size = Vector3.new(0.15, raio * 2, raio * 2) }, Enum.EasingStyle.Linear)
	table.insert(partes, fundo)
	table.insert(partes, enchendo)
	task.delay(duracao, function()
		for _, p in partes do
			if p.Parent then
				p.Color = BRANCO
			end
		end
		sumir(partes, 0.15)
	end)
end

local function telegrafoCone(centro: Vector3, direcao: Vector3, raio: number, arcoGraus: number, duracao: number, cor: Color3)
	local partes = {}
	local fatias = math.max(4, math.floor(arcoGraus / 12))
	local inicio = -math.rad(arcoGraus) / 2
	local passo = math.rad(arcoGraus) / fatias
	local base = CFrame.lookAt(centro, centro + direcao)
	local function ponto(angulo: number, r: number)
		return base:PointToWorldSpace(Vector3.new(-r * math.sin(angulo), 0, -r * math.cos(angulo)))
	end
	for i = 0, fatias - 1 do
		for _, w in triangulo(centro, ponto(inicio + i * passo, raio), ponto(inicio + (i + 1) * passo, raio), cor, 0.78) do
			table.insert(partes, w)
		end
	end
	-- borda do cone
	for i = 0, fatias - 1 do
		local a, b = ponto(inicio + i * passo, raio), ponto(inicio + (i + 1) * passo, raio)
		table.insert(partes, parte(Vector3.new(0.3, 0.16, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), cor, 0.15))
	end
	for _, angulo in { inicio, -inicio } do
		local a = ponto(angulo, raio)
		table.insert(partes, parte(Vector3.new(0.3, 0.16, raio), CFrame.lookAt((centro + a) / 2, a), cor, 0.15))
	end
	for _, p in partes do
		animar(p, duracao, { Transparency = math.max(0.35, p.Transparency - 0.35) }, Enum.EasingStyle.Linear)
	end
	task.delay(duracao, function()
		for _, p in partes do
			if p.Parent then
				p.Color = BRANCO
			end
		end
		sumir(partes, 0.15)
	end)
end

local function telegrafoLinha(inicio: Vector3, direcao: Vector3, comprimento: number, largura: number, duracao: number, cor: Color3)
	local base = CFrame.lookAt(inicio, inicio + direcao)
	local fundo = parte(Vector3.new(largura, 0.14, comprimento), base * CFrame.new(0, 0, -comprimento / 2), cor, 0.8)
	local enchendo = parte(Vector3.new(largura, 0.16, 0.2), base * CFrame.new(0, 0.01, -0.1), cor, 0.45)
	animar(enchendo, duracao, { Size = Vector3.new(largura, 0.16, comprimento), CFrame = base * CFrame.new(0, 0.01, -comprimento / 2) }, Enum.EasingStyle.Linear)
	local partes = { fundo, enchendo }
	for _, lado in { -1, 1 } do
		table.insert(partes, parte(Vector3.new(0.3, 0.17, comprimento), base * CFrame.new(lado * largura / 2, 0.02, -comprimento / 2), cor, 0.15))
	end
	task.delay(duracao, function()
		for _, p in partes do
			if p.Parent then
				p.Color = BRANCO
			end
		end
		sumir(partes, 0.15)
	end)
end

function Vfx.telegrafo(dados)
	local cor = if dados.chefe then Color3.fromRGB(255, 40, 60) else Color3.fromRGB(255, 80, 50)
	local centro = dados.pos + Vector3.new(0, 0.12, 0)
	if dados.forma == "cone" then
		telegrafoCone(centro, dados.dir, dados.raio, dados.arco, dados.duracao, cor)
	elseif dados.forma == "linha" then
		telegrafoLinha(centro, dados.dir, dados.comprimento, dados.largura, dados.duracao, cor)
	else
		telegrafoCirculo(centro, dados.raio, dados.duracao, cor)
	end
end

------------------------------------------------------------------------
-- Números de dano, cura e textos flutuantes
------------------------------------------------------------------------

local function textoFlutuante(posicao: Vector3, texto: string, cor: Color3, tamanho: number, opcoes)
	opcoes = opcoes or {}
	local a = ancora(posicao + Vector3.new((math.random() - 0.5) * 1.6, 0, (math.random() - 0.5) * 1.6))
	local placa = Instance.new("BillboardGui")
	placa.Size = UDim2.fromOffset(tamanho * 5, tamanho * 1.4)
	placa.AlwaysOnTop = true
	placa.LightInfluence = 0
	placa.MaxDistance = 140
	placa.Parent = a
	local rotulo = UI.texto({
		Size = UDim2.fromScale(1, 1),
		FontFace = UI.fontes.numero,
		Text = texto,
		TextColor3 = cor,
		Parent = placa,
	})
	local contorno = UI.contorno(rotulo, if tamanho > 40 then 3 else 2, 0)
	local pulo = UI.criar("UIScale", { Scale = opcoes.pop or 1.6, Parent = rotulo })
	animar(pulo, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	local subida = opcoes.subida or 3
	animar(placa, 0.8, { StudsOffset = Vector3.new((math.random() - 0.5) * 1.5, subida, 0) }, Enum.EasingStyle.Quad)
	task.delay(0.45, function()
		animar(rotulo, 0.35, { TextTransparency = 1 })
		animar(contorno, 0.35, { Transparency = 1 })
	end)
	Debris:AddItem(a, 0.85)
end

-- Respingo de sangue: gotas que caem e mancham o chão (golpes do Assassino)
local function respingoDeSangue(posicao: Vector3, forca: number, soGotas: boolean?)
	local sangue = Color3.fromRGB(150, 0, 15)
	if not soGotas then
		if VfxKit.custom("Sangue", CFrame.new(posicao)) then
			return
		end
		soltar(posicao, "gotas", { cor = Color3.fromRGB(170, 10, 25), quantidade = math.floor(16 * forca), escala = forca })
		soltar(posicao, "fumaca", { cor = Color3.fromRGB(120, 0, 15), quantidade = 2, escala = 0.35 * forca })
	end
	if soGotas then
		particulas(posicao, { cor = sangue, quantidade = 3, tamanho = 0.25, velocidade = 4, vida = 0.5, gravidade = 50, luz = 0 })
		return
	end
	particulas(posicao + Vector3.new(0, 0.5, 0), {
		cor = Color3.fromRGB(200, 20, 30),
		cor2 = sangue,
		quantidade = math.floor(10 * forca),
		tamanho = 0.35 * forca,
		velocidade = 14 * forca,
		vida = 0.5,
		gravidade = 60,
		luz = 0,
		espalhar = Vector2.new(60, 60),
	})
	-- mancha no chão que some devagar
	if math.random() < 0.6 then
		-- procura o chão logo abaixo
		local parametros = RaycastParams.new()
		parametros.FilterType = Enum.RaycastFilterType.Exclude
		local ignorar: { Instance } = { pasta }
		local visuais = workspace:FindFirstChild("InimigosVisuais")
		if visuais then
			table.insert(ignorar, visuais)
		end
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignorar, player.Character)
			end
		end
		parametros.FilterDescendantsInstances = ignorar
		local acerto = workspace:Raycast(posicao, Vector3.new(0, -15, 0), parametros)
		if not acerto then
			return
		end
		local tamanho = (1.2 + math.random() * 1.5) * forca
		local chao = acerto.Position + Vector3.new(math.random() - 0.5, 0.04, math.random() - 0.5)
		local mancha = disco(chao, tamanho, sangue, 0.25, 0.05)
		mancha.Material = Enum.Material.SmoothPlastic
		sumir({ mancha }, 1.5, 2.5)
	end
end

-- Impacto de um golpe: clarão, faíscas em rastro, brasas e (no crítico) núcleo e anel
local function impactoDeGolpe(pos: Vector3, cor: Color3, critico: boolean)
	if VfxKit.custom(if critico then "Critico" else "Impacto", CFrame.new(pos)) then
		return
	end
	soltar(pos, "clarao", { cor = cor, escala = if critico then 0.9 else 0.5, quantidade = 1 })
	soltar(pos, "estrela", { cor = cor, escala = if critico then 1.1 else 0.45, quantidade = 1 })
	soltar(pos, "faiscas", { cor = cor, quantidade = if critico then 26 else 12, escala = if critico then 1.2 else 0.8 })
	soltar(pos, "brasas", { cor = cor, quantidade = if critico then 12 else 5, escala = 0.7 })
	if critico then
		soltar(pos, "nucleo", { cor = Color3.fromRGB(255, 220, 120), quantidade = 2, escala = 0.45 })
		soltar(pos, "anel", { cor = Color3.fromRGB(255, 230, 150), quantidade = 1, escala = 0.6, extra = { Orientation = Enum.ParticleOrientation.FacingCamera } })
	end
end

function Vfx.dano(dados)
	local critico = dados.critico
	if dados.impacto and not dados.dot then
		impactoDeGolpe(dados.impacto, dados.cor or Color3.fromRGB(255, 200, 140), critico == true)
	end
	-- som do golpe (dano contínuo de fogo/sangramento não faz barulho a cada tique)
	if dados.impacto and not dados.dot then
		local autorSom = dados.autor
		if dados.principal and typeof(autorSom) == "Instance" and autorSom:GetAttribute("Classe") == "cavaleiro" then
			Sons.tocar("golpeEspada", { pos = dados.impacto, tom = if critico then 0.9 else 1.08 })
		else
			Sons.tocar(if critico then "critico" else "impacto", { pos = dados.impacto })
		end
		if dados.sangue == true then
			Sons.tocar("sangue", { pos = dados.impacto })
		end
	end
	-- cada acerto seu dá um tranco leve na câmera (sensação de impacto)
	if dados.autor == jogador and not critico then
		Vfx.tremer(0.18, 0.05)
	end
	local cor = dados.cor or (if critico then Color3.fromRGB(255, 214, 70) else Color3.fromRGB(255, 250, 240))
	textoFlutuante(dados.pos, if critico then dados.valor .. "!" else tostring(dados.valor), cor, if critico then 46 else 30, { pop = if critico then 2.2 else 1.5 })
	local autor = dados.autor
	local doAssassino = typeof(autor) == "Instance" and autor:GetAttribute("Classe") == "assassino"
	if dados.sangue and dados.impacto then
		if dados.sangue == "gota" and Vfx.temPrefab("SangueGota") then
			Vfx.prefab("SangueGota", CFrame.new(dados.impacto), nil, 1)
		elseif dados.sangue == "gota" or not (doAssassino and Vfx.temPrefab("ImpactoAdaga")) then
			respingoDeSangue(dados.impacto, if critico then 1.6 else 1, dados.sangue == "gota")
		end
		-- (golpe do Assassino: o sangue já vem no impacto do pacote, logo abaixo)
	end
	local impactoPronto = false
	if dados.principal and dados.impacto and typeof(autor) == "Instance" and autor:GetAttribute("Classe") == "cavaleiro" then
		local nomeImpacto = if dados.fogo and Vfx.temPrefab("ImpactoCorteFogo") then "ImpactoCorteFogo" else "ImpactoCorte"
		impactoPronto = Vfx.temPrefab(nomeImpacto)
		Vfx.prefab(nomeImpacto, CFrame.new(dados.impacto + Vector3.new(0, 1, 0)), nil, if critico then 1.3 else 0.9)
	elseif dados.principal and dados.impacto and doAssassino then
		local nomeImpacto = if critico then "ImpactoCostas" else "ImpactoAdaga"
		impactoPronto = Vfx.temPrefab(nomeImpacto)
		Vfx.prefab(nomeImpacto, CFrame.new(dados.impacto + Vector3.new(0, 0.5, 0)), nil, 0.6)
	elseif dados.principal and dados.impacto and typeof(autor) == "Instance" and autor:GetAttribute("Classe") == "arqueiro" then
		-- flecha: estouro verde (ou de fogo) que volta na direção de quem atirou
		local nomeImpacto = if dados.fogo and prefabDe("ImpactoFlechaFogo") then "ImpactoFlechaFogo" else "ImpactoFlecha"
		impactoPronto = Vfx.temPrefab(nomeImpacto)
		local raizAutor = raizDoJogador(autor)
		local volta = if raizAutor then raizAutor.Position - dados.impacto else Vector3.zero
		volta = Vector3.new(volta.X, 0, volta.Z)
		local onde = if volta.Magnitude > 0.1
			then CFrame.lookAt(dados.impacto, dados.impacto + volta.Unit) * CFrame.Angles(-math.pi / 2, 0, 0)
			else CFrame.new(dados.impacto)
		Vfx.prefab(nomeImpacto, onde, nil, if critico then 0.45 else 0.3)
	end
	if dados.impacto and not impactoPronto then
		particulas(dados.impacto, {
			cor = if critico then Color3.fromRGB(255, 230, 120) else Color3.fromRGB(255, 240, 220),
			cor2 = dados.cor or Color3.fromRGB(255, 160, 80),
			quantidade = if critico then 14 else 7,
			tamanho = if critico then 0.6 else 0.4,
			velocidade = if critico then 24 else 16,
			vida = 0.3,
		})
		if critico then
			Vfx.tremerEm(dados.impacto, 0.5, 0.1)
		end
	end
end

function Vfx.danoJogador(dados)
	local raiz = raizDoJogador(dados.jogador)
	if raiz then
		Sons.tocar("danoJogador", { pos = raiz.Position, volume = if dados.jogador == jogador then 1 else 0.5 })
		soltar(raiz.Position, "faiscas", { cor = Color3.fromRGB(255, 60, 50), quantidade = 10, escala = 0.7 })
		soltar(raiz.Position, "clarao", { cor = Color3.fromRGB(255, 60, 50), quantidade = 1, escala = 0.5 })
	end
	if Vfx.aoJogadorAtingido then
		Vfx.aoJogadorAtingido(dados.jogador)
	end
	if raiz then
		textoFlutuante(raiz.Position + Vector3.new(0, 3, 0), "-" .. dados.valor, Color3.fromRGB(255, 80, 80), 30, { pop = 1.4 })
	end
	if dados.jogador == jogador then
		Vfx.tremer(math.clamp(dados.valor / 15, 0.4, 2), 0.25)
		if Vfx.aoDanoLocal then
			Vfx.aoDanoLocal(dados.valor)
		end
	end
end

function Vfx.cura(dados)
	local raiz = raizDoJogador(dados.jogador)
	if raiz then
		textoFlutuante(raiz.Position + Vector3.new(0, 3, 0), "+" .. dados.valor, Color3.fromRGB(110, 255, 140), 28, { pop = 1.3 })
		particulas(raiz.Position, { cor = Color3.fromRGB(150, 255, 170), quantidade = 8, velocidade = 6, vida = 0.8, espalhar = Vector2.new(30, 30) })
	end
end

local function pilarDeLuz(raiz: BasePart, cor: Color3, altura: number, largura: number)
	local base = raiz.Position - Vector3.new(0, 3, 0)
	local pilar = parte(Vector3.new(altura, largura, largura), CFrame.new(base + Vector3.new(0, altura / 2, 0)) * EM_PE, cor, 0.35, Enum.PartType.Cylinder)
	animar(pilar, 0.7, { Size = Vector3.new(altura, 0.3, 0.3), Transparency = 1 })
	Debris:AddItem(pilar, 0.75)
	local onda = disco(base + Vector3.new(0, 0.2, 0), 1, cor, 0.2)
	animar(onda, 0.5, { Size = Vector3.new(0.15, 12, 12), Transparency = 1 })
	Debris:AddItem(onda, 0.55)
	particulas(raiz.Position, { cor = BRANCO, cor2 = cor, quantidade = 26, tamanho = 0.6, velocidade = 14, vida = 1, gravidade = -6, espalhar = Vector2.new(40, 40) })
	clarao(raiz.Position, cor, 26, 0.7, 5)
end

function Vfx.carta(dados)
	local raiz = raizDoJogador(dados.jogador)
	if dados.jogador == jogador then
		Sons.tocar("carta")
	end
	if raiz then
		local lendaria = dados.raridade == "Lendaria"
		pilarDeLuz(raiz, dados.cor, if lendaria then 60 else 30, if lendaria then 6 else 3.5)
		if lendaria and dados.jogador == jogador then
			Vfx.tremer(1.5, 0.4)
		end
	end
end

function Vfx.escolheuClasse(dados)
	local raiz = raizDoJogador(dados.jogador)
	if raiz then
		pilarDeLuz(raiz, dados.cor, 40, 5)
	end
end

function Vfx.reviver(dados)
	local raiz = raizDoJogador(dados.jogador)
	Sons.tocar("reviver", { pos = raiz and raiz.Position })
	if raiz then
		pilarDeLuz(raiz, Color3.fromRGB(140, 255, 170), 30, 4)
		textoFlutuante(raiz.Position + Vector3.new(0, 4, 0), "DE PÉ!", Color3.fromRGB(140, 255, 170), 34, { pop = 1.8 })
	end
end

function Vfx.segundaChance(dados)
	local raiz = raizDoJogador(dados.jogador)
	Sons.tocar("reviver", { pos = raiz and raiz.Position })
	if raiz then
		pilarDeLuz(raiz, Color3.fromRGB(255, 220, 110), 50, 6)
		textoFlutuante(raiz.Position + Vector3.new(0, 4, 0), "SEGUNDA CHANCE!", Color3.fromRGB(255, 220, 110), 40, { pop = 2 })
	end
end

function Vfx.caiu(dados)
	local raiz = raizDoJogador(dados.jogador)
	Sons.tocar("caiu", { pos = raiz and raiz.Position })
	if raiz then
		particulas(raiz.Position, { cor = Color3.fromRGB(80, 70, 90), quantidade = 20, velocidade = 10, vida = 0.8, luz = 0, gravidade = 5 })
	end
end

function Vfx.bloqueio(dados)
	local raiz = raizDoJogador(dados.jogador)
	Sons.tocar("escudo", { pos = raiz and raiz.Position })
	-- Barreira Arcana do Mago: a bolha roxa estoura
	local jogadorDados = dados.jogador
	if raiz and typeof(jogadorDados) == "Instance" and jogadorDados:GetAttribute("Classe") == "mago" and Vfx.temPrefab("BarreiraArcanaQuebra") then
		local tronco = (raiz.Parent :: Model):FindFirstChild("UpperTorso") or raiz
		Vfx.prefab("BarreiraArcanaQuebra", CFrame.new((tronco :: BasePart).Position), nil, 1.9)
		textoFlutuante(raiz.Position + Vector3.new(0, 3.5, 0), "BLOQUEADO", Color3.fromRGB(190, 110, 255), 30)
		return
	end
	if raiz then
		local cor = Color3.fromRGB(110, 190, 255)
		local bolha = parte(Vector3.one * 5, CFrame.new(raiz.Position), cor, 0.4, Enum.PartType.Ball, Enum.Material.ForceField)
		animar(bolha, 0.4, { Size = Vector3.one * 8, Transparency = 1 })
		Debris:AddItem(bolha, 0.45)
		textoFlutuante(raiz.Position + Vector3.new(0, 3.5, 0), "BLOQUEADO", cor, 30)
	end
end

--[[ Efeito pronto que acompanha o corpo por "duracao" segundos, virado para trás do movimento
	(os riscos e linhas do pacote saem para o -Z dele, então ficam para trás) ]]
local function rastroNoCorpo(raiz: BasePart, nome: string, duracao: number, escala: number)
	local inicio = os.clock()
	Vfx.prefab(nome, function()
		if not raiz.Parent or os.clock() - inicio > duracao then
			return nil
		end
		local v = raiz.AssemblyLinearVelocity
		local plano = Vector3.new(v.X, 0, v.Z)
		local tras = if plano.Magnitude > 1 then -plano.Unit else -raiz.CFrame.LookVector
		return CFrame.lookAt(raiz.Position, raiz.Position + tras)
	end, 0, escala)
end

local COR_ESQUIVA = {
	cavaleiro = Color3.fromRGB(255, 225, 160),
	mago = Color3.fromRGB(210, 160, 255),
	arqueiro = Color3.fromRGB(170, 255, 190),
	assassino = Color3.fromRGB(120, 30, 60),
}

function Vfx.esquiva(dados)
	local raiz = raizDoJogador(dados.jogador)
	if not raiz then
		return
	end
	Sons.tocar("esquiva", { pai = raiz })
	local personagem = raiz.Parent
	local cor = COR_ESQUIVA[dados.classe] or Color3.fromRGB(200, 230, 255)
	if dados.classe == "mago" and Vfx.temPrefab("PortalMago") then
		Vfx.prefab("PortalMago", CFrame.new(raiz.Position), nil, 0.7)
		task.delay(0.17, function()
			if raiz.Parent then
				Vfx.prefab("PortalMago", CFrame.new(raiz.Position), nil, 0.7)
			end
		end)
		return
	end
	if dados.classe == "assassino" and Vfx.temPrefab("RastroSombra") then
		-- passo de sombra: riscos escuros e linhas vermelhas atrás dele e uma lufada de fumaça
		rastroNoCorpo(raiz, "RastroSombra", 0.3, 1.8)
		return
	end
	if dados.classe == "arqueiro" and Vfx.temPrefab("PassoArqueiro") then
		rastroNoCorpo(raiz, "PassoArqueiro", 0.38, 1.8)
		task.delay(0.32, function()
			if raiz.Parent then
				Sons.tocar("pouso", { pai = raiz, tom = 1.2, volume = 0.6 })
			end
		end)
		return
	end
	if dados.classe == "cavaleiro" and Vfx.temPrefab("Rolamento") then
		-- rolamento do Cavaleiro: só o efeito pronto (vento e fumaça no chão) e o baque ao levantar
		local chao = raiz.Position - Vector3.new(0, 2.6, 0)
		Vfx.prefab("Rolamento", CFrame.lookAt(chao, chao + raiz.CFrame.LookVector))
		task.delay(0.3, function()
			if raiz.Parent then
				Sons.tocar("pouso", { pai = raiz, tom = 0.85 })
			end
		end)
		return
	end
	if not VfxKit.custom("Esquiva", raiz.CFrame) then
		local pe = raiz.Position - Vector3.new(0, 2.6, 0)
		soltar(pe, "poeira", { cor = Color3.fromRGB(190, 175, 150), quantidade = 10, escala = 0.8 })
		soltar(raiz.Position, "faiscas", { cor = cor, quantidade = 10, escala = 0.6, extra = { Acceleration = Vector3.zero } })
	end
	-- "fantasmas" do personagem que ficam para trás
	for i = 0, 2 do
		task.delay(i * 0.05, function()
			if not personagem or not personagem.Parent then
				return
			end
			for _, peca in personagem:GetChildren() do
				if peca:IsA("BasePart") and peca.Name ~= "HumanoidRootPart" and peca.Transparency < 1 then
					local fantasma = parte(peca.Size, peca.CFrame, cor, 0.5 + i * 0.1, nil, Enum.Material.Neon)
					animar(fantasma, 0.3, { Transparency = 1, Size = peca.Size * 0.85 })
					Debris:AddItem(fantasma, 0.32)
				end
			end
		end)
	end
	particulas(raiz.Position - Vector3.new(0, 2, 0), { cor = Color3.fromRGB(230, 240, 255), quantidade = 10, velocidade = 10, vida = 0.35, luz = 0.5 })
	if dados.classe == "cavaleiro" then
		local chao = raiz.Position - Vector3.new(0, 2.6, 0)
		Vfx.prefab("Rolamento", CFrame.lookAt(chao, chao + raiz.CFrame.LookVector))
		-- rolamento: poeira ao mergulhar e ao levantar
		poeiraNoChao(raiz.Position - Vector3.new(0, 2.6, 0), 3, 8)
		task.delay(0.3, function()
			if raiz.Parent then
				poeiraNoChao(raiz.Position - Vector3.new(0, 2.6, 0), 3.5, 12)
				Sons.tocar("pouso", { pai = raiz, tom = 0.85 })
			end
		end)
	end
	-- risco de vento que acompanha o corpo durante o impulso
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = raiz
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.6, 0)
	a1.Parent = raiz
	local vento = Instance.new("Trail")
	vento.Attachment0 = a0
	vento.Attachment1 = a1
	vento.Color = ColorSequence.new(BRANCO, cor)
	vento.Transparency = sequencia({ { 0, 0.35 }, { 1, 1 } })
	vento.Lifetime = 0.2
	vento.LightEmission = 1
	vento.LightInfluence = 0
	vento.FaceCamera = true
	vento.Parent = raiz
	task.delay(0.22, function()
		vento.Enabled = false
	end)
	Debris:AddItem(vento, 0.5)
	Debris:AddItem(a0, 0.5)
	Debris:AddItem(a1, 0.5)
end

------------------------------------------------------------------------
-- Ataque carregado
------------------------------------------------------------------------

-- Carga cheia: clarão dourado na ponta da arma
function Vfx.cargaCheia(dados)
	if not VfxKit.custom("CargaCheia", CFrame.new(dados.pos)) then
		local ouro = Color3.fromRGB(255, 214, 90)
		soltar(dados.pos, "clarao", { cor = ouro, quantidade = 1, escala = 0.7 })
		soltar(dados.pos, "anel", { cor = ouro, quantidade = 1, escala = 0.5, extra = { Orientation = Enum.ParticleOrientation.FacingCamera } })
		soltar(dados.pos, "brasas", { cor = ouro, quantidade = 14, escala = 0.7 })
	end
	Sons.tocar("cargaCheia", { pos = dados.pos, volume = if dados.local_ then 1 else 0.5 })
	if dados.classe == "assassino" and Vfx.temPrefab("CargaCheiaAssassino") then
		Vfx.prefab("CargaCheiaAssassino", CFrame.new(dados.pos), nil, 0.6)
		if dados.local_ then
			Vfx.tremer(0.25, 0.08)
		end
		return
	end
	if dados.classe == "arqueiro" and Vfx.temPrefab("CargaCheiaArqueiro") then
		Vfx.prefab("CargaCheiaArqueiro", CFrame.new(dados.pos), nil, 0.6)
		if dados.local_ then
			Vfx.tremer(0.25, 0.08)
		end
		return
	end
	local ouro = Color3.fromRGB(255, 214, 90)
	local bola = parte(Vector3.one * 0.6, CFrame.new(dados.pos), ouro:Lerp(BRANCO, 0.4), 0.1, Enum.PartType.Ball, Enum.Material.Neon)
	animar(bola, 0.25, { Size = Vector3.one * 4, Transparency = 1 })
	Debris:AddItem(bola, 0.3)
	particulas(dados.pos, { cor = BRANCO, cor2 = ouro, quantidade = 12, tamanho = 0.35, velocidade = 14, vida = 0.3 })
	clarao(dados.pos, ouro, 14, 0.25, 4)
	if dados.local_ then
		Vfx.tremer(0.35, 0.1)
	end
end

-- Fumaça escura que fica onde o Assassino some ou aparece
local function fumaca(posicao: Vector3, cor: Color3, quantidade: number)
	particulas(posicao, { cor = Color3.fromRGB(30, 22, 40), cor2 = cor, quantidade = quantidade, tamanho = 1.1, velocidade = 7, vida = 0.5, luz = 0 })
	local nuvem = parte(Vector3.one * 2, CFrame.new(posicao), Color3.fromRGB(25, 18, 32), 0.35, Enum.PartType.Ball, Enum.Material.SmoothPlastic)
	animar(nuvem, 0.4, { Size = Vector3.one * 5, Transparency = 1 })
	Debris:AddItem(nuvem, 0.45)
end

-- Assassino: some numa fumaça e aparece em outro lugar, deixando um risco no ar
function Vfx.passoSombrio(dados)
	if not VfxKit.custom("PassoSombrio", CFrame.new(dados.ate)) then
		local escuro = Color3.fromRGB(35, 10, 30)
		soltar(dados.de, "fumaca", { cor = escuro, quantidade = if dados.leve then 5 else 12, escala = 0.8 })
		soltar(dados.ate, "implosao", { cor = dados.cor, quantidade = 2, escala = 0.5 })
		soltar(dados.ate, "fumaca", { cor = escuro, quantidade = if dados.leve then 4 else 9, escala = 0.7 })
		soltar(dados.ate, "faiscas", { cor = dados.cor, quantidade = 12, escala = 0.8 })
	end
	Sons.tocar("passoSombrio", { pos = dados.ate, volume = if dados.leve then 0.6 else 1 })
	if dados.leve then
		Sons.tocar("adaga", { pos = dados.ate })
	end
	local de, ate = dados.de, dados.ate
	local cor = dados.cor
	if Vfx.temPrefab("FumacaSombria") then
		local escala = if dados.leve then 0.6 else 1
		Vfx.prefab("FumacaSombria", CFrame.new(de), nil, escala)
		Vfx.prefab("FumacaSombria", CFrame.new(ate), nil, escala * 0.8)
		if dados.jogador == jogador and not dados.leve then
			Vfx.tremer(0.4, 0.1)
		end
		return
	end
	fumaca(de, cor, if dados.leve then 6 else 12)
	fumaca(ate, cor, if dados.leve then 4 else 8)
	-- silhueta escura que fica onde o Assassino estava
	local raiz = raizDoJogador(dados.jogador)
	local personagem = raiz and raiz.Parent
	if personagem then
		local deslocamento = de - ate
		for _, peca in personagem:GetChildren() do
			if peca:IsA("BasePart") and peca.Name ~= "HumanoidRootPart" and peca.Transparency < 1 then
				local sombra = parte(peca.Size, peca.CFrame + deslocamento, Color3.fromRGB(40, 0, 20), 0.35, nil, Enum.Material.Neon)
				animar(sombra, 0.4, { Transparency = 1 })
				Debris:AddItem(sombra, 0.45)
			end
		end
	end
	-- corte em X vermelho onde ele aparece
	local frente = Vector3.new(ate.X - de.X, 0, ate.Z - de.Z)
	frente = if frente.Magnitude > 0.1 then frente.Unit else Vector3.new(0, 0, -1)
	local origemX = CFrame.lookAt(ate, ate + frente)
	arcoDeCorte(origemX * CFrame.Angles(0, 0, math.rad(45)), 3.2, 140, cor, { espessura = 1.1, duracao = 0.12 })
	task.delay(0.05, function()
		arcoDeCorte(origemX * CFrame.Angles(0, 0, math.rad(-45)), 3.2, 140, cor, { espessura = 1.1, duracao = 0.12, reverso = true })
	end)
	local distancia = (ate - de).Magnitude
	if distancia > 1 then
		local risco = parte(Vector3.new(0.35, 0.35, distancia), CFrame.lookAt((de + ate) / 2, ate), cor, 0.2, nil, Enum.Material.Neon)
		animar(risco, 0.25, { Size = Vector3.new(0.05, 0.05, distancia), Transparency = 1 })
		Debris:AddItem(risco, 0.3)
	end
	if dados.jogador == jogador and not dados.leve then
		Vfx.tremer(0.4, 0.1)
	end
end

-- Investida Letal do Assassino (golpe carregado): linha de cortes no caminho
function Vfx.investidaLetal(dados)
	Sons.tocar("investida", { pos = dados.de })
	local de, ate = dados.de, dados.ate
	local cor = if dados.perfeito then dados.cor:Lerp(Color3.fromRGB(255, 214, 90), 0.5) else dados.cor
	local distancia = (ate - de).Magnitude
	if distancia < 0.5 then
		return
	end
	local direcao = (ate - de).Unit
	if Vfx.temPrefab("InvestidaFim") then
		for i = 0, 2 do
			task.delay(i * 0.05, function()
				Vfx.prefab("CorteAdaga", CFrame.new(de + direcao * distancia * (0.3 + 0.3 * i) + Vector3.new(0, 0.4, 0)), nil, 0.6)
			end)
		end
		local raiz = raizDoJogador(dados.jogador)
		if raiz then
			rastroNoCorpo(raiz, "RastroSombra", 0.25, 1.8)
		end
		-- no fim do avanço, a explosão vermelha e preta sai para a frente
		task.delay(0.2, function()
			Vfx.prefab("InvestidaFim", CFrame.lookAt(ate, ate + direcao), nil, if dados.perfeito then 0.24 else 0.16)
		end)
		Vfx.tremerEm(ate, if dados.perfeito then 1 else 0.6, 0.12)
		return
	end
	for i = 0, 2 do
		task.delay(i * 0.04, function()
			local lado = if i % 2 == 0 then 1 else -1
			local origem = CFrame.lookAt(de + direcao * distancia * (0.3 + 0.3 * i), de + direcao * distancia * (0.3 + 0.3 * i) + direcao)
			arcoDeCorte(origem * CFrame.Angles(0, 0, math.rad(35 * lado)), 3.2, 160, cor, { espessura = 0.9, duracao = 0.12, reverso = lado < 0 })
		end)
	end
	local rastro = parte(Vector3.new(1.2, 0.2, distancia), CFrame.lookAt((de + ate) / 2, ate), cor, 0.3, nil, Enum.Material.Neon)
	animar(rastro, 0.35, { Size = Vector3.new(0.1, 0.05, distancia), Transparency = 1 })
	Debris:AddItem(rastro, 0.4)
	particulas(ate, { cor = cor, cor2 = BRANCO, quantidade = 12, tamanho = 0.4, velocidade = 18, vida = 0.3 })
	Vfx.tremerEm(ate, if dados.perfeito then 1 else 0.6, 0.12)
end

-- Chão em chamas deixado pelo Meteoro
function Vfx.zonaFogo(dados)
	Sons.tocar("bolaFogo", { pos = dados.pos, tom = 0.7, volume = 0.5 })
	local centro = dados.pos + Vector3.new(0, 0.1, 0)
	local diametro = dados.raio * 2
	local base = disco(centro, diametro, FOGO, 0.45)
	-- peça invisível e achatada: as chamas saem de toda a área dela, para cima
	local area = parte(Vector3.new(diametro * 0.75, 0.2, diametro * 0.75), CFrame.new(centro), FOGO, 1)
	local chamas = VfxKit.continuo(area, "fogo", 45, {
		cor = FOGO,
		escala = 1.3,
		extra = { Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Speed = NumberRange.new(3, 7) },
	})
	local fumacaZona = VfxKit.continuo(area, "fumaca", 8, {
		cor = Color3.fromRGB(70, 60, 55),
		extra = { Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(2, 4) },
	})
	task.delay(dados.duracao, function()
		fumacaZona.Enabled = false
	end)
	local luz = Instance.new("PointLight")
	luz.Color = FOGO
	luz.Range = diametro
	luz.Brightness = 2
	luz.Parent = area
	task.delay(dados.duracao, function()
		chamas.Enabled = false
		animar(luz, 0.3, { Brightness = 0 })
	end)
	sumir({ base }, 0.4, dados.duracao)
	Debris:AddItem(area, dados.duracao + 1)
end

-- Escudo do Cavaleiro bloqueou um golpe: faíscas no escudo. Defesa perfeita: clarão dourado.
function Vfx.defesa(dados)
	if not VfxKit.custom("Defesa", CFrame.lookAt(dados.pos, dados.pos + (dados.dir or Vector3.new(0, 0, -1)))) then
		local corFaisca = if dados.perfeita then Color3.fromRGB(255, 214, 90) else Color3.fromRGB(255, 170, 90)
		soltar(dados.pos, "faiscas", { cor = corFaisca, quantidade = if dados.perfeita then 40 else 20, escala = 1.1, direcao = dados.dir, extra = { SpreadAngle = Vector2.new(55, 55) } })
		soltar(dados.pos, "clarao", { cor = corFaisca, quantidade = 1, escala = if dados.perfeita then 1.2 else 0.6 })
		if dados.perfeita then
			soltar(dados.pos, "anel", { cor = corFaisca, quantidade = 1, escala = 0.9, extra = { Orientation = Enum.ParticleOrientation.FacingCamera } })
			soltar(dados.pos, "brasas", { cor = corFaisca, quantidade = 16 })
		end
	end
	Sons.tocar(if dados.perfeita then "escudoPerfeito" else "escudo", { pos = dados.pos })
	local pos = dados.pos + Vector3.new(0, 0.6, 0)
	local dir = dados.dir or Vector3.new(0, 0, -1)
	local cor = if dados.perfeita then Color3.fromRGB(255, 214, 90) else Color3.fromRGB(150, 200, 255)
	if not dados.perfeita and Vfx.temPrefab("BloqueioEscudo") then
		-- golpe bloqueado: estouro azul no escudo
		Vfx.prefab("BloqueioEscudo", CFrame.lookAt(pos, pos + dir), nil, 1.2)
		if dados.jogador == jogador then
			Vfx.tremer(0.45, 0.12)
		end
		return
	end
	if dados.perfeita and Vfx.temPrefab("DefesaPerfeita") then
		Vfx.prefab("DefesaPerfeita", CFrame.lookAt(pos, pos + dir), nil, 1.5)
		local raiz = raizDoJogador(dados.jogador)
		textoFlutuante((if raiz then raiz.Position else pos) + Vector3.new(0, 3.5, 0), "DEFESA PERFEITA!", cor, 34, { pop = 2 })
		if dados.jogador == jogador then
			Vfx.tremer(0.9, 0.12)
		end
		return
	end
	-- anel que sai do escudo para a frente
	local anelEscudo = parte(Vector3.new(0.2, 2.5, 2.5), CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0), cor, 0.2, Enum.PartType.Cylinder)
	animar(anelEscudo, 0.25, { Size = Vector3.new(0.05, if dados.perfeita then 9 else 5, if dados.perfeita then 9 else 5), Transparency = 1 })
	Debris:AddItem(anelEscudo, 0.3)
	particulas(pos, {
		cor = BRANCO,
		cor2 = cor,
		quantidade = if dados.perfeita then 26 else 12,
		tamanho = 0.3,
		velocidade = if dados.perfeita then 32 else 20,
		vida = 0.3,
		gravidade = 30,
		espalhar = Vector2.new(70, 70),
	})
	clarao(pos, cor, if dados.perfeita then 22 else 12, 0.2, if dados.perfeita then 6 else 3)
	riscos(pos, cor, if dados.perfeita then 22 else 10, if dados.perfeita then 45 else 30, dir)
	if dados.perfeita then
		local substituir = Vfx.temPrefab("DefesaPerfeita")
		Vfx.prefab("DefesaPerfeita", CFrame.lookAt(pos, pos + dir))
		if not substituir then
			-- estrela: raios de luz saindo do escudo, de frente para quem atacou
			local plano = CFrame.lookAt(pos, pos + dir)
			for i = 1, 10 do
				local angulo = i / 10 * math.pi * 2 + math.random() * 0.2
				local comprimento = if i % 2 == 0 then 7 else 4.5
				local raio = parte(Vector3.new(0.18, 0.18, 0.4), plano * CFrame.Angles(0, 0, angulo), BRANCO, 0)
				local destino = plano * CFrame.Angles(0, 0, angulo) * CFrame.new(0, comprimento / 2, 0)
				animar(raio, 0.12, { Size = Vector3.new(0.16, comprimento, 0.16), CFrame = destino, Color = cor })
				task.delay(0.12, function()
					animar(raio, 0.2, { Size = Vector3.new(0.02, comprimento * 1.2, 0.02), Transparency = 1 })
				end)
				Debris:AddItem(raio, 0.4)
			end
			local bolha = parte(Vector3.one * 2, CFrame.new(pos), cor, 0.3, Enum.PartType.Ball, Enum.Material.ForceField)
			animar(bolha, 0.3, { Size = Vector3.one * 8, Transparency = 1 })
			Debris:AddItem(bolha, 0.35)
		end
		local raiz = raizDoJogador(dados.jogador)
		textoFlutuante((if raiz then raiz.Position else pos) + Vector3.new(0, 3.5, 0), "DEFESA PERFEITA!", cor, 34, { pop = 2 })
	end
	if dados.jogador == jogador then
		Vfx.tremer(if dados.perfeita then 0.9 else 0.45, 0.12)
	end
end

-- Escudo ganho com o Julgamento do Cavaleiro
function Vfx.escudoGanho(dados)
	local raiz = raizDoJogador(dados.jogador)
	if not raiz then
		return
	end
	Sons.tocar("escudo", { pos = raiz.Position, tom = 1.4, volume = 0.5 })
	local bolha = parte(Vector3.one * 2, raiz.CFrame, dados.cor:Lerp(BRANCO, 0.4), 0.3, Enum.PartType.Ball, Enum.Material.ForceField)
	animar(bolha, 0.5, { Size = Vector3.one * 7, Transparency = 1 })
	Debris:AddItem(bolha, 0.55)
	textoFlutuante(raiz.Position + Vector3.new(0, 3.5, 0), "🛡️ ESCUDO", dados.cor:Lerp(BRANCO, 0.4), 26)
end

function Vfx.supremo(dados)
	local raiz = raizDoJogador(dados.jogador)
	if not raiz then
		return
	end
	textoFlutuante(raiz.Position + Vector3.new(0, 5, 0), string.upper(dados.nome) .. "!", dados.cor:Lerp(BRANCO, 0.3), 54, { pop = 2.4, subida = 4 })
	local onda = parte(Vector3.one * 2, CFrame.new(raiz.Position), dados.cor, 0.2, Enum.PartType.Ball)
	animar(onda, 0.5, { Size = Vector3.one * 24, Transparency = 1 })
	Debris:AddItem(onda, 0.55)
	clarao(raiz.Position, dados.cor, 40, 0.8, 6)
	if dados.jogador == jogador then
		Vfx.tremer(1.5, 0.35)
	end
end

------------------------------------------------------------------------
-- Portal de invocação e moedas
------------------------------------------------------------------------

function Vfx.portal(dados)
	Sons.tocar("portal", { pos = dados.pos, volume = 0.7 })
	local cor = if dados.elite then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(150, 70, 255)
	local centro = dados.pos + Vector3.new(0, 0.12, 0)
	local base = disco(centro, 0.5, cor, 0.3)
	animar(base, dados.duracao * 0.5, { Size = Vector3.new(0.15, 6, 6) }, Enum.EasingStyle.Back)
	local partes = anel(centro + Vector3.new(0, 0.03, 0), 3.4, cor, 0.1, 14, 0.3)
	table.insert(partes, base)
	local a = ancora(centro)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(cor:Lerp(BRANCO, 0.4), cor)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = sequencia({ { 0, 0.4 }, { 1, 0 } })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(4, 8)
	e.SpreadAngle = Vector2.new(15, 15)
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.Rate = 45
	e.Parent = a
	local l = Instance.new("PointLight")
	l.Color = cor
	l.Range = 14
	l.Brightness = 2
	l.Parent = a
	task.delay(dados.duracao, function()
		e.Enabled = false
		animar(l, 0.3, { Brightness = 0 })
		particulas(centro + Vector3.new(0, 1, 0), { cor = cor, quantidade = 16, velocidade = 12, vida = 0.4 })
	end)
	sumir(partes, 0.3, dados.duracao)
	Debris:AddItem(a, dados.duracao + 1)
end

function Vfx.moedas(dados)
	Sons.tocar("moeda", { pos = dados.pos })
	local destino = raizDoJogador(jogador)
	local ouro = Color3.fromRGB(255, 206, 70)
	for _ = 1, dados.quantidade do
		local moeda = Instance.new("Part")
		moeda.Shape = Enum.PartType.Cylinder
		moeda.Size = Vector3.new(0.18, 0.9, 0.9)
		moeda.Material = Enum.Material.Neon
		moeda.Color = ouro
		moeda.CanQuery = false
		moeda.CanTouch = false
		moeda.CastShadow = false
		moeda.CFrame = CFrame.new(dados.pos + Vector3.new(0, 1, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		moeda.Parent = pasta
		moeda.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 22, math.random(18, 30), (math.random() - 0.5) * 22)
		moeda.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), 0)
		task.delay(0.9 + math.random() * 0.4, function()
			if not moeda.Parent then
				return
			end
			moeda.Anchored = true
			local alvo = destino and destino.Parent and destino.Position or moeda.Position + Vector3.new(0, 4, 0)
			local tween = animar(moeda, 0.35, { CFrame = CFrame.new(alvo), Size = Vector3.new(0.1, 0.4, 0.4) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween.Completed:Once(function()
				moeda:Destroy()
			end)
		end)
		Debris:AddItem(moeda, 3)
	end
end

-- Estouro genérico (usado na morte dos inimigos)
function Vfx.estouro(posicao: Vector3, cor: Color3, quantidade: number, velocidade: number)
	if not VfxKit.custom("Morte", CFrame.new(posicao)) then
		soltar(posicao, "fumaca", { cor = cor:Lerp(Color3.fromRGB(40, 35, 45), 0.6), quantidade = 10, escala = 0.9 })
		soltar(posicao, "faiscas", { cor = cor, quantidade = 22, escala = 1 })
		soltar(posicao, "brasas", { cor = cor, quantidade = 14, escala = 0.9 })
		soltar(posicao, "clarao", { cor = cor, quantidade = 1, escala = 0.8 })
	end
	Sons.tocar("inimigoMorre", { pos = posicao })
	particulas(posicao, { cor = cor:Lerp(BRANCO, 0.3), cor2 = cor, quantidade = quantidade, tamanho = 0.7, velocidade = velocidade, vida = 0.6, gravidade = 20 })
	clarao(posicao, cor, 16, 0.3, 3)
end


------------------------------------------------------------------------
-- Habilidades e supremos com efeitos elaborados
------------------------------------------------------------------------

-- Peças que giram em volta de um centro (anéis de vento, detritos...) até "duracao" acabar.
-- cada item: { parte, raio, altura, velocidade, fase, inclinacao }
local function orbitar(centroFn: () -> Vector3?, itens, duracao: number, aoTerminar: (() -> ())?)
	local inicio = os.clock()
	local conexao
	conexao = RunService.RenderStepped:Connect(function()
		local t = os.clock() - inicio
		local centro = centroFn()
		if t > duracao or not centro then
			conexao:Disconnect()
			for _, item in itens do
				animar(item.parte, 0.25, { Transparency = 1 })
				Debris:AddItem(item.parte, 0.3)
			end
			if aoTerminar then
				aoTerminar()
			end
			return
		end
		for _, item in itens do
			local a = item.fase + t * item.velocidade
			if item.anel then
				-- anel deitado girando no próprio eixo, levemente inclinado
				item.parte.CFrame = CFrame.new(centro + Vector3.new(0, item.altura, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(item.inclinacao or 0, 0, 0) * EM_PE
			else
				item.parte.CFrame = CFrame.new(centro + Vector3.new(math.cos(a) * item.raio, item.altura + math.sin(t * 6 + item.fase) * 0.4, math.sin(a) * item.raio)) * CFrame.Angles(a, a * 1.3, 0)
			end
		end
	end)
end

-- Redemoinho: tornado de vento em volta do Cavaleiro, com arcos de espada, poeira e
-- pedrinhas girando
function Vfx.redemoinho(dados)
	local raiz = raizDoJogador(dados.jogador)
	if not raiz then
		return
	end
	local cor = if dados.fogo then FOGO else dados.cor
	local raio = dados.raio
	Sons.tocar("giro", { pai = raiz })
	-- efeito pronto do pacote de VFX: uma tempestade de cortes girando em volta do Cavaleiro
	-- (diferente do tornado do ataque carregado); com poder de fogo, os cortes são de fogo
	local nome = if dados.fogo and Vfx.temPrefab("RedemoinhoFogo") then "RedemoinhoFogo" else "Redemoinho"
	local substituir = Vfx.temPrefab(nome)
	Vfx.prefab(nome, function()
		if not raiz.Parent then
			return nil
		end
		return CFrame.new(raiz.Position)
	end, dados.duracao, raio / 9)
	if substituir then
		return
	end
	VfxKit.custom("Redemoinho", raiz.CFrame)
	local aura = Instance.new("Attachment")
	aura.Parent = raiz
	local faiscasGiro = VfxKit.continuo(aura, "faiscas", 60, { cor = cor, escala = 0.8, extra = { Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface } })
	local brasasGiro = VfxKit.continuo(aura, "brasas", 30, { cor = cor })
	local pePoeira = Instance.new("Attachment")
	pePoeira.Position = Vector3.new(0, -2.6, 0)
	pePoeira.Parent = raiz
	local poeiraGiro = VfxKit.continuo(pePoeira, "poeira", 40, { cor = Color3.fromRGB(185, 170, 145), escala = 1.1, extra = { SpreadAngle = Vector2.new(180, 5), EmissionDirection = Enum.NormalId.Right } })
	task.delay(dados.duracao, function()
		faiscasGiro.Enabled = false
		brasasGiro.Enabled = false
		poeiraGiro.Enabled = false
		Debris:AddItem(aura, 1.5)
		Debris:AddItem(pePoeira, 1.5)
	end)
	-- arcos da espada (dois, girando)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	local b0, b1 = Instance.new("Attachment"), Instance.new("Attachment")
	for _, a in { a0, a1, b0, b1 } do
		a.Parent = terreno
	end
	local feixesA = { novoFeixe(a0, a1, cor:Lerp(BRANCO, 0.5), 0.8), novoFeixe(a0, a1, cor, 2.6) }
	local feixesB = { novoFeixe(b0, b1, cor:Lerp(BRANCO, 0.5), 0.8), novoFeixe(b0, b1, cor, 2.6) }
	for i, feixe in { feixesA[1], feixesA[2], feixesB[1], feixesB[2] } do
		feixe.Transparency = sequencia({ { 0, 1 }, { 0.5, if i % 2 == 1 then 0 else 0.5 }, { 1, 0.1 } })
	end
	-- tornado: funil de vento em volta do Cavaleiro
	local itens = {}
	local vento = funil(raio * 0.85, 7, cor, 4, 0.3)
	local humanoid = if raiz.Parent then raiz.Parent:FindFirstChildOfClass("Humanoid") else nil
	-- detritos girando
	for i = 1, 8 do
		local pedra = parte(Vector3.one * (0.3 + math.random() * 0.4), CFrame.new(), Color3.fromRGB(120, 110, 100), 0, nil, Enum.Material.Slate)
		table.insert(itens, { parte = pedra, raio = raio * (0.5 + math.random() * 0.6), altura = -1.5 + math.random() * 4, velocidade = 7 + math.random() * 5, fase = i * 0.8 })
	end
	-- poeira no chão
	local poeira = ancora(raiz.Position - Vector3.new(0, 2.6, 0))
	local emissorPoeira = Instance.new("ParticleEmitter")
	emissorPoeira.Color = ColorSequence.new(Color3.fromRGB(200, 185, 160))
	emissorPoeira.LightInfluence = 1
	emissorPoeira.Transparency = sequencia({ { 0, 0.4 }, { 1, 1 } })
	emissorPoeira.Size = sequencia({ { 0, 1 }, { 1, 2.5 } })
	emissorPoeira.Lifetime = NumberRange.new(0.5, 0.8)
	emissorPoeira.Speed = NumberRange.new(10, 16)
	emissorPoeira.SpreadAngle = Vector2.new(5, 180)
	emissorPoeira.EmissionDirection = Enum.NormalId.Right
	emissorPoeira.Rate = 50
	emissorPoeira.Parent = poeira
	local inicio = os.clock()
	local conexao
	conexao = RunService.RenderStepped:Connect(function()
		local t = os.clock() - inicio
		if t > dados.duracao or not raiz.Parent then
			conexao:Disconnect()
			for _, a in { a0, a1, b0, b1 } do
				a:Destroy()
			end
			vento.parar(0.25)
			emissorPoeira.Enabled = false
			Debris:AddItem(poeira, 1)
			return
		end
		local centro = CFrame.new(raiz.Position) * CFrame.Angles(0, -t * 14, 0)
		posicionarArco(a0, a1, feixesA, centro, raio * 0.8, 150)
		posicionarArco(b0, b1, feixesB, centro * CFrame.Angles(0, math.pi, 0), raio * 0.8, 150)
		vento.atualizar(Vector3.new(raiz.Position.X, chaoDe(raiz, humanoid), raiz.Position.Z), t, math.min(1, t / 0.2))
		poeira.WorldCFrame = CFrame.new(raiz.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, t * 9, 0)
	end)
	orbitar(function()
		return if raiz.Parent then raiz.Position else nil
	end, itens, dados.duracao)
end

-- Julgamento: uma espada de luz gigante cai do céu e crava no chão; o chão racha,
-- pilares de luz sobem em volta e pedras voam
-- Clarão na tela inteira de quem está perto: o brilho sobe de uma vez e volta devagar
local function clarearTela(posicao: Vector3, cor: Color3, forca: number, duracao: number)
	local raiz = raizDoJogador(jogador)
	if raiz and (raiz.Position - posicao).Magnitude > 120 then
		return
	end
	local efeito = Instance.new("ColorCorrectionEffect")
	efeito.Name = "ClaraoTela"
	efeito.Brightness = forca
	efeito.Contrast = forca * 0.6
	efeito.TintColor = BRANCO:Lerp(cor, 0.35)
	efeito.Parent = Lighting
	animar(efeito, duracao, { Brightness = 0, Contrast = 0, TintColor = BRANCO })
	Debris:AddItem(efeito, duracao + 0.1)
end

function Vfx.julgamento(dados)
	Sons.tocar("julgamento", { pos = dados.pos, alcance = 260 })
	local escala = math.max(1, (dados.raio or 15) / 15)
	if Vfx.temPrefab("Julgamento") then
		-- efeitos do pacote: quando o golpe acontece (0,35s, igual ao servidor) cai um raio azul
		-- e o chão explode em luz dourada; a tela dá um clarão e treme forte
		task.delay(0.33, function()
			Vfx.prefab("JulgamentoRaio", CFrame.new(dados.pos + Vector3.new(0, 12, 0)), nil, escala)
			Vfx.prefab("Julgamento", CFrame.new(dados.pos), nil, escala * 0.9)
			Sons.tocar("trovao", { pos = dados.pos, alcance = 300, volume = 1.3 })
			clarearTela(dados.pos, OURO, 0.55, 0.6)
			Vfx.tremerEm(dados.pos, 4, 0.6)
		end)
		return
	end
	Vfx.prefab("Julgamento", CFrame.new(dados.pos), nil, escala)
	local pos, raio = dados.pos, dados.raio
	local cor = Color3.fromRGB(255, 220, 120)
	local corClasse = dados.cor or cor
	local alto = pos + Vector3.new(0, 70, 0)
	local lamina = parte(Vector3.new(1.6, 22, 0.5), CFrame.new(alto), cor:Lerp(BRANCO, 0.4), 0.05)
	local guarda = parte(Vector3.new(7, 1, 1), CFrame.new(alto + Vector3.new(0, 11.5, 0)), cor, 0)
	local cabo = parte(Vector3.new(0.9, 4, 0.9), CFrame.new(alto + Vector3.new(0, 14, 0)), corClasse, 0)
	local aura = parte(Vector3.new(4, 26, 4), CFrame.new(alto + Vector3.new(0, 2, 0)), cor, 0.75, Enum.PartType.Ball)
	luzEm(lamina, cor, 40, 4)
	local partes = { lamina, guarda, cabo, aura }
	local destino = pos + Vector3.new(0, 9, 0)
	for _, p in partes do
		animar(p, 0.32, { CFrame = p.CFrame - (alto - destino) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	task.delay(0.32, function()
		sumir(partes, 0.5, 0.35)
		-- ondas de choque
		for i = 0, 2 do
			task.delay(i * 0.12, function()
				local onda = disco(pos + Vector3.new(0, 0.25, 0), 3, if i == 0 then BRANCO else corClasse, 0.15)
				animar(onda, 0.5, { Size = Vector3.new(0.15, raio * 2.2, raio * 2.2), Transparency = 1 })
				Debris:AddItem(onda, 0.55)
			end)
		end
		-- rachaduras brilhantes saindo do centro
		for i = 1, 10 do
			local angulo = i / 10 * math.pi * 2 + math.random() * 0.3
			local comprimento = raio * (0.6 + math.random() * 0.5)
			local direcao = Vector3.new(math.cos(angulo), 0, math.sin(angulo))
			local rachadura = parte(Vector3.new(0.35, 0.1, 0.1), CFrame.lookAt(pos + Vector3.new(0, 0.18, 0), pos + Vector3.new(0, 0.18, 0) + direcao), cor, 0)
			animar(rachadura, 0.15, { Size = Vector3.new(0.35, 0.1, comprimento), CFrame = CFrame.lookAt(pos + direcao * comprimento / 2 + Vector3.new(0, 0.18, 0), pos + direcao * comprimento + Vector3.new(0, 0.18, 0)) })
			sumir({ rachadura }, 0.8, 0.9)
		end
		-- pilares de luz em volta
		for i = 1, 6 do
			local angulo = i / 6 * math.pi * 2
			local p = pos + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * raio * 0.75
			task.delay(0.05 * i, function()
				local pilar = parte(Vector3.new(1.4, 0.2, 1.4), CFrame.new(p), cor, 0.2)
				animar(pilar, 0.2, { Size = Vector3.new(1, 18, 1), CFrame = CFrame.new(p + Vector3.new(0, 9, 0)) })
				sumir({ pilar }, 0.4, 0.25)
			end)
		end
		-- pedras voando
		for _ = 1, 10 do
			local pedra = parte(Vector3.one * (0.6 + math.random() * 0.8), CFrame.new(pos + Vector3.new(math.random(-3, 3), 0.8, math.random(-3, 3))), Color3.fromRGB(110, 100, 92), 0, nil, Enum.Material.Slate)
			pedra.Anchored = false
			pedra.AssemblyLinearVelocity = Vector3.new(math.random(-30, 30), math.random(25, 45), math.random(-30, 30))
			pedra.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
			sumir({ pedra }, 0.4, 1.2)
		end
		particulas(pos + Vector3.new(0, 1, 0), { cor = BRANCO, cor2 = cor, quantidade = 50, tamanho = 1, velocidade = 45, vida = 0.8, gravidade = 25 })
		if not VfxKit.custom("Julgamento", CFrame.new(pos), raio / 10) then
			local e = raio / 9
			soltar(pos + Vector3.new(0, 2, 0), "clarao", { cor = cor, quantidade = 1, escala = e * 2 })
			soltar(pos + Vector3.new(0, 0.25, 0), "circulo", { cor = cor, escala = raio / 4, quantidade = 1, extra = { Lifetime = NumberRange.new(1.4, 1.4) } })
			soltar(pos + Vector3.new(0, 1, 0), "nucleo", { cor = cor, quantidade = 8, escala = e })
			soltar(pos + Vector3.new(0, 0.3, 0), "onda", { cor = cor, quantidade = 1, escala = e * 1.4 })
			task.delay(0.1, function()
				soltar(pos + Vector3.new(0, 0.3, 0), "onda", { cor = BRANCO, quantidade = 1, escala = e })
			end)
			soltar(pos + Vector3.new(0, 0.5, 0), "poeira", { cor = Color3.fromRGB(170, 150, 120), quantidade = 30, escala = e * 1.4 })
			soltar(pos + Vector3.new(0, 1, 0), "faiscas", { cor = cor, quantidade = 50, escala = e * 1.5 })
			soltar(pos + Vector3.new(0, 1, 0), "brasas", { cor = cor, quantidade = 30, escala = e })
		end
		clarao(pos, cor, raio * 4, 0.6, 8)
		Vfx.tremerEm(pos, 3.5, 0.5)
	end)
end

-- Meteoro: rocha em brasa girando, com fumaça e fogo, que cai e abre uma cratera
function Vfx.meteoro(dados)
	Sons.tocar("meteoro", { pos = dados.pos, alcance = 200 })
	-- meteoro do Mago: roxo arcano (o do chefe continua de fogo)
	local FOGO = if dados.arcano then Color3.fromRGB(190, 110, 255) else FOGO
	local alvo = dados.pos
	local inicio = alvo + Vector3.new(-16, 55, -16)
	local rocha = parte(Vector3.one * 3.2, CFrame.new(inicio), Color3.fromRGB(60, 40, 35), 0, Enum.PartType.Ball, Enum.Material.Basalt)
	local brasa = parte(Vector3.one * 4.2, CFrame.new(inicio), FOGO, 0.45, Enum.PartType.Ball)
	local fogo = Instance.new("Fire")
	fogo.Size = 10
	fogo.Heat = 0
	fogo.Parent = rocha
	VfxKit.continuo(rocha, "fogo", 70, { cor = FOGO, escala = 1.4 })
	VfxKit.continuo(rocha, "fumaca", 30, { cor = Color3.fromRGB(60, 50, 50), escala = 1.2, extra = { Speed = NumberRange.new(1, 3) } })
	emissorEm(rocha, {
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), FOGO),
		LightEmission = 1,
		Size = sequencia({ { 0, 0.5 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 50,
	})
	rastro(rocha, FOGO, 3, 0.5)
	luzEm(rocha, FOGO, 30, 4)
	local destino = alvo + Vector3.new(0, 1.5, 0)
	animar(rocha, dados.duracao, { CFrame = CFrame.new(destino) * CFrame.Angles(6, 4, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	animar(brasa, dados.duracao, { CFrame = CFrame.new(destino) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(rocha, dados.duracao + 0.05)
	Debris:AddItem(brasa, dados.duracao + 0.05)
	if dados.amigo then
		local partes = anel(alvo + Vector3.new(0, 0.15, 0), dados.raio or 10, FOGO, 0.35, 24, 0.4)
		sumir(partes, 0.2, dados.duracao)
		soltar(alvo + Vector3.new(0, 0.2, 0), "circulo", { cor = FOGO, escala = (dados.raio or 10) / 4, quantidade = 1, extra = { Lifetime = NumberRange.new(dados.duracao + 0.2, dados.duracao + 0.2) } })
	end
	task.delay(dados.duracao, function()
		if dados.arcano and Vfx.temPrefab("MeteoroImpacto") then
			Vfx.prefab("MeteoroImpacto", CFrame.new(alvo + Vector3.new(0, 0.2, 0)), nil, (dados.raio or 10) / 12)
			Vfx.prefab("MeteoroExplosao", CFrame.new(alvo + Vector3.new(0, 3, 0)), nil, (dados.raio or 10) / 16)
			Vfx.tremerEm(alvo, 2, 0.4)
			return
		end
		if not VfxKit.custom("Meteoro", CFrame.new(alvo), (dados.raio or 10) / 10) then
			soltar(alvo + Vector3.new(0, 1, 0), "fogo", { cor = FOGO, quantidade = 30, escala = 1.6 })
			soltar(alvo + Vector3.new(0, 0.5, 0), "fumaca", { cor = Color3.fromRGB(60, 50, 48), quantidade = 18, escala = 1.6 })
			soltar(alvo + Vector3.new(0, 0.3, 0), "poeira", { cor = Color3.fromRGB(140, 115, 95), quantidade = 24, escala = 1.5 })
		end
		-- cratera: pedras que se erguem em volta do impacto
		local raioCratera = (dados.raio or 10) * 0.55
		for i = 1, 12 do
			local angulo = i / 12 * math.pi * 2
			local p = alvo + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * raioCratera
			local bloco = parte(Vector3.new(1.6, 0.2, 1.2), CFrame.lookAt(p, alvo) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(70, 55, 50), 0, nil, Enum.Material.Basalt)
			animar(bloco, 0.12, { Size = Vector3.new(1.6, 2.2, 1.2) }, Enum.EasingStyle.Back)
			sumir({ bloco }, 0.6, 2.4)
		end
		-- coluna de fogo
		local coluna = parte(Vector3.new(3, 1, 3), CFrame.new(alvo), Color3.fromRGB(255, 200, 90), 0.1, Enum.PartType.Ball)
		animar(coluna, 0.3, { Size = Vector3.new(5, 16, 5), CFrame = CFrame.new(alvo + Vector3.new(0, 7, 0)), Transparency = 1, Color = FOGO })
		Debris:AddItem(coluna, 0.35)
		for _ = 1, 8 do
			local pedaco = parte(Vector3.one * (0.5 + math.random() * 0.6), CFrame.new(alvo + Vector3.new(0, 1, 0)), Color3.fromRGB(255, 120, 40), 0, nil, Enum.Material.Neon)
			pedaco.Anchored = false
			pedaco.AssemblyLinearVelocity = Vector3.new(math.random(-25, 25), math.random(25, 45), math.random(-25, 25))
			sumir({ pedaco }, 0.3, 0.9)
		end
	end)
end

-- Tempestade Arcana: nuvem escura sobre o Mago enquanto os raios caem
local function nuvemDeTempestade(raiz: BasePart, cor: Color3, duracao: number)
	local centro = raiz.Position + Vector3.new(0, 34, 0)
	-- peça invisível e achatada: a fumaça escura nasce em toda a área dela
	local nuvem = parte(Vector3.new(60, 8, 60), CFrame.new(centro), Color3.fromRGB(40, 30, 60), 1)
	emissorEm(nuvem, {
		Color = ColorSequence.new(Color3.fromRGB(50, 40, 70), Color3.fromRGB(30, 25, 45)),
		LightEmission = 0,
		Transparency = sequencia({ { 0, 1 }, { 0.3, 0.35 }, { 1, 1 } }),
		Size = sequencia({ { 0, 10 }, { 1, 16 } }),
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(0.5, 2),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = 30,
	})
	emissorEm(nuvem, {
		Color = ColorSequence.new(cor:Lerp(BRANCO, 0.5)),
		LightEmission = 1,
		Transparency = sequencia({ { 0, 0.2 }, { 1, 1 } }),
		Size = sequencia({ { 0, 6 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.08, 0.15),
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = 6,
	})
	task.delay(duracao, function()
		for _, e in nuvem:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
		end
		Debris:AddItem(nuvem, 3.5)
	end)
end

-- Raio que vem do céu, com galhos que se abrem e marca queimada no chão
function Vfx.raioCeu(dados)
	if not VfxKit.custom("Raio", CFrame.new(dados.pos)) then
		local corRaio = dados.cor or Color3.fromRGB(200, 150, 255)
		soltar(dados.pos + Vector3.new(0, 0.5, 0), "clarao", { cor = corRaio, quantidade = 1, escala = 1 })
		VfxKit.feixeRaio(dados.pos + Vector3.new(math.random(-3, 3), 34, math.random(-3, 3)), dados.pos, corRaio, 4, 0.25)
		soltar(dados.pos + Vector3.new(0, 0.5, 0), "faiscas", { cor = corRaio, quantidade = 22, escala = 1 })
		soltar(dados.pos + Vector3.new(0, 0.2, 0), "anel", { cor = corRaio, quantidade = 1, escala = 0.7 })
		soltar(dados.pos + Vector3.new(0, 0.3, 0), "fumaca", { cor = Color3.fromRGB(60, 55, 70), quantidade = 5, escala = 0.6 })
	end
	Sons.tocar("raio", { pos = dados.pos, volume = 0.7, alcance = 220 })
	if Vfx.temPrefab("RaioTempestade") then
		-- raio roxo do pacote de VFX (o desenho é um raio em pé: o centro fica no meio da altura)
		Vfx.prefab("RaioTempestade", CFrame.new(dados.pos + Vector3.new(0, 12, 0)))
		Vfx.tremerEm(dados.pos, 0.5, 0.12)
		return
	end
	local cor = dados.cor or Color3.fromRGB(200, 150, 255)
	local topo = dados.pos + Vector3.new(math.random(-3, 3), 34, math.random(-3, 3))
	zigueZague(topo, dados.pos, cor:Lerp(BRANCO, 0.6), 0.6, 4, 8)
	zigueZague(topo, dados.pos, cor, 1.5, 3, 6)
	-- galhos
	for _ = 1, 2 do
		local meio = topo:Lerp(dados.pos, 0.3 + math.random() * 0.4)
		zigueZague(meio, meio + Vector3.new(math.random(-8, 8), -math.random(4, 9), math.random(-8, 8)), cor, 0.35, 2, 4)
	end
	local onda = disco(dados.pos + Vector3.new(0, 0.2, 0), 1, cor, 0.2)
	animar(onda, 0.3, { Size = Vector3.new(0.15, 10, 10), Transparency = 1 })
	Debris:AddItem(onda, 0.35)
	local marca = disco(dados.pos + Vector3.new(0, 0.08, 0), 4, Color3.fromRGB(25, 20, 30), 0.3, 0.05)
	marca.Material = Enum.Material.SmoothPlastic
	sumir({ marca }, 1, 1.5)
	particulas(dados.pos + Vector3.new(0, 0.5, 0), { cor = BRANCO, cor2 = cor, quantidade = 14, velocidade = 22, vida = 0.35 })
	clarao(dados.pos, cor, 24, 0.25, 7)
	Vfx.tremerEm(dados.pos, 0.6, 0.15)
end

------------------------------------------------------------------------
-- Arqueiro: disparo, carga, salto, Chuva de Flechas e Saraivada. Os efeitos vêm dos pacotes,
-- em verde; com a carta Flechas de Fogo, as versões "...Fogo" (quando existem)
------------------------------------------------------------------------

local MADEIRA_FLECHA = Color3.fromRGB(150, 110, 70)

-- Nome do efeito na versão de fogo, se ela existir
local function comFogo(nome: string, fogo: boolean?): string
	if fogo and prefabDe(nome .. "Fogo") then
		return nome .. "Fogo"
	end
	return nome
end

--[[ Disparo do arco: anel de vento na corda (tiro normal) ou rajada para a frente (tiro forte).
	"origem" é o arco e "direcao" para onde a flecha vai. ]]
function Vfx.disparoArqueiro(origem: Vector3, direcao: Vector3, forte: boolean, escala: number, fogo: boolean?)
	if direcao.Magnitude < 0.01 then
		return
	end
	local frente = CFrame.lookAt(origem, origem + direcao.Unit)
	if forte then
		-- a rajada do pacote sopra para o -X dela: gira para soprar na direção do tiro
		Vfx.prefab(comFogo("DisparoForte", fogo), frente * CFrame.Angles(0, -math.pi / 2, 0), nil, escala)
	else
		-- o anel fica de pé, de frente para o alvo
		Vfx.prefab(comFogo("DisparoArco", fogo), frente, nil, escala)
	end
end

-- Carregando o tiro: arcos de energia na ponta da flecha ("ponto" devolve onde ela está a cada
-- quadro). Devolve a função que apaga o efeito, ou nil se ele não existe.
function Vfx.cargaArqueiro(ponto: () -> Vector3?, fogo: boolean?): (() -> ())?
	return Vfx.prefab(comFogo("CargaArqueiro", fogo), function()
		local p = ponto()
		return if p then CFrame.new(p) else nil
	end, 0, 0.7)
end

-- Salto para trás da Chuva de Flechas: lufada de vento no chão de onde ele saiu
function Vfx.saltoArqueiro(raiz: BasePart)
	local chao = raiz.Position - Vector3.new(0, 2.6, 0)
	Vfx.prefab("SaltoArqueiro", CFrame.lookAt(chao, chao + raiz.CFrame.LookVector), nil, 1.6)
end

-- Flecha que cai do céu: madeira com a ponta colorida; fica cravada no chão um instante e some.
-- Uma a cada três levanta o estouro do impacto (o efeito pronto).
local function flechaCaindo(topo: Vector3, chao: Vector3, corPonta: Color3, impacto: string?)
	local direcao = (chao - topo).Unit
	local inicio = CFrame.lookAt(topo, topo + direcao)
	local haste = parte(Vector3.new(0.16, 0.16, 2.4), inicio, MADEIRA_FLECHA, 0, nil, Enum.Material.Wood)
	local ponta = parte(Vector3.new(0.3, 0.3, 0.5), inicio * CFrame.new(0, 0, -1.3), corPonta, 0, nil, Enum.Material.Neon)
	-- cravada: a ponta entra um pouco no chão
	local final = CFrame.lookAt(chao - direcao, chao)
	local tempo = 0.26
	animar(haste, tempo, { CFrame = final }, Enum.EasingStyle.Linear)
	local tween = animar(ponta, tempo, { CFrame = final * CFrame.new(0, 0, -1.3) }, Enum.EasingStyle.Linear)
	tween.Completed:Once(function()
		if impacto then
			Vfx.prefab(impacto, CFrame.new(chao), nil, 0.13)
		end
		sumir({ haste, ponta }, 0.25, 0.35)
	end)
end

-- Chuva de Flechas: um portal verde abre no céu e despeja flechas na área marcada no chão
function Vfx.chuvaFlechas(dados)
	Sons.tocar("chuvaFlechas", { pos = dados.pos })
	local centro, raio, duracao, cor = dados.pos, dados.raio, dados.duracao, dados.cor
	local corPonta = if dados.fogo then FOGO else cor
	local nomeImpacto = comFogo("ImpactoFlecha", dados.fogo)
	if not prefabDe(nomeImpacto) then
		nomeImpacto = nil
	end
	-- círculo fino no chão: mostra onde as flechas caem
	local partes = anel(centro + Vector3.new(0, 0.15, 0), raio, corPonta, 0.45, 28, 0.3)
	sumir(partes, 0.4, duracao)
	soltar(centro + Vector3.new(0, 0.2, 0), "circulo", { cor = cor, escala = raio / 4, quantidade = 1, extra = { Lifetime = NumberRange.new(duracao, duracao), RotSpeed = NumberRange.new(25, 25) } })
	local ceu = centro + Vector3.new(0, 22, 0)
	if Vfx.temPrefab("PortalChuva") then
		-- de frente para baixo: as linhas do portal descem junto com as flechas
		Vfx.prefab("PortalChuva", CFrame.new(ceu) * CFrame.Angles(-math.pi / 2, 0, 0), duracao, raio * 0.42)
	else
		local fundo = disco(centro + Vector3.new(0, 0.12, 0), raio * 2, cor, 0.85)
		sumir({ fundo }, 0.4, duracao)
		local portal = disco(ceu, 0.5, cor:Lerp(BRANCO, 0.3), 0.3)
	animar(portal, 0.3, { Size = Vector3.new(0.2, raio * 2.2, raio * 2.2) }, Enum.EasingStyle.Back)
		local runas = anel(ceu, raio * 1.15, cor, 0.2, 20, 0.3)
		sumir(runas, 0.4, duracao)
		orbitar(function()
			return ceu
		end, { { parte = portal, anel = true, altura = 0, velocidade = 2, fase = 0 } }, duracao)
	end
	task.spawn(function()
		local fim = os.clock() + duracao
		local contagem = 0
		while os.clock() < fim do
			contagem += 1
			local angulo = math.random() * math.pi * 2
			local distancia = math.sqrt(math.random()) * raio
			local chao = centro + Vector3.new(math.cos(angulo) * distancia, 0, math.sin(angulo) * distancia)
			local topo = ceu + Vector3.new(math.cos(angulo) * distancia * 0.5, 0, math.sin(angulo) * distancia * 0.5)
			flechaCaindo(topo, chao, corPonta, if contagem % 3 == 0 then nomeImpacto else nil)
			task.wait(0.035)
		end
	end)
end

-- Saraivada: vendaval verde girando em volta do Arqueiro enquanto ele atira
local function vendaval(raiz: BasePart, cor: Color3, duracao: number)
	Sons.tocar("giro", { pai = raiz, tom = 1.3, volume = 0.6 })
	local itens = {}
	for i = 0, 2 do
		local largura = 6 + i * 2.5
		local anelVento = parte(Vector3.new(0.12, largura, largura), CFrame.new(), if i == 1 then BRANCO else cor, 0.5, Enum.PartType.Cylinder)
		table.insert(itens, { parte = anelVento, anel = true, altura = -1.5 + i * 1.6, velocidade = 12 - i * 3, fase = i, inclinacao = math.rad(12 * (i - 1)) })
	end
	for i = 1, 6 do
		local folha = parte(Vector3.new(0.4, 0.1, 0.7), CFrame.new(), cor, 0.1)
		table.insert(itens, { parte = folha, raio = 3.5 + math.random() * 2, altura = -1 + math.random() * 3, velocidade = 9 + math.random() * 4, fase = i })
	end
	orbitar(function()
		return if raiz.Parent then raiz.Position else nil
	end, itens, duracao)
end

-- Ao usar um supremo: nome no ar + onda; Tempestade e Saraivada ganham efeitos que duram
local supremoBase = Vfx.supremo
function Vfx.supremo(dados)
	supremoBase(dados)
	local raiz = raizDoJogador(dados.jogador)
	if not raiz then
		return
	end
	Sons.tocar("supremo", { pos = raiz.Position, alcance = 220 })
	if not VfxKit.custom("Supremo", raiz.CFrame) then
		soltar(raiz.Position, "clarao", { cor = dados.cor, quantidade = 1, escala = 1.6 })
		soltar(raiz.Position - Vector3.new(0, 2.6, 0), "anel", { cor = dados.cor, quantidade = 1, escala = 1.3 })
		soltar(raiz.Position - Vector3.new(0, 2.5, 0), "circulo", { cor = dados.cor, quantidade = 1, escala = 1.6, extra = { Lifetime = NumberRange.new(1.2, 1.2) } })
		soltar(raiz.Position - Vector3.new(0, 2.6, 0), "onda", { cor = dados.cor, quantidade = 1, escala = 1 })
		soltar(raiz.Position, "brasas", { cor = dados.cor, quantidade = 30, escala = 1.2 })
		soltar(raiz.Position, "vortice", { cor = dados.cor, quantidade = 2, escala = 2 })
	end
	if dados.nome == "Tempestade Arcana" then
		nuvemDeTempestade(raiz, dados.cor, 5)
		Sons.tocar("tempestade", { pos = raiz.Position + Vector3.new(0, 20, 0), alcance = 260 })
	elseif dados.nome == "Saraivada" then
		if Vfx.temPrefab("VendavalArqueiro") then
			-- estouro verde em volta e um redemoinho de vento que acompanha o Arqueiro
			Sons.tocar("giro", { pai = raiz, tom = 1.3, volume = 0.6 })
			Vfx.prefab("SaraivadaInicio", CFrame.new(raiz.Position - Vector3.new(0, 1, 0)), nil, 0.25)
			Vfx.prefab("VendavalArqueiro", function()
				return if raiz.Parent then CFrame.new(raiz.Position - Vector3.new(0, 1.5, 0)) else nil
			end, 4, 1.4)
		else
			vendaval(raiz, dados.cor, 4)
		end
	elseif dados.nome == "Lâminas da Noite" and Vfx.temPrefab("OlhosVermelhos") then
		-- explosão vermelha e preta subindo do chão e os olhos acendem enquanto ele caça
		local chao = raiz.Position - Vector3.new(0, 2.5, 0)
		Vfx.prefab("InvestidaFim", CFrame.new(chao) * CFrame.Angles(math.pi / 2, 0, 0), nil, 0.3)
		local cabeca = raiz.Parent and raiz.Parent:FindFirstChild("Head")
		if cabeca and cabeca:IsA("BasePart") then
			Vfx.prefab("OlhosVermelhos", function()
				return if cabeca.Parent then cabeca.CFrame else nil
			end, 10 * 0.28 + 0.3, 1)
		end
	elseif dados.nome == "Lâminas da Noite" then
		-- uma lua vermelha aparece no alto
		local lua = parte(Vector3.one * 6, CFrame.new(raiz.Position + Vector3.new(0, 30, 0)), Color3.fromRGB(255, 70, 90), 0.2, Enum.PartType.Ball)
		luzEm(lua, Color3.fromRGB(255, 60, 80), 60, 2)
		animar(lua, 0.5, { Size = Vector3.one * 12 }, Enum.EasingStyle.Back)
		sumir({ lua }, 0.6, 3)
	end
end

------------------------------------------------------------------------
-- Cavaleiro: tornado, vento da carga e barreira do escudo
------------------------------------------------------------------------

--[[ Tornado do ataque carregado: nasce na frente do Cavaleiro quando a espada desce (saida)
	e anda de "de" até "ate" (no chão) em "duracao" segundos ]]
function Vfx.tornado(dados)
	local de: Vector3, ate: Vector3 = dados.de, dados.ate
	local raio = dados.raio or 6
	local perfeito = dados.perfeito == true
	local cor = if perfeito then dados.cor:Lerp(OURO, 0.35) else dados.cor
	if dados.fogo then
		cor = if perfeito then FOGO:Lerp(OURO, 0.3) else FOGO
	end
	local altura = raio * 2.3
	task.delay(dados.saida or 0, function()
		Sons.tocar("espadaPesada", { pos = de, tom = 0.8, volume = 1.2 })
		Sons.tocar("giro", { pos = de, tom = 0.75, volume = 1 })
		-- o vento acompanha o tornado enquanto ele anda (som que já vem com o Roblox)
		local ventoAncora = ancora(de)
		Sons.tocar("vento", { pai = ventoAncora, duracao = dados.duracao, tom = 0.8 })
		Debris:AddItem(ventoAncora, dados.duracao + 1)
		task.spawn(function()
			local inicioVento = os.clock()
			while ventoAncora.Parent and os.clock() - inicioVento < dados.duracao do
				ventoAncora.WorldPosition = de:Lerp(ate, (os.clock() - inicioVento) / dados.duracao)
				task.wait(0.05)
			end
		end)
		Vfx.tremerEm(de, if perfeito then 1.6 else 1.1, 0.25)
		local substituir = Vfx.temPrefab("Tornado")
		-- a espada bate no chão: pancada do pacote de VFX no ponto de saída (no lugar da onda feita por código)
		local lancamento = Vfx.prefab("LancamentoTornado", CFrame.new(de + Vector3.new(0, 0.3, 0)), nil, 0.4) ~= nil
		if not substituir and not lancamento then
			-- a espada bate no chão: onda e poeira no ponto de saída
			local onda = disco(de + Vector3.new(0, 0.15, 0), 2, cor:Lerp(BRANCO, 0.4), 0.2)
			animar(onda, 0.3, { Size = Vector3.new(0.12, raio * 3, raio * 3), Transparency = 1 })
			Debris:AddItem(onda, 0.35)
			poeiraNoChao(de + Vector3.new(0, 0.4, 0), raio, 16)
			riscos(de + Vector3.new(0, 1, 0), cor, 20, 45)
		end

		local centroAtual = de
		local terminou = false
		if dados.fogo then
			-- tornado de fogo: chamas fortes acompanham o funil enquanto ele anda
			Vfx.prefab("TornadoFogo", function()
				return if terminou then nil else CFrame.new(centroAtual + Vector3.new(0, 1, 0))
			end, dados.duracao + 0.4, raio / 3)
		end
		-- o tornado do pacote de VFX (azul; de fogo com uma carta de fogo)
		local nomeTornado = if dados.fogo and Vfx.temPrefab("TornadoChamas") then "TornadoChamas" else "Tornado"
		substituir = Vfx.temPrefab(nomeTornado)
		local pararPrefab = Vfx.prefab(nomeTornado, function()
			return if terminou then nil else CFrame.lookAt(centroAtual, centroAtual + (ate - de) + Vector3.new(0, 0, 0.001))
		end, dados.duracao + 0.4, raio / 6)
		if substituir then
			local inicio = os.clock()
			local conexao
			conexao = RunService.RenderStepped:Connect(function()
				local k = math.min(1, (os.clock() - inicio) / dados.duracao)
				centroAtual = de:Lerp(ate, k)
				if k >= 1 then
					conexao:Disconnect()
					terminou = true
				end
			end)
			return
		end

		local funilFora = funil(raio, altura, cor, 6, 0.2, if perfeito then OURO else nil)
		local funilDentro = funil(raio * 0.55, altura * 0.85, cor:Lerp(BRANCO, 0.5), 4, 0.35)
		-- miolo do tornado: colunas com material de campo de força (brilho que se mexe sozinho)
		local miolo1 = parte(Vector3.new(altura * 0.55, raio * 0.55, raio * 0.55), CFrame.new(de), cor:Lerp(BRANCO, 0.35), 0.35, Enum.PartType.Cylinder, Enum.Material.ForceField)
		local miolo2 = parte(Vector3.new(altura * 0.5, raio * 1.1, raio * 1.1), CFrame.new(de), cor, 0.45, Enum.PartType.Cylinder, Enum.Material.ForceField)
		local brilhoChao = disco(de, raio * 2.2, cor, 0.72)
		-- pedras e faíscas girando em espiral
		local detritos = {}
		for i = 1, 12 do
			local pedra = parte(Vector3.one * (0.35 + math.random() * 0.45), CFrame.new(de), Color3.fromRGB(125, 115, 105), 0, nil, Enum.Material.Slate)
			table.insert(detritos, { parte = pedra, fase = i * 0.52, velocidade = 8 + math.random() * 5, subida = 1.2 + math.random() * 1.6, raioK = 0.35 + math.random() * 0.6 })
		end
		-- base: poeira girando, faíscas subindo e luz
		local base = ancora(de)
		local poeira = emissorEm(base, {
			Texture = TEXTURA_FUMACA,
			Color = ColorSequence.new(POEIRA),
			LightInfluence = 1,
			Transparency = sequencia({ { 0, 0.4 }, { 1, 1 } }),
			Size = sequencia({ { 0, raio * 0.3 }, { 1, raio * 0.7 } }),
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(raio * 1.4, raio * 2.2),
			Drag = 4,
			SpreadAngle = Vector2.new(10, 180),
			EmissionDirection = Enum.NormalId.Right,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			Rate = 45,
		})
		local brilhos = emissorEm(base, {
			Color = ColorSequence.new(BRANCO, cor),
			LightEmission = 1,
			Size = sequencia({ { 0, 0.45 }, { 1, 0 } }),
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(8, 16),
			Acceleration = Vector3.new(0, 10, 0),
			SpreadAngle = Vector2.new(30, 30),
			Rate = 45,
		})
		luzEm(base, cor, raio * 3, 3)

		local inicio = os.clock()
		local conexao
		conexao = RunService.RenderStepped:Connect(function()
			local t = os.clock() - inicio
			local k = math.min(1, t / dados.duracao)
			local centro = de:Lerp(ate, k)
			centroAtual = centro
			-- nasce rápido, balança um pouco enquanto anda
			local escala = math.min(1, 0.3 + t / 0.2 * 0.7)
			local balanco = Vector3.new(math.sin(t * 7) * 0.4, 0, math.cos(t * 5.3) * 0.4)
			local c = centro + balanco
			funilFora.atualizar(c, t, escala)
			funilDentro.atualizar(c, t * 1.3 + 2, escala)
			miolo1.CFrame = CFrame.new(c + Vector3.new(0, altura * 0.28 * escala, 0)) * CFrame.Angles(0, -t * 9, 0) * EM_PE
			miolo2.CFrame = CFrame.new(c + Vector3.new(0, altura * 0.62 * escala, 0)) * CFrame.Angles(0, t * 7, 0) * EM_PE
			brilhoChao.CFrame = CFrame.new(centro + Vector3.new(0, 0.12, 0)) * EM_PE
			base.WorldCFrame = CFrame.new(centro + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, t * 8, 0)
			for _, d in detritos do
				local a = d.fase + t * d.velocidade
				local h = (d.fase + t * d.subida) % 1
				local r = raio * escala * d.raioK * (0.4 + 0.8 * h)
				d.parte.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * r, h * altura * 0.9, math.sin(a) * r)) * CFrame.Angles(a, a * 1.4, 0)
			end
			if k >= 1 then
				conexao:Disconnect()
				terminou = true
				-- desfaz: o funil abre, sobe e some
				funilFora.parar(0.35)
				funilDentro.parar(0.3)
				for _, p in { miolo1, miolo2, brilhoChao } do
					animar(p, 0.35, { Transparency = 1, Size = p.Size * Vector3.new(1.2, 1.3, 1.3) })
					Debris:AddItem(p, 0.4)
				end
				for _, d in detritos do
					d.parte.Anchored = false
					d.parte.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), math.random(15, 30), math.random(-20, 20))
					sumir({ d.parte }, 0.3, 0.5)
				end
				poeira.Enabled = false
				brilhos.Enabled = false
				poeiraNoChao(centro + Vector3.new(0, 0.4, 0), raio, 12)
				Debris:AddItem(base, 1)
				if pararPrefab then
					pararPrefab()
				end
			end
		end)
	end)
end

--[[ Vento da carga do Cavaleiro: círculo mágico girando no chão, funil de vento em volta e
	brilhos sendo sugados para o corpo. "carga()" diz de 0 a 1 o quanto já carregou.
	Devolve a função que apaga o efeito. ]]
function Vfx.ventoCarga(personagem: Model, cor: Color3, carga: (() -> number)?): () -> ()
	local raiz = personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = personagem:FindFirstChildOfClass("Humanoid")
	if not raiz then
		return function() end
	end
	local function ondeEsta(): CFrame?
		if not raiz.Parent then
			return nil
		end
		return CFrame.new(raiz.Position.X, chaoDe(raiz, humanoid), raiz.Position.Z)
	end
	local substituir = Vfx.temPrefab("CargaCavaleiro")
	local apagado = false
	-- o anel de energia do pacote fica na altura da espada girando acima da cabeça
	local ALTURA_ESPADA = Vector3.new(0, 2.3, 0)
	local pararPrefab = Vfx.prefab("CargaCavaleiro", function()
		return if apagado or not raiz.Parent then nil else CFrame.new(raiz.Position + ALTURA_ESPADA)
	end, 0, 1.4)
	if substituir then
		-- partículas do pacote de VFX: energia azul subindo em volta do corpo enquanto carrega;
		-- quando a carga enche, um estouro dourado e um brilho dourado na espada
		local pararAura = Vfx.prefab("CargaAura", function()
			return if apagado or not raiz.Parent then nil else CFrame.new(raiz.Position)
		end, 0, 1.3)
		local pararBrilho: (() -> ())? = nil
		local luz = Instance.new("PointLight")
		luz.Color = cor
		luz.Range = 14
		luz.Brightness = 0
		luz.Parent = raiz
		local cheio = false
		local conexao
		conexao = RunService.RenderStepped:Connect(function()
			if apagado or not raiz.Parent then
				conexao:Disconnect()
				if pararAura then
					pararAura()
				end
				if pararBrilho then
					pararBrilho()
				end
				animar(luz, 0.2, { Brightness = 0 })
				Debris:AddItem(luz, 0.3)
				return
			end
			local nivel = if carga then carga() else 1
			luz.Brightness = 0.6 + 2 * nivel
			if nivel >= 1 and not cheio then
				cheio = true
				luz.Color = OURO
				Vfx.prefab("CargaCheia", CFrame.new(raiz.Position + ALTURA_ESPADA), nil, 0.8)
				pararBrilho = Vfx.prefab("CargaBrilhoCheia", function()
					return if apagado or not raiz.Parent then nil else CFrame.new(raiz.Position + ALTURA_ESPADA)
				end, 0, 1.6)
			end
		end)
		return function()
			apagado = true
			if pararPrefab then
				pararPrefab()
			end
		end
	end

	-- círculo mágico: dois anéis, um hexagrama e runas, girando em sentidos opostos
	local RAIO_FORA, RAIO_DENTRO = 4.6, 3.3
	local pecas = {} -- { parte, raio, angulo, giro (sentido), comprimento?, tipo }
	local function anelDePecas(r: number, n: number, giro: number, largura: number)
		for i = 1, n do
			local p = parte(Vector3.new(largura, 0.08, 2 * math.pi * r / n * 1.08), CFrame.new(), cor, 1)
			table.insert(pecas, { parte = p, raio = r, angulo = i / n * math.pi * 2, giro = giro, tipo = "anel" })
		end
	end
	anelDePecas(RAIO_FORA, 24, 0.7, 0.22)
	anelDePecas(RAIO_FORA - 0.45, 24, 0.7, 0.08)
	anelDePecas(RAIO_DENTRO, 18, -1.1, 0.14)
	-- hexagrama: 6 linhas entre pontos do anel de dentro (dois triângulos)
	local lado = RAIO_DENTRO * math.sqrt(3)
	for i = 0, 5 do
		local p = parte(Vector3.new(0.12, 0.08, lado), CFrame.new(), cor, 1)
		table.insert(pecas, { parte = p, raio = RAIO_DENTRO / 2, angulo = i * math.pi / 3 + math.pi / 6, giro = -1.1, tipo = "linha" })
	end
	for i = 0, 5 do
		local runa = parte(Vector3.new(0.5, 0.1, 0.5), CFrame.new(), cor:Lerp(BRANCO, 0.4), 1)
		table.insert(pecas, { parte = runa, raio = RAIO_FORA - 0.22, angulo = i * math.pi / 3, giro = 0.7, tipo = "runa" })
	end
	local vento = funil(3.4, 5.5, cor, 3, 0.5)
	-- brilhos vindo de fora para dentro (esfera invisível que emite para o centro)
	local esfera = parte(Vector3.one * 10, CFrame.new(raiz.Position), cor, 1, Enum.PartType.Ball)
	local sugados = emissorEm(esfera, {
		Color = ColorSequence.new(BRANCO, cor),
		LightEmission = 1,
		Size = sequencia({ { 0, 0 }, { 0.3, 0.35 }, { 1, 0.1 } }),
		Lifetime = NumberRange.new(0.45, 0.55),
		Speed = NumberRange.new(9, 11),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Rate = 30,
	})
	local luz = Instance.new("PointLight")
	luz.Color = cor
	luz.Range = 14
	luz.Brightness = 0
	luz.Parent = esfera

	local inicio = os.clock()
	local cheio = false
	local sumindo: number? = nil
	local conexao
	conexao = RunService.RenderStepped:Connect(function()
		local agora = os.clock()
		local t = agora - inicio
		local onde = ondeEsta()
		local fim = if sumindo then math.clamp((agora - sumindo) / 0.25, 0, 1) else 0
		if not onde or fim >= 1 then
			conexao:Disconnect()
			vento.parar(0.15)
			for _, item in pecas do
				item.parte:Destroy()
			end
			sugados.Enabled = false
			Debris:AddItem(esfera, 0.6)
			return
		end
		local nivel = if carga then carga() else math.min(1, t / 1.1)
		if nivel >= 1 and not cheio then
			-- carga cheia: o círculo fica dourado e dá um pulso
			cheio = true
			local pulso = disco(onde.Position + Vector3.new(0, 0.2, 0), RAIO_FORA * 2, OURO, 0.2)
			animar(pulso, 0.35, { Size = Vector3.new(0.12, RAIO_FORA * 3.2, RAIO_FORA * 3.2), Transparency = 1 })
			Debris:AddItem(pulso, 0.4)
			for _, item in pecas do
				item.parte.Color = if item.tipo == "runa" then BRANCO else OURO
			end
			sugados.Color = ColorSequence.new(BRANCO, OURO)
			luz.Color = OURO
		end
		local abrir = math.min(1, t / 0.3)
		abrir = 1 - (1 - abrir) ^ 3
		local escala = abrir * (1 - 0.4 * fim)
		local transparencia = 1 - (0.25 + 0.55 * nivel) * abrir * (1 - fim)
		if cheio then
			transparencia = math.max(0, transparencia - 0.15 - 0.1 * math.sin(t * 16))
		end
		local centro = onde.Position + Vector3.new(0, 0.12, 0)
		for _, item in pecas do
			local a = item.angulo + t * item.giro * (1 + nivel)
			local r = item.raio * escala
			local pos = centro + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			if item.tipo == "linha" then
				-- linha tangente ao círculo de raio r (forma o hexagrama)
				item.parte.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
				item.parte.Size = Vector3.new(0.12, 0.08, RAIO_DENTRO * math.sqrt(3) * escala)
			elseif item.tipo == "runa" then
				item.parte.CFrame = CFrame.new(pos) * CFrame.Angles(0, a + t * 3, 0)
			else
				item.parte.CFrame = CFrame.lookAt(pos, centro) * CFrame.Angles(0, math.rad(90), 0)
			end
			item.parte.Transparency = transparencia
		end
		vento.atualizar(onde.Position, t, (0.6 + 0.4 * nivel) * escala)
		esfera.CFrame = CFrame.new(raiz.Position)
		sugados.Rate = if sumindo then 0 else 15 + 45 * nivel
		luz.Brightness = (1 + 2.5 * nivel) * (1 - fim)
	end)
	return function()
		if not sumindo then
			sumindo = os.clock()
		end
		apagado = true
		if pararPrefab then
			pararPrefab()
		end
	end
end

--[[ Barreira do escudo: enquanto o Cavaleiro defende, uma parede de energia aparece na frente
	do escudo e acompanha o braço. Devolve a função que apaga a barreira. ]]
function Vfx.barreiraEscudo(personagem: Model, cor: Color3): () -> ()
	local acessorios = personagem:FindFirstChild("AcessoriosDeClasse")
	local escudo = if acessorios then acessorios:FindFirstChild("Escudo") :: BasePart? else nil
	if not escudo then
		return function() end
	end
	-- estouro de energia quando o escudo chega na frente (mostra que a defesa ligou)
	task.delay(0.1, function()
		if escudo.Parent then
			Vfx.prefab("EscudoAtivado", escudo.CFrame * CFrame.new(-0.5, 0, 0), nil, 1.2)
		end
	end)
	local substituir = Vfx.temPrefab("EscudoErguido")
	local apagado = false
	local pararPrefab = Vfx.prefab("EscudoErguido", function()
		return if apagado or not escudo.Parent then nil else escudo.CFrame * CFrame.new(-0.4, 0, 0)
	end, 0)
	if substituir then
		return function()
			apagado = true
			if pararPrefab then
				pararPrefab()
			end
		end
	end
	local TAMANHO = 4.6
	local clara = cor:Lerp(BRANCO, 0.35)
	-- o cilindro tem o eixo no X, igual à "frente" do escudo
	local barreira = parte(Vector3.new(0.06, 1, 1), escudo.CFrame, clara, 0.1, Enum.PartType.Cylinder, Enum.Material.ForceField)
	local borda = parte(Vector3.new(0.04, 1, 1), escudo.CFrame, cor, 0.7, Enum.PartType.Cylinder)
	local faiscas = emissorEm(barreira, {
		Color = ColorSequence.new(BRANCO, cor),
		LightEmission = 1,
		Size = sequencia({ { 0, 0.25 }, { 1, 0 } }),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 14,
	})
	local luz = Instance.new("PointLight")
	luz.Color = cor
	luz.Range = 9
	luz.Brightness = 1.6
	luz.Parent = barreira
	-- clarão ao erguer
	local anelErguer = parte(Vector3.new(0.05, 2, 2), escudo.CFrame * CFrame.new(-0.4, 0, 0), BRANCO, 0.2, Enum.PartType.Cylinder)
	animar(anelErguer, 0.22, { Size = Vector3.new(0.05, 7, 7), Transparency = 1 })
	Debris:AddItem(anelErguer, 0.25)

	local inicio = os.clock()
	local sumindo: number? = nil
	local conexao
	conexao = RunService.RenderStepped:Connect(function()
		local agora = os.clock()
		local t = agora - inicio
		local fim = if sumindo then math.clamp((agora - sumindo) / 0.15, 0, 1) else 0
		if not escudo.Parent or fim >= 1 then
			conexao:Disconnect()
			barreira:Destroy()
			borda:Destroy()
			return
		end
		-- abre com um "estalo" (passa um pouco do tamanho e volta) e pulsa de leve
		local abrir = math.min(1, t / 0.12)
		local estalo = if abrir < 1 then abrir * 1.15 else 1 + math.max(0, 0.15 - (t - 0.12) * 1.2)
		local d = TAMANHO * estalo * (1 - 0.5 * fim) + math.sin(t * 6) * 0.08
		barreira.Size = Vector3.new(0.06, d, d)
		borda.Size = Vector3.new(0.04, d + 0.35, d + 0.35)
		barreira.CFrame = escudo.CFrame * CFrame.new(-0.42, 0, 0)
		borda.CFrame = escudo.CFrame * CFrame.new(-0.36, 0, 0)
		barreira.Transparency = 0.1 + 0.9 * fim
		borda.Transparency = 0.7 + 0.3 * fim + math.sin(t * 9) * 0.06
	end)
	return function()
		if not sumindo then
			sumindo = os.clock()
			faiscas.Enabled = false
		end
		apagado = true
		if pararPrefab then
			pararPrefab()
		end
	end
end
------------------------------------------------------------------------
-- Brilho do supremo do Cavaleiro: enquanto dura o bônus (recebe menos dano), o corpo fica com
-- um contorno brilhante azul e dourado que pulsa de leve, e uma luz em volta
------------------------------------------------------------------------

function Vfx.auraSupremo(dados)
	local raiz = raizDoJogador(dados.jogador)
	if not raiz then
		return
	end
	local personagem = raiz.Parent :: Model
	local duracao = dados.duracao or 10
	local cor = dados.cor or Color3.fromRGB(86, 156, 255)
	local brilho = Instance.new("Highlight")
	brilho.Name = "BrilhoSupremo"
	brilho.Adornee = personagem
	brilho.DepthMode = Enum.HighlightDepthMode.Occluded
	brilho.FillColor = cor:Lerp(BRANCO, 0.25)
	brilho.OutlineColor = OURO
	brilho.FillTransparency = 1
	brilho.OutlineTransparency = 1
	brilho.Parent = personagem
	local luz = Instance.new("PointLight")
	luz.Color = cor:Lerp(OURO, 0.3)
	luz.Range = 14
	luz.Brightness = 0
	luz.Parent = raiz
	clarearTela(raiz.Position, cor, 0.2, 0.4)
	local inicio = os.clock()
	local conexao
	conexao = RunService.RenderStepped:Connect(function()
		local t = os.clock() - inicio
		if t > duracao or not brilho.Parent then
			conexao:Disconnect()
			animar(brilho, 0.5, { FillTransparency = 1, OutlineTransparency = 1 })
			animar(luz, 0.5, { Brightness = 0 })
			Debris:AddItem(brilho, 0.6)
			Debris:AddItem(luz, 0.6)
			return
		end
		-- entra em 0,3s e pulsa devagar
		local entrar = math.min(1, t / 0.3)
		local pulso = (math.sin(t * 4) + 1) / 2
		brilho.FillTransparency = 1 - entrar * (0.12 + 0.1 * pulso)
		brilho.OutlineTransparency = 1 - entrar * (0.55 + 0.35 * pulso)
		luz.Brightness = entrar * (1.6 + 0.8 * pulso)
	end)
end

------------------------------------------------------------------------
-- Entrada
------------------------------------------------------------------------

function Vfx.receber(dados)
	local funcao = Vfx.extras[dados.t] or (Vfx :: any)[dados.t]
	if type(funcao) == "function" then
		local ok, erro = pcall(funcao, dados)
		if not ok then
			warn("[Vfx] Erro no efeito " .. tostring(dados.t) .. ": " .. tostring(erro))
		end
	end
end

return Vfx
