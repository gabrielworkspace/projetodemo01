-- Gera as salas da masmorra por código. Cada sala é sorteada na hora: tamanho, pilares,
-- lava e decoração mudam a cada partida, e o visual muda conforme o tema do andar.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Masmorra = {}

local ALTURA_PAREDE = 24
local LARGURA_PORTA = 10
local ALTURA_PORTA = 13
local TAMANHO_LAJOTA = 10
local EM_PE = CFrame.Angles(0, 0, math.rad(90)) -- deixa um cilindro em pé (ou deitado como disco)

local function planar(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function escurecer(cor: Color3, quanto: number): Color3
	return cor:Lerp(Color3.new(0, 0, 0), quanto)
end

local function variar(cor: Color3, rng: Random, quanto: number): Color3
	local fator = 1 + rng:NextNumber(-quanto, quanto)
	return Color3.new(math.clamp(cor.R * fator, 0, 1), math.clamp(cor.G * fator, 0, 1), math.clamp(cor.B * fator, 0, 1))
end

-- opcoes: formato, colide (padrão true), transparencia, sombra (padrão true)
local function parte(pai: Instance, nome: string, tamanho: Vector3, cframe: CFrame, material: Enum.Material, cor: Color3, opcoes): Part
	opcoes = opcoes or {}
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.Shape = opcoes.formato or Enum.PartType.Block
	p.Size = tamanho
	p.CFrame = cframe
	p.Material = material
	p.Color = cor
	p.Transparency = opcoes.transparencia or 0
	p.CanCollide = opcoes.colide ~= false
	p.CastShadow = opcoes.sombra ~= false
	if opcoes.colide == false then
		p.CanQuery = false
		p.CanTouch = false
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = pai
	return p
end

local function ponta(pai: Instance, nome: string, tamanho: Vector3, cframe: CFrame, material: Enum.Material, cor: Color3): CornerWedgePart
	local w = Instance.new("CornerWedgePart")
	w.Name = nome
	w.Anchored = true
	w.Size = tamanho
	w.CFrame = cframe
	w.Material = material
	w.Color = cor
	w.CanCollide = false
	w.CanQuery = false
	w.Parent = pai
	return w
end

local function luz(pai: Instance, cor: Color3, alcance: number, brilho: number, tremula: boolean?)
	local l = Instance.new("PointLight")
	l.Color = cor
	l.Range = alcance
	l.Brightness = brilho
	l.Parent = pai
	if tremula then
		CollectionService:AddTag(l, "Chama") -- os jogadores fazem a luz tremular
	end
	return l
end

local function sequencia(pontos): NumberSequence
	local chaves = {}
	for _, ponto in pontos do
		table.insert(chaves, NumberSequenceKeypoint.new(ponto[1], ponto[2]))
	end
	return NumberSequence.new(chaves)
end

-- Efeito do pacote de VFX (ReplicatedStorage > EfeitosVFX) preso numa peça e ligado direto,
-- como no lobby (Lobby.luau). Devolve nil se o efeito não existe.
local function efeitoPronto(nome: string, pai: BasePart, escala: number, deslocamento: CFrame?): Attachment?
	local efeitos = ReplicatedStorage:FindFirstChild("EfeitosVFX")
	local molde = efeitos and efeitos:FindFirstChild(nome)
	if not molde then
		return nil
	end
	local anexo = Instance.new("Attachment")
	anexo.Name = "Efeito" .. nome
	anexo.CFrame = deslocamento or CFrame.identity
	anexo.Parent = pai
	for _, original in molde:GetDescendants() do
		if original:IsA("ParticleEmitter") then
			local emissor = original:Clone()
			if escala ~= 1 then
				local chaves = {}
				for _, chave in emissor.Size.Keypoints do
					table.insert(chaves, NumberSequenceKeypoint.new(chave.Time, chave.Value * escala, chave.Envelope * escala))
				end
				emissor.Size = NumberSequence.new(chaves)
				emissor.Speed = NumberRange.new(emissor.Speed.Min * escala, emissor.Speed.Max * escala)
			end
			emissor.Enabled = true
			emissor.Parent = anexo
		end
	end
	return anexo
end

-- Fogo das tochas e braseiros: as chamas do pacote de VFX (LaminaFogo). Sem o pacote, usa a
-- chama clássica do Roblox com faíscas subindo.
local function fogo(pai: BasePart, cor: Color3, tamanho: number)
	if efeitoPronto("LaminaFogo", pai, tamanho * 0.3, CFrame.new(0, 0.2, 0)) then
		return
	end
	local f = Instance.new("Fire")
	f.Size = tamanho
	f.Heat = tamanho * 2
	f.Color = cor
	f.SecondaryColor = Color3.fromRGB(255, 60, 10)
	f.Parent = pai

	local e = Instance.new("ParticleEmitter")
	e.Name = "Faiscas"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 230, 160), cor)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = sequencia({ { 0, 0.18 * tamanho / 2 }, { 1, 0 } })
	e.Transparency = sequencia({ { 0, 0 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, 4, 0)
	e.Drag = 1
	e.Rate = 6 * tamanho
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = pai
end

------------------------------------------------------------------------
-- Posições livres
------------------------------------------------------------------------

-- Caminho da entrada até a porta (nada que atrapalhe é colocado ali)
local function noCaminho(sala, pos: Vector3, folga: number): boolean
	local local_ = pos - sala.origem
	local meiaC = sala.comprimento / 2
	local pertoDaEntrada = (planar(local_) - Vector3.new(0, 0, -meiaC + 7)).Magnitude < 12 + folga
	local pertoDaPorta = math.abs(local_.X) < 8 + folga and local_.Z > meiaC - 14 - folga
	return pertoDaEntrada or pertoDaPorta
end

-- Limites (coordenadas locais) de onde os inimigos podem ficar: a câmara trancada no momento
-- ou a sala inteira
function Masmorra.limites(sala): (number, number, number, number)
	local c = sala.camaraAtiva
	if c then
		return c.x0, c.x1, c.z0, c.z1
	end
	return -sala.largura / 2, sala.largura / 2, -sala.comprimento / 2, sala.comprimento / 2
end

-- Bate em parede interna ou rocha maciça (para projéteis)
function Masmorra.bloqueado(sala, pos: Vector3): boolean
	for _, b in sala.blocos do
		local d = pos - b.centro
		if math.abs(d.X) < b.meio.X and math.abs(d.Z) < b.meio.Z then
			return true
		end
	end
	return false
end

function Masmorra.posicaoValida(sala, pos: Vector3, raio: number): boolean
	local local_ = pos - sala.origem
	local x0, x1, z0, z1 = Masmorra.limites(sala)
	if local_.X < x0 + raio or local_.X > x1 - raio or local_.Z < z0 + raio or local_.Z > z1 - raio then
		return false
	end
	for _, lista in { sala.blocos, sala.reservas } do
		for _, b in lista do
			local d = pos - b.centro
			if math.abs(d.X) < b.meio.X + raio and math.abs(d.Z) < b.meio.Z + raio then
				return false
			end
		end
	end
	for _, pilar in sala.pilares do
		if planar(pos - pilar.pos).Magnitude < pilar.raio + raio then
			return false
		end
	end
	for _, perigo in sala.perigos do
		local d = pos - perigo.centro
		if math.abs(d.X) < perigo.meio.X + raio and math.abs(d.Z) < perigo.meio.Z + raio then
			return false
		end
	end
	return true
end

local function posicaoLivre(sala, rng: Random, raio: number, evitarCaminho: boolean): Vector3?
	local x0, x1, z0, z1 = Masmorra.limites(sala)
	for _ = 1, 40 do
		local x = rng:NextNumber(x0 + raio + 2, x1 - raio - 2)
		local z = rng:NextNumber(z0 + raio + 2, z1 - raio - 2)
		local pos = sala.origem + Vector3.new(x, 0, z)
		if Masmorra.posicaoValida(sala, pos, raio) and not (evitarCaminho and noCaminho(sala, pos, raio)) then
			return pos
		end
	end
	return nil
end

function Masmorra.pontoLivre(sala, rng: Random, raio: number): Vector3?
	return posicaoLivre(sala, rng, raio, false)
end

-- Ponto encostado numa parede (para decoração), com a direção "para dentro" da sala
local function pontoNaParede(sala, rng: Random, recuo: number): (Vector3, Vector3)
	local meiaL, meiaC = sala.largura / 2, sala.comprimento / 2
	local lado = rng:NextInteger(1, 3) -- 1 esquerda, 2 direita, 3 fundo
	if lado == 1 then
		return sala.origem + Vector3.new(-meiaL + recuo, 0, rng:NextNumber(-meiaC + 14, meiaC - 6)), Vector3.new(1, 0, 0)
	elseif lado == 2 then
		return sala.origem + Vector3.new(meiaL - recuo, 0, rng:NextNumber(-meiaC + 14, meiaC - 6)), Vector3.new(-1, 0, 0)
	end
	local x = rng:NextNumber(meiaL * 0.35, meiaL - 6) * (if rng:NextNumber() < 0.5 then -1 else 1)
	return sala.origem + Vector3.new(x, 0, -meiaC + recuo), Vector3.new(0, 0, 1)
end

-- Registra um objeto como obstáculo (inimigos desviam e projéteis batem nele)
local function obstaculo(sala, pos: Vector3, raio: number)
	table.insert(sala.pilares, { pos = pos, raio = raio })
end

------------------------------------------------------------------------
-- Partes da sala
------------------------------------------------------------------------

local function criarChao(sala, rng: Random)
	local origem, tema, modelo = sala.origem, sala.tema, sala.modelo
	parte(modelo, "Base", Vector3.new(sala.largura + 4, 2, sala.comprimento + 4), CFrame.new(origem + Vector3.new(0, -1.2, 0)), tema.detalhe.material, escurecer(tema.detalhe.cor, 0.35))
	-- Lajotas com pequenas variações de cor (as frestas mostram a base mais escura)
	local colunas = math.ceil(sala.largura / TAMANHO_LAJOTA)
	local linhas = math.ceil(sala.comprimento / TAMANHO_LAJOTA)
	local larguraLajota = sala.largura / colunas
	local comprimentoLajota = sala.comprimento / linhas
	for i = 0, colunas - 1 do
		for j = 0, linhas - 1 do
			local x = -sala.largura / 2 + (i + 0.5) * larguraLajota
			local z = -sala.comprimento / 2 + (j + 0.5) * comprimentoLajota
			local especial = rng:NextNumber() < 0.08
			parte(
				modelo,
				"Lajota",
				Vector3.new(larguraLajota - 0.3, 0.6, comprimentoLajota - 0.3),
				CFrame.new(origem + Vector3.new(x, -0.3, z)),
				if especial then tema.detalhe.material else tema.chao.material,
				variar(if especial then tema.detalhe.cor else tema.chao.cor, rng, 0.09),
				{ sombra = false }
			)
		end
	end
end

local function criarArandela(sala, pos: Vector3, paraDentro: Vector3)
	local tema, modelo = sala.tema, sala.modelo
	local base = CFrame.lookAt(pos, pos + paraDentro)
	parte(modelo, "Suporte", Vector3.new(0.5, 0.5, 1.6), base * CFrame.new(0, 0, -0.6), Enum.Material.Metal, Color3.fromRGB(45, 40, 40), { colide = false })
	local tigela = parte(modelo, "Tigela", Vector3.new(0.7, 1.2, 1.2), base * CFrame.new(0, 0.2, -1.4) * EM_PE, Enum.Material.Metal, Color3.fromRGB(60, 52, 48), { formato = Enum.PartType.Cylinder, colide = false })
	local chama = parte(modelo, "Chama", Vector3.new(0.6, 0.6, 0.6), tigela.CFrame * CFrame.new(0.6, 0, 0), Enum.Material.Neon, tema.luz, { colide = false, sombra = false })
	fogo(chama, tema.luz, 2.2)
	luz(chama, tema.luz, 22, 1.7, true)
end

local function criarBraseiro(sala, pos: Vector3, escala: number)
	local tema, modelo = sala.tema, sala.modelo
	parte(modelo, "PeBraseiro", Vector3.new(3 * escala, 1.4 * escala, 1.4 * escala), CFrame.new(pos + Vector3.new(0, 1.5 * escala, 0)) * EM_PE, tema.detalhe.material, tema.detalhe.cor, { formato = Enum.PartType.Cylinder })
	parte(modelo, "Base", Vector3.new(0.6 * escala, 2.4 * escala, 2.4 * escala), CFrame.new(pos + Vector3.new(0, 0.3 * escala, 0)) * EM_PE, tema.detalhe.material, escurecer(tema.detalhe.cor, 0.2), { formato = Enum.PartType.Cylinder })
	local tigela = parte(modelo, "Tigela", Vector3.new(1 * escala, 3 * escala, 3 * escala), CFrame.new(pos + Vector3.new(0, 3.3 * escala, 0)) * EM_PE, Enum.Material.Metal, Color3.fromRGB(55, 48, 44), { formato = Enum.PartType.Cylinder })
	local brasa = parte(modelo, "Brasa", Vector3.new(0.3, 2.4 * escala, 2.4 * escala), tigela.CFrame * CFrame.new(0.5 * escala, 0, 0), Enum.Material.Neon, tema.luz, { formato = Enum.PartType.Cylinder, colide = false })
	fogo(brasa, tema.luz, 4 * escala)
	luz(brasa, tema.luz, 30 * escala, 2, true)
	obstaculo(sala, pos, 1.6 * escala)
end

local function criarParedes(sala)
	local origem, tema, modelo = sala.origem, sala.tema, sala.modelo
	local meiaL, meiaC = sala.largura / 2, sala.comprimento / 2
	local y = ALTURA_PAREDE / 2
	local corParede, matParede = tema.parede.cor, tema.parede.material
	local corDetalhe, matDetalhe = tema.detalhe.cor, tema.detalhe.material

	local function parede(tamanho: Vector3, posicao: Vector3)
		parte(modelo, "Parede", tamanho, CFrame.new(origem + posicao), matParede, corParede)
	end

	parede(Vector3.new(2, ALTURA_PAREDE, sala.comprimento + 4), Vector3.new(-meiaL - 1, y, 0))
	parede(Vector3.new(2, ALTURA_PAREDE, sala.comprimento + 4), Vector3.new(meiaL + 1, y, 0))
	parede(Vector3.new(sala.largura + 4, ALTURA_PAREDE, 2), Vector3.new(0, y, -meiaC - 1))
	local segmento = (sala.largura + 4 - LARGURA_PORTA) / 2
	parede(Vector3.new(segmento, ALTURA_PAREDE, 2), Vector3.new(-(LARGURA_PORTA / 2 + segmento / 2), y, meiaC + 1))
	parede(Vector3.new(segmento, ALTURA_PAREDE, 2), Vector3.new(LARGURA_PORTA / 2 + segmento / 2, y, meiaC + 1))
	local alturaVerga = ALTURA_PAREDE - ALTURA_PORTA
	parede(Vector3.new(LARGURA_PORTA, alturaVerga, 2), Vector3.new(0, ALTURA_PORTA + alturaVerga / 2, meiaC + 1))

	-- Rodapé e cornija (dão volume às paredes)
	for _, info in {
		{ Vector3.new(1, 1.6, sala.comprimento), Vector3.new(-meiaL + 0.5, 0.8, 0) },
		{ Vector3.new(1, 1.6, sala.comprimento), Vector3.new(meiaL - 0.5, 0.8, 0) },
		{ Vector3.new(sala.largura, 1.6, 1), Vector3.new(0, 0.8, -meiaC + 0.5) },
	} do
		parte(modelo, "Rodape", info[1], CFrame.new(origem + info[2]), matDetalhe, corDetalhe)
		parte(modelo, "Cornija", info[1] + Vector3.new(0.6, -0.4, 0.6), CFrame.new(origem + info[2] + Vector3.new(0, ALTURA_PAREDE - 1.6, 0)), matDetalhe, corDetalhe, { colide = false })
	end

	-- Contrafortes ao longo das paredes laterais, com arandelas entre eles
	local passos = math.max(3, math.floor(sala.comprimento / 16))
	for i = 0, passos do
		local z = -meiaC + 4 + i * ((sala.comprimento - 8) / passos)
		for _, lado in { -1, 1 } do
			local x = lado * (meiaL - 1)
			parte(modelo, "Contraforte", Vector3.new(2.4, ALTURA_PAREDE, 2.4), CFrame.new(origem + Vector3.new(x, y, z)), matDetalhe, corDetalhe)
			parte(modelo, "Capitel", Vector3.new(3, 1, 3), CFrame.new(origem + Vector3.new(x, ALTURA_PAREDE - 3, z)), matDetalhe, escurecer(corDetalhe, 0.15), { colide = false })
			if i < passos and i % 2 == 0 and not Masmorra.bloqueado(sala, origem + Vector3.new(lado * (meiaL - 3), 0, z + (sala.comprimento - 8) / passos / 2)) then
				local zMeio = z + (sala.comprimento - 8) / passos / 2
				criarArandela(sala, origem + Vector3.new(lado * meiaL, 8, zMeio), Vector3.new(-lado, 0, 0))
			end
		end
	end

	-- Estandartes no fundo
	for _, x in { -meiaL / 2, meiaL / 2 } do
		local estandarte = parte(modelo, "Estandarte", Vector3.new(4.4, 9, 0.2), CFrame.new(origem + Vector3.new(x, 13, -meiaC + 0.2)), Enum.Material.Fabric, Color3.fromRGB(120, 24, 34), { colide = false })
		parte(modelo, "Barra", Vector3.new(5.2, 0.3, 0.3), estandarte.CFrame * CFrame.new(0, 4.6, 0), Enum.Material.Metal, Color3.fromRGB(200, 160, 70), { colide = false })
		parte(modelo, "Simbolo", Vector3.new(1.6, 1.6, 0.1), estandarte.CFrame * CFrame.new(0, 1, -0.12) * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Neon, tema.luz, { colide = false })
	end
end

local function criarPorta(sala)
	local origem, tema, modelo = sala.origem, sala.tema, sala.modelo
	local meiaC = sala.comprimento / 2
	local corDetalhe, matDetalhe = tema.detalhe.cor, tema.detalhe.material
	local zParede = meiaC + 1

	-- Moldura em arco
	for _, lado in { -1, 1 } do
		parte(modelo, "Umbral", Vector3.new(2.2, ALTURA_PORTA + 1, 3), CFrame.new(origem + Vector3.new(lado * (LARGURA_PORTA / 2 + 1), (ALTURA_PORTA + 1) / 2, zParede - 0.5)), matDetalhe, corDetalhe)
	end
	parte(modelo, "Arco", Vector3.new(LARGURA_PORTA + 4.4, 2.2, 3), CFrame.new(origem + Vector3.new(0, ALTURA_PORTA + 1.1, zParede - 0.5)), matDetalhe, corDetalhe)
	local runa = parte(modelo, "Runa", Vector3.new(1.4, 1.4, 0.3), CFrame.new(origem + Vector3.new(0, ALTURA_PORTA + 1.1, zParede - 2.05)) * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Neon, Color3.fromRGB(255, 70, 70), { colide = false })
	sala.runaPorta = runa

	-- Grade levadiça (sobe quando a sala é limpa)
	local grade = Instance.new("Model")
	grade.Name = "Grade"
	local corFerro = Color3.fromRGB(46, 44, 46)
	for i = 0, 5 do
		local x = -LARGURA_PORTA / 2 + 0.8 + i * ((LARGURA_PORTA - 1.6) / 5)
		parte(grade, "Barra", Vector3.new(0.5, ALTURA_PORTA, 0.5), CFrame.new(origem + Vector3.new(x, ALTURA_PORTA / 2, zParede)), Enum.Material.Metal, corFerro)
	end
	for _, h in { 3, 7, 11 } do
		parte(grade, "Travessa", Vector3.new(LARGURA_PORTA, 0.4, 0.4), CFrame.new(origem + Vector3.new(0, h, zParede)), Enum.Material.Metal, corFerro)
	end
	grade.Parent = modelo
	sala.grade = grade

	-- Gatilho invisível no vão (quem entra vai para a próxima sala)
	local gatilho = parte(modelo, "Porta", Vector3.new(LARGURA_PORTA, ALTURA_PORTA, 1.5), CFrame.new(origem + Vector3.new(0, ALTURA_PORTA / 2, zParede + 1.5)), Enum.Material.Neon, Color3.fromRGB(80, 255, 140), { colide = false, transparencia = 1 })
	gatilho.CanTouch = true
	sala.porta = gatilho

	-- Corredor com névoa atrás da porta
	parte(modelo, "Corredor", Vector3.new(LARGURA_PORTA + 4, 2, 14), CFrame.new(origem + Vector3.new(0, -1, meiaC + 9)), tema.chao.material, escurecer(tema.chao.cor, 0.3))
	parte(modelo, "ParedeCorredor", Vector3.new(2, ALTURA_PORTA + 2, 14), CFrame.new(origem + Vector3.new(-LARGURA_PORTA / 2 - 1, ALTURA_PORTA / 2, meiaC + 9)), tema.parede.material, tema.parede.cor)
	parte(modelo, "ParedeCorredor", Vector3.new(2, ALTURA_PORTA + 2, 14), CFrame.new(origem + Vector3.new(LARGURA_PORTA / 2 + 1, ALTURA_PORTA / 2, meiaC + 9)), tema.parede.material, tema.parede.cor)
	parte(modelo, "FundoCorredor", Vector3.new(LARGURA_PORTA + 4, ALTURA_PORTA + 2, 2), CFrame.new(origem + Vector3.new(0, ALTURA_PORTA / 2, meiaC + 17)), tema.parede.material, tema.parede.cor)
	local nevoa = parte(modelo, "Nevoa", Vector3.new(LARGURA_PORTA, 1, 10), CFrame.new(origem + Vector3.new(0, 0.6, meiaC + 9)), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), { colide = false, transparencia = 1 })
	local emissor = Instance.new("ParticleEmitter")
	emissor.Name = "Nevoa"
	emissor.Color = ColorSequence.new(tema.nevoa:Lerp(Color3.new(1, 1, 1), 0.3))
	emissor.Size = sequencia({ { 0, 3 }, { 1, 6 } })
	emissor.Transparency = sequencia({ { 0, 1 }, { 0.3, 0.75 }, { 1, 1 } })
	emissor.Lifetime = NumberRange.new(3, 5)
	emissor.Speed = NumberRange.new(0.3, 1)
	emissor.SpreadAngle = Vector2.new(180, 30)
	emissor.Rate = 8
	emissor.Shape = Enum.ParticleEmitterShape.Box
	emissor.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emissor.Parent = nevoa
	sala.luzPorta = luz(nevoa, Color3.fromRGB(255, 80, 80), 18, 1.2, false)
end

local function criarEntrada(sala)
	local origem, tema, modelo = sala.origem, sala.tema, sala.modelo
	local meiaC = sala.comprimento / 2
	local centro = origem + Vector3.new(0, 0.05, -meiaC + 7)
	-- Círculo de runas onde o grupo aparece (anel = disco brilhante + disco do chão por cima)
	parte(modelo, "Circulo", Vector3.new(0.12, 11, 11), CFrame.new(centro) * EM_PE, Enum.Material.Neon, tema.luz, { formato = Enum.PartType.Cylinder, colide = false, transparencia = 0.3, sombra = false })
	parte(modelo, "CirculoMiolo", Vector3.new(0.14, 10, 10), CFrame.new(centro + Vector3.new(0, 0.02, 0)) * EM_PE, tema.chao.material, escurecer(tema.chao.cor, 0.15), { formato = Enum.PartType.Cylinder, colide = false, sombra = false })
	parte(modelo, "PortaEntrada", Vector3.new(LARGURA_PORTA, ALTURA_PORTA, 0.6), CFrame.new(origem + Vector3.new(0, ALTURA_PORTA / 2, -meiaC + 0.1)), Enum.Material.WoodPlanks, Color3.fromRGB(70, 46, 30))
	for _, lado in { -1, 1 } do
		parte(modelo, "UmbralEntrada", Vector3.new(2, ALTURA_PORTA + 1, 1.6), CFrame.new(origem + Vector3.new(lado * (LARGURA_PORTA / 2 + 1), (ALTURA_PORTA + 1) / 2, -meiaC + 0.6)), tema.detalhe.material, tema.detalhe.cor)
	end
end

local function criarPilares(sala, rng: Random)
	local origem, tema, modelo = sala.origem, sala.tema, sala.modelo
	local posicoes = {}
	if sala.tipo == "chefe" then
		local dx, dz = sala.largura / 3, sala.comprimento / 3
		posicoes = {
			origem + Vector3.new(-dx, 0, -dz / 2),
			origem + Vector3.new(dx, 0, -dz / 2),
			origem + Vector3.new(-dx, 0, dz),
			origem + Vector3.new(dx, 0, dz),
			origem + Vector3.new(-dx * 1.15, 0, dz * 0.25),
			origem + Vector3.new(dx * 1.15, 0, dz * 0.25),
		}
	elseif sala.tipo == "combate" then
		-- mais pilares em salas maiores (cobertura contra disparos)
		-- (com câmaras, as paredes internas já dão cobertura: menos pilares)
		local area = sala.largura * sala.comprimento / 8000 * (if sala.camaras then 0.55 else 1)
		for _ = 1, math.floor(rng:NextInteger(3, 6) * area + 0.5) do
			local pos = posicaoLivre(sala, rng, 9, true)
			if pos then
				table.insert(posicoes, pos)
				-- reserva o espaço para o próximo pilar não ficar colado neste
				table.insert(sala.pilares, { pos = pos, raio = 5 })
			end
		end
		table.clear(sala.pilares)
	end

	for _, pos in posicoes do
		local diametro = rng:NextInteger(4, 6)
		parte(modelo, "Pilar", Vector3.new(ALTURA_PAREDE, diametro, diametro), CFrame.new(pos + Vector3.new(0, ALTURA_PAREDE / 2, 0)) * EM_PE, tema.parede.material, tema.parede.cor, { formato = Enum.PartType.Cylinder })
		parte(modelo, "BasePilar", Vector3.new(diametro + 1.6, 1.6, diametro + 1.6), CFrame.new(pos + Vector3.new(0, 0.8, 0)), tema.detalhe.material, tema.detalhe.cor)
		parte(modelo, "AnelPilar", Vector3.new(0.8, diametro + 0.6, diametro + 0.6), CFrame.new(pos + Vector3.new(0, 2.2, 0)) * EM_PE, tema.detalhe.material, escurecer(tema.detalhe.cor, 0.15), { formato = Enum.PartType.Cylinder })
		parte(modelo, "Capitel", Vector3.new(diametro + 1.4, 1.4, diametro + 1.4), CFrame.new(pos + Vector3.new(0, ALTURA_PAREDE - 2, 0)), tema.detalhe.material, tema.detalhe.cor, { colide = false })
		-- Runa brilhante no pilar
		parte(modelo, "RunaPilar", Vector3.new(0.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.new(diametro / 2, 0, 0) * CFrame.Angles(math.rad(45), 0, 0), Enum.Material.Neon, tema.luz, { colide = false, sombra = false })
		table.insert(sala.pilares, { pos = pos, raio = diametro / 2 + 0.6 })
	end
end

local function criarLava(sala, rng: Random)
	if sala.tipo ~= "combate" then
		return
	end
	if not (sala.tema.lava or (sala.numero >= 7 and rng:NextNumber() < 0.35)) then
		return
	end
	for _ = 1, rng:NextInteger(2, 4) do
		local tamanho = Vector3.new(rng:NextInteger(8, 16), 0.4, rng:NextInteger(8, 16))
		local pos = posicaoLivre(sala, rng, math.max(tamanho.X, tamanho.Z) / 2 + 2, true)
		if pos then
			parte(sala.modelo, "Borda", tamanho + Vector3.new(1.6, 0.3, 1.6), CFrame.new(pos + Vector3.new(0, 0.1, 0)), Enum.Material.Basalt, Color3.fromRGB(35, 28, 28), { colide = false })
			local lava = parte(sala.modelo, "Lava", tamanho, CFrame.new(pos + Vector3.new(0, 0.2, 0)), Enum.Material.Neon, Color3.fromRGB(255, 96, 24), { colide = false, sombra = false })
			luz(lava, Color3.fromRGB(255, 110, 40), 18, 1.6, true)
			local brasas = Instance.new("ParticleEmitter")
			brasas.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20))
			brasas.LightEmission = 1
			brasas.Size = sequencia({ { 0, 0.3 }, { 1, 0 } })
			brasas.Lifetime = NumberRange.new(1, 2)
			brasas.Speed = NumberRange.new(2, 5)
			brasas.SpreadAngle = Vector2.new(20, 20)
			brasas.Rate = 10
			brasas.EmissionDirection = Enum.NormalId.Top
			brasas.Shape = Enum.ParticleEmitterShape.Box
			brasas.Parent = lava
			table.insert(sala.perigos, { centro = pos, meio = Vector3.new(tamanho.X / 2, 0, tamanho.Z / 2) })
		end
	end
end

-- Decoração própria de cada tema, encostada nas paredes
local function criarDecoracao(sala, rng: Random)
	local tema, modelo = sala.tema, sala.modelo
	local area = sala.largura * sala.comprimento / 7000
	local quantidade = math.floor(rng:NextInteger(6, 10) * math.max(1, area) + 0.5)
	for _ = 1, quantidade do
		local pos, dentro = pontoNaParede(sala, rng, 3)
		local giro = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		if not Masmorra.posicaoValida(sala, pos, 2) then
			continue -- (sala com câmaras) dentro da rocha ou na frente de um portão
		end
		if tema.id == "calabouco" then
			if rng:NextNumber() < 0.5 then
				local barril = parte(modelo, "Barril", Vector3.new(3, 2.2, 2.2), CFrame.new(pos + Vector3.new(0, 1.5, 0)) * EM_PE, Enum.Material.WoodPlanks, Color3.fromRGB(110, 72, 44), { formato = Enum.PartType.Cylinder })
				for _, h in { -0.9, 0.9 } do
					parte(modelo, "Aro", Vector3.new(0.2, 2.3, 2.3), barril.CFrame * CFrame.new(h, 0, 0), Enum.Material.Metal, Color3.fromRGB(60, 56, 56), { formato = Enum.PartType.Cylinder, colide = false })
				end
				obstaculo(sala, pos, 1.3)
			else
				local tamanho = rng:NextNumber(2.2, 3.2)
				parte(modelo, "Caixote", Vector3.one * tamanho, CFrame.new(pos + Vector3.new(0, tamanho / 2, 0)) * giro, Enum.Material.WoodPlanks, Color3.fromRGB(125, 88, 52))
				if rng:NextNumber() < 0.5 then
					parte(modelo, "Caixote", Vector3.one * tamanho * 0.7, CFrame.new(pos + Vector3.new(0, tamanho + tamanho * 0.35, 0)) * giro * CFrame.Angles(0, 0.4, 0), Enum.Material.WoodPlanks, Color3.fromRGB(110, 76, 46))
				end
				obstaculo(sala, pos, tamanho * 0.7)
			end
			-- Crânio no chão
			parte(modelo, "Cranio", Vector3.one * 0.8, CFrame.new(pos + dentro * 2.5 + Vector3.new(0, 0.4, 0)), Enum.Material.SmoothPlastic, Color3.fromRGB(225, 218, 196), { formato = Enum.PartType.Ball, colide = false })
		elseif tema.id == "caverna" then
			if rng:NextNumber() < 0.6 then
				-- Cogumelos brilhantes
				for k = 1, rng:NextInteger(2, 4) do
					local p = pos + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
					local altura = rng:NextNumber(1.2, 3.5)
					parte(modelo, "Caule", Vector3.new(altura, 0.5, 0.5), CFrame.new(p + Vector3.new(0, altura / 2, 0)) * EM_PE, Enum.Material.SmoothPlastic, Color3.fromRGB(220, 215, 190), { formato = Enum.PartType.Cylinder, colide = false })
					local chapeu = parte(modelo, "Chapeu", Vector3.new(0.6, altura * 0.9 + 0.6, altura * 0.9 + 0.6), CFrame.new(p + Vector3.new(0, altura + 0.2, 0)) * EM_PE, Enum.Material.Neon, if k % 2 == 0 then Color3.fromRGB(90, 255, 180) else Color3.fromRGB(140, 120, 255), { formato = Enum.PartType.Cylinder, colide = false })
					if k == 1 then
						luz(chapeu, chapeu.Color, 10, 1, false)
					end
				end
			else
				-- Estalagmite
				local altura = rng:NextNumber(5, 9)
				for k = 0, 2 do
					local h = altura * (1 - k * 0.3)
					parte(modelo, "Estalagmite", Vector3.new(h, 2.6 - k * 0.7, 2.6 - k * 0.7), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * EM_PE, tema.parede.material, escurecer(tema.parede.cor, k * 0.08), { formato = Enum.PartType.Cylinder })
				end
				obstaculo(sala, pos, 1.4)
			end
		elseif tema.id == "cripta" then
			if rng:NextNumber() < 0.55 then
				-- Lápide
				local lapide = CFrame.lookAt(pos, pos + dentro)
				parte(modelo, "Lapide", Vector3.new(2.4, 3, 0.6), lapide * CFrame.new(0, 1.5, 0), Enum.Material.Slate, Color3.fromRGB(120, 125, 140))
				parte(modelo, "TopoLapide", Vector3.new(0.6, 2.4, 2.4), lapide * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(90), 0), Enum.Material.Slate, Color3.fromRGB(120, 125, 140), { formato = Enum.PartType.Cylinder, colide = false })
				local vela = parte(modelo, "Vela", Vector3.new(0.3, 0.8, 0.3), lapide * CFrame.new(0.8, 0.4, -1), Enum.Material.SmoothPlastic, Color3.fromRGB(230, 230, 240), { colide = false })
				local chama = parte(modelo, "ChamaVela", Vector3.one * 0.25, vela.CFrame * CFrame.new(0, 0.55, 0), Enum.Material.Neon, Color3.fromRGB(140, 210, 255), { colide = false, sombra = false })
				luz(chama, Color3.fromRGB(140, 210, 255), 8, 1, true)
				obstaculo(sala, pos, 1.3)
			else
				-- Cristais de gelo
				for _ = 1, rng:NextInteger(2, 4) do
					local altura = rng:NextNumber(2, 6)
					local p = pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
					parte(modelo, "Cristal", Vector3.new(1, altura, 1), CFrame.new(p + Vector3.new(0, altura / 2 - 0.3, 0)) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 3), rng:NextNumber(-0.35, 0.35)), Enum.Material.Glass, Color3.fromRGB(160, 220, 255), { colide = false, transparencia = 0.25 })
				end
				local nucleo = parte(modelo, "Nucleo", Vector3.one * 0.6, CFrame.new(pos + Vector3.new(0, 1, 0)), Enum.Material.Neon, Color3.fromRGB(150, 220, 255), { colide = false, sombra = false })
				luz(nucleo, nucleo.Color, 10, 1, false)
			end
		else
			if rng:NextNumber() < 0.6 then
				-- Espinhos de obsidiana
				for _ = 1, rng:NextInteger(2, 4) do
					local altura = rng:NextNumber(3, 7)
					local p = pos + Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))
					ponta(modelo, "Espinho", Vector3.new(1.4, altura, 1.4), CFrame.new(p + Vector3.new(0, altura / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), Enum.Material.Basalt, Color3.fromRGB(28, 22, 26))
				end
				obstaculo(sala, pos, 1.6)
			else
				-- Fenda de lava na parede
				local fenda = parte(modelo, "Fenda", Vector3.new(0.4, rng:NextNumber(4, 9), 1.2), CFrame.lookAt(pos - dentro * 2.3, pos) * CFrame.new(0, 3, 0), Enum.Material.Neon, Color3.fromRGB(255, 100, 30), { colide = false, sombra = false })
				luz(fenda, Color3.fromRGB(255, 110, 40), 14, 1.4, true)
			end
		end
	end
end

-- Partículas no ar da sala (poeira, esporos, neve ou brasas)
local function criarAtmosfera(sala)
	local tema = sala.tema
	local volume = parte(sala.modelo, "Atmosfera", Vector3.new(sala.largura - 4, 12, sala.comprimento - 4), CFrame.new(sala.origem + Vector3.new(0, 8, 0)), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), { colide = false, transparencia = 1, sombra = false })
	local e = Instance.new("ParticleEmitter")
	e.Name = "Ambiente"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.LightInfluence = 0
	local area = sala.largura * sala.comprimento / 6000
	if tema.particulas == "neve" then
		e.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
		e.Size = sequencia({ { 0, 0.25 }, { 1, 0.15 } })
		e.Transparency = sequencia({ { 0, 1 }, { 0.15, 0.2 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(5, 8)
		e.Speed = NumberRange.new(1, 2)
		e.Acceleration = Vector3.new(0.4, -1.5, 0)
		e.Rate = 50 * area
		e.LightEmission = 0.4
	elseif tema.particulas == "brasas" then
		e.Color = ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 70, 20))
		e.Size = sequencia({ { 0, 0.22 }, { 1, 0 } })
		e.Transparency = sequencia({ { 0, 0 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(3, 6)
		e.Speed = NumberRange.new(1, 3)
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Rate = 40 * area
		e.LightEmission = 1
	elseif tema.particulas == "esporos" then
		e.Color = ColorSequence.new(Color3.fromRGB(150, 255, 170), Color3.fromRGB(120, 200, 255))
		e.Size = sequencia({ { 0, 0 }, { 0.3, 0.25 }, { 1, 0 } })
		e.Transparency = NumberSequence.new(0.2)
		e.Lifetime = NumberRange.new(4, 7)
		e.Speed = NumberRange.new(0.2, 0.8)
		e.Acceleration = Vector3.new(0, 0.3, 0)
		e.Rate = 30 * area
		e.LightEmission = 1
	else
		e.Color = ColorSequence.new(Color3.fromRGB(220, 205, 185))
		e.Size = sequencia({ { 0, 0 }, { 0.3, 0.15 }, { 1, 0 } })
		e.Transparency = NumberSequence.new(0.45)
		e.Lifetime = NumberRange.new(5, 9)
		e.Speed = NumberRange.new(0.1, 0.5)
		e.Rate = 25 * area
		e.LightEmission = 0.3
	end
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = volume
end

local function criarSalaDoChefe(sala)
	local origem, tema, modelo = sala.origem, sala.tema, sala.modelo
	local meiaL, meiaC = sala.largura / 2, sala.comprimento / 2
	-- Círculo ritual no centro: escuro e discreto (vermelho forte parecia um aviso de golpe)
	local centro = origem + Vector3.new(0, 0.05, 6)
	local runa = Color3.fromRGB(60, 110, 70)
	parte(modelo, "Ritual", Vector3.new(0.12, 60, 60), CFrame.new(centro) * EM_PE, Enum.Material.Neon, runa, { formato = Enum.PartType.Cylinder, colide = false, transparencia = 0.8, sombra = false })
	parte(modelo, "RitualMiolo", Vector3.new(0.14, 58, 58), CFrame.new(centro + Vector3.new(0, 0.02, 0)) * EM_PE, tema.chao.material, escurecer(tema.chao.cor, 0.2), { formato = Enum.PartType.Cylinder, colide = false, sombra = false })
	parte(modelo, "RitualInterno", Vector3.new(0.12, 20, 20), CFrame.new(centro + Vector3.new(0, 0.04, 0)) * EM_PE, Enum.Material.Neon, runa, { formato = Enum.PartType.Cylinder, colide = false, transparencia = 0.8, sombra = false })
	parte(modelo, "RitualInternoMiolo", Vector3.new(0.14, 18.6, 18.6), CFrame.new(centro + Vector3.new(0, 0.06, 0)) * EM_PE, tema.chao.material, escurecer(tema.chao.cor, 0.25), { formato = Enum.PartType.Cylinder, colide = false, sombra = false })
	-- Trono no fundo
	local trono = origem + Vector3.new(0, 0, meiaC - 8)
	parte(modelo, "Degrau", Vector3.new(16, 1, 8), CFrame.new(trono + Vector3.new(0, 0.5, 0)), tema.detalhe.material, tema.detalhe.cor)
	parte(modelo, "Assento", Vector3.new(6, 3, 4), CFrame.new(trono + Vector3.new(0, 2.5, 0.5)), tema.detalhe.material, escurecer(tema.detalhe.cor, 0.1))
	parte(modelo, "Encosto", Vector3.new(6, 9, 1.4), CFrame.new(trono + Vector3.new(0, 6, 2.6)), tema.detalhe.material, escurecer(tema.detalhe.cor, 0.1))
	local gema = parte(modelo, "Gema", Vector3.one * 1.4, CFrame.new(trono + Vector3.new(0, 9.4, 1.8)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Enum.Material.Neon, Color3.fromRGB(255, 50, 60), { colide = false })
	luz(gema, gema.Color, 16, 2, false)
	obstaculo(sala, trono, 4)
	-- Braseiros grandes nos cantos
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			criarBraseiro(sala, origem + Vector3.new(x * (meiaL - 8), 0, z * (meiaC - 10)), 1.6)
		end
	end
end

local function criarBau(sala)
	local origem, tema, modelo = sala.origem, sala.tema, sala.modelo
	local madeira = Color3.fromRGB(120, 75, 40)
	local dourado = Color3.fromRGB(255, 200, 60)
	local centro = origem + Vector3.new(0, 0, 4)
	parte(modelo, "Estrado", Vector3.new(12, 1, 10), CFrame.new(centro + Vector3.new(0, 0.5, 0)), tema.detalhe.material, tema.detalhe.cor)
	local base = parte(modelo, "Bau", Vector3.new(5, 3, 3.5), CFrame.new(centro + Vector3.new(0, 2.5, 0)), Enum.Material.WoodPlanks, madeira)
	local tampa = parte(modelo, "Tampa", Vector3.new(5.2, 1.2, 3.7), CFrame.new(centro + Vector3.new(0, 4.6, 0)), Enum.Material.WoodPlanks, escurecer(madeira, 0.25))
	parte(modelo, "Faixa", Vector3.new(5.3, 0.4, 3.8), CFrame.new(centro + Vector3.new(0, 3.6, 0)), Enum.Material.Neon, dourado, { colide = false })
	for _, x in { -1.8, 1.8 } do
		parte(modelo, "Reforco", Vector3.new(0.35, 3.2, 3.8), CFrame.new(centro + Vector3.new(x, 2.6, 0)), Enum.Material.Metal, dourado)
	end
	-- Moedas espalhadas
	for _ = 1, 14 do
		local p = centro + Vector3.new(math.random(-5, 5), 1.15, math.random(-4, 4))
		parte(modelo, "Moeda", Vector3.new(0.15, 0.8, 0.8), CFrame.new(p) * EM_PE * CFrame.Angles(math.random() * 0.5, 0, 0), Enum.Material.Neon, dourado, { formato = Enum.PartType.Cylinder, colide = false, sombra = false })
	end
	-- Feixe de luz vindo de cima
	parte(modelo, "Feixe", Vector3.new(40, 7, 7), CFrame.new(centro + Vector3.new(0, 20, 0)) * EM_PE, Enum.Material.Neon, dourado, { formato = Enum.PartType.Cylinder, colide = false, transparencia = 0.88, sombra = false })
	luz(base, dourado, 24, 2.5, false)
	local brilho = Instance.new("ParticleEmitter")
	brilho.Color = ColorSequence.new(dourado)
	brilho.LightEmission = 1
	brilho.Size = sequencia({ { 0, 0 }, { 0.5, 0.4 }, { 1, 0 } })
	brilho.Lifetime = NumberRange.new(1, 2)
	brilho.Speed = NumberRange.new(1, 3)
	brilho.SpreadAngle = Vector2.new(60, 60)
	brilho.Rate = 12
	brilho.EmissionDirection = Enum.NormalId.Top
	brilho.Parent = base

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir"
	prompt.ObjectText = "Baú do Tesouro"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	sala.bau = base
	sala.tampaBau = tampa
	sala.promptBau = prompt
	obstaculo(sala, centro, 3)
end

------------------------------------------------------------------------
-- Câmaras: a sala grande é dividida em três fileiras de câmaras ligadas por portões. Uma
-- fileira pode ocupar a largura toda, ser estreita (rocha maciça dos lados) ou ter uma câmara
-- de desafio ao lado. Ao entrar numa câmara, os portões trancam e as ondas começam (Partida).
------------------------------------------------------------------------

local ESPESSURA_DIVISORIA = 3

-- Obstáculo sólido retangular (coordenadas locais): nada aparece ali e os projéteis batem
local function bloco(sala, x0: number, x1: number, z0: number, z1: number)
	table.insert(sala.blocos, {
		centro = sala.origem + Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2),
		meio = Vector3.new((x1 - x0) / 2, 0, (z1 - z0) / 2),
	})
end

-- Área que precisa ficar livre (vãos dos portões): nada é construído nem aparece ali
local function reservar(sala, centro: Vector3, meioX: number, meioZ: number)
	table.insert(sala.reservas, { centro = centro, meio = Vector3.new(meioX, 0, meioZ) })
end

-- Contraforte com tocha numa face de parede interna. "paraDentro" aponta para a câmara.
local function contraforteComTocha(sala, pos: Vector3, paraDentro: Vector3, tocha: boolean)
	local tema, modelo = sala.tema, sala.modelo
	local y = ALTURA_PAREDE / 2
	parte(modelo, "Contraforte", Vector3.new(2.4, ALTURA_PAREDE, 2.4), CFrame.new(pos + Vector3.new(0, y, 0)), tema.detalhe.material, tema.detalhe.cor)
	parte(modelo, "Capitel", Vector3.new(3, 1, 3), CFrame.new(pos + Vector3.new(0, ALTURA_PAREDE - 3, 0)), tema.detalhe.material, escurecer(tema.detalhe.cor, 0.15), { colide = false })
	if tocha then
		criarArandela(sala, pos + paraDentro * 1.2 + Vector3.new(0, 8, 0), paraDentro)
	end
end

-- Pedaço de parede interna entre (a) e (b) ao longo de um eixo; "aoLongoDeX" = a parede corre em X
local function segmentoDeParede(sala, aoLongoDeX: boolean, fixo: number, a: number, b: number, altura: number, base: number)
	if b - a < 0.2 then
		return
	end
	local tema, modelo = sala.tema, sala.modelo
	local meio = (a + b) / 2
	local tamanho = if aoLongoDeX then Vector3.new(b - a, altura, ESPESSURA_DIVISORIA) else Vector3.new(ESPESSURA_DIVISORIA, altura, b - a)
	local pos = if aoLongoDeX then Vector3.new(meio, base + altura / 2, fixo) else Vector3.new(fixo, base + altura / 2, meio)
	parte(modelo, "Divisoria", tamanho, CFrame.new(sala.origem + pos), tema.parede.material, tema.parede.cor)
	if base == 0 then
		local h = ESPESSURA_DIVISORIA / 2
		if aoLongoDeX then
			bloco(sala, a, b, fixo - h, fixo + h)
		else
			bloco(sala, fixo - h, fixo + h, a, b)
		end
		-- rodapé e cornija dos dois lados
		local faixa = if aoLongoDeX then Vector3.new(b - a, 1.6, ESPESSURA_DIVISORIA + 1) else Vector3.new(ESPESSURA_DIVISORIA + 1, 1.6, b - a)
		local centroFaixa = if aoLongoDeX then Vector3.new(meio, 0.8, fixo) else Vector3.new(fixo, 0.8, meio)
		parte(modelo, "Rodape", faixa, CFrame.new(sala.origem + centroFaixa), tema.detalhe.material, tema.detalhe.cor)
		parte(modelo, "Cornija", faixa + (if aoLongoDeX then Vector3.new(0, -0.4, 0.4) else Vector3.new(0.4, -0.4, 0)), CFrame.new(sala.origem + centroFaixa + Vector3.new(0, altura - 1.6, 0)), tema.detalhe.material, tema.detalhe.cor, { colide = false })
		-- contrafortes com tochas nas duas faces
		local passos = math.floor((b - a) / 18)
		for i = 1, passos do
			local t = a + i * (b - a) / (passos + 1)
			for _, lado in { -1, 1 } do
				local dentro = if aoLongoDeX then Vector3.new(0, 0, lado) else Vector3.new(lado, 0, 0)
				local p = sala.origem + (if aoLongoDeX then Vector3.new(t, 0, fixo) else Vector3.new(fixo, 0, t)) + dentro * (ESPESSURA_DIVISORIA / 2 + 1)
				contraforteComTocha(sala, p, dentro, i % 2 == 1)
			end
		end
	end
end

-- Portão levadiço com moldura de pedra num vão de parede (começa aberto)
local function criarPortao(sala, centro: Vector3, largura: number, aoLongoDeX: boolean)
	local tema, modelo = sala.tema, sala.modelo
	local corDetalhe, matDetalhe = tema.detalhe.cor, tema.detalhe.material
	local base = CFrame.new(centro) * (if aoLongoDeX then CFrame.identity else CFrame.Angles(0, math.rad(90), 0))
	for _, lado in { -1, 1 } do
		parte(modelo, "Umbral", Vector3.new(2.4, ALTURA_PORTA + 1, ESPESSURA_DIVISORIA + 1.2), base * CFrame.new(lado * (largura / 2 + 1.2), (ALTURA_PORTA + 1) / 2, 0), matDetalhe, corDetalhe)
	end
	parte(modelo, "Arco", Vector3.new(largura + 4.8, 2.2, ESPESSURA_DIVISORIA + 1.2), base * CFrame.new(0, ALTURA_PORTA + 1.1, 0), matDetalhe, corDetalhe)
	local runas = {}
	for _, lado in { -1, 1 } do
		local runa = parte(modelo, "Runa", Vector3.new(1.2, 1.2, 0.3), base * CFrame.new(0, ALTURA_PORTA + 1.1, lado * (ESPESSURA_DIVISORIA / 2 + 0.7)) * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Neon, Color3.fromRGB(90, 255, 150), { colide = false })
		table.insert(runas, runa)
	end
	local corFerro = Color3.fromRGB(46, 44, 46)
	local barras = {}
	local n = math.max(5, math.floor(largura / 1.8))
	for i = 0, n do
		local x = -largura / 2 + 0.6 + i * ((largura - 1.2) / n)
		local barra = parte(modelo, "Barra", Vector3.new(0.5, ALTURA_PORTA, 0.5), base * CFrame.new(x, ALTURA_PORTA / 2, 0), Enum.Material.Metal, corFerro)
		table.insert(barras, { barra, barra.CFrame })
	end
	for _, h in { 3, 7, 11 } do
		local travessa = parte(modelo, "Travessa", Vector3.new(largura, 0.4, 0.4), base * CFrame.new(0, h, 0), Enum.Material.Metal, corFerro)
		table.insert(barras, { travessa, travessa.CFrame })
	end
	-- aberto: erguido dentro da parede e sem colisão
	for _, info in barras do
		info[1].CFrame = info[2] + Vector3.new(0, ALTURA_PORTA - 1, 0)
		info[1].CanCollide = false
	end
	local portao = { barras = barras, runas = runas, aberto = true, centro = centro }
	table.insert(sala.portoes, portao)
	reservar(sala, centro, if aoLongoDeX then largura / 2 + 3 else 6, if aoLongoDeX then 6 else largura / 2 + 3)
	return portao
end

local function moverPortao(portao, aberto: boolean)
	if portao.aberto == aberto then
		return
	end
	portao.aberto = aberto
	for _, info in portao.barras do
		local peca, fechado = info[1], info[2]
		if peca.Parent then
			peca.CanCollide = not aberto
			TweenService:Create(peca, TweenInfo.new(if aberto then 1.2 else 0.35, if aberto then Enum.EasingStyle.Quad else Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
				CFrame = if aberto then fechado + Vector3.new(0, ALTURA_PORTA - 1, 0) else fechado,
			}):Play()
		end
	end
	for _, runa in portao.runas do
		runa.Color = if aberto then Color3.fromRGB(90, 255, 150) else Color3.fromRGB(255, 70, 70)
	end
end

-- Divisória que atravessa a sala em X na altura "z", com um vão (portão) centrado em "xVao"
local function divisoriaX(sala, z: number, x0: number, x1: number, xVao: number, largura: number)
	local a, b = xVao - largura / 2, xVao + largura / 2
	segmentoDeParede(sala, true, z, x0, a, ALTURA_PAREDE, 0)
	segmentoDeParede(sala, true, z, b, x1, ALTURA_PAREDE, 0)
	segmentoDeParede(sala, true, z, a, b, ALTURA_PAREDE - ALTURA_PORTA, ALTURA_PORTA) -- verga
	return criarPortao(sala, sala.origem + Vector3.new(xVao, 0, z), largura, true)
end

local function divisoriaZ(sala, x: number, z0: number, z1: number, zVao: number, largura: number)
	local a, b = zVao - largura / 2, zVao + largura / 2
	segmentoDeParede(sala, false, x, z0, a, ALTURA_PAREDE, 0)
	segmentoDeParede(sala, false, x, b, z1, ALTURA_PAREDE, 0)
	segmentoDeParede(sala, false, x, a, b, ALTURA_PAREDE - ALTURA_PORTA, ALTURA_PORTA)
	return criarPortao(sala, sala.origem + Vector3.new(x, 0, zVao), largura, false)
end

-- Rocha maciça que estreita uma fileira (com contrafortes e tochas na face da câmara)
local function massaDeRocha(sala, rng: Random, x0: number, x1: number, z0: number, z1: number, ladoDaCamara: number)
	if x1 - x0 < 1 then
		return
	end
	local tema, modelo = sala.tema, sala.modelo
	parte(modelo, "Rocha", Vector3.new(x1 - x0, ALTURA_PAREDE, z1 - z0), CFrame.new(sala.origem + Vector3.new((x0 + x1) / 2, ALTURA_PAREDE / 2, (z0 + z1) / 2)), tema.parede.material, escurecer(tema.parede.cor, 0.08))
	bloco(sala, x0, x1, z0, z1)
	local face = if ladoDaCamara > 0 then x1 else x0
	local dentro = Vector3.new(ladoDaCamara, 0, 0)
	parte(modelo, "Rodape", Vector3.new(1, 1.6, z1 - z0), CFrame.new(sala.origem + Vector3.new(face + ladoDaCamara * 0.5, 0.8, (z0 + z1) / 2)), tema.detalhe.material, tema.detalhe.cor)
	parte(modelo, "Cornija", Vector3.new(1.6, 1.2, z1 - z0), CFrame.new(sala.origem + Vector3.new(face + ladoDaCamara * 0.4, ALTURA_PAREDE - 1.6, (z0 + z1) / 2)), tema.detalhe.material, tema.detalhe.cor, { colide = false })
	local passos = math.max(1, math.floor((z1 - z0) / 18))
	for i = 1, passos do
		local z = z0 + i * (z1 - z0) / (passos + 1)
		contraforteComTocha(sala, sala.origem + Vector3.new(face, 0, z) + dentro * 1.2, dentro, i % 2 == 1)
	end
	-- pedras soltas no pé da rocha
	for _ = 1, math.floor((z1 - z0) / 10) do
		local t = rng:NextNumber(1, 2.6)
		local p = sala.origem + Vector3.new(face + ladoDaCamara * rng:NextNumber(0.5, 2.5), t / 2 - 0.2, rng:NextNumber(z0 + 3, z1 - 3))
		parte(modelo, "Pedregulho", Vector3.new(t, t * 0.8, t * 1.1), CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), tema.parede.material, escurecer(tema.parede.cor, rng:NextNumber(0, 0.2)))
	end
end

local function sortearLinhas(sala, rng: Random)
	local meiaL, meiaC = sala.largura / 2, sala.comprimento / 2
	local zA = -meiaC + sala.comprimento * rng:NextNumber(0.3, 0.36)
	local zB = zA + sala.comprimento * rng:NextNumber(0.3, 0.36)
	local zs = { -meiaC, zA, zB, meiaC }
	local tipos = { "inteira", "estreita", "dividida" }
	local linhas = {}
	local temDividida = false
	for r = 1, 3 do
		local tipo = tipos[rng:NextInteger(1, 3)]
		if r == 2 and not temDividida and rng:NextNumber() < 0.5 then
			tipo = "dividida"
		end
		if r == 3 and linhas[1].tipo == "inteira" and linhas[2].tipo == "inteira" and tipo == "inteira" then
			tipo = "estreita"
		end
		local linha = { z0 = zs[r], z1 = zs[r + 1], tipo = tipo }
		if tipo == "inteira" then
			linha.px0, linha.px1 = -meiaL, meiaL
		elseif tipo == "estreita" then
			local w = sala.largura * rng:NextNumber(0.5, 0.68)
			local folga = if r == 2 then meiaL - w / 2 else math.min(meiaL - w / 2, w / 2 - 16)
			local c = rng:NextNumber(-folga, folga)
			linha.px0, linha.px1 = c - w / 2, c + w / 2
		else
			temDividida = true
			local lado = if rng:NextNumber() < 0.5 then -1 else 1
			local xs = lado * rng:NextNumber(25, meiaL - 42)
			linha.xs = xs
			if lado > 0 then
				linha.px0, linha.px1 = -meiaL, xs
				linha.lado = { x0 = xs, x1 = meiaL }
			else
				linha.px0, linha.px1 = xs, meiaL
				linha.lado = { x0 = -meiaL, x1 = xs }
			end
		end
		linhas[r] = linha
	end
	-- portões entre as fileiras: no trecho que as duas câmaras do caminho têm em comum
	local largura = Config.CAMARAS.porta
	for r = 1, 2 do
		local a, b = linhas[r], linhas[r + 1]
		local x0 = math.max(a.px0, b.px0) + largura / 2 + 7
		local x1 = math.min(a.px1, b.px1) - largura / 2 - 7
		if x1 < x0 then
			return nil
		end
		a.xPorta = rng:NextNumber(x0, x1)
	end
	return linhas
end

local function criarCamaras(sala, rng: Random)
	local meiaL = sala.largura / 2
	local largura = Config.CAMARAS.porta
	local linhas = nil
	for _ = 1, 30 do
		linhas = sortearLinhas(sala, rng)
		if linhas then
			break
		end
	end
	if not linhas then
		return -- (nunca deveria acontecer) fica uma sala só
	end
	local h = ESPESSURA_DIVISORIA / 2
	local camaras = {}
	for r, linha in linhas do
		local z0 = linha.z0 + (if r > 1 then h else 0)
		local z1 = linha.z1 - (if r < 3 then h else 0)
		local x0, x1 = linha.px0, linha.px1
		if linha.tipo == "dividida" then
			if linha.xs > 0 then
				x1 -= h
			else
				x0 += h
			end
		end
		local camara = { x0 = x0, x1 = x1, z0 = z0, z1 = z1, caminho = true, linha = r, portoes = {}, numero = r }
		camaras[r] = camara
		linha.camara = camara
		if linha.tipo == "dividida" then
			local lx0, lx1 = linha.lado.x0, linha.lado.x1
			if linha.xs > 0 then
				lx0 += h
			else
				lx1 -= h
			end
			local lateral = { x0 = lx0, x1 = lx1, z0 = z0, z1 = z1, caminho = false, linha = r, portoes = {}, desafio = true }
			linha.lateral = lateral
		end
	end
	for _, linha in linhas do
		if linha.lateral then
			table.insert(camaras, linha.lateral)
		end
	end

	-- divisórias entre as fileiras (com o portão do caminho)
	for r = 1, 2 do
		local portao = divisoriaX(sala, linhas[r].z1, -meiaL, meiaL, linhas[r].xPorta, largura)
		table.insert(linhas[r].camara.portoes, portao)
		table.insert(linhas[r + 1].camara.portoes, portao)
	end
	for r, linha in linhas do
		if linha.tipo == "dividida" then
			local z0 = linha.z0 + (if r > 1 then h else 0)
			local z1 = linha.z1 - (if r < 3 then h else 0)
			local zVao = rng:NextNumber(z0 + largura / 2 + 8, z1 - largura / 2 - 8)
			local portao = divisoriaZ(sala, linha.xs, z0, z1, zVao, largura - 2)
			table.insert(linha.camara.portoes, portao)
			table.insert(linha.lateral.portoes, portao)
		elseif linha.tipo == "estreita" then
			local z0 = linha.z0 + (if r > 1 then h else 0)
			local z1 = linha.z1 - (if r < 3 then h else 0)
			massaDeRocha(sala, rng, -meiaL, linha.px0, z0, z1, 1)
			massaDeRocha(sala, rng, linha.px1, meiaL, z0, z1, -1)
		end
	end
	sala.camaras = camaras
	sala.linhas = linhas
end

-- Braseiros nos cantos de cada câmara (cada câmara é iluminada por conta própria)
local function iluminarCamaras(sala)
	for _, c in sala.camaras do
		for _, cx in { c.x0 + 5, c.x1 - 5 } do
			for _, cz in { c.z0 + 5, c.z1 - 5 } do
				local pos = sala.origem + Vector3.new(cx, 0, cz)
				if Masmorra.posicaoValida(sala, pos, 2) then
					criarBraseiro(sala, pos, 1)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

-- Cria uma sala nova. "origem" é o centro do chão (a superfície fica em origem.Y).
function Masmorra.construir(origem: Vector3, numero: number, tipo: string, rng: Random)
	local tema = Config.temaDaSala(numero)
	local comCamaras = tipo == "combate" and tema.camaras == true
	local largura, comprimento
	-- salas amplas: espaço para esquivar, cercar e lutar em grupo
	if comCamaras then
		local info = Config.CAMARAS
		largura = rng:NextInteger(info.largura[1] // 5, info.largura[2] // 5) * 5
		comprimento = rng:NextInteger(info.comprimento[1] // 5, info.comprimento[2] // 5) * 5
	elseif tipo == "chefe" then
		largura, comprimento = 150, 150
	elseif tipo == "tesouro" then
		largura, comprimento = 64, 70
	else
		largura = rng:NextInteger(21, 28) * 5
		comprimento = rng:NextInteger(21, 28) * 5
	end

	local modelo = Instance.new("Model")
	modelo.Name = "Sala" .. numero

	local sala = {
		modelo = modelo,
		origem = origem,
		numero = numero,
		tipo = tipo,
		tema = tema,
		largura = largura,
		comprimento = comprimento,
		pilares = {},
		perigos = {},
		blocos = {}, -- paredes internas e rocha maciça (sala com câmaras)
		reservas = {}, -- vãos dos portões (ficam livres)
		portoes = {},
		camaras = nil, -- lista de câmaras (sala com câmaras); camaraAtiva = a trancada agora
		spawn = CFrame.lookAt(origem + Vector3.new(0, 3, -comprimento / 2 + 7), origem + Vector3.new(0, 3, comprimento / 2)),
	}

	criarChao(sala, rng)
	if comCamaras then
		criarCamaras(sala, rng) -- antes do resto: paredes, pilares e enfeites desviam das câmaras
	end
	criarParedes(sala)
	criarPorta(sala)
	criarEntrada(sala)
	criarPilares(sala, rng)
	criarLava(sala, rng)
	criarDecoracao(sala, rng)
	criarAtmosfera(sala)
	if tipo == "chefe" then
		criarSalaDoChefe(sala)
	elseif tipo == "tesouro" then
		criarBau(sala)
	elseif sala.camaras then
		iluminarCamaras(sala)
	else
		-- braseiros nos cantos da entrada e no meio das laterais (iluminam a sala grande)
		local meiaL, meiaC = largura / 2, comprimento / 2
		criarBraseiro(sala, origem + Vector3.new(-meiaL + 5, 0, -meiaC + 5), 1)
		criarBraseiro(sala, origem + Vector3.new(meiaL - 5, 0, -meiaC + 5), 1)
		criarBraseiro(sala, origem + Vector3.new(-meiaL + 5, 0, 0), 1.2)
		criarBraseiro(sala, origem + Vector3.new(meiaL - 5, 0, 0), 1.2)
		criarBraseiro(sala, origem + Vector3.new(-meiaL + 5, 0, meiaC - 5), 1)
		criarBraseiro(sala, origem + Vector3.new(meiaL - 5, 0, meiaC - 5), 1)
	end
	return sala
end

-- Câmara em que um ponto está (nil = no vão de um portão ou fora)
function Masmorra.camaraDe(sala, pos: Vector3)
	local local_ = pos - sala.origem
	for _, c in sala.camaras or {} do
		if local_.X > c.x0 + 1 and local_.X < c.x1 - 1 and local_.Z > c.z0 + 1 and local_.Z < c.z1 - 1 then
			return c
		end
	end
	return nil
end

-- Tranca uma câmara (portões descem; os inimigos ficam presos nela) ou destranca (camara = nil)
function Masmorra.trancar(sala, camara)
	if sala.camaraAtiva then
		for _, portao in sala.camaraAtiva.portoes do
			moverPortao(portao, true)
		end
	end
	sala.camaraAtiva = camara
	if camara then
		for _, portao in camara.portoes do
			moverPortao(portao, false)
		end
	end
end

-- Ponto livre para um inimigo dentro da câmara, longe dos pontos de "evitar" (os jogadores)
function Masmorra.posicaoNaCamara(sala, rng: Random, camara, evitar: { Vector3 }, distancia: number): Vector3
	local anterior = sala.camaraAtiva
	sala.camaraAtiva = camara
	local melhor = nil
	for tentativa = 1, 40 do
		local pos = posicaoLivre(sala, rng, 3, false)
		if pos then
			local longe = true
			for _, p in evitar do
				if planar(pos - p).Magnitude < (if tentativa > 30 then distancia * 0.5 else distancia) then
					longe = false
					break
				end
			end
			melhor = melhor or pos
			if longe then
				melhor = pos
				break
			end
		end
	end
	sala.camaraAtiva = anterior
	return melhor or (sala.origem + Vector3.new((camara.x0 + camara.x1) / 2, 0, (camara.z0 + camara.z1) / 2))
end

-- Ponto no chão para um inimigo aparecer, longe da entrada dos jogadores
function Masmorra.posicaoInimigo(sala, rng: Random): Vector3
	local entrada = sala.spawn.Position
	for _ = 1, 30 do
		local pos = posicaoLivre(sala, rng, 3, false)
		if pos and planar(pos - entrada).Magnitude > 34 then
			return pos
		end
	end
	return sala.origem + Vector3.new(0, 0, sala.comprimento / 4)
end

function Masmorra.naLava(sala, pos: Vector3): boolean
	if pos.Y > sala.origem.Y + 6 then
		return false
	end
	for _, perigo in sala.perigos do
		local d = pos - perigo.centro
		if math.abs(d.X) < perigo.meio.X and math.abs(d.Z) < perigo.meio.Z then
			return true
		end
	end
	return false
end

-- Sobe a grade e acende a saída. Retorna a peça que leva para a próxima sala.
function Masmorra.abrirPorta(sala): BasePart
	if sala.grade then
		for _, barra in sala.grade:GetChildren() do
			if barra:IsA("BasePart") then
				barra.CanCollide = false
				TweenService:Create(barra, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
					CFrame = barra.CFrame + Vector3.new(0, ALTURA_PORTA - 1, 0),
				}):Play()
			end
		end
	end
	if sala.runaPorta then
		sala.runaPorta.Color = Color3.fromRGB(90, 255, 150)
		luz(sala.runaPorta, Color3.fromRGB(90, 255, 150), 20, 2, false)
	end
	if sala.luzPorta then
		sala.luzPorta.Color = Color3.fromRGB(90, 255, 150)
		sala.luzPorta.Brightness = 3
	end
	local porta = sala.porta
	porta.Transparency = 0.8

	local placa = Instance.new("BillboardGui")
	placa.Size = UDim2.fromScale(12, 2.5)
	placa.StudsOffset = Vector3.new(0, 9, -2)
	placa.AlwaysOnTop = true
	placa.MaxDistance = 150
	placa.LightInfluence = 0
	placa.Parent = porta

	local texto = Instance.new("TextLabel")
	texto.Size = UDim2.fromScale(1, 1)
	texto.BackgroundTransparency = 1
	texto.Text = "PRÓXIMA SALA ➜"
	texto.TextScaled = true
	texto.Font = Enum.Font.Merriweather
	texto.TextColor3 = Color3.fromRGB(140, 255, 175)
	texto.TextStrokeTransparency = 0.2
	texto.Parent = placa
	return porta
end

function Masmorra.abrirBau(sala)
	local tampa = sala.tampaBau
	if tampa then
		TweenService:Create(tampa, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
			CFrame = tampa.CFrame * CFrame.new(0, 1.2, 1.8) * CFrame.Angles(math.rad(-70), 0, 0),
		}):Play()
	end
end

return Masmorra
