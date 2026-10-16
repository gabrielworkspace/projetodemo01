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

-- Fogo: chama clássica + faíscas subindo
local function fogo(pai: BasePart, cor: Color3, tamanho: number)
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

function Masmorra.posicaoValida(sala, pos: Vector3, raio: number): boolean
	local local_ = pos - sala.origem
	if math.abs(local_.X) > sala.largura / 2 - raio or math.abs(local_.Z) > sala.comprimento / 2 - raio then
		return false
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
	for _ = 1, 40 do
		local x = rng:NextNumber(-sala.largura / 2 + raio + 2, sala.largura / 2 - raio - 2)
		local z = rng:NextNumber(-sala.comprimento / 2 + raio + 2, sala.comprimento / 2 - raio - 2)
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
			if i < passos and i % 2 == 0 then
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
		local area = sala.largura * sala.comprimento / 8000
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
-- API
------------------------------------------------------------------------

-- Cria uma sala nova. "origem" é o centro do chão (a superfície fica em origem.Y).
function Masmorra.construir(origem: Vector3, numero: number, tipo: string, rng: Random)
	local largura, comprimento
	-- salas amplas: espaço para esquivar, cercar e lutar em grupo
	if tipo == "chefe" then
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
		tema = Config.temaDaSala(numero),
		largura = largura,
		comprimento = comprimento,
		pilares = {},
		perigos = {},
		spawn = CFrame.lookAt(origem + Vector3.new(0, 3, -comprimento / 2 + 7), origem + Vector3.new(0, 3, comprimento / 2)),
	}

	criarChao(sala, rng)
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
