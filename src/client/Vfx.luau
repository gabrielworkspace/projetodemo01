-- Efeitos visuais desenhados no computador do jogador: cortes, projéteis, explosões,
-- avisos de ataque no chão, números de dano, moedas e tremor da câmera.
-- O servidor manda { t = "tipo", ... } e Vfx.receber chama a função certa.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

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
	posicionarArco(a0, a1, { nucleo, aura }, origem, raio, arcoGraus)

	local inicio = os.clock()
	local conexao
	conexao = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - inicio) / duracao
		local cabeca = t * 1.45
		nucleo.Transparency = transparenciaDeVarredura(cabeca, 0.45, 0)
		aura.Transparency = transparenciaDeVarredura(cabeca, 0.55, 0.45)
		if cabeca > 1.6 then
			conexao:Disconnect()
			a0:Destroy()
			a1:Destroy()
		end
	end)
	-- faíscas na ponta do arco
	local fim = origem:PointToWorldSpace(Vector3.new(raio * math.sin(math.rad(arcoGraus) / 2), 0, -raio * math.cos(math.rad(arcoGraus) / 2)))
	task.delay(duracao * 0.6, function()
		particulas(fim, { cor = cor:Lerp(BRANCO, 0.4), quantidade = 6, tamanho = 0.35, velocidade = 12, vida = 0.3 })
	end)
end

function Vfx.corte(dados)
	local raiz = raizDoJogador(dados.jogador)
	local base = if raiz then raiz.Position else dados.pos
	local direcao = dados.dir
	local origem = CFrame.lookAt(base, base + direcao)
	local combo = dados.combo or 1
	local final = combo == 3
	local raio = dados.alcance * 0.8
	if final then
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

function Vfx.golpeInimigo(dados)
	local base = dados.pos
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

function Vfx.redemoinho(dados)
	local raiz = raizDoJogador(dados.jogador)
	if not raiz then
		return
	end
	local cor = if dados.fogo then FOGO else dados.cor
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
	local inicio = os.clock()
	local conexao
	conexao = RunService.RenderStepped:Connect(function()
		local t = os.clock() - inicio
		if t > dados.duracao or not raiz.Parent then
			conexao:Disconnect()
			for _, a in { a0, a1, b0, b1 } do
				a:Destroy()
			end
			return
		end
		local centro = CFrame.new(raiz.Position) * CFrame.Angles(0, -t * 14, 0)
		posicionarArco(a0, a1, feixesA, centro, dados.raio * 0.8, 150)
		posicionarArco(b0, b1, feixesB, centro * CFrame.Angles(0, math.pi, 0), dados.raio * 0.8, 150)
		if math.random() < 0.3 then
			particulas(raiz.Position + Vector3.new(math.random(-4, 4), -1, math.random(-4, 4)), { cor = cor, quantidade = 3, tamanho = 0.4, velocidade = 8, vida = 0.4 })
		end
	end)
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
	flechaCarregada = { cor = Color3.fromRGB(255, 230, 120), formato = "flecha", tamanho = 1 },
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

function Vfx.projeteis(dados)
	for _, info in dados.lista do
		local visual, cor = criarVisualProjetil(info.tipo, info.tamanho or 1)
		visual.CFrame = CFrame.lookAt(info.pos, info.pos + info.dir)
		projeteis[info.id] = {
			parte = visual,
			pos = info.pos,
			dir = info.dir,
			vel = info.vel,
			alcance = info.alcance,
			percorrido = 0,
			cor = cor,
			tipo = info.tipo,
			girar = info.tipo == "gelo",
		}
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
	Debris:AddItem(p.parte, 0.3) -- deixa o rastro terminar
	if impacto then
		particulas(onde, { cor = p.cor, cor2 = BRANCO, quantidade = 10, tamanho = 0.45, velocidade = 16, vida = 0.35 })
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

function Vfx.impacto(dados)
	local pos, raio = dados.pos, dados.raio or 6
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

function Vfx.meteoro(dados)
	local alvo = dados.pos
	local inicio = alvo + Vector3.new(-14, 48, -14)
	local bola = parte(Vector3.one * 3.4, CFrame.new(inicio), FOGO, 0, Enum.PartType.Ball)
	local f = Instance.new("Fire")
	f.Size = 8
	f.Heat = 0
	f.Parent = bola
	rastro(bola, FOGO, 2.6, 0.4)
	local l = Instance.new("PointLight")
	l.Color = FOGO
	l.Range = 24
	l.Brightness = 3
	l.Parent = bola
	animar(bola, dados.duracao, { CFrame = CFrame.new(alvo + Vector3.new(0, 1.5, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(bola, dados.duracao + 0.05)
	if dados.amigo then
		local partes = anel(alvo + Vector3.new(0, 0.15, 0), dados.raio or 10, FOGO, 0.35, 24, 0.4)
		sumir(partes, 0.2, dados.duracao)
	end
end

function Vfx.chuvaFlechas(dados)
	local centro, raio, duracao, cor = dados.pos, dados.raio, dados.duracao, dados.cor
	local partes = anel(centro + Vector3.new(0, 0.15, 0), raio, cor, 0.35, 28, 0.45)
	local fundo = disco(centro + Vector3.new(0, 0.12, 0), raio * 2, cor, 0.85)
	table.insert(partes, fundo)
	sumir(partes, 0.4, duracao)
	task.spawn(function()
		local fim = os.clock() + duracao
		while os.clock() < fim do
			local angulo = math.random() * math.pi * 2
			local distancia = math.sqrt(math.random()) * raio
			local chao = centro + Vector3.new(math.cos(angulo) * distancia, 0, math.sin(angulo) * distancia)
			local topo = chao + Vector3.new(3, 26, 3)
			local flecha = parte(Vector3.new(0.15, 0.15, 2.4), CFrame.lookAt(topo, chao), cor:Lerp(BRANCO, 0.3), 0)
			local tween = animar(flecha, 0.22, { CFrame = CFrame.lookAt(chao + Vector3.new(0, 0.8, 0), chao + Vector3.new(-3, -26, -3)) }, Enum.EasingStyle.Linear)
			tween.Completed:Once(function()
				particulas(chao + Vector3.new(0, 0.3, 0), { cor = Color3.fromRGB(200, 185, 160), quantidade = 3, tamanho = 0.3, velocidade = 6, vida = 0.25, luz = 0 })
				sumir({ flecha }, 0.3, 0.3)
			end)
			task.wait(0.035)
		end
	end)
end

function Vfx.julgamento(dados)
	local pos, raio, cor = dados.pos, dados.raio, Color3.fromRGB(255, 220, 120)
	local coluna = parte(Vector3.new(60, 6, 6), CFrame.new(pos + Vector3.new(0, 60, 0)) * EM_PE, cor, 0.1, Enum.PartType.Cylinder)
	animar(coluna, 0.3, { CFrame = CFrame.new(pos + Vector3.new(0, 30, 0)) * EM_PE }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.3, function()
		animar(coluna, 0.5, { Size = Vector3.new(60, 0.5, 0.5), Transparency = 1 })
		Debris:AddItem(coluna, 0.55)
		for i = 0, 2 do
			task.delay(i * 0.12, function()
				local onda = disco(pos + Vector3.new(0, 0.25, 0), 3, if i == 0 then BRANCO else dados.cor or cor, 0.15)
				animar(onda, 0.5, { Size = Vector3.new(0.15, raio * 2.2, raio * 2.2), Transparency = 1 })
				Debris:AddItem(onda, 0.55)
			end)
		end
		particulas(pos + Vector3.new(0, 1, 0), { cor = BRANCO, cor2 = cor, quantidade = 50, tamanho = 1, velocidade = 45, vida = 0.8, gravidade = 25 })
		clarao(pos, cor, raio * 4, 0.6, 8)
		Vfx.tremerEm(pos, 3.5, 0.5)
	end)
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

function Vfx.raioCeu(dados)
	local cor = dados.cor or Color3.fromRGB(200, 150, 255)
	zigueZague(dados.pos + Vector3.new(math.random(-3, 3), 45, math.random(-3, 3)), dados.pos, cor:Lerp(BRANCO, 0.5), 0.6, 4, 7)
	zigueZague(dados.pos + Vector3.new(0, 45, 0), dados.pos, cor, 1.4, 3, 6)
	local onda = disco(dados.pos + Vector3.new(0, 0.2, 0), 1, cor, 0.2)
	animar(onda, 0.3, { Size = Vector3.new(0.15, 10, 10), Transparency = 1 })
	Debris:AddItem(onda, 0.35)
	particulas(dados.pos + Vector3.new(0, 0.5, 0), { cor = BRANCO, cor2 = cor, quantidade = 12, velocidade = 20, vida = 0.35 })
	clarao(dados.pos, cor, 22, 0.25, 6)
	Vfx.tremerEm(dados.pos, 0.6, 0.15)
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

function Vfx.dano(dados)
	local critico = dados.critico
	local cor = dados.cor or (if critico then Color3.fromRGB(255, 214, 70) else Color3.fromRGB(255, 250, 240))
	textoFlutuante(dados.pos, if critico then dados.valor .. "!" else tostring(dados.valor), cor, if critico then 46 else 30, { pop = if critico then 2.2 else 1.5 })
	if dados.impacto then
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
	if raiz then
		pilarDeLuz(raiz, Color3.fromRGB(140, 255, 170), 30, 4)
		textoFlutuante(raiz.Position + Vector3.new(0, 4, 0), "DE PÉ!", Color3.fromRGB(140, 255, 170), 34, { pop = 1.8 })
	end
end

function Vfx.segundaChance(dados)
	local raiz = raizDoJogador(dados.jogador)
	if raiz then
		pilarDeLuz(raiz, Color3.fromRGB(255, 220, 110), 50, 6)
		textoFlutuante(raiz.Position + Vector3.new(0, 4, 0), "SEGUNDA CHANCE!", Color3.fromRGB(255, 220, 110), 40, { pop = 2 })
	end
end

function Vfx.caiu(dados)
	local raiz = raizDoJogador(dados.jogador)
	if raiz then
		particulas(raiz.Position, { cor = Color3.fromRGB(80, 70, 90), quantidade = 20, velocidade = 10, vida = 0.8, luz = 0, gravidade = 5 })
	end
end

function Vfx.bloqueio(dados)
	local raiz = raizDoJogador(dados.jogador)
	if raiz then
		local cor = Color3.fromRGB(110, 190, 255)
		local bolha = parte(Vector3.one * 5, CFrame.new(raiz.Position), cor, 0.4, Enum.PartType.Ball, Enum.Material.ForceField)
		animar(bolha, 0.4, { Size = Vector3.one * 8, Transparency = 1 })
		Debris:AddItem(bolha, 0.45)
		textoFlutuante(raiz.Position + Vector3.new(0, 3.5, 0), "BLOQUEADO", cor, 30)
	end
end

local COR_ESQUIVA = {
	cavaleiro = Color3.fromRGB(255, 225, 160),
	mago = Color3.fromRGB(210, 160, 255),
	arqueiro = Color3.fromRGB(170, 255, 190),
}

function Vfx.esquiva(dados)
	local raiz = raizDoJogador(dados.jogador)
	if not raiz then
		return
	end
	local personagem = raiz.Parent
	local cor = COR_ESQUIVA[dados.classe] or Color3.fromRGB(200, 230, 255)
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

-- Giro do Cavaleiro com a espada carregada
function Vfx.giroCarregado(dados)
	local raiz = raizDoJogador(dados.jogador)
	if not raiz then
		return
	end
	local base = raiz.Position
	local raio = dados.raio
	local cor = if dados.perfeito then dados.cor:Lerp(Color3.fromRGB(255, 214, 90), 0.6) else dados.cor
	local origem = CFrame.lookAt(base, base + raiz.CFrame.LookVector)
	arcoDeCorte(origem, raio * 0.85, 180, cor, { espessura = 1.8, duracao = 0.16 })
	task.delay(0.08, function()
		arcoDeCorte(origem * CFrame.Angles(0, math.pi, 0), raio * 0.85, 180, cor, { espessura = 1.8, duracao = 0.16 })
	end)
	local chao = Vector3.new(base.X, base.Y - 2.6, base.Z)
	local onda = disco(chao, 2, cor, 0.3)
	animar(onda, 0.35, { Size = Vector3.new(0.15, raio * 2.2, raio * 2.2), Transparency = 1 })
	Debris:AddItem(onda, 0.4)
	particulas(chao + Vector3.new(0, 0.5, 0), { cor = cor, cor2 = BRANCO, quantidade = 20, tamanho = 0.5, velocidade = 26, vida = 0.4 })
	Vfx.tremerEm(base, if dados.perfeito then 1.6 else 1, 0.2)
	if dados.perfeito then
		clarao(base, cor, 30, 0.4, 6)
	end
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
	particulas(posicao, { cor = cor:Lerp(BRANCO, 0.3), cor2 = cor, quantidade = quantidade, tamanho = 0.7, velocidade = velocidade, vida = 0.6, gravidade = 20 })
	clarao(posicao, cor, 16, 0.3, 3)
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
