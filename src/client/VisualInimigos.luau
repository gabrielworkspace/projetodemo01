-- Dá vida aos inimigos no computador do jogador: monta o modelo (Modelos.luau), anima
-- (andar, preparar golpe, golpear, conjurar, pular...), mostra barra de vida, piscar ao levar
-- dano, fogo, gelo, atordoamento, aura de elite e a explosão de peças na morte.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Modelos = require(script.Parent.Modelos)
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
	v.placa = placa
	v.barra = barra
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
		})
	end

	for _, definicao in rig.pecas do
		local parte, malha = construirPeca(definicao, escala)
		local cf = CFrame.new(definicao.cf.Position * escala) * definicao.cf.Rotation
		adicionar(parte, definicao.osso, cf, { malha = malha, olho = definicao.olho, geleia = definicao.geleia })
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
	}

	if not v.chefe then
		criarBarra(v)
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
		v.impacto = 1
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
	v.acao = string.match(texto, "^([^|]*)") or ""
	v.acaoInicio = os.clock()
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

	local atordoado = modelo:GetAttribute("Atordoado") == true
	if atordoado and not v.estrelas then
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
		for _, peca in v.pecas do
			if peca.olho then
				peca.corBase = Color3.fromRGB(255, 40, 40)
				peca.parte.Color = peca.corBase
			end
		end
		emissor(ancora, Color3.fromRGB(255, 60, 40), { Rate = 30, Speed = NumberRange.new(3, 6), Acceleration = Vector3.new(0, 6, 0), Size = sequencia({ { 0, 0.8 * v.escala }, { 1, 0 } }) })
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

local POSES = {
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
	if (v.acao == "golpe" or v.acao == "disparo" or v.acao == "giro") and v.acaoT > 1.2 then
		v.acao = ""
	end
	v.atordoado = v.estrelas ~= nil
	v.impacto = math.max(0, v.impacto - dt * 6)

	local base = raizCF * CFrame.new(0, -v.alturaRaiz, 0)
	if v.salto then
		local s = (agora - v.salto.inicio) / v.salto.duracao
		if s >= 1 then
			v.salto = nil
		else
			local p = v.salto.de:Lerp(v.salto.para, s) + Vector3.new(0, v.salto.altura * 4 * s * (1 - s), 0)
			base = CFrame.new(p - Vector3.new(0, v.alturaRaiz, 0)) * raizCF.Rotation
		end
	end
	local idade = agora - v.nascimento
	if idade < 0.4 then
		base *= CFrame.new(0, -(1 - idade / 0.4) * 3 * v.escala, 0)
	end

	local alvos = {}
	local pose = POSES[v.rig.estilo] or poseBipede
	pose(v, agora, andar, alvos)

	for _, nome in v.ordem do
		local o = v.ossos[nome]
		local alvo = alvos[nome] or ZERO
		if alvo.direto then
			o.rx, o.ry, o.rz = alvo.rx or 0, alvo.ry or 0, alvo.rz or 0
		else
			local k = math.min(1, dt * (if alvo.rapido then 30 else 12))
			o.rx += ((alvo.rx or 0) - o.rx) * k
			o.ry += ((alvo.ry or 0) - o.ry) * k
			o.rz += ((alvo.rz or 0) - o.rz) * k
		end
		local k = math.min(1, dt * (if alvo.rapido then 30 else 12))
		o.ox += ((alvo.ox or 0) - o.ox) * k
		o.oy += ((alvo.oy or 0) - o.oy) * k
		o.oz += ((alvo.oz or 0) - o.oz) * k
		local paiCF = if o.pai == "raiz" then base else v.ossos[o.pai].mundo
		o.mundo = paiCF * o.relativo * CFrame.new(o.ox, o.oy, o.oz) * CFrame.Angles(o.rx, o.ry, o.rz)
	end

	-- Piscar branco ao levar dano
	if agora < v.flashAte and not v.flashAtivo then
		v.flashAtivo = true
		for _, peca in v.pecas do
			if not peca.ancora then
				peca.parte.Color = BRANCO
			end
		end
	elseif v.flashAtivo and agora >= v.flashAte then
		v.flashAtivo = false
		for _, peca in v.pecas do
			peca.parte.Color = peca.corBase
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
		local centro = cabeca.mundo.Position + Vector3.new(0, 2.2 * v.escala, 0)
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

local function morrer(v)
	for _, conexao in v.conexoes do
		conexao:Disconnect()
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
		for _, atributo in { "Queimando", "Lento", "Atordoado", "Furioso" } do
			table.insert(v.conexoes, modelo:GetAttributeChangedSignal(atributo):Connect(function()
				atualizarEstados(v)
			end))
		end
	end)
end

local function remover(modelo: Instance)
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
