-- Dá vida aos inimigos no computador do jogador: monta o modelo (Modelos.luau), anima
-- (andar, preparar golpe, golpear, conjurar, pular...), mostra barra de vida, piscar ao levar
-- dano, fogo, gelo, atordoamento, aura de elite e a explosão de peças na morte.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BracoMalha = require(script.Parent.BracoMalha)
local Modelos = require(script.Parent.Modelos)
local Sons = require(script.Parent.Sons)
local UI = require(script.Parent.UI)
local Vfx = require(script.Parent.Vfx)

local VisualInimigos = {}

local visuais = {} -- [modelo do servidor] = visual
local pasta = Instance.new("Folder")
pasta.Name = "InimigosVisuais"
pasta.Parent = workspace

local BRANCO = Color3.new(1, 1, 1)
local CORES_ELITE = {
	Blindado = Color3.fromRGB(205, 215, 235),
	Veloz = Color3.fromRGB(255, 232, 80),
	["Gélido"] = Color3.fromRGB(120, 210, 255),
	Explosivo = Color3.fromRGB(255, 120, 40),
	Gigante = Color3.fromRGB(255, 80, 80),
}
local ZERO = {}

------------------------------------------------------------------------
-- Montagem
------------------------------------------------------------------------

local function construirPeca(definicao, escala: number): (BasePart, SpecialMesh?)
	local parte: BasePart
	local malha = nil
	local forma = definicao.forma
	if forma == "cunha" then
		parte = Instance.new("WedgePart")
	elseif forma == "canto" then
		parte = Instance.new("CornerWedgePart")
	else
		local p = Instance.new("Part")
		if forma == "bola" then
			p.Shape = Enum.PartType.Ball
		elseif forma == "cilindro" then
			p.Shape = Enum.PartType.Cylinder
		end
		parte = p
	end
	parte.Size = definicao.tamanho * escala
	if forma == "elipse" then
		malha = Instance.new("SpecialMesh")
		malha.MeshType = Enum.MeshType.Sphere
		malha.Parent = parte
	end
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.CastShadow = definicao.tamanho.Magnitude * escala > 1.5
	parte.Material = definicao.material or Enum.Material.SmoothPlastic
	parte.Color = definicao.cor
	parte.Transparency = definicao.transp or 0
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	return parte, malha
end

local function sequencia(pontos): NumberSequence
	local chaves = {}
	for _, ponto in pontos do
		table.insert(chaves, NumberSequenceKeypoint.new(ponto[1], ponto[2]))
	end
	return NumberSequence.new(chaves)
end

local function emissor(pai: Instance, cor: Color3, propriedades)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(cor:Lerp(BRANCO, 0.3), cor)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = sequencia({ { 0, 0.35 }, { 1, 0 } })
	e.Transparency = sequencia({ { 0, 0.1 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 12
	for chave, valor in propriedades or {} do
		(e :: any)[chave] = valor
	end
	e.Parent = pai
	return e
end

-- Efeitos permanentes de cada modelo (alma, esporos, chama...)
local function criarEfeito(ancora: BasePart, tipo: string, cor: Color3, escala: number)
	if tipo == "chama" or tipo == "fogo" then
		local f = Instance.new("Fire")
		f.Size = (if tipo == "fogo" then 6 else 1.5) * escala
		f.Heat = if tipo == "fogo" then 8 else 3
		f.Color = cor
		f.SecondaryColor = Color3.fromRGB(255, 60, 10)
		f.Parent = ancora
		if tipo == "fogo" then
			emissor(ancora, cor, { Rate = 25, Speed = NumberRange.new(3, 7), Acceleration = Vector3.new(0, 6, 0), Size = sequencia({ { 0, 0.5 * escala }, { 1, 0 } }) })
		end
	elseif tipo == "alma" then
		emissor(ancora, cor, { Rate = 30, Speed = NumberRange.new(1, 4), Acceleration = Vector3.new(0, 5, 0), Size = sequencia({ { 0, 0.6 * escala }, { 1, 0 } }) })
	elseif tipo == "esporos" or tipo == "veneno" then
		emissor(ancora, cor, { Rate = 8, Speed = NumberRange.new(0.5, 1.5), Acceleration = Vector3.new(0, if tipo == "veneno" then -4 else 1, 0) })
	elseif tipo == "gelo" then
		emissor(ancora, cor, { Rate = 14, Speed = NumberRange.new(0.5, 2), Acceleration = Vector3.new(0, -2, 0), Size = sequencia({ { 0, 0.25 }, { 1, 0 } }) })
	else
		emissor(ancora, cor, { Rate = 10 })
	end
end

local function ordenarOssos(ossos): { string }
	local ordem, prontos = {}, { raiz = true }
	local restantes = 0
	for _ in ossos do
		restantes += 1
	end
	while restantes > 0 do
		local avancou = false
		for nome, o in ossos do
			if not prontos[nome] and prontos[o.pai] then
				table.insert(ordem, nome)
				prontos[nome] = true
				restantes -= 1
				avancou = true
			end
		end
		if not avancou then
			break -- osso com pai inexistente: ignorado
		end
	end
	return ordem
end

local function criarBarra(v)
	local modelo = v.modelo
	local elite = modelo:GetAttribute("Elite") or ""
	local temNome = elite ~= ""
	local placa = UI.criar("BillboardGui", {
		Adornee = v.raiz,
		Size = UDim2.fromOffset(120, if temNome then 34 else 14),
		StudsOffset = Vector3.new(0, (modelo:GetAttribute("AlturaBarra") or 4), 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 110,
		Enabled = temNome,
		Parent = pasta,
	})
	if temNome then
		local rotulo = UI.texto({
			Size = UDim2.new(1, 0, 0, 18),
			FontFace = UI.fontes.numero,
			Text = "★ " .. elite,
			TextColor3 = CORES_ELITE[elite] or UI.cores.ouro,
			Parent = placa,
		})
		UI.contorno(rotulo, 1.5, 0)
	end
	local barra = UI.barra({
		Parent = placa,
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(100, 10),
		Raio = 3,
		Cor = if temNome then Color3.fromRGB(230, 150, 40) else UI.cores.vida,
	})
	barra.rotulo.Visible = false
	-- escudo de runas por cima da barra (azul, encolhe conforme absorve)
	local escudo = UI.criar("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(120, 200, 255),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = 4,
		Visible = false,
		Parent = barra.quadro,
	})
	UI.cantos(escudo, 3)
	v.placa = placa
	v.barra = barra
	v.barraEscudo = escudo
end

-- Toca um efeito pronto (ReplicatedStorage.EfeitosVFX) seguindo uma âncora do modelo; para sozinho
-- quando a âncora some (morte ou fim da sala). Devolve a função que para o efeito.
local function tocarPronto(ancora: BasePart, nome: string, escala: number, opcoes: any?): (() -> ())?
	return Vfx.prefab(nome, function()
		return if ancora.Parent then ancora.CFrame else nil
	end, 0, escala, opcoes)
end

-- Despertar do chefe com câmera, em quatro tomadas:
--   1. de baixo, longe, enquanto ele sobe da tumba (a câmera se aproxima devagar)
--   2. close no rosto quando os olhos acendem
--   3. afasta rápido no rugido (com tremor)
--   4. volta suave para o jogador
local function cinematicaDeEntrada(v)
	local camera = workspace.CurrentCamera
	local personagem = Players.LocalPlayer.Character
	local minha = personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not minha or (minha.Position - v.raiz.Position).Magnitude > 220 then
		return
	end
	local subida = v.rig.subida or 2
	local altura = (v.rig.altura or 8) * v.escala
	local chao = v.raiz.Position - Vector3.new(0, v.alturaRaiz, 0)
	local frente = v.raiz.CFrame.LookVector
	local rosto = chao + Vector3.new(0, altura * 0.78, 0) + frente * altura * 0.1
	local peito = chao + Vector3.new(0, altura * 0.6, 0)
	local tomadas = {
		-- { até (s), posição da câmera, para onde olha }
		{ subida - 0.35, chao + frente * altura * 2 + Vector3.new(0, 2, 0), peito },
		{ subida + 0.6, rosto + frente * altura * 0.6 - Vector3.new(0, altura * 0.04, 0), rosto },
		{ subida + 1.9, chao + frente * altura * 1.6 + Vector3.new(0, altura * 0.25, 0), peito },
	}
	local volta = 0.7
	local original = camera.CFrame
	local tipoAntes = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local inicio = os.clock()
	local nome = "CinematicaChefe"
	local terminou = false
	local anterior = CFrame.lookAt(tomadas[1][2] + frente * altura * 0.6 - Vector3.new(0, 1, 0), peito)
	local function terminar()
		if terminou then
			return
		end
		terminou = true
		pcall(function()
			RunService:UnbindFromRenderStep(nome)
		end)
		camera.CameraType = if tipoAntes == Enum.CameraType.Scriptable then Enum.CameraType.Custom else tipoAntes
	end
	RunService:BindToRenderStep(nome, Enum.RenderPriority.Camera.Value, function()
		local t = os.clock() - inicio
		local comeco = 0
		local de = anterior
		for i, tomada in tomadas do
			local alvo = CFrame.lookAt(tomada[2], tomada[3])
			if t < tomada[1] then
				local duracao = tomada[1] - comeco
				-- a 1ª tomada vai devagar; as outras chegam rápido e seguram
				local rapidez = if i == 1 then 1 else 0.35
				local s = math.clamp((t - comeco) / (duracao * rapidez), 0, 1)
				s = s * s * (3 - 2 * s)
				camera.CFrame = de:Lerp(alvo, s)
				return
			end
			comeco = tomada[1]
			de = alvo
		end
		if t < comeco + volta then
			local s = (t - comeco) / volta
			s = s * s * (3 - 2 * s)
			camera.CFrame = de:Lerp(original, s)
		else
			terminar()
		end
	end)
	task.delay(tomadas[#tomadas][1] + volta + 1, terminar) -- segurança: a câmera sempre volta
end

-- Efeitos prontos ligados às ações do chefe (rig.efeitosAcao): "inicio" toca quando a ação
-- começa (com "enquanto" = até a ação acabar), "fim" toca quando ela termina e "repetir" toca
-- de tempos em tempos enquanto durar. Cada efeito nasce numa âncora do modelo (rig.ancoras).
local function iniciarEfeito(v, spec): (() -> ())?
	local ancora = v.ancoras and v.ancoras[spec.ancora or "centro"]
	if not ancora or not ancora.Parent then
		return nil
	end
	local escala = (spec.escala or 1) * v.escala
	local opcoes = { cor = spec.cor, inteiro = spec.inteiro }
	local giro = spec.giro or CFrame.identity
	local function onde(): CFrame
		local pos = ancora.Position
		if spec.virado then
			return CFrame.lookAt(pos, pos + v.raiz.CFrame.LookVector) * giro
		end
		return CFrame.new(pos) * giro
	end
	if spec.fixo then
		Vfx.prefab(spec.nome, onde(), spec.duracao, escala, opcoes)
		return nil
	end
	return Vfx.prefab(spec.nome, function()
		return if ancora.Parent then onde() else nil
	end, if spec.enquanto then 0 else spec.duracao, escala, opcoes)
end

local function trocarEfeitosDeAcao(v, anterior: string, nova: string)
	local efeitos = v.rig.efeitosAcao
	if not efeitos or anterior == nova then
		return -- a mesma ação de novo (ex.: cada corte do giro) não repete os efeitos
	end
	for _, parar in v.efeitosAtivos or {} do
		parar()
	end
	v.efeitosAtivos = {}
	local antes = efeitos[anterior]
	if antes and antes.fim then
		for _, spec in antes.fim do
			iniciarEfeito(v, spec)
		end
	end
	local agora = efeitos[nova]
	v.proximaRepeticao = 0
	if agora and agora.inicio then
		for _, spec in agora.inicio do
			local parar = iniciarEfeito(v, spec)
			if parar and spec.enquanto then
				table.insert(v.efeitosAtivos, parar)
			end
		end
	end
end

-- Despertar: a tumba racha, a névoa sobe, os olhos acendem e ele ruge (efeitos do pacote)
local function despertar(v)
	local rig = v.rig
	local fx = v.escalaFx
	local subida = rig.subida or 2
	local chao = v.raiz.Position - Vector3.new(0, v.alturaRaiz, 0)
	Vfx.prefab(rig.entrada.tumulo, CFrame.new(chao), nil, fx)
	Vfx.tremerEm(chao, 1.2, subida)
	Sons.tocar("pouso", { pos = chao, tom = 0.4, volume = 1.4, alcance = 250 })
	task.delay(subida * 0.5, function()
		Vfx.prefab(rig.entrada.tumulo, CFrame.new(chao), nil, fx * 1.3)
		Vfx.tremerEm(chao, 1.6, 0.6)
	end)
	task.delay(subida - 0.3, function()
		-- os olhos acendem
		if v.ancoras and v.ancoras.rosto and v.ancoras.rosto.Parent then
			Vfx.prefab("CargaCheiaArqueiro", CFrame.new(v.ancoras.rosto.Position), nil, 1.6, { cor = rig.corAura })
			Sons.tocar("cargaCheia", { pos = v.ancoras.rosto.Position, tom = 0.6, volume = 1.2, alcance = 250 })
		end
	end)
	task.delay(subida + 0.6, function()
		-- rugido: onda de choque no chão e a aura acende
		if v.ancoraCorpo and v.ancoraCorpo.Parent then
			Vfx.prefab(rig.entrada.rugido, CFrame.new(v.ancoraCorpo.Position), nil, 0.3 * fx)
			Vfx.prefab("SaltoRei", CFrame.new(chao + Vector3.new(0, 0.2, 0)), nil, 0.8 * fx)
			Vfx.tremerEm(v.ancoraCorpo.Position, 3.5, 1)
			Sons.tocar("supremo", { pos = v.ancoraCorpo.Position, tom = 0.5, volume = 1.3, alcance = 300 })
		end
	end)
	task.spawn(cinematicaDeEntrada, v)
end

local function criarVisual(modelo: Model)
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local humanoid = modelo:WaitForChild("Humanoid", 5) :: Humanoid?
	if not raiz or not humanoid or not modelo.Parent then
		return nil
	end
	local tipo = modelo:GetAttribute("Tipo")
	local construtor = (Modelos :: any)[tipo] or Modelos.padrao
	local rig = construtor()
	local escala = (rig.escala or 1) * (modelo:GetAttribute("Escala") or 1)

	local visual = Instance.new("Model")
	visual.Name = "Visual_" .. tostring(tipo)

	local ossos = {}
	for nome, definicao in rig.ossos do
		ossos[nome] = {
			pai = definicao.pai,
			repouso = CFrame.new(definicao.pivo * escala),
			lado = definicao.lado,
			grupo = definicao.grupo,
			rx = 0, ry = 0, rz = 0, ox = 0, oy = 0, oz = 0,
			mundo = CFrame.identity,
		}
	end
	for _, o in ossos do
		local repousoPai = if o.pai == "raiz" then CFrame.identity else (ossos[o.pai] and ossos[o.pai].repouso or CFrame.identity)
		o.relativo = repousoPai:Inverse() * o.repouso
	end

	local pecas = {}
	local function adicionar(parte: BasePart, nomeOsso: string, cfRepouso: CFrame, extra)
		local o = ossos[nomeOsso] or ossos.corpo
		if not o then
			parte:Destroy()
			return
		end
		parte.Parent = visual
		table.insert(pecas, {
			parte = parte,
			osso = if ossos[nomeOsso] then nomeOsso else "corpo",
			local_ = o.repouso:Inverse() * cfRepouso,
			corBase = parte.Color,
			malha = extra and extra.malha,
			olho = extra and extra.olho,
			geleia = extra and extra.geleia,
			ancora = extra and extra.ancora,
			modelo3d = extra and extra.modelo3d,
		})
	end

	for _, definicao in rig.pecas do
		local parte, malha = construirPeca(definicao, escala)
		local cf = CFrame.new(definicao.cf.Position * escala) * definicao.cf.Rotation
		adicionar(parte, definicao.osso, cf, { malha = malha, olho = definicao.olho, geleia = definicao.geleia })
	end

	-- Modelos 3D prontos (ReplicatedStorage > ModelosChefes): a peça é copiada, ganha o tamanho
	-- pedido e fica com os pés no chão. Um Highlight faz o contorno brilhante e o piscar de dano.
	local destaque = nil
	local malhaComBraco = nil
	local pastaModelos = game:GetService("ReplicatedStorage"):FindFirstChild("ModelosChefes")
	for _, definicao in rig.malhas or {} do
		local origem = pastaModelos and pastaModelos:FindFirstChild(definicao.nome)
		local original = origem and (if origem:IsA("MeshPart") then origem else origem:FindFirstChildWhichIsA("MeshPart", true))
		if original then
			local malha = original:Clone() :: MeshPart
			for _, filho in malha:GetChildren() do
				if not filho:IsA("SurfaceAppearance") then
					filho:Destroy()
				end
			end
			local tamanho = malha.Size * (definicao.altura * escala / malha.Size.Y)
			malha.Size = tamanho
			malha.Anchored = true
			malha.CanCollide = false
			malha.CanQuery = false
			malha.CanTouch = false
			malha.CastShadow = true
			malha.Massless = true
			local cf = CFrame.new((definicao.centroX or 0) * tamanho.X, tamanho.Y / 2, 0) * CFrame.Angles(0, math.rad(definicao.giro or 0), 0)
			adicionar(malha, definicao.osso, cf, { modelo3d = true })
			if definicao.braco and not malhaComBraco then
				-- o braço é ligado depois (a malha editável demora um pouco para carregar)
				local caixa = definicao.braco.caixa
				malhaComBraco = {
					parte = malha,
					def = definicao.braco,
					cf = cf,
					k = tamanho.Y / (caixa.max.Y - caixa.min.Y),
					centro = (caixa.min + caixa.max) / 2,
				}
			end
			if not destaque then
				-- invisível: só aparece no piscar branco ao levar dano (o corpo mantém as cores)
				destaque = Instance.new("Highlight")
				destaque.Adornee = malha
				destaque.DepthMode = Enum.HighlightDepthMode.Occluded
				destaque.FillColor = BRANCO
				destaque.FillTransparency = 1
				destaque.OutlineTransparency = 1
				destaque.Parent = malha
			end
		end
	end

	-- Âncoras invisíveis para luzes e efeitos
	local ancoraCorpo = nil
	local function novaAncora(nomeOsso: string, pos: Vector3): BasePart
		local a = Instance.new("Part")
		a.Size = Vector3.one * 0.2
		a.Transparency = 1
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		adicionar(a, nomeOsso, CFrame.new(pos * escala), { ancora = true })
		return a
	end
	for _, luz in rig.luzes or {} do
		local a = novaAncora(luz.osso, luz.pos)
		local l = Instance.new("PointLight")
		l.Color = luz.cor
		l.Range = luz.alcance * math.sqrt(escala)
		l.Brightness = luz.brilho
		l.Parent = a
	end
	for _, efeito in rig.efeitos or {} do
		criarEfeito(novaAncora(efeito.osso, efeito.pos), efeito.tipo, efeito.cor, escala)
	end
	if ossos.corpo then
		local pivoCorpo = rig.ossos.corpo.pivo
		ancoraCorpo = novaAncora("corpo", pivoCorpo + Vector3.new(0, (rig.altura or 2) * 0.5, 0))
	end
	-- Âncoras com nome (lâmina, ponta, rosto, peito, chão...) onde nascem os efeitos das ações
	local ancoras = { corpo = ancoraCorpo }
	for nomeAncora, definicao in rig.ancoras or {} do
		ancoras[nomeAncora] = novaAncora(definicao.osso, definicao.pos)
	end
	-- efeitos prontos dos pacotes (chamas, névoa...) presos em ossos; começam depois de montar
	local ancorasProntas = {}
	for _, definicao in rig.prefabs or {} do
		table.insert(ancorasProntas, { def = definicao, ancora = novaAncora(definicao.osso, definicao.pos) })
	end
	visual.Parent = pasta

	local v = {
		modelo = modelo,
		raiz = raiz,
		humanoid = humanoid,
		rig = rig,
		escala = escala,
		alturaRaiz = humanoid.HipHeight + raiz.Size.Y / 2,
		ossos = ossos,
		ordem = ordenarOssos(ossos),
		pecas = pecas,
		visual = visual,
		ancoraCorpo = ancoraCorpo,
		ultimaPos = raiz.Position,
		velocidade = 0,
		fase = math.random() * 6,
		acao = "",
		acaoInicio = 0,
		nascimento = os.clock(),
		vidaAnterior = modelo:GetAttribute("Vida") or 1,
		flashAte = 0,
		flashAtivo = false,
		impacto = 0,
		chefe = modelo:GetAttribute("Chefe") == true,
		conexoes = {},
		escalaFx = escala * (rig.escalaEfeitos or 1),
		destaque = destaque,
		malhaComBraco = malhaComBraco,
		bracoAtual = { 0, 0, 0, 0 },
		ancoras = ancoras,
		efeitosAtivos = {},
	}

	if not v.chefe then
		criarBarra(v)
	end
	if malhaComBraco then
		task.spawn(function()
			local braco = BracoMalha.criar(malhaComBraco.parte, malhaComBraco.def)
			if not braco or not malhaComBraco.parte.Parent then
				return
			end
			-- troca a peça parada pela que tem o braço mexendo, no mesmo lugar
			local nova = braco.parte
			nova.CFrame = malhaComBraco.parte.CFrame
			nova.Parent = visual
			for _, peca in pecas do
				if peca.parte == malhaComBraco.parte then
					peca.parte = nova
				end
			end
			if v.destaque then
				v.destaque.Adornee = nova
				v.destaque.Parent = nova
			end
			malhaComBraco.parte:Destroy()
			malhaComBraco.parte = nova
			v.braco = braco
		end)
	end

	v.prontos = {}
	for _, item in ancorasProntas do
		local definicao = item.def
		item.comecar = function()
			if item.ancora.Parent and not item.parar then
				item.parar = tocarPronto(item.ancora, definicao.nome, definicao.escala * escala, { cor = definicao.cor, inteiro = definicao.inteiro, taxa = definicao.taxa })
			end
		end
		if definicao.soFase2 then
			-- liga só quando a 2ª fase começa (atualizarEstados)
		elseif definicao.atraso then
			task.delay(definicao.atraso, item.comecar) -- acende aos poucos no despertar
		else
			item.comecar()
		end
		table.insert(v.prontos, item)
	end
	-- entrada de chefe: o chão racha onde ele vai subir e, quando termina de subir, ele ruge
	if rig.entrada and rig.cinematica then
		despertar(v)
	elseif rig.entrada then
		local chao = raiz.Position - Vector3.new(0, v.alturaRaiz, 0)
		Vfx.prefab(rig.entrada.tumulo, CFrame.new(chao), nil, v.escalaFx)
		Vfx.tremerEm(chao, 1.5, rig.subida or 1)
		task.delay(rig.subida or 0.4, function()
			if v.ancoraCorpo and v.ancoraCorpo.Parent then
				Vfx.prefab(rig.entrada.rugido, CFrame.new(v.ancoraCorpo.Position), nil, 0.25 * v.escalaFx)
				Vfx.tremerEm(v.ancoraCorpo.Position, 3, 0.6)
			end
		end)
	end

	-- Elite: aura colorida
	local elite = modelo:GetAttribute("Elite") or ""
	if elite ~= "" and ancoraCorpo then
		local cor = CORES_ELITE[elite] or UI.cores.ouro
		emissor(ancoraCorpo, cor, {
			Rate = 18,
			Speed = NumberRange.new(2, 4),
			Acceleration = Vector3.new(0, 4, 0),
			Size = sequencia({ { 0, 0.5 * escala }, { 1, 0 } }),
			Shape = Enum.ParticleEmitterShape.Sphere,
		})
		local l = Instance.new("PointLight")
		l.Color = cor
		l.Range = 10 * escala
		l.Brightness = 1.5
		l.Parent = ancoraCorpo
	end
	return v
end

------------------------------------------------------------------------
-- Reações aos atributos vindos do servidor
------------------------------------------------------------------------

local function atualizarVida(v)
	local vida = v.modelo:GetAttribute("Vida") or 0
	local maxima = v.modelo:GetAttribute("VidaMax") or 1
	if vida < v.vidaAnterior then
		v.flashAte = os.clock() + 0.07
		-- recua para longe de quem bateu (o jogador mais perto); golpes pesados recuam mais
		local perdido = (v.vidaAnterior - vida) / math.max(1, maxima)
		v.impacto = math.min(1.8, v.impacto + (if perdido >= 0.12 then 1.8 else 1))
		local pos = v.raiz.Position
		local melhor, distancia = nil, 60
		for _, player in Players:GetPlayers() do
			local raizJogador = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if raizJogador then
				local d = (raizJogador.Position - pos).Magnitude
				if d < distancia then
					melhor, distancia = raizJogador, d
				end
			end
		end
		if melhor then
			local fora = Vector3.new(pos.X - melhor.Position.X, 0, pos.Z - melhor.Position.Z)
			v.recuo = if fora.Magnitude > 0.1 then fora.Unit else nil
		end
		if v.placa then
			v.placa.Enabled = true
		end
	end
	v.vidaAnterior = vida
	if v.barra then
		v.barra.definir(vida / math.max(1, maxima))
	end
end

local function atualizarAcao(v)
	local texto = v.modelo:GetAttribute("Acao") or ""
	local anterior = v.acao
	v.acao = string.match(texto, "^([^|]*)") or ""
	v.acaoInicio = os.clock()
	trocarEfeitosDeAcao(v, anterior, v.acao)
	if v.acao == "golpe" then
		v.golpes = (v.golpes or 0) + 1 -- golpes seguidos alternam o lado
	end
	if v.acao == "golpeVarrida" then
		v.varridas = (v.varridas or 0) + 1 -- a próxima varrida volta pelo outro lado
	end
end

local function atualizarEstados(v)
	local modelo = v.modelo
	local ancora = v.ancoraCorpo
	if not ancora then
		return
	end
	local queimando = modelo:GetAttribute("Queimando") == true
	local fogo = ancora:FindFirstChild("Queimando")
	if queimando and not fogo then
		local f = Instance.new("Fire")
		f.Name = "Queimando"
		f.Size = 4 * v.escala
		f.Heat = 6
		f.Parent = ancora
	elseif not queimando and fogo then
		fogo:Destroy()
	end

	local lento = modelo:GetAttribute("Lento") == true
	local gelo = ancora:FindFirstChild("Lento")
	if lento and not gelo then
		local e = emissor(ancora, Color3.fromRGB(150, 220, 255), { Rate = 20, Shape = Enum.ParticleEmitterShape.Sphere, Speed = NumberRange.new(0.5, 1.5) })
		e.Name = "Lento"
	elseif not lento and gelo then
		gelo:Destroy()
	end

	-- Escudo de runas (Guardião Rúnico): bolha azul em volta e faixa azul na barra de vida
	local escudoAtual = modelo:GetAttribute("Escudo") or 0
	local escudoMax = math.max(1, modelo:GetAttribute("EscudoMax") or 1)
	if escudoAtual > 0 then
		if not v.bolha then
			local bolha = Instance.new("Part")
			bolha.Name = "BolhaEscudo"
			bolha.Shape = Enum.PartType.Ball
			bolha.Material = Enum.Material.ForceField
			bolha.Color = Color3.fromRGB(110, 190, 255)
			bolha.Anchored = true
			bolha.CanCollide = false
			bolha.CanQuery = false
			bolha.CanTouch = false
			bolha.CastShadow = false
			bolha.Transparency = 0.15
			bolha.Size = Vector3.one * (v.raiz.Size.Magnitude * 1.4 + 2)
			bolha.Parent = v.visual
			v.bolha = bolha
		end
		v.bolha.Transparency = 0.15 + 0.5 * (1 - escudoAtual / escudoMax)
		if v.barraEscudo then
			v.barraEscudo.Visible = true
			v.barraEscudo.Size = UDim2.fromScale(math.clamp(escudoAtual / escudoMax, 0, 1), 1)
		end
		if v.placa then
			v.placa.Enabled = true
		end
	else
		if v.bolha then
			v.bolha:Destroy()
			v.bolha = nil
		end
		if v.barraEscudo then
			v.barraEscudo.Visible = false
		end
	end

	-- Inspirado (grito do Porta-Estandarte): aura vermelha subindo
	local inspirado = modelo:GetAttribute("Inspirado") == true
	local aura = ancora:FindFirstChild("Inspirado")
	if inspirado and not aura then
		local e = emissor(ancora, Color3.fromRGB(255, 70, 50), {
			Rate = 30,
			Speed = NumberRange.new(2, 5),
			Acceleration = Vector3.new(0, 8, 0),
			Size = sequencia({ { 0, 0.6 * v.escala }, { 1, 0 } }),
			Shape = Enum.ParticleEmitterShape.Sphere,
		})
		e.Name = "Inspirado"
	elseif not inspirado and aura then
		aura:Destroy()
	end

	-- Sangrando (Assassino): gotas de sangue caindo, mais forte com mais cortes
	local pilhas = modelo:GetAttribute("Sangrando") or 0
	local gotas = ancora:FindFirstChild("Sangrando") :: ParticleEmitter?
	if pilhas > 0 then
		if not gotas then
			gotas = emissor(ancora, Color3.fromRGB(150, 0, 15), {
				LightEmission = 0,
				Acceleration = Vector3.new(0, -40, 0),
				Speed = NumberRange.new(1, 3),
				Size = sequencia({ { 0, 0.22 * v.escala }, { 1, 0.12 * v.escala } }),
				Lifetime = NumberRange.new(0.5, 0.8),
				Shape = Enum.ParticleEmitterShape.Sphere,
			});
			(gotas :: ParticleEmitter).Name = "Sangrando"
		end
		(gotas :: ParticleEmitter).Rate = 8 + pilhas * 7
	elseif gotas then
		gotas:Destroy()
	end

	-- grogue (postura quebrada): ajoelha e brilha em branco; o golpe que preparava some
	local grogue = modelo:GetAttribute("Grogue") == true
	if grogue ~= (v.grogue == true) then
		v.grogue = grogue
		if grogue then
			Vfx.cancelarAvisos(modelo)
			for _, parar in v.efeitosAtivos or {} do
				parar()
			end
			v.efeitosAtivos = {}
		end
		if v.destaque then
			v.destaque.OutlineColor = BRANCO
			v.destaque.OutlineTransparency = if grogue then 0.2 else 1
			v.destaque.FillColor = BRANCO
			v.destaque.FillTransparency = 1
		end
	end

	local atordoado = modelo:GetAttribute("Atordoado") == true
	if atordoado and not v.estrelas then
		Vfx.cancelarAvisos(modelo) -- o golpe que ele preparava não vai sair
		v.estrelas = {}
		for _ = 1, 3 do
			local estrela = Instance.new("Part")
			estrela.Shape = Enum.PartType.Ball
			estrela.Size = Vector3.one * 0.45
			estrela.Material = Enum.Material.Neon
			estrela.Color = Color3.fromRGB(255, 230, 90)
			estrela.Anchored = true
			estrela.CanCollide = false
			estrela.CanQuery = false
			estrela.CanTouch = false
			estrela.Parent = v.visual
			table.insert(v.estrelas, estrela)
		end
	elseif not atordoado and v.estrelas then
		for _, estrela in v.estrelas do
			estrela:Destroy()
		end
		v.estrelas = nil
	end

	if modelo:GetAttribute("Furioso") == true and not v.furioso then
		v.furioso = true
		-- 2ª fase: liga os efeitos extras (aura mais forte)
		for _, item in v.prontos do
			if item.def.soFase2 and item.comecar then
				item.comecar()
			end
		end
		for _, peca in v.pecas do
			if peca.olho then
				peca.corBase = Color3.fromRGB(255, 40, 40)
				peca.parte.Color = peca.corBase
			end
		end
		if v.rig.furia and Vfx.temPrefab(v.rig.furia.rugido) then
			-- chamas verdes viram vermelhas e ele ruge
			for _, item in v.prontos do
				if item.def.furia then
					if item.parar then
						item.parar()
					end
					item.parar = tocarPronto(item.ancora, item.def.furia, item.def.escala * v.escala)
				end
			end
			Vfx.prefab(v.rig.furia.rugido, CFrame.new(ancora.Position), nil, 0.25 * v.escalaFx)
		else
			emissor(ancora, Color3.fromRGB(255, 60, 40), { Rate = 30, Speed = NumberRange.new(3, 6), Acceleration = Vector3.new(0, 6, 0), Size = sequencia({ { 0, 0.8 * v.escala }, { 1, 0 } }) })
		end
	end
end

------------------------------------------------------------------------
-- Poses (ângulos de cada osso conforme a ação)
------------------------------------------------------------------------

local function poseBipede(v, t: number, andar: number, alvos)
	local s = math.sin(v.fase)
	local escala = v.escala
	local curvado = if v.rig.curvado then -0.25 else 0
	alvos.corpo = {
		rx = curvado - 0.08 * andar,
		oy = math.abs(math.cos(v.fase)) * 0.12 * andar * escala + math.sin(t * 2.2) * 0.04 * escala,
	}
	alvos.pernaE = { rx = s * 0.7 * andar }
	alvos.pernaD = { rx = -s * 0.7 * andar }
	alvos.bracoE = { rx = -s * 0.5 * andar + math.sin(t * 1.7) * 0.04, rz = -0.08 }
	alvos.bracoD = { rx = s * 0.5 * andar + math.sin(t * 1.7 + 1) * 0.04, rz = 0.08 }
	alvos.cabeca = { rx = math.sin(t * 1.3) * 0.05 }
	alvos.capa = { rx = -(0.1 + 0.4 * andar) + math.sin(t * 2) * 0.05 }
	alvos.cauda = { ry = math.sin(t * 4) * 0.35 }
	alvos.asaE = { ry = math.sin(t * 16) * 0.5 }
	alvos.asaD = { ry = -math.sin(t * 16) * 0.5 }

	local acao, at = v.acao, v.acaoT
	if acao == "preparar" then
		alvos.bracoD = { rx = 3.3, rz = 0.2 }
		alvos.bracoE = { rx = 0.6, rz = -0.2 }
		alvos.corpo.rx += 0.18
		alvos.corpo.ry = 0.3
	elseif acao == "golpe" then
		alvos.bracoD = { rx = 0.5, rz = -0.2, rapido = true }
		alvos.bracoE = { rx = -0.3 }
		alvos.corpo.rx -= 0.3
		alvos.corpo.ry = -0.25
		alvos.corpo.oz = -0.4 * escala
		alvos.corpo.rapido = true
	elseif acao == "prepararGiro" then
		alvos.bracoE = { rz = -1.4 }
		alvos.bracoD = { rz = 1.4 }
		alvos.corpo.ry = 0.9
	elseif acao == "giro" then
		alvos.bracoE = { rz = -1.4, rapido = true }
		alvos.bracoD = { rz = 1.4, rapido = true }
		alvos.corpo.ry = -at * 22
		alvos.corpo.direto = true
	elseif acao == "conjurar" then
		alvos.bracoE = { rx = 2.3, rz = -0.3 }
		alvos.bracoD = { rx = 2.3, rz = 0.3 }
		alvos.corpo.rx += 0.12
		alvos.cabeca = { rx = 0.2 }
	elseif acao == "disparo" then
		alvos.bracoE = { rx = 1.57, rapido = true }
		alvos.bracoD = { rx = 1.45, ry = 0.3, rapido = true }
	elseif acao == "prepararInvestida" then
		alvos.corpo.rx -= 0.45
		alvos.corpo.oy -= 0.4 * escala
		alvos.bracoE = { rx = -0.7 }
		alvos.bracoD = { rx = -0.7 }
		alvos.pernaE = { rx = 0.5 }
		alvos.pernaD = { rx = -0.3 }
	elseif acao == "investida" then
		local corrida = math.sin(t * 25)
		alvos.corpo.rx -= 0.6
		alvos.bracoE = { rx = 1.2 }
		alvos.bracoD = { rx = 1.2 }
		alvos.pernaE = { rx = corrida * 0.9, rapido = true }
		alvos.pernaD = { rx = -corrida * 0.9, rapido = true }
	elseif acao == "prepararSalto" then
		alvos.corpo.oy -= 0.7 * escala
		alvos.corpo.rx -= 0.3
		alvos.bracoE = { rx = -0.8 }
		alvos.bracoD = { rx = -0.8 }
		alvos.pernaE = { rx = 0.7 }
		alvos.pernaD = { rx = 0.7 }
	elseif acao == "salto" then
		alvos.bracoE = { rx = 2.6 }
		alvos.bracoD = { rx = 2.6 }
		alvos.pernaE = { rx = 0.9 }
		alvos.pernaD = { rx = -0.3 }
	elseif acao == "prepararExplosao" then
		alvos.corpo.rx += math.sin(t * 60) * 0.08
	end
	if v.atordoado then
		alvos.corpo.rx = -0.35
		alvos.cabeca = { rx = -0.3, ry = math.sin(t * 3) * 0.4 }
		alvos.bracoE = { rx = 0.2, rz = -0.2 }
		alvos.bracoD = { rx = 0.2, rz = 0.2 }
	end
	alvos.corpo.rx += v.impacto * 0.3
end

local function poseFlutuante(v, t: number, andar: number, alvos)
	local escala = v.escala
	alvos.corpo = { oy = math.sin(t * 2) * 0.35 * escala, rx = -0.15 * andar }
	alvos.manto = { rx = -0.35 * andar + math.sin(t * 3) * 0.08 }
	alvos.bracoE = { rx = math.sin(t * 1.5) * 0.15, rz = -0.15 }
	alvos.bracoD = { rx = math.sin(t * 1.5 + 1) * 0.15, rz = 0.15 }
	alvos.cabeca = { rx = math.sin(t * 1.1) * 0.06 }
	alvos.base = { ry = t * 5, direto = true }
	alvos.orbita = { ry = t * 1.5, direto = true }
	local acao, at = v.acao, v.acaoT
	if acao == "conjurar" or acao == "prepararGiro" then
		alvos.bracoE = { rx = 2.4, rz = -0.4 }
		alvos.bracoD = { rx = 2.4, rz = 0.4 }
		alvos.corpo.oy += 0.5 * escala
	elseif acao == "disparo" then
		alvos.bracoD = { rx = 1.6, rapido = true }
	elseif acao == "preparar" then
		alvos.bracoD = { rx = 3, rz = 0.2 }
		alvos.corpo.rx += 0.15
	elseif acao == "golpe" then
		alvos.bracoD = { rx = 0.6, rapido = true }
		alvos.corpo.rx -= 0.25
		alvos.corpo.oz = -0.4 * escala
	elseif acao == "giro" then
		alvos.corpo.ry = -at * 20
		alvos.corpo.direto = true
		alvos.bracoE = { rz = -1.4 }
		alvos.bracoD = { rz = 1.4 }
	end
	if v.atordoado then
		alvos.corpo.rx = -0.3
		alvos.corpo.oy = -0.5 * escala
	end
	alvos.corpo.rx += v.impacto * 0.3
end

local function poseQuadrupede(v, t: number, andar: number, alvos)
	local s = math.sin(v.fase * 1.2)
	local escala = v.escala
	alvos.corpo = { oy = math.abs(math.cos(v.fase * 1.2)) * 0.08 * andar * escala }
	alvos.pernaFE = { rx = s * 0.7 * andar }
	alvos.pernaTD = { rx = s * 0.7 * andar }
	alvos.pernaFD = { rx = -s * 0.7 * andar }
	alvos.pernaTE = { rx = -s * 0.7 * andar }
	alvos.cabeca = { rx = math.sin(t * 3) * 0.06 }
	alvos.cauda = { ry = math.sin(t * 6) * 0.5 }
	local acao = v.acao
	if acao == "preparar" then
		alvos.corpo.rx = 0.25
		alvos.cabeca = { rx = 0.3 }
	elseif acao == "golpe" then
		alvos.corpo.rx = -0.15
		alvos.corpo.oz = -0.5 * escala
		alvos.corpo.rapido = true
	end
	alvos.corpo.rx = (alvos.corpo.rx or 0) + v.impacto * 0.2
end

local function poseAranha(v, t: number, andar: number, alvos)
	local escala = v.escala
	alvos.corpo = { oy = math.sin(v.fase * 2) * 0.08 * andar * escala + math.sin(t * 2) * 0.03 * escala }
	for nome, o in v.ossos do
		if o.lado and string.sub(nome, 1, 5) == "perna" then
			local fase = v.fase * 1.2 + (if o.grupo == 1 then math.pi else 0)
			alvos[nome] = {
				ry = math.sin(fase) * 0.35 * andar,
				rz = (math.max(0, math.cos(fase)) * 0.3 * andar + math.sin(t * 2 + o.grupo) * 0.03) * o.lado,
			}
		end
	end
	local acao = v.acao
	if acao == "preparar" or acao == "prepararSalto" or acao == "conjurar" then
		alvos.corpo.rx = 0.35
		alvos.corpo.oy -= 0.3 * escala
	elseif acao == "golpe" then
		alvos.corpo.rx = -0.2
		alvos.corpo.oz = -0.6 * escala
		alvos.corpo.rapido = true
	elseif acao == "salto" then
		for nome, o in v.ossos do
			if o.lado and string.sub(nome, 1, 5) == "perna" then
				alvos[nome] = { rz = 0.5 * o.lado }
			end
		end
	end
	alvos.corpo.rx = (alvos.corpo.rx or 0) + v.impacto * 0.2
end

-- Gosmas: em vez de ossos, o corpo estica e encolhe
local function poseGosma(v, t: number, andar: number, alvos)
	local escala = v.escala
	local s = math.sin(v.fase * 1.3)
	local sy, sxz = 1 + math.sin(t * 3) * 0.04, 1 - math.sin(t * 3) * 0.02
	local pulo = 0
	if andar > 0.1 then
		sy = 1 + 0.16 * s * andar
		sxz = 1 - 0.08 * s * andar
		pulo = math.max(0, s) * 0.7 * andar * escala
	end
	local oz = 0
	local acao, at = v.acao, v.acaoT
	if acao == "preparar" or acao == "prepararGiro" or acao == "conjurar" then
		sy, sxz = 0.72, 1.22
	elseif acao == "golpe" or acao == "giro" then
		sy, sxz = 1.3, 0.86
		oz = -0.6 * escala
	elseif acao == "prepararExplosao" then
		local inchar = 1 + math.min(at, 1) * 0.35 + math.sin(t * 40) * 0.05
		sy, sxz = inchar, inchar
	end
	sy += v.impacto * -0.15
	sxz += v.impacto * 0.1
	v.escalaGeleia = Vector3.new(sxz, sy, sxz)
	alvos.corpo = { oy = pulo, oz = oz, rapido = acao == "golpe" }
end

-- Rei Esqueleto: o corpo do bípede, mas pesado e com o espadão. Ergue a espada com as duas mãos
-- antes do golpe e desce com tudo; no giro, a lâmina vai esticada para fora; ao invocar, segura
-- o espadão em pé como um cetro e ergue a outra mão.
local function poseRei(v, t: number, andar: number, alvos)
	poseBipede(v, t, andar, alvos)
	local escala = v.escala
	local s = math.sin(v.fase)
	alvos.corpo.rx = -0.12 - 0.06 * andar
	alvos.corpo.ry = s * 0.1 * andar
	alvos.corpo.oy = math.abs(math.cos(v.fase)) * 0.2 * andar * escala + math.sin(t * 1.4) * 0.07 * escala
	alvos.cabeca = { rx = 0.12 + math.sin(t * 1.4) * 0.04 }
	alvos.bracoD = { rx = 0.35 + s * 0.12 * andar, rz = 0.12 }
	alvos.bracoE = { rx = 0.1 - s * 0.35 * andar, rz = -0.18 }
	alvos.pernaE = { rx = s * 0.55 * andar }
	alvos.pernaD = { rx = -s * 0.55 * andar }

	local acao, at = v.acao, v.acaoT
	if acao == "preparar" or acao == "salto" then
		alvos.bracoD = { rx = 3, rz = 0.35 }
		alvos.bracoE = { rx = 2.9, rz = -0.45 }
		alvos.corpo.rx = 0.22
		alvos.corpo.ry = 0.12
		alvos.cabeca = { rx = 0.25 }
		if acao == "salto" then
			alvos.pernaE = { rx = 0.9 }
			alvos.pernaD = { rx = -0.4 }
		end
	elseif acao == "golpe" then
		alvos.bracoD = { rx = 0.05, rz = 0.2, rapido = true }
		alvos.bracoE = { rx = 0.25, rz = 0.55, rapido = true }
		alvos.corpo.rx = -0.55
		alvos.corpo.ry = -0.1
		alvos.corpo.oz = -0.5 * escala
		alvos.corpo.oy = -0.35 * escala
		alvos.corpo.rapido = true
		alvos.pernaE = { rx = 0.5 }
		alvos.pernaD = { rx = -0.35 }
	elseif acao == "prepararGiro" then
		alvos.bracoD = { rx = 0.15, rz = 1.35 }
		alvos.bracoE = { rz = -1.1 }
		alvos.corpo.ry = 1
		alvos.corpo.oy = -0.3 * escala
	elseif acao == "giro" then
		alvos.bracoD = { rx = 0.1, rz = 1.45, rapido = true }
		alvos.bracoE = { rz = -1.3, rapido = true }
		alvos.corpo.ry = -at * 20
		alvos.corpo.direto = true
		alvos.corpo.oy = -0.25 * escala
	elseif acao == "conjurar" then
		alvos.bracoD = { rx = 1.45, rz = 0.05 }
		alvos.bracoE = { rx = 2.7, rz = -0.4 }
		alvos.corpo.rx = 0.12
		alvos.cabeca = { rx = 0.35 }
	elseif acao == "prepararSalto" then
		alvos.corpo.oy = -0.9 * escala
		alvos.corpo.rx = -0.35
		alvos.bracoD = { rx = -0.7, rz = 0.2 }
		alvos.bracoE = { rx = -0.7, rz = -0.2 }
		alvos.pernaE = { rx = 0.8 }
		alvos.pernaD = { rx = 0.8 }
	end
	if v.atordoado then
		alvos.corpo.rx = -0.35
		alvos.bracoD = { rx = 0.2, rz = 0.2 }
		alvos.bracoE = { rx = 0.2, rz = -0.2 }
	end
	-- (o Rei quase não recua com os golpes)
	alvos.corpo.rx += v.impacto * 0.12
end

-- Skullbane (modelo 3D de uma peça): o corpo inteiro inclina, torce, agacha e gira pelo
-- quadril, com peso. Cada ação tem antecipação (prepara), golpe rápido e recuperação.
local function suaveEntre(a: number, b: number, x: number): number
	local k = math.clamp((x - a) / (b - a), 0, 1)
	return k * k * (3 - 2 * k)
end

local function poseSenhor(v, t: number, andar: number, alvos)
	local e = v.escala
	local f = v.fase
	-- andar pesado: o corpo desce a cada passo, o peso vai de um lado para o outro e os ombros
	-- torcem junto; parado, respira devagar e balança um pouco. O braço da lâmina balança
	-- ao contrário da perna, como um passo de verdade.
	local respiro = math.sin(t * 1.25)
	local c = {
		rx = -0.03 - 0.11 * andar + respiro * 0.018,
		ry = math.sin(f) * 0.09 * andar + math.sin(t * 0.55) * 0.03 * (1 - andar),
		rz = math.sin(f) * 0.06 * andar + math.sin(t * 0.8) * 0.012,
		oy = ((math.abs(math.cos(f)) - 0.65) * 0.7 * andar + respiro * 0.12) * e,
		oz = -0.25 * andar * e,
	}
	-- braço: { levanta, abre, gira, cotovelo }
	local b = { 0.12 + respiro * 0.03 + math.sin(f) * 0.22 * andar, 0.05, 0, 0.15 + 0.08 * andar }
	local acao, at = v.acao, v.acaoT
	local lado = if (v.golpes or 0) % 2 == 0 then -1 else 1
	local function braco(alvo, k: number?, rapido: boolean?)
		k = k or 1
		b = { b[1] + (alvo[1] - b[1]) * k, b[2] + (alvo[2] - b[2]) * k, b[3] + (alvo[3] - b[3]) * k, b[4] + (alvo[4] - b[4]) * k, rapido = rapido }
	end

	if acao == "preparar" then
		-- Corte Descendente: abaixa um instante, ergue a lâmina acima da cabeça torcendo para
		-- trás e treme de força enquanto segura
		local k = suaveEntre(0.12, 0.75, at)
		c.rx = -0.12 + 0.42 * k
		c.ry = -0.4 * k
		c.rz = math.sin(t * 45) * 0.018 * k
		c.oy = (-0.6 + 1.2 * k) * e
		c.oz = 0.4 * k * e
		braco({ 2.75 + math.sin(t * 40) * 0.02 * k, 0.25, 0.1, 0.65 }, k)
	elseif acao == "golpe" then
		if at < 0.3 then
			-- desce com tudo e passa do ponto: a lâmina bate no chão à frente
			c.rx = -0.5
			c.ry = 0.25 * lado
			c.oz = -2 * e
			c.oy = -1.1 * e
			c.rapido = true
			braco({ 0.5, 0.05, 0, 0.05 }, 1, true)
		else
			local k = suaveEntre(0.3, 1, at)
			c.rx = -0.5 + 0.35 * k
			c.ry = 0.25 * lado * (1 - k)
			c.oz = -2 * e * (1 - k)
			c.oy = -1.1 * e * (1 - k)
			braco({ 0.55, 0.05, 0, 0.05 }, 1 - k)
		end
	elseif acao == "preso" then
		-- a lâmina cravada no chão: curvado, dando puxões para soltar
		local puxao = math.max(0, math.sin(t * 7)) ^ 4
		c.rx = -0.55 + puxao * 0.12
		c.ry = 0.35
		c.oz = (-1.6 + puxao * 0.4) * e
		c.oy = (-1.3 + puxao * 0.3) * e
		c.rz = math.sin(t * 13) * 0.02
		braco({ 0.5 + puxao * 0.14, 0.05, math.sin(t * 13) * 0.04, 0.05 + puxao * 0.2 })
	elseif acao == "prepararVarrida" then
		-- Varrida: a lâmina vai para o lado de fora e para trás (ou cruzada na frente, na volta)
		local k = suaveEntre(0, 0.45, at)
		local volta = (v.varridas or 0) % 2 == 1
		c.ry = (if volta then 0.45 else -0.6) * k
		c.oy = -0.5 * k * e
		c.rx = -0.08 * k
		braco(if volta then { 1.3, -0.25, 1, 0.25 } else { 0.8, 1.15, -0.75, 0.35 }, k)
	elseif acao == "golpeVarrida" then
		-- varre na altura da cintura, o tronco desenrola junto
		local volta = (v.varridas or 0) % 2 == 0 -- (já contou esta varrida)
		local k = suaveEntre(0, 0.14, at) * (1 - suaveEntre(0.45, 1, at))
		c.ry = (if volta then -0.55 else 0.55) * k
		c.oy = -0.6 * k * e
		c.oz = -0.8 * k * e
		c.rx = -0.18 * k
		c.rapido = at < 0.2
		braco(if volta then { 0.8, 1.15, -0.75, 0.2 } else { 1.3, -0.25, 1, 0.1 }, math.max(k, 0.0001), at < 0.2)
	elseif acao == "prepararEstocada" then
		-- recua a lâmina com o cotovelo dobrado, o corpo vai para trás como uma mola
		local k = suaveEntre(0, 0.5, at)
		c.ry = -0.35 * k
		c.rx = 0.08 * k
		c.oz = 0.8 * k * e
		c.oy = -0.4 * k * e
		c.rz = math.sin(t * 38) * 0.012 * k
		braco({ 1.05, 0.15, -0.25, 1.6 }, k)
	elseif acao == "golpeEstocada" then
		local k = 1 - suaveEntre(0.35, 1, at)
		c.rx = -0.35 * k
		c.ry = 0.1 * k
		c.oz = -2.6 * k * e
		c.oy = -0.4 * k * e
		c.rapido = at < 0.2
		braco({ 1.55, 0.05, 0.05, 0 }, k, at < 0.2)
	elseif acao == "prepararNova" then
		-- Explosão de Almas: ergue a lâmina com a ponta para baixo para cravar no chão
		local k = suaveEntre(0, 0.4, at)
		c.rx = 0.15 * k
		c.oy = 0.5 * k * e
		c.rz = math.sin(t * 40) * 0.015 * k
		braco({ 2.3, 0.45, 0.2, 0.9 }, k)
	elseif acao == "golpeNova" then
		local k = 1 - suaveEntre(0.35, 1, at)
		c.rx = -0.45 * k
		c.oy = -1.8 * k * e
		c.oz = -0.8 * k * e
		c.rapido = at < 0.2
		braco({ 0.3, 0.1, 0.2, 0 }, k, at < 0.2)
	elseif acao == "prepararGiro" then
		local k = suaveEntre(0, 0.7, at)
		c.ry = -1.1 * k
		c.oy = -0.7 * k * e
		c.rx = -0.12 * k
		c.rz = math.sin(t * 40) * 0.012 * k
		braco({ 1.45, 1.25, -0.3, 0.1 }, k)
	elseif acao == "giro" then
		v.giroAcum = (v.giroAcum or 0) + (v.dt or 0) * 16
		c.ry = v.giroAcum
		c.direto = true
		c.oy = -0.45 * e
		c.rx = -0.14
		c.rz = 0.05
		braco({ 1.45, 1.25, 0, 0.05 })
	elseif acao == "conjurar" then
		-- peito para cima e a lâmina erguida para o céu: rugido, invocação, transformação
		local k = suaveEntre(0, 0.5, at)
		c.rx = 0.25 * k
		c.oy = 0.8 * k * e
		c.ry = math.sin(t * 2) * 0.05
		c.rz = math.sin(t * 32) * 0.015 * k
		braco({ 2.5, 0.5, 0.15, 0.2 }, k)
	elseif acao == "prepararPuxao" then
		-- aponta a lâmina para quem está longe; a energia junta
		local k = suaveEntre(0, 0.5, at)
		c.rx = 0.1 * k
		c.ry = -0.15 * k
		c.rz = math.sin(t * 36) * 0.015 * k
		braco({ 1.6, 0.15, 0.35, 0 }, k)
	elseif acao == "puxao" then
		-- puxa com força para trás, trazendo todo mundo
		local k = suaveEntre(0, 0.2, at)
		c.rx = 0.18 * k
		c.ry = -0.4 * k
		c.oz = 0.6 * k * e
		c.oy = -0.5 * k * e
		braco({ 1, 0.3, -0.5, 1.3 }, k, true)
	elseif acao == "disparo" then
		c.rx = -0.2
		c.oz = -0.8 * e
		c.rapido = true
		braco({ 1.3, -0.25, 0.9, 0.1 }, 1, true)
	elseif acao == "prepararSalto" then
		local k = suaveEntre(0, 0.6, at)
		c.oy = -1.9 * k * e
		c.rx = -0.32 * k
		c.rz = math.sin(t * 30) * 0.015 * k
		braco({ -0.35, 0.35, 0, 0.3 }, k)
	elseif acao == "salto" then
		-- estica para cima com a lâmina acima da cabeça e se encolhe para cair com ela
		local k = suaveEntre(0.15, 0.6, at)
		c.rx = 0.22 - 0.6 * k
		c.oy = 0.5 * e
		braco({ 2.8, 0.2, 0, 0.5 })
	elseif acao == "prepararInvestida" then
		local k = suaveEntre(0, 0.6, at)
		c.rx = -0.38 * k
		c.ry = -0.28 * k
		c.oy = -0.9 * k * e
		c.rz = math.sin(t * 24) * 0.02 * k
		braco({ 0.55, 0.55, -0.55, 0.3 }, k)
	elseif acao == "investida" then
		c.rx = -0.48
		c.rz = math.sin(t * 22) * 0.06
		c.oy = (math.abs(math.sin(t * 22)) * 0.5 - 0.3) * e
		c.oz = -0.8 * e
		braco({ 1.05, 0.25, -0.15, 0.1 })
	end
	-- fim do giro: volta para o ângulo equivalente mais perto (sem "desgirar")
	if acao ~= "giro" and v.giroAcum then
		local o = v.ossos.corpo
		o.ry = math.atan2(math.sin(o.ry), math.cos(o.ry))
		v.giroAcum = nil
	end
	-- pouso do salto: amortece e a lâmina bate no chão
	local desdePouso = t - (v.pouso or -10)
	if desdePouso < 0.5 then
		local k = 1 - desdePouso / 0.5
		c.oy = (c.oy or 0) - 1.6 * k * e
		c.rx = (c.rx or 0) - 0.25 * k
		braco({ 0.55, 0.05, 0, 0.05 }, k, true)
	end

	-- despertar (entrada): sobe curvado de cabeça baixa, endireita tremendo e ruge com a
	-- lâmina erguida para o lado
	local idade = t - v.nascimento
	local subida = v.rig.subida or 2
	if v.rig.cinematica and idade < subida + 2 then
		if idade < subida then
			local s = idade / subida
			c.rx = -0.7 * (1 - s) - 0.15
			c.ry = 0
			c.rz = math.sin(t * 9) * 0.03 * (1 - s)
			c.oz = 0
			b = { 0, 0.1, 0, 0.2 }
		elseif idade < subida + 0.6 then
			local s = (idade - subida) / 0.6
			c.rx = -0.15 + 0.15 * s
			c.rz = math.sin(t * 30) * 0.02
		else
			local s = suaveEntre(subida + 0.6, subida + 0.9, idade) * (1 - suaveEntre(subida + 1.6, subida + 2, idade))
			c.rx = 0.38 * s
			c.oy = 1 * s * e
			c.ry = math.sin(t * 22) * 0.035 * s
			c.rz = math.sin(t * 27) * 0.03 * s
			braco({ 1.9, 0.9, -0.2, 0.5 }, s)
		end
	end
	if v.atordoado then
		c.rx = -0.3
		c.rz = math.sin(t * 3) * 0.07
		c.oy = -0.7 * e
		b = { 0.05, 0.1, 0, 0.1 }
	end
	if v.grogue then
		-- de joelhos, curvado sobre a espada fincada no chão, respirando pesado
		local ofego = math.sin(t * 2.4)
		c.rx = -0.5 + ofego * 0.04
		c.ry = 0.1
		c.rz = math.sin(t * 1.3) * 0.04
		c.oy = (-2.4 + ofego * 0.12) * e
		c.oz = -0.8 * e
		c.direto = nil
		b = { 0.45, 0.25, 0.1, 0.1 }
	end
	c.rx += v.impacto * 0.06
	alvos.corpo = c
	alvos.braco = b
end

-- Ceifador Esmeralda (lacaio do Skullbane): passos ágeis de esqueleto, tronco curvado para a
-- frente e a espada em pé na guarda; ergue a espada atrás da cabeça e corta para a frente,
-- ou varre de lado. Sai do chão encolhido e se endireita.
local function poseCeifador(v, t: number, andar: number, alvos)
	local e = v.escala
	local f = v.fase
	local tremor = math.sin(t * 11 + v.nascimento) * 0.012 -- ossos que nunca param
	local c = {
		rx = -0.12 - 0.14 * andar + tremor,
		ry = math.sin(f) * 0.12 * andar,
		rz = math.sin(f) * 0.08 * andar + math.sin(t * 1.7) * 0.02,
		oy = ((math.abs(math.cos(f)) - 0.6) * 0.5 * andar + math.sin(t * 2.1) * 0.05) * e,
	}
	local b = { 0.1 + math.sin(f) * 0.25 * andar, 0.05, 0, 0.1 }
	local acao, at = v.acao, v.acaoT
	local function braco(alvo, k: number?, rapido: boolean?)
		k = k or 1
		b = { b[1] + (alvo[1] - b[1]) * k, b[2] + (alvo[2] - b[2]) * k, b[3] + (alvo[3] - b[3]) * k, b[4] + (alvo[4] - b[4]) * k, rapido = rapido }
	end
	if acao == "preparar" then
		local k = suaveEntre(0, 0.45, at)
		c.rx = 0.18 * k
		c.ry = -0.3 * k
		c.oy = 0.2 * k * e
		braco({ 2.4, 0.2, 0, 0.5 }, k)
	elseif acao == "golpe" then
		local k = 1 - suaveEntre(0.3, 0.9, at)
		c.rx = -0.4 * k
		c.ry = 0.25 * k
		c.oz = -1 * k * e
		c.oy = -0.4 * k * e
		c.rapido = at < 0.2
		braco({ 1.5, 0.05, 0.3, 0 }, k, at < 0.2)
	elseif acao == "prepararVarrida" then
		local k = suaveEntre(0, 0.4, at)
		c.ry = -0.5 * k
		c.oy = -0.3 * k * e
		braco({ 0.6, 1, -0.7, 0.3 }, k)
	elseif acao == "golpeVarrida" then
		local k = suaveEntre(0, 0.12, at) * (1 - suaveEntre(0.4, 0.9, at))
		c.ry = 0.5 * k
		c.oy = -0.35 * k * e
		c.oz = -0.6 * k * e
		c.rapido = at < 0.2
		braco({ 1.3, -0.2, 0.9, 0.1 }, math.max(k, 0.0001), at < 0.2)
	elseif acao == "prepararInvestida" then
		local k = suaveEntre(0, 0.5, at)
		c.rx = -0.4 * k
		c.oy = -0.6 * k * e
		braco({ 1.2, 0.4, -0.4, 0.2 }, k)
	elseif acao == "investida" then
		c.rx = -0.5
		c.oy = (math.abs(math.sin(t * 24)) * 0.3 - 0.2) * e
		braco({ 1.5, 0.1, 0, 0 })
	end
	-- saindo do chão: encolhido, a cabeça baixa, e se endireita com um tremor
	local idade = t - v.nascimento
	local subida = v.rig.subida or 1
	if idade < subida + 0.4 then
		local s = math.clamp(idade / subida, 0, 1)
		c.rx = -0.8 * (1 - s) + math.sin(t * 30) * 0.03 * (1 - s)
		c.rz = math.sin(t * 17) * 0.05 * (1 - s)
		braco({ 2.2, 0.3, 0, 0.3 }, 1 - suaveEntre(subida, subida + 0.4, idade))
	end
	if v.atordoado then
		c.rx = -0.4
		c.rz = math.sin(t * 3) * 0.08
		b = { 0, 0.1, 0, 0 }
	end
	c.rx += v.impacto * 0.2
	alvos.corpo = c
	alvos.braco = b
end

local POSES = {
	ceifador = poseCeifador,
	senhor = poseSenhor,
	rei = poseRei,
	bipede = poseBipede,
	flutuante = poseFlutuante,
	quadrupede = poseQuadrupede,
	aranha = poseAranha,
	gosma = poseGosma,
}

------------------------------------------------------------------------
-- Atualização a cada frame
------------------------------------------------------------------------

local function atualizarVisual(v, dt: number, agora: number, partes, cframes)
	local raizCF = v.raiz.CFrame
	if v.rig.suave then
		-- chefe pesado: segue a caixa do servidor com suavidade (sem trancos ao virar ou parar)
		local anterior = v.cfSuave or raizCF
		-- quanto mais longe a caixa está, mais rápido alcança (na investida não fica para trás)
		local distancia = (raizCF.Position - anterior.Position).Magnitude
		local p = if distancia > 30 then raizCF.Position else anterior.Position:Lerp(raizCF.Position, math.min(1, dt * (10 + distancia * 3)))
		local rotacao = anterior.Rotation:Lerp(raizCF.Rotation, math.min(1, dt * (v.rig.giroSuave or 5)))
		v.cfSuave = CFrame.new(p) * rotacao
		raizCF = v.cfSuave
	end
	v.dt = dt
	local pos = raizCF.Position
	local deslocamento = pos - v.ultimaPos
	v.ultimaPos = pos
	local velocidade = Vector3.new(deslocamento.X, 0, deslocamento.Z).Magnitude / math.max(dt, 1 / 240)
	if velocidade > 120 then
		velocidade = 0 -- teleporte
	end
	v.velocidade += (velocidade - v.velocidade) * math.min(1, dt * 8)
	local andar = math.clamp(v.velocidade / 12, 0, 1)
	v.fase += dt * (2 + v.velocidade * 0.6) * (v.rig.ritmo or 1)
	v.acaoT = agora - v.acaoInicio
	if (string.sub(v.acao, 1, 5) == "golpe" or v.acao == "disparo" or v.acao == "giro") and v.acaoT > 1.2 then
		v.acao = ""
	end
	v.atordoado = v.estrelas ~= nil
	v.impacto = math.max(0, v.impacto - dt * 5)

	local base = raizCF * CFrame.new(0, -v.alturaRaiz, 0)
	if v.salto then
		local s = (agora - v.salto.inicio) / v.salto.duracao
		if s >= 1 then
			if v.cfSuave then
				v.cfSuave = CFrame.new(v.salto.para) * v.cfSuave.Rotation -- já no ponto de chegada
			end
			v.salto = nil
			v.pouso = agora
		else
			local p = v.salto.de:Lerp(v.salto.para, s) + Vector3.new(0, v.salto.altura * 4 * s * (1 - s), 0)
			base = CFrame.new(p - Vector3.new(0, v.alturaRaiz, 0)) * raizCF.Rotation
		end
	end
	-- rastro da lâmina nos golpes; presa no chão, solta faíscas verdes na ponta
	local efeitosAcao = v.rig.efeitosAcao and v.rig.efeitosAcao[v.acao]
	if efeitosAcao and efeitosAcao.repetir and agora >= (v.proximaRepeticao or 0) then
		v.proximaRepeticao = agora + efeitosAcao.repetir.intervalo
		for _, spec in efeitosAcao.repetir.efeitos do
			iniciarEfeito(v, spec)
		end
	end
	-- passos pesados: poeira e tremor a cada pé no chão
	if v.rig.passo and andar > 0.3 and not v.salto then
		local lado = math.sin(v.fase) >= 0
		if lado ~= v.ultimoPe then
			v.ultimoPe = lado
			iniciarEfeito(v, v.rig.passo)
			Vfx.tremerEm(pos, 0.35 * andar, 0.12)
		end
	end
	-- bolha do escudo de runas acompanha o inimigo, girando devagar
	if v.bolha then
		v.bolha.CFrame = CFrame.new(base.Position + Vector3.new(0, v.alturaRaiz, 0)) * CFrame.Angles(0, agora * 0.8, 0)
	end
	-- recuo ao levar golpe: escorrega e inclina para longe de quem bateu
	if v.recuo and v.impacto > 0.01 then
		local forca = math.min(v.impacto, 1.8)
		local eixo = Vector3.yAxis:Cross(v.recuo)
		base = CFrame.new(base.Position + v.recuo * forca * 0.45 * v.escala) * CFrame.fromAxisAngle(eixo, forca * 0.2) * base.Rotation
	end
	local idade = agora - v.nascimento
	local subida = v.rig.subida or 0.4
	if idade < subida then
		local falta = 1 - idade / subida
		base *= CFrame.new(0, -falta * falta * (v.rig.profundidade or 3) * v.escala, 0)
	end

	local alvos = {}
	local pose = POSES[v.rig.estilo] or poseBipede
	pose(v, agora, andar, alvos)
	v.alvoBraco = (alvos :: any).braco

	for _, nome in v.ordem do
		local o = v.ossos[nome]
		local alvo = alvos[nome] or ZERO
		if alvo.direto then
			o.rx, o.ry, o.rz = alvo.rx or 0, alvo.ry or 0, alvo.rz or 0
		else
			local k = math.min(1, dt * (if alvo.rapido then 30 else (v.rig.rigidez or 12)))
			o.rx += ((alvo.rx or 0) - o.rx) * k
			o.ry += ((alvo.ry or 0) - o.ry) * k
			o.rz += ((alvo.rz or 0) - o.rz) * k
		end
		local k = math.min(1, dt * (if alvo.rapido then 30 else (v.rig.rigidez or 12)))
		o.ox += ((alvo.ox or 0) - o.ox) * k
		o.oy += ((alvo.oy or 0) - o.oy) * k
		o.oz += ((alvo.oz or 0) - o.oz) * k
		local paiCF = if o.pai == "raiz" then base else v.ossos[o.pai].mundo
		o.mundo = paiCF * o.relativo * CFrame.new(o.ox, o.oy, o.oz) * CFrame.Angles(o.rx, o.ry, o.rz)
	end

	-- Braço do modelo 3D: a pose vai suave até o alvo (rápida nos golpes) e a malha é deformada
	-- no máximo 30 vezes por segundo; a lâmina (âncoras de efeitos) acompanha o braço
	local alvoBraco = v.alvoBraco
	if alvoBraco and v.malhaComBraco then
		local atual = v.bracoAtual
		local k = math.min(1, dt * (if alvoBraco.rapido then 22 else 8))
		atual[1] += ((alvoBraco[1] or 0) - atual[1]) * k
		atual[2] += ((alvoBraco[2] or 0) - atual[2]) * k
		atual[3] += ((alvoBraco[3] or 0) - atual[3]) * k
		atual[4] += ((alvoBraco[4] or 0) - atual[4]) * k
		if v.braco then
			local ultimo = v.bracoAplicado
			local mudou = not ultimo
				or math.abs(ultimo[1] - atual[1]) + math.abs(ultimo[2] - atual[2]) + math.abs(ultimo[3] - atual[3]) + math.abs(ultimo[4] - atual[4]) > 0.004
			if mudou and agora >= (v.proximoBraco or 0) then
				v.proximoBraco = agora + 1 / 30
				v.braco.aplicar(atual[1], atual[2], atual[3], atual[4])
				v.bracoAplicado = { atual[1], atual[2], atual[3], atual[4] }
			end
			local aplicado = v.bracoAplicado
			local lamina = v.ossos.lamina
			if aplicado and lamina then
				local info = v.malhaComBraco
				local cg = BracoMalha.transformacao(info.def, aplicado[1], aplicado[2], aplicado[3], aplicado[4])
				local rot = cg.Rotation
				local d = (rot:VectorToWorldSpace(info.centro) + cg.Position - info.centro) * info.k
				local cRig = info.cf * CFrame.new(d) * rot * info.cf:Inverse()
				local corpo = v.ossos.corpo
				lamina.mundo = corpo.mundo * corpo.repouso:Inverse() * cRig * lamina.repouso
			end
		end
	end

	-- Piscar branco ao levar dano
	if agora < v.flashAte and not v.flashAtivo then
		v.flashAtivo = true
		for _, peca in v.pecas do
			if not peca.ancora and not peca.modelo3d then
				peca.parte.Color = BRANCO
			end
		end
		if v.destaque then
			v.destaque.FillColor = BRANCO
			v.flashTransparencia = v.destaque.FillTransparency
			v.destaque.FillTransparency = 0.45
		end
	elseif v.grogue and not v.flashAtivo and v.destaque then
		v.destaque.FillTransparency = 0.7 + 0.15 * math.sin(agora * 7)
	elseif v.flashAtivo and agora >= v.flashAte then
		v.flashAtivo = false
		for _, peca in v.pecas do
			if not peca.modelo3d then
				peca.parte.Color = peca.corBase
			end
		end
		if v.destaque then
			v.destaque.FillColor = BRANCO
			v.destaque.FillTransparency = v.flashTransparencia or 1
		end
	end

	local geleia = v.escalaGeleia
	for _, peca in v.pecas do
		local o = v.ossos[peca.osso]
		local cf
		if geleia and peca.osso == "corpo" then
			cf = o.mundo * CFrame.new(peca.local_.Position * geleia) * peca.local_.Rotation
			if peca.malha and peca.geleia then
				peca.malha.Scale = geleia
			end
		else
			cf = o.mundo * peca.local_
		end
		table.insert(partes, peca.parte)
		table.insert(cframes, cf)
	end

	if v.estrelas then
		local cabeca = v.ossos.cabeca or v.ossos.corpo
		local altura = if v.ossos.cabeca then 2.2 else (v.rig.alturaCabeca or 2.2)
		local centro = cabeca.mundo.Position + Vector3.new(0, altura * v.escala, 0)
		for i, estrela in v.estrelas do
			local angulo = agora * 6 + i * (math.pi * 2 / 3)
			table.insert(partes, estrela)
			table.insert(cframes, CFrame.new(centro + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * 1.2 * v.escala))
		end
	end
end

------------------------------------------------------------------------
-- Morte: as peças se soltam e voam
------------------------------------------------------------------------

-- Morte de chefe com modelo 3D: ele cambaleia e cai de joelhos, as almas estouram pelo corpo
-- e um raio de luz verde desce do céu sobre ele, que some aos poucos. Só efeitos do pacote.
-- Lacaio com modelo 3D: desaba para trás, as almas escapam e ele some
local function morteDeLacaio3D(v)
	local cor = v.rig.corAura or BRANCO
	local corpo = v.ossos.corpo
	local mundo0 = corpo.mundo
	local inicio = os.clock()
	for _, parar in v.efeitosAtivos or {} do
		parar()
	end
	local centro = v.ancoraCorpo and v.ancoraCorpo.Position or v.ultimaPos
	Vfx.prefab("ImpactoFlecha", CFrame.new(centro), nil, 1.6, { inteiro = true })
	Sons.tocar("inimigoMorre", { pos = centro, tom = 0.7 })
	task.spawn(function()
		while true do
			local s = (os.clock() - inicio) / 0.6
			if s >= 1 then
				break
			end
			local cf = mundo0 * CFrame.new(0, -s * s * 2.5 * v.escala, s * 0.6 * v.escala) * CFrame.Angles(0.9 * s * s, 0, 0.2 * s)
			local partes, cframes = {}, {}
			for _, peca in v.pecas do
				if peca.parte.Parent then
					table.insert(partes, peca.parte)
					table.insert(cframes, cf * peca.local_)
				end
			end
			workspace:BulkMoveTo(partes, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			task.wait()
		end
		Vfx.prefab("TumuloRei", CFrame.new(v.ultimaPos - Vector3.new(0, v.alturaRaiz, 0)), nil, 0.8)
		Vfx.prefab("ChamaEspectral", CFrame.new(centro), 0.6, 1, { cor = cor })
		for _, peca in v.pecas do
			if peca.ancora then
				peca.parte:Destroy()
			else
				TweenService:Create(peca.parte, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(v.visual, 0.6)
	end)
end

local function morteDeModelo3D(v)
	if not v.chefe then
		morteDeLacaio3D(v)
		return
	end
	local cor = v.rig.corAura or BRANCO
	local corpo = v.ossos.corpo
	local inicio = os.clock()
	local queda = 2.4
	local mundo0 = corpo.mundo
	local centro = v.ancoraCorpo and v.ancoraCorpo.Position or v.ultimaPos
	local chao = v.ultimaPos - Vector3.new(0, v.alturaRaiz, 0)
	local fx = v.escalaFx
	for _, parar in v.efeitosAtivos or {} do
		parar()
	end
	v.efeitosAtivos = {}
	Sons.tocar("supremo", { pos = centro, tom = 0.45, volume = 1.3, alcance = 300 })
	Vfx.prefab("RugidoRei", CFrame.new(centro), nil, 0.3 * fx)
	task.spawn(function()
		local proximaAlma = 0
		while true do
			local t = os.clock() - inicio
			if t >= queda then
				break
			end
			local s = t / queda
			-- cambaleia e cai de joelhos para a frente
			local tremor = math.sin(t * 38) * 0.025 * (1 - s)
			local cf = mundo0 * CFrame.new(0, -s * s * 4.5 * v.escala, -s * 1.5 * v.escala) * CFrame.Angles(-0.38 * s * s + tremor, 0, math.sin(t * 6) * 0.05 * (1 - s))
			local partes, cframes = {}, {}
			for _, peca in v.pecas do
				if peca.parte.Parent then
					table.insert(partes, peca.parte)
					table.insert(cframes, cf * peca.local_)
				end
			end
			workspace:BulkMoveTo(partes, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			if t >= proximaAlma then
				-- almas estourando pelo corpo
				proximaAlma = t + 0.22
				local ponto = (cf * CFrame.new((math.random() - 0.5) * 8 * v.escala, math.random() * 8 * v.escala, -1.5 * v.escala)).Position
				Vfx.prefab("ImpactoFlecha", CFrame.new(ponto), nil, 1.2 + s)
				Vfx.tremerEm(ponto, 0.6 + s * 1.5, 0.2)
			end
			task.wait()
		end
		-- final: raio verde do céu, explosão de luz, a tumba racha e a onda de choque
		Vfx.prefab("JulgamentoRaio", CFrame.new(chao + Vector3.new(0, 12, 0)), nil, 0.9 * fx, { cor = cor, inteiro = true })
		Vfx.prefab("Julgamento", CFrame.new(chao), nil, 0.55 * fx, { cor = cor })
		Vfx.prefab("SaltoRei", CFrame.new(chao + Vector3.new(0, 0.2, 0)), nil, 0.9 * fx)
		Vfx.prefab("TumuloRei", CFrame.new(chao), nil, fx)
		Vfx.prefab("RugidoRei", CFrame.new(centro), nil, 0.35 * fx)
		Sons.tocar("trovao", { pos = centro, tom = 0.7, volume = 1.2, alcance = 300 })
		Vfx.tremerEm(centro, 4, 0.9)
		for _, peca in v.pecas do
			if peca.ancora then
				peca.parte:Destroy()
			else
				TweenService:Create(peca.parte, TweenInfo.new(0.9), { Transparency = 1 }):Play()
			end
		end
		if v.destaque then
			v.destaque.FillColor = cor
			v.destaque.FillTransparency = 0.4
			TweenService:Create(v.destaque, TweenInfo.new(0.9), { FillTransparency = 1 }):Play()
		end
		Debris:AddItem(v.visual, 1.1)
	end)
end

local function morrer(v)
	for _, conexao in v.conexoes do
		conexao:Disconnect()
	end
	if v.rig.malhas and v.destaque then
		if v.placa then
			v.placa:Destroy()
		end
		if v.estrelas then
			for _, estrela in v.estrelas do
				estrela:Destroy()
			end
		end
		if v.bolha then
			v.bolha:Destroy()
		end
		morteDeModelo3D(v)
		return
	end
	if v.placa then
		v.placa:Destroy()
	end
	if v.estrelas then
		for _, estrela in v.estrelas do
			estrela:Destroy()
		end
	end
	local centro = v.ultimaPos
	Vfx.estouro(centro, v.rig.cor or BRANCO, if v.chefe then 60 else 18, if v.chefe then 40 else 18)
	if v.chefe then
		Vfx.tremerEm(centro, 3, 0.8)
		if v.rig.entrada then
			-- o rei cai com um último rugido e o chão racha de novo
			Vfx.prefab(v.rig.entrada.rugido, CFrame.new(centro), nil, 0.3 * v.escalaFx)
			Vfx.prefab(v.rig.entrada.tumulo, CFrame.new(centro - Vector3.new(0, v.alturaRaiz, 0)), nil, v.escalaFx)
		end
	end
	for _, peca in v.pecas do
		local parte = peca.parte
		if peca.ancora then
			parte:Destroy()
		else
			parte.Anchored = false
			parte.CanCollide = true
			local fora = parte.Position - centro
			fora = if fora.Magnitude > 0.1 then fora.Unit else Vector3.new(0, 1, 0)
			parte.AssemblyLinearVelocity = fora * math.random(10, 24) + Vector3.new(0, math.random(14, 28), 0)
			parte.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
			task.delay(0.6 + math.random() * 0.3, function()
				if parte.Parent then
					TweenService:Create(parte, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end
			end)
		end
	end
	Debris:AddItem(v.visual, 1.6)
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

-- Efeito de salto vindo do servidor: o modelo voa num arco até o destino
function VisualInimigos.salto(dados)
	local v = visuais[dados.modelo]
	if v then
		local distancia = (dados.para - dados.de).Magnitude
		v.salto = {
			inicio = os.clock(),
			de = dados.de,
			para = dados.para,
			duracao = dados.duracao,
			altura = math.max(6, distancia * 0.35),
		}
	end
end

local function adicionar(modelo: Instance)
	if not modelo:IsA("Model") or visuais[modelo] then
		return
	end
	task.spawn(function()
		local v = criarVisual(modelo)
		if not v then
			return
		end
		if not modelo.Parent then
			v.visual:Destroy()
			return
		end
		visuais[modelo] = v
		atualizarVida(v)
		atualizarAcao(v)
		atualizarEstados(v)
		table.insert(v.conexoes, modelo:GetAttributeChangedSignal("Vida"):Connect(function()
			atualizarVida(v)
		end))
		table.insert(v.conexoes, modelo:GetAttributeChangedSignal("Acao"):Connect(function()
			atualizarAcao(v)
		end))
		for _, atributo in { "Queimando", "Lento", "Atordoado", "Furioso", "Sangrando", "Escudo", "Inspirado", "Grogue" } do
			table.insert(v.conexoes, modelo:GetAttributeChangedSignal(atributo):Connect(function()
				atualizarEstados(v)
			end))
		end
	end)
end

local function remover(modelo: Instance)
	Vfx.cancelarAvisos(modelo)
	local v = visuais[modelo]
	if v then
		visuais[modelo] = nil
		morrer(v)
	end
end

function VisualInimigos.iniciar()
	for _, modelo in CollectionService:GetTagged("Inimigo") do
		adicionar(modelo)
	end
	CollectionService:GetInstanceAddedSignal("Inimigo"):Connect(adicionar)
	CollectionService:GetInstanceRemovedSignal("Inimigo"):Connect(remover)

	RunService.RenderStepped:Connect(function(dt)
		local agora = os.clock()
		local partes, cframes = {}, {}
		for modelo, v in visuais do
			if v.raiz.Parent then
				atualizarVisual(v, dt, agora, partes, cframes)
			else
				remover(modelo)
			end
		end
		if #partes > 0 then
			workspace:BulkMoveTo(partes, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return VisualInimigos
