-- Gera as salas da masmorra por código. Cada sala é sorteada na hora: tamanho, pilares,
-- lava e decoração mudam a cada partida, e o visual muda conforme o tema do andar.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Masmorra = {}

local ALTURA_PAREDE = 24
local LARGURA_PORTA = 10
local ALTURA_PORTA = 13
local TAMANHO_LAJOTA = 10
local EM_PE = CFrame.Angles(0, 0, math.rad(90)) -- deixa um cilindro em pé (ou deitado como disco)

-- Estilo "fantasia" (tema com estilo = "fantasia", como o lobby): tudo em peças lisas
-- (SmoothPlastic) com cores vivas, sem neon de enfeite; o fogo vem do pacote de VFX.
-- Vale para a sala que está sendo construída agora (Masmorra.construir liga e desliga).
local estiloLiso = false
local PALETA = {
	ouro = Color3.fromRGB(236, 192, 92),
	madeira = Color3.fromRGB(160, 106, 64),
	madeiraClara = Color3.fromRGB(196, 140, 86),
	madeiraEscura = Color3.fromRGB(128, 82, 50),
	lilasEscuro = Color3.fromRGB(112, 98, 140),
	lilas = Color3.fromRGB(182, 168, 208),
	pedraClara = Color3.fromRGB(232, 216, 186),
	brasa = Color3.fromRGB(214, 96, 46),
	bandeira = Color3.fromRGB(126, 70, 205),
	ferro = Color3.fromRGB(92, 84, 112),
	prata = Color3.fromRGB(214, 218, 232),
}
Masmorra.PALETA = PALETA

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
	-- estilo liso: só o vidro (gemas) e o que precisa brilhar de verdade (opcoes.brilho) fogem
	if estiloLiso and not opcoes.brilho and material ~= Enum.Material.Glass then
		material = Enum.Material.SmoothPlastic
	end
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

-- Efeito do pacote de VFX (ReplicatedStorage > EfeitosVFX) preso numa peça e ligado direto
-- (as chamas das tochas e dos braseiros). Igual ao do lobby (Lobby.luau).
local function efeitoPronto(nome: string, pai: BasePart, opcoes): Attachment?
	opcoes = opcoes or {}
	local efeitos = ReplicatedStorage:FindFirstChild("EfeitosVFX")
	local molde = efeitos and efeitos:FindFirstChild(nome)
	if not molde then
		return nil
	end
	local anexo = Instance.new("Attachment")
	anexo.Name = "Efeito" .. nome
	anexo.CFrame = opcoes.deslocamento or CFrame.identity
	anexo.Parent = pai
	local escala = opcoes.escala or 1
	local velocidade = opcoes.velocidade or escala
	for _, original in molde:GetDescendants() do
		if original:IsA("ParticleEmitter") then
			local emissor = original:Clone()
			if escala ~= 1 then
				local chaves = {}
				for _, chave in emissor.Size.Keypoints do
					table.insert(chaves, NumberSequenceKeypoint.new(chave.Time, chave.Value * escala, chave.Envelope * escala))
				end
				emissor.Size = NumberSequence.new(chaves)
			end
			if velocidade ~= 1 then
				emissor.Speed = NumberRange.new(emissor.Speed.Min * velocidade, emissor.Speed.Max * velocidade)
			end
			if opcoes.taxa then
				emissor.Rate *= opcoes.taxa
			end
			emissor.Enabled = opcoes.ligado ~= false
			emissor.Parent = anexo
		end
	end
	return anexo
end
Masmorra.efeitoPronto = efeitoPronto

-- Fogo: chama clássica + faíscas subindo (no estilo liso, as chamas do pacote de VFX)
local function fogo(pai: BasePart, cor: Color3, tamanho: number)
	if estiloLiso and efeitoPronto("LaminaFogo", pai, { escala = tamanho * 0.3, deslocamento = CFrame.new(0, 0.2, 0) }) then
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
	-- sacadas, torre, ruínas e armadilhas da sala de exploração
	for _, bloco in sala.blocos do
		local d = pos - bloco.centro
		if math.abs(d.X) < bloco.meio.X + raio and math.abs(d.Z) < bloco.meio.Z + raio then
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
	if estiloLiso then
		-- tocha de madeira num suporte dourado, com o fogo do pacote
		parte(modelo, "Placa", Vector3.new(1.4, 2.2, 0.3), base * CFrame.new(0, 0, -0.15), Enum.Material.SmoothPlastic, PALETA.ouro, { colide = false })
		parte(modelo, "Suporte", Vector3.new(0.4, 0.4, 1.4), base * CFrame.new(0, -0.3, -0.8), Enum.Material.SmoothPlastic, PALETA.ouro, { colide = false })
		local cabo = parte(modelo, "Tocha", Vector3.new(0.5, 2.2, 0.5), base * CFrame.new(0, 0.5, -1.5) * CFrame.Angles(math.rad(-18), 0, 0), Enum.Material.SmoothPlastic, PALETA.madeira, { colide = false })
		local ponta = parte(modelo, "Brasa", Vector3.new(0.75, 0.6, 0.75), cabo.CFrame * CFrame.new(0, 1.2, 0), Enum.Material.SmoothPlastic, PALETA.brasa, { colide = false, sombra = false })
		fogo(ponta, tema.luz, 2.2)
		luz(ponta, tema.luz, 24, 1.8, true)
		return
	end
	parte(modelo, "Suporte", Vector3.new(0.5, 0.5, 1.6), base * CFrame.new(0, 0, -0.6), Enum.Material.Metal, Color3.fromRGB(45, 40, 40), { colide = false })
	local tigela = parte(modelo, "Tigela", Vector3.new(0.7, 1.2, 1.2), base * CFrame.new(0, 0.2, -1.4) * EM_PE, Enum.Material.Metal, Color3.fromRGB(60, 52, 48), { formato = Enum.PartType.Cylinder, colide = false })
	local chama = parte(modelo, "Chama", Vector3.new(0.6, 0.6, 0.6), tigela.CFrame * CFrame.new(0.6, 0, 0), Enum.Material.Neon, tema.luz, { colide = false, sombra = false })
	fogo(chama, tema.luz, 2.2)
	luz(chama, tema.luz, 22, 1.7, true)
end

local function criarBraseiro(sala, pos: Vector3, escala: number)
	local tema, modelo = sala.tema, sala.modelo
	if estiloLiso then
		-- igual aos braseiros do lobby: pé lilás, tigela, aro dourado e brasa com o fogo do pacote
		parte(modelo, "PeBraseiro", Vector3.new(3 * escala, 1.3 * escala, 1.3 * escala), CFrame.new(pos + Vector3.new(0, 1.5 * escala, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.lilasEscuro, { formato = Enum.PartType.Cylinder })
		parte(modelo, "Base", Vector3.new(0.6 * escala, 2.4 * escala, 2.4 * escala), CFrame.new(pos + Vector3.new(0, 0.3 * escala, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.lilas, { formato = Enum.PartType.Cylinder })
		parte(modelo, "Tigela", Vector3.new(1 * escala, 2.9 * escala, 2.9 * escala), CFrame.new(pos + Vector3.new(0, 3.3 * escala, 0)) * EM_PE, Enum.Material.SmoothPlastic, Color3.fromRGB(78, 66, 96), { formato = Enum.PartType.Cylinder })
		parte(modelo, "Aro", Vector3.new(0.3 * escala, 3.2 * escala, 3.2 * escala), CFrame.new(pos + Vector3.new(0, 3.75 * escala, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.ouro, { formato = Enum.PartType.Cylinder, colide = false })
		local brasa = parte(modelo, "Brasa", Vector3.new(0.3 * escala, 2.3 * escala, 2.3 * escala), CFrame.new(pos + Vector3.new(0, 3.85 * escala, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.brasa, { formato = Enum.PartType.Cylinder, colide = false, sombra = false })
		efeitoPronto("LaminaFogo", brasa, { escala = 1.2 * escala, deslocamento = CFrame.new(0.2, 0, 0) })
		luz(brasa, tema.luz, 30 * escala, 2, true)
		obstaculo(sala, pos, 1.6 * escala)
		return
	end
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
	local ALTURA_PAREDE = sala.altura
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
				criarArandela(sala, origem + Vector3.new(lado * meiaL, if sala.exploracao then 16 else 8, zMeio), Vector3.new(-lado, 0, 0))
			end
		end
	end

	-- Estandartes no fundo
	for _, x in { -meiaL / 2, meiaL / 2 } do
		local estandarte = parte(modelo, "Estandarte", Vector3.new(4.4, 9, 0.2), CFrame.new(origem + Vector3.new(x, 13, -meiaC + 0.2)), Enum.Material.Fabric, if estiloLiso then PALETA.bandeira else Color3.fromRGB(120, 24, 34), { colide = false })
		parte(modelo, "Barra", Vector3.new(5.2, 0.3, 0.3), estandarte.CFrame * CFrame.new(0, 4.6, 0), Enum.Material.Metal, Color3.fromRGB(200, 160, 70), { colide = false })
		parte(modelo, "Simbolo", Vector3.new(1.6, 1.6, 0.1), estandarte.CFrame * CFrame.new(0, 1, -0.12) * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Neon, if estiloLiso then PALETA.ouro else tema.luz, { colide = false })
	end
	if estiloLiso then
		-- faixas de pedra clara e pedras salientes: a parede lisa ganha forma sem textura
		for _, h in { 6, 13, 20 } do
			if h < ALTURA_PAREDE - 3 then
				for _, info in {
					{ Vector3.new(0.8, 0.7, sala.comprimento), Vector3.new(-meiaL + 0.3, h, 0) },
					{ Vector3.new(0.8, 0.7, sala.comprimento), Vector3.new(meiaL - 0.3, h, 0) },
					{ Vector3.new(sala.largura, 0.7, 0.8), Vector3.new(0, h, -meiaC + 0.3) },
				} do
					parte(modelo, "Faixa", info[1], CFrame.new(origem + info[2]), matDetalhe, escurecer(corDetalhe, 0.08), { colide = false, sombra = false })
				end
			end
		end
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
	local runa = parte(modelo, "Runa", Vector3.new(1.4, 1.4, 0.3), CFrame.new(origem + Vector3.new(0, ALTURA_PORTA + 1.1, zParede - 2.05)) * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Neon, Color3.fromRGB(255, 70, 70), { colide = false, brilho = true })
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
	local ALTURA_PAREDE = sala.altura
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
	elseif sala.tipo == "combate" and not sala.exploracao then
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
		parte(modelo, "RunaPilar", Vector3.new(0.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.new(diametro / 2, 0, 0) * CFrame.Angles(math.rad(45), 0, 0), Enum.Material.Neon, if estiloLiso then PALETA.ouro else tema.luz, { colide = false, sombra = false })
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
		if #sala.blocos > 0 and not Masmorra.posicaoValida(sala, pos, 2) then
			continue -- (sala de exploração) em cima de uma sacada, escada ou armadilha
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
	local runa = if estiloLiso then PALETA.ouro else Color3.fromRGB(60, 110, 70)
	parte(modelo, "Ritual", Vector3.new(0.12, 60, 60), CFrame.new(centro) * EM_PE, Enum.Material.Neon, runa, { formato = Enum.PartType.Cylinder, colide = false, transparencia = if estiloLiso then 0 else 0.8, sombra = false })
	parte(modelo, "RitualMiolo", Vector3.new(0.14, 58, 58), CFrame.new(centro + Vector3.new(0, 0.02, 0)) * EM_PE, tema.chao.material, escurecer(tema.chao.cor, 0.2), { formato = Enum.PartType.Cylinder, colide = false, sombra = false })
	parte(modelo, "RitualInterno", Vector3.new(0.12, 20, 20), CFrame.new(centro + Vector3.new(0, 0.04, 0)) * EM_PE, Enum.Material.Neon, runa, { formato = Enum.PartType.Cylinder, colide = false, transparencia = if estiloLiso then 0 else 0.8, sombra = false })
	parte(modelo, "RitualInternoMiolo", Vector3.new(0.14, 18.6, 18.6), CFrame.new(centro + Vector3.new(0, 0.06, 0)) * EM_PE, tema.chao.material, escurecer(tema.chao.cor, 0.25), { formato = Enum.PartType.Cylinder, colide = false, sombra = false })
	-- Trono no fundo
	local trono = origem + Vector3.new(0, 0, meiaC - 8)
	parte(modelo, "Degrau", Vector3.new(16, 1, 8), CFrame.new(trono + Vector3.new(0, 0.5, 0)), tema.detalhe.material, tema.detalhe.cor)
	parte(modelo, "Assento", Vector3.new(6, 3, 4), CFrame.new(trono + Vector3.new(0, 2.5, 0.5)), tema.detalhe.material, escurecer(tema.detalhe.cor, 0.1))
	parte(modelo, "Encosto", Vector3.new(6, 9, 1.4), CFrame.new(trono + Vector3.new(0, 6, 2.6)), tema.detalhe.material, escurecer(tema.detalhe.cor, 0.1))
	local gema = parte(modelo, "Gema", Vector3.one * 1.4, CFrame.new(trono + Vector3.new(0, 9.4, 1.8)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), if estiloLiso then Enum.Material.Glass else Enum.Material.Neon, if estiloLiso then Color3.fromRGB(90, 230, 140) else Color3.fromRGB(255, 50, 60), { colide = false })
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
-- Sala de exploração (temas com exploracao = true): três áreas, sacadas, torre, ruínas,
-- baús de relíquias, relicário do mini-chefe e armadilhas
------------------------------------------------------------------------

local ALTURA_SACADA = 10
local FUNDO_SACADA = 14
local ALTURA_TORRE = 22

-- Área retangular onde nada aparece (inimigos, baús, armadilhas) e que os inimigos contornam
local function obstaculoRetangulo(sala, centro: Vector3, meioX: number, meioZ: number)
	local chao = Vector3.new(centro.X, sala.origem.Y, centro.Z)
	table.insert(sala.blocos, { centro = chao, meio = Vector3.new(meioX, 0, meioZ) })
	local porX = meioX >= meioZ
	local longo, curto = math.max(meioX, meioZ), math.min(meioX, meioZ)
	local n = math.max(1, math.ceil(longo / math.max(curto, 1.5)))
	local raio = math.sqrt(curto * curto + (longo / n) ^ 2)
	for i = 1, n do
		local t = -longo + (2 * i - 1) * longo / n
		obstaculo(sala, chao + (if porX then Vector3.new(t, 0, 0) else Vector3.new(0, 0, t)), raio)
	end
end

-- Ponto livre para algo de "raio" (fora de blocos, pilares, caminho e de outras coisas)
local function livre(sala, pos: Vector3, raio: number): boolean
	return Masmorra.posicaoValida(sala, pos, raio) and not noCaminho(sala, pos, raio)
end

-- Peças do pacote de natureza (ServerStorage > PacoteCenario), como no lobby
local pacoteCenario: Instance? = nil
local function cenario(sala, nome: string, pos: Vector3, escala: number, giro: number): Instance?
	pacoteCenario = pacoteCenario or ServerStorage:FindFirstChild("PacoteCenario")
	local molde = pacoteCenario and pacoteCenario:FindFirstChild(nome, true)
	if not molde then
		return nil
	end
	local copia = molde:Clone()
	local rotacao = CFrame.Angles(0, giro, 0)
	if copia:IsA("BasePart") then
		copia.Anchored = true
		copia.Size *= escala
		copia.CFrame = CFrame.new(pos + Vector3.new(0, copia.Size.Y / 2 - 0.15, 0)) * rotacao
	elseif copia:IsA("Model") then
		for _, peca in copia:GetDescendants() do
			if peca:IsA("BasePart") then
				peca.Anchored = true
			end
		end
		pcall(function()
			copia:ScaleTo(copia:GetScale() * escala)
		end)
		copia:PivotTo(CFrame.new(copia:GetPivot().Position) * rotacao)
		local caixa, tamanho = copia:GetBoundingBox()
		local alvo = pos + Vector3.new(0, tamanho.Y / 2 - 0.15, 0)
		copia:PivotTo(copia:GetPivot() + (alvo - caixa.Position))
	else
		copia:Destroy()
		return nil
	end
	for _, peca in copia:GetDescendants() do
		if peca:IsA("Script") or peca:IsA("LocalScript") then
			peca:Destroy()
		end
	end
	copia.Parent = sala.modelo
	return copia
end

local PLANTAS = { "Fern1", "Fern2", "Fern3", "Grass1", "Grass2", "Grass3" }
local COGUMELOS = { "MushroomCluster1", "MushroomCluster2", "MushroomCluster3", "LargeMushroon" }
local function cantinhoVerde(sala, rng: Random, pos: Vector3, comPedra: boolean)
	if comPedra then
		cenario(sala, "Rock" .. rng:NextInteger(1, 10), pos, rng:NextNumber(0.5, 0.85), rng:NextNumber(0, math.pi * 2))
		obstaculo(sala, pos, 2.4)
	end
	for _ = 1, rng:NextInteger(2, 4) do
		local p = pos + Vector3.new(rng:NextNumber(-3.5, 3.5), 0, rng:NextNumber(-3.5, 3.5))
		local nome = if rng:NextNumber() < 0.3 then COGUMELOS[rng:NextInteger(1, #COGUMELOS)] else PLANTAS[rng:NextInteger(1, #PLANTAS)]
		local planta = cenario(sala, nome, p, rng:NextNumber(0.7, 1.1), rng:NextNumber(0, math.pi * 2))
		if planta then
			for _, peca in (if planta:IsA("BasePart") then { planta } else planta:GetDescendants()) do
				if peca:IsA("BasePart") then
					peca.CanCollide = false
					peca.CanQuery = false
				end
			end
		end
	end
end

-- Escada de mão: treliça invisível (o Roblox deixa subir) com trilhos e degraus de madeira
local function criarEscadaDeMao(sala, base: Vector3, altura: number, paraFora: Vector3)
	local modelo = sala.modelo
	local cf = CFrame.lookAt(base, base + paraFora)
	local trelica = Instance.new("TrussPart")
	trelica.Name = "Escada"
	trelica.Anchored = true
	trelica.Size = Vector3.new(2, altura, 2)
	trelica.CFrame = cf * CFrame.new(0, altura / 2, -1)
	trelica.Transparency = 1
	trelica.Parent = modelo
	for _, x in { -1.15, 1.15 } do
		parte(modelo, "Trilho", Vector3.new(0.35, altura + 1.6, 0.35), cf * CFrame.new(x, (altura + 1.6) / 2, -1), Enum.Material.SmoothPlastic, PALETA.madeiraEscura, { colide = false })
	end
	for h = 1, altura, 1.4 do
		parte(modelo, "Degrau", Vector3.new(2.5, 0.3, 0.4), cf * CFrame.new(0, h, -1), Enum.Material.SmoothPlastic, PALETA.madeiraClara, { colide = false })
	end
	obstaculo(sala, base + paraFora * 1, 1.6)
end

-- Baú de relíquia. tipo: "chao", "alto", "torre", "relicario" ou "chefe" (Reliquias.BAUS)
local CORES_BAU = {
	chao = Color3.fromRGB(196, 202, 214),
	alto = Color3.fromRGB(72, 165, 255),
	torre = Color3.fromRGB(190, 100, 255),
	relicario = Color3.fromRGB(255, 186, 48),
	chefe = Color3.fromRGB(255, 186, 48),
}
local NOMES_BAU = {
	chao = "Baú Antigo",
	alto = "Baú Esquecido",
	torre = "Baú da Atalaia",
	relicario = "Relicário do Carcereiro",
	chefe = "Tesouro do Senhor da Guerra",
}
local function criarBauReliquia(sala, cframe: CFrame, tipo: string)
	local modelo = sala.modelo
	local grande = tipo == "relicario" or tipo == "chefe"
	local k = if grande then 1.35 else 1
	local cor = CORES_BAU[tipo] or PALETA.ouro
	local madeira = if grande then Color3.fromRGB(112, 70, 150) else PALETA.madeira
	local base = parte(modelo, "Bau", Vector3.new(4 * k, 2.4 * k, 2.8 * k), cframe * CFrame.new(0, 1.2 * k, 0), Enum.Material.SmoothPlastic, madeira)
	local tampa = parte(modelo, "Tampa", Vector3.new(4.2 * k, 1 * k, 3 * k), cframe * CFrame.new(0, 2.9 * k, 0), Enum.Material.SmoothPlastic, escurecer(madeira, 0.2))
	parte(modelo, "Faixa", Vector3.new(4.3 * k, 0.35 * k, 3.1 * k), cframe * CFrame.new(0, 2.35 * k, 0), Enum.Material.SmoothPlastic, PALETA.ouro, { colide = false })
	for _, x in { -1.45, 1.45 } do
		parte(modelo, "Reforco", Vector3.new(0.35 * k, 2.6 * k, 3.1 * k), cframe * CFrame.new(x * k, 1.3 * k, 0), Enum.Material.SmoothPlastic, PALETA.ouro, { colide = false })
	end
	-- a gema da fechadura tem a cor da raridade que o baú costuma dar
	parte(modelo, "Gema", Vector3.new(0.7, 0.7, 0.3) * k, cframe * CFrame.new(0, 2.3 * k, -1.55 * k), Enum.Material.Glass, cor, { colide = false })
	local brilho = Instance.new("ParticleEmitter")
	brilho.Name = "Brilho"
	brilho.Color = ColorSequence.new(cor:Lerp(Color3.new(1, 1, 1), 0.4), cor)
	brilho.LightEmission = 1
	brilho.LightInfluence = 0
	brilho.Size = sequencia({ { 0, 0 }, { 0.5, 0.28 * k }, { 1, 0 } })
	brilho.Lifetime = NumberRange.new(1, 1.8)
	brilho.Speed = NumberRange.new(0.6, 1.6)
	brilho.SpreadAngle = Vector2.new(70, 70)
	brilho.Rate = if grande then 14 else 6
	brilho.EmissionDirection = Enum.NormalId.Top
	brilho.Parent = base
	local luzBau = luz(base, cor, if grande then 18 else 11, if grande then 1.6 else 0.9, false)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir"
	prompt.ObjectText = NOMES_BAU[tipo] or "Baú"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	local bau = { tipo = tipo, base = base, tampa = tampa, prompt = prompt, brilho = brilho, luz = luzBau, aberto = false, pos = cframe.Position }
	table.insert(sala.baus, bau)
	return bau
end
Masmorra.criarBauReliquia = function(sala, pos: Vector3, tipo: string)
	local anterior = estiloLiso
	estiloLiso = sala.tema.estilo == "fantasia"
	local paraEntrada = planar(sala.spawn.Position - pos)
	local bau = criarBauReliquia(sala, CFrame.lookAt(pos, pos + (if paraEntrada.Magnitude > 0.1 then paraEntrada.Unit else Vector3.new(0, 0, -1))), tipo)
	estiloLiso = anterior
	return bau
end

-- Sacada encostada na parede lateral. acesso "mao" = escada de mão; "pedra" = escadaria.
-- sentido = lado (em Z) onde fica o acesso.
local function criarSacada(sala, rng: Random, lado: number, zCentro: number, comprimento: number, acesso: string, sentido: number)
	local origem, tema, modelo = sala.origem, sala.tema, sala.modelo
	local meiaL = sala.largura / 2
	local fundo, altura = FUNDO_SACADA, ALTURA_SACADA
	local xFrente = lado * (meiaL - fundo)
	local centro = origem + Vector3.new(lado * (meiaL - fundo / 2), 0, zCentro)
	local corDetalhe, matDetalhe = tema.detalhe.cor, tema.detalhe.material
	parte(modelo, "Sacada", Vector3.new(fundo, altura, comprimento), CFrame.new(centro + Vector3.new(0, altura / 2, 0)), tema.parede.material, escurecer(tema.parede.cor, 0.06))
	parte(modelo, "PisoSacada", Vector3.new(fundo, 0.4, comprimento), CFrame.new(centro + Vector3.new(0, altura + 0.2, 0)), tema.chao.material, tema.chao.cor)
	parte(modelo, "BordaSacada", Vector3.new(1.4, 1, comprimento + 0.8), CFrame.new(origem + Vector3.new(xFrente - lado * 0.4, altura - 0.1, zCentro)), matDetalhe, corDetalhe)
	-- arcos fechados na frente (painéis escuros entre colunas claras)
	local arcos = math.max(2, math.floor(comprimento / 11))
	local passo = comprimento / arcos
	for i = 0, arcos - 1 do
		local z = zCentro - comprimento / 2 + (i + 0.5) * passo
		parte(modelo, "Arco", Vector3.new(0.3, altura - 3.5, passo - 3.4), CFrame.new(origem + Vector3.new(xFrente - lado * 0.1, (altura - 3.5) / 2 + 0.6, z)), Enum.Material.SmoothPlastic, escurecer(tema.parede.cor, 0.38), { colide = false, sombra = false })
		parte(modelo, "TopoArco", Vector3.new(0.4, 1.3, passo - 1.6), CFrame.new(origem + Vector3.new(xFrente - lado * 0.15, altura - 2.6, z)), matDetalhe, corDetalhe, { colide = false })
	end
	for i = 0, arcos do
		local z = zCentro - comprimento / 2 + i * passo
		parte(modelo, "ColunaSacada", Vector3.new(1.8, altura, 1.8), CFrame.new(origem + Vector3.new(xFrente - lado * 0.5, altura / 2, z)), matDetalhe, corDetalhe)
	end

	local zAcesso = zCentro + sentido * comprimento / 2
	local zEscada = nil
	if acesso == "mao" then
		zEscada = zAcesso - sentido * 4
		criarEscadaDeMao(sala, origem + Vector3.new(xFrente - lado * 1.2, 0, zEscada), altura, Vector3.new(-lado, 0, 0))
	else
		-- escadaria de pedra encostada na parede, subindo até a ponta da sacada
		local largura = 7
		for k = 1, 9 do
			local h = altura - k
			local z = zAcesso + sentido * (k - 0.5) * 2
			parte(modelo, "DegrauPedra", Vector3.new(largura, h, 2), CFrame.new(origem + Vector3.new(lado * (meiaL - largura / 2), h / 2, z)), tema.parede.material, escurecer(tema.parede.cor, 0.03 * (k % 2)))
			parte(modelo, "BordaDegrau", Vector3.new(largura, 0.3, 2.1), CFrame.new(origem + Vector3.new(lado * (meiaL - largura / 2), h + 0.15, z)), matDetalhe, corDetalhe)
		end
		local meioZ = 9
		obstaculoRetangulo(sala, origem + Vector3.new(lado * (meiaL - largura / 2), 0, zAcesso + sentido * meioZ), largura / 2, meioZ)
	end

	-- balaústre na beirada (com vão na escada de mão)
	local xGrade = xFrente + lado * 0.5
	local inicio, fim = zCentro - comprimento / 2 + 0.5, zCentro + comprimento / 2 - 0.5
	local z = inicio
	while z <= fim do
		if not zEscada or math.abs(z - zEscada) > 2 then
			parte(modelo, "Balaustre", Vector3.new(0.6, 2.6, 0.6), CFrame.new(origem + Vector3.new(xGrade, altura + 1.7, z)), matDetalhe, corDetalhe)
		end
		z += 2.2
	end
	local function corrimao(z1: number, z2: number)
		if z2 - z1 > 0.5 then
			parte(modelo, "Corrimao", Vector3.new(0.9, 0.5, z2 - z1), CFrame.new(origem + Vector3.new(xGrade, altura + 3.2, (z1 + z2) / 2)), Enum.Material.SmoothPlastic, PALETA.ouro)
		end
	end
	if zEscada then
		corrimao(inicio, zEscada - 2)
		corrimao(zEscada + 2, fim)
	else
		corrimao(inicio, fim)
	end

	-- em cima: baú na ponta longe do acesso, barris e um braseiro
	local zBau = zCentro - sentido * (comprimento / 2 - 5)
	local posBau = origem + Vector3.new(lado * (meiaL - fundo / 2 - 1), altura + 0.4, zBau)
	criarBauReliquia(sala, CFrame.lookAt(posBau, posBau + Vector3.new(-lado, 0, 0)), "alto")
	criarBraseiro(sala, origem + Vector3.new(lado * (meiaL - 3), altura + 0.4, zCentro), 0.8)
	for _ = 1, 2 do
		local p = origem + Vector3.new(lado * (meiaL - 2.5), altura + 0.4, zCentro + rng:NextNumber(-comprimento / 2 + 4, comprimento / 2 - 4))
		local barril = parte(modelo, "Barril", Vector3.new(3, 2.2, 2.2), CFrame.new(p + Vector3.new(0, 1.5, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.madeiraClara, { formato = Enum.PartType.Cylinder })
		for _, h in { -0.9, 0.9 } do
			parte(modelo, "Aro", Vector3.new(0.2, 2.3, 2.3), barril.CFrame * CFrame.new(h, 0, 0), Enum.Material.SmoothPlastic, PALETA.madeiraEscura, { formato = Enum.PartType.Cylinder, colide = false })
		end
	end
	obstaculoRetangulo(sala, centro, fundo / 2 + 0.5, comprimento / 2)
	return { lado = lado, zCentro = zCentro, comprimento = comprimento, acesso = acesso }
end

-- Torre de vigia: sobe pulando pelas pedras flutuantes em espiral; o melhor baú fica no topo
local function criarTorre(sala, rng: Random, centroLocal: Vector3)
	local origem, tema, modelo = sala.origem, sala.tema, sala.modelo
	local lado, altura = 12, ALTURA_TORRE
	local base = origem + centroLocal
	local corDetalhe, matDetalhe = tema.detalhe.cor, tema.detalhe.material
	parte(modelo, "Torre", Vector3.new(lado, altura, lado), CFrame.new(base + Vector3.new(0, altura / 2, 0)), tema.parede.material, tema.parede.cor)
	parte(modelo, "BaseTorre", Vector3.new(lado + 2.4, 2, lado + 2.4), CFrame.new(base + Vector3.new(0, 1, 0)), matDetalhe, corDetalhe)
	for _, h in { 8, 15 } do
		parte(modelo, "FaixaTorre", Vector3.new(lado + 0.7, 0.8, lado + 0.7), CFrame.new(base + Vector3.new(0, h, 0)), matDetalhe, escurecer(corDetalhe, 0.06), { colide = false })
	end
	-- janelinhas escuras
	for _, giro in { 0, math.pi / 2, math.pi, math.pi * 1.5 } do
		for _, h in { 11.5, 18.5 } do
			local cf = CFrame.new(base + Vector3.new(0, h, 0)) * CFrame.Angles(0, giro, 0) * CFrame.new(0, 0, -lado / 2 - 0.05)
			parte(modelo, "Janela", Vector3.new(1.6, 2.8, 0.2), cf, Enum.Material.SmoothPlastic, Color3.fromRGB(40, 32, 58), { colide = false, sombra = false })
			parte(modelo, "TopoJanela", Vector3.new(2.2, 0.4, 0.4), cf * CFrame.new(0, 1.6, 0), matDetalhe, corDetalhe, { colide = false })
		end
	end
	-- topo com ameias
	local topo = altura + 1
	parte(modelo, "TopoTorre", Vector3.new(lado + 2, 1, lado + 2), CFrame.new(base + Vector3.new(0, altura + 0.5, 0)), matDetalhe, corDetalhe)

	-- pedras flutuantes (cada uma num pilar fino), 4 studs mais alta que a anterior
	local angulo = rng:NextNumber(0, math.pi * 2)
	local giroSentido = if rng:NextNumber() < 0.5 then 1 else -1
	local raio = 11.5
	local ultima = Vector3.zero
	for i, h in { 4, 8, 12, 16, 20 } do
		local a = angulo + giroSentido * (i - 1) * 0.8
		local p = base + Vector3.new(math.cos(a) * raio, 0, math.sin(a) * raio)
		parte(modelo, "PedraFlutuante", Vector3.new(5.5, 1, 5.5), CFrame.new(p + Vector3.new(0, h - 0.5, 0)) * CFrame.Angles(0, a, 0), matDetalhe, PALETA.pedraClara)
		parte(modelo, "BordaPedra", Vector3.new(5.9, 0.35, 5.9), CFrame.new(p + Vector3.new(0, h - 1.1, 0)) * CFrame.Angles(0, a, 0), Enum.Material.SmoothPlastic, PALETA.ouro, { colide = false })
		parte(modelo, "Haste", Vector3.new(h - 1, 1.2, 1.2), CFrame.new(p + Vector3.new(0, (h - 1) / 2, 0)) * EM_PE, tema.parede.material, escurecer(tema.parede.cor, 0.1), { formato = Enum.PartType.Cylinder })
		obstaculo(sala, p, 3.2)
		ultima = Vector3.new(math.cos(a), 0, math.sin(a))
	end
	-- ameias, com vão do lado da última pedra (para pular para o topo)
	local meio = lado / 2 + 0.6
	for i = -2, 2 do
		for _, info in { { Vector3.new(i * 2.6, 0, -meio), Vector3.new(1.8, 1.8, 1) }, { Vector3.new(i * 2.6, 0, meio), Vector3.new(1.8, 1.8, 1) }, { Vector3.new(-meio, 0, i * 2.6), Vector3.new(1, 1.8, 1.8) }, { Vector3.new(meio, 0, i * 2.6), Vector3.new(1, 1.8, 1.8) } } do
			local rel = info[1]
			if (rel.Unit - ultima).Magnitude > 0.75 then
				parte(modelo, "Ameia", info[2], CFrame.new(base + rel + Vector3.new(0, topo + 0.9, 0)), tema.parede.material, tema.parede.cor)
			end
		end
	end
	-- bandeira e o baú no meio do topo
	local mastro = base + Vector3.new(-ultima.X * 4, topo, -ultima.Z * 4)
	parte(modelo, "Mastro", Vector3.new(0.35, 9, 0.35), CFrame.new(mastro + Vector3.new(0, 4.5, 0)), Enum.Material.SmoothPlastic, PALETA.madeiraEscura, { colide = false })
	parte(modelo, "Bandeira", Vector3.new(0.15, 2.4, 3.6), CFrame.new(mastro + Vector3.new(0, 7.6, 1.85)), Enum.Material.SmoothPlastic, PALETA.bandeira, { colide = false })
	local posBau = base + Vector3.new(0, topo, 0)
	criarBauReliquia(sala, CFrame.lookAt(posBau, posBau + ultima), "torre")
	obstaculoRetangulo(sala, base, lado / 2 + 1.2, lado / 2 + 1.2)
end

-- Muro em ruínas: pedaços de parede quebrados com vãos (o meio fica livre até a porta)
local function criarRuinas(sala, rng: Random, zLinha: number)
	local origem, tema, modelo = sala.origem, sala.tema, sala.modelo
	local meiaL = sala.largura / 2
	local x = -meiaL + FUNDO_SACADA + 6
	while x < meiaL - FUNDO_SACADA - 6 do
		local comprimento = rng:NextInteger(8, 15)
		local cx = x + comprimento / 2
		local z = zLinha + rng:NextNumber(-2.5, 2.5)
		if math.abs(cx) - comprimento / 2 > 10 and math.abs(cx) + comprimento / 2 < meiaL - FUNDO_SACADA - 4 then
			local centro = origem + Vector3.new(cx, 0, z)
			local h = rng:NextNumber(5, 9)
			parte(modelo, "Ruina", Vector3.new(comprimento, h, 2.4), CFrame.new(centro + Vector3.new(0, h / 2, 0)), tema.parede.material, tema.parede.cor)
			parte(modelo, "BaseRuina", Vector3.new(comprimento + 0.8, 0.8, 3.2), CFrame.new(centro + Vector3.new(0, 0.4, 0)), tema.detalhe.material, tema.detalhe.cor)
			-- topo quebrado: blocos de alturas diferentes
			local resto = comprimento
			local px = cx - comprimento / 2
			while resto > 1 do
				local w = math.min(resto, rng:NextNumber(2, 4.5))
				local extra = rng:NextNumber(0, 3.5)
				if extra > 0.6 then
					parte(modelo, "Ameia", Vector3.new(w, extra, 2.4), CFrame.new(origem + Vector3.new(px + w / 2, h + extra / 2, z)), tema.parede.material, escurecer(tema.parede.cor, rng:NextNumber(0, 0.06)))
				end
				px += w
				resto -= w
			end
			-- pedras caídas no chão
			for _ = 1, rng:NextInteger(1, 3) do
				local t = rng:NextNumber(0.8, 1.8)
				local p = centro + Vector3.new(rng:NextNumber(-comprimento / 2, comprimento / 2), t / 2, (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(2, 4))
				parte(modelo, "Entulho", Vector3.one * t, CFrame.new(p) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1)), tema.parede.material, escurecer(tema.parede.cor, 0.08), { colide = false })
			end
			obstaculoRetangulo(sala, centro, comprimento / 2, 1.4)
			if rng:NextNumber() < 0.55 then
				cantinhoVerde(sala, rng, centro + Vector3.new(rng:NextNumber(-comprimento / 2, comprimento / 2), 0, (if rng:NextNumber() < 0.5 then -1 else 1) * 3.5), false)
			end
		end
		x += comprimento + rng:NextInteger(9, 15)
	end
end

-- Armadilha de espinhos: placa de ferro; os espinhos sobem de tempos em tempos (Armadilhas.luau)
local function criarEspinhos(sala, pos: Vector3)
	local modelo = sala.modelo
	local placa = parte(modelo, "PlacaEspinhos", Vector3.new(8, 0.25, 8), CFrame.new(pos + Vector3.new(0, 0.12, 0)), Enum.Material.SmoothPlastic, PALETA.ferro, { sombra = false })
	for _, info in { { Vector3.new(8.4, 0.3, 0.4), Vector3.new(0, 0.15, 4) }, { Vector3.new(8.4, 0.3, 0.4), Vector3.new(0, 0.15, -4) }, { Vector3.new(0.4, 0.3, 8.4), Vector3.new(4, 0.15, 0) }, { Vector3.new(0.4, 0.3, 8.4), Vector3.new(-4, 0.15, 0) } } do
		parte(modelo, "BordaPlaca", info[1], CFrame.new(pos + info[2]), Enum.Material.SmoothPlastic, escurecer(PALETA.ferro, 0.3), { colide = false, sombra = false })
	end
	local pecas = {}
	for i = -1, 1 do
		for j = -1, 1 do
			local p = pos + Vector3.new(i * 2.5, 0, j * 2.5)
			parte(modelo, "Furo", Vector3.new(1.2, 0.05, 1.2), CFrame.new(p + Vector3.new(0, 0.27, 0)), Enum.Material.SmoothPlastic, Color3.fromRGB(34, 28, 44), { colide = false, sombra = false })
			local corpo = parte(modelo, "Espinho", Vector3.new(1.8, 0.75, 0.75), CFrame.new(p + Vector3.new(0, -1.6, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.prata, { formato = Enum.PartType.Cylinder, colide = false })
			local ponta_ = parte(modelo, "PontaEspinho", Vector3.new(1.2, 0.4, 0.4), CFrame.new(p + Vector3.new(0, -0.15, 0)) * EM_PE, Enum.Material.SmoothPlastic, Color3.fromRGB(240, 242, 250), { formato = Enum.PartType.Cylinder, colide = false })
			table.insert(pecas, { corpo, corpo.CFrame })
			table.insert(pecas, { ponta_, ponta_.CFrame })
		end
	end
	table.insert(sala.armadilhas, { tipo = "espinhos", centro = pos, meio = Vector3.new(4, 0, 4), pecas = pecas, placa = placa, corPlaca = placa.Color })
end

-- Respiradouro de fogo: grade no chão que solta um jato de chamas (fogo do pacote de VFX)
local function criarRespiradouro(sala, pos: Vector3)
	local modelo = sala.modelo
	parte(modelo, "BrasaGrade", Vector3.new(0.1, 5.4, 5.4), CFrame.new(pos + Vector3.new(0, 0.05, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.brasa, { formato = Enum.PartType.Cylinder, colide = false, sombra = false })
	parte(modelo, "AroGrade", Vector3.new(0.35, 6.4, 6.4), CFrame.new(pos + Vector3.new(0, 0.12, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.ferro, { formato = Enum.PartType.Cylinder, sombra = false })
	parte(modelo, "MioloGrade", Vector3.new(0.4, 5.2, 5.2), CFrame.new(pos + Vector3.new(0, 0.14, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.brasa, { formato = Enum.PartType.Cylinder, colide = false, sombra = false })
	for i = -2, 2 do
		parte(modelo, "Barra", Vector3.new(0.45, 0.3, 5.6 - math.abs(i) * 0.9), CFrame.new(pos + Vector3.new(i * 1.1, 0.36, 0)), Enum.Material.SmoothPlastic, escurecer(PALETA.ferro, 0.25), { colide = false, sombra = false })
	end
	local bocal = parte(modelo, "Bocal", Vector3.one, CFrame.new(pos + Vector3.new(0, 0.6, 0)), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), { colide = false, transparencia = 1, sombra = false })
	local brasas = efeitoPronto("LaminaFogo", bocal, { escala = 0.55, taxa = 0.4 })
	local jato = efeitoPronto("LaminaFogo", bocal, { escala = 2.4, velocidade = 3, ligado = false })
	local luzJato = luz(bocal, Color3.fromRGB(255, 140, 60), 20, 0, false)
	table.insert(sala.armadilhas, { tipo = "fogo", centro = pos, meio = Vector3.new(3.2, 0, 3.2), jato = jato, brasas = brasas, luz = luzJato })
end

-- Relicário: estrado com colunas e o baú acorrentado (abre quando o mini-chefe cai)
local function criarRelicario(sala, centro: Vector3)
	local tema, modelo = sala.tema, sala.modelo
	parte(modelo, "Estrado", Vector3.new(1.2, 20, 20), CFrame.new(centro + Vector3.new(0, 0.6, 0)) * EM_PE, tema.detalhe.material, tema.detalhe.cor, { formato = Enum.PartType.Cylinder })
	parte(modelo, "AroEstrado", Vector3.new(0.3, 20.6, 20.6), CFrame.new(centro + Vector3.new(0, 1.05, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.ouro, { formato = Enum.PartType.Cylinder, colide = false })
	parte(modelo, "MioloEstrado", Vector3.new(0.1, 14, 14), CFrame.new(centro + Vector3.new(0, 1.22, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.bandeira, { formato = Enum.PartType.Cylinder, colide = false, sombra = false })
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local p = centro + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8)
		parte(modelo, "ColunaRelicario", Vector3.new(9, 1.6, 1.6), CFrame.new(p + Vector3.new(0, 5.7, 0)) * EM_PE, tema.parede.material, PALETA.lilas, { formato = Enum.PartType.Cylinder })
		parte(modelo, "CapitelRelicario", Vector3.new(2.4, 0.8, 2.4), CFrame.new(p + Vector3.new(0, 10.4, 0)), Enum.Material.SmoothPlastic, PALETA.ouro)
		local chama = parte(modelo, "Brasa", Vector3.new(1, 0.4, 1), CFrame.new(p + Vector3.new(0, 11, 0)), Enum.Material.SmoothPlastic, PALETA.brasa, { colide = false })
		fogo(chama, Color3.fromRGB(140, 255, 170), 2)
		luz(chama, Color3.fromRGB(140, 255, 170), 16, 1.2, true)
		obstaculo(sala, p, 1.4)
	end
	local posBau = centro + Vector3.new(0, 1.2, 0)
	local paraEntrada = planar(sala.spawn.Position - centro).Unit
	local bau = criarBauReliquia(sala, CFrame.lookAt(posBau, posBau + paraEntrada), "relicario")
	bau.travado = true
	bau.prompt.Enabled = false
	-- correntes cruzando o baú
	bau.correntes = {}
	for _, giro in { math.rad(35), math.rad(-35) } do
		local corrente = parte(modelo, "Corrente", Vector3.new(0.35, 0.35, 7.4), CFrame.new(posBau + Vector3.new(0, 1.8, 0)) * CFrame.lookAt(Vector3.zero, paraEntrada).Rotation * CFrame.Angles(0, math.rad(90), giro), Enum.Material.SmoothPlastic, PALETA.ferro, { colide = false })
		table.insert(bau.correntes, corrente)
	end
	sala.relicario = bau
	sala.posMiniChefe = centro + paraEntrada * 13
end

-- Tapete do caminho principal (da entrada até a porta), com bordas douradas
local function criarTapete(sala)
	local origem, modelo = sala.origem, sala.modelo
	local meiaC = sala.comprimento / 2
	local inicio, fim = -meiaC + 13, meiaC - 1
	local centro = origem + Vector3.new(0, 0.03, (inicio + fim) / 2)
	parte(modelo, "Tapete", Vector3.new(8, 0.06, fim - inicio), CFrame.new(centro), Enum.Material.SmoothPlastic, PALETA.bandeira, { colide = false, sombra = false })
	for _, x in { -4.3, 4.3 } do
		parte(modelo, "BordaTapete", Vector3.new(0.6, 0.08, fim - inicio), CFrame.new(centro + Vector3.new(x, 0.01, 0)), Enum.Material.SmoothPlastic, PALETA.ouro, { colide = false, sombra = false })
	end
	-- losangos dourados ao longo do tapete
	for z = inicio + 8, fim - 6, 16 do
		parte(modelo, "Losango", Vector3.new(2.6, 0.08, 2.6), CFrame.new(origem + Vector3.new(0, 0.05, z)) * CFrame.Angles(0, math.rad(45), 0), Enum.Material.SmoothPlastic, PALETA.ouro, { colide = false, sombra = false })
	end
end

-- Colunas dos dois lados do tapete, cada uma com uma tocha virada para o caminho
local function criarColunata(sala, rng: Random)
	local origem, tema, modelo = sala.origem, sala.tema, sala.modelo
	local meiaC = sala.comprimento / 2
	local altura = 17
	for z = -meiaC + 30, meiaC - 26, 24 do
		local perto = false
		for i = 2, 3 do
			if math.abs(z - sala.areas[i].inicio) < 9 then
				perto = true
			end
		end
		for _, lado in { -1, 1 } do
			local pos = origem + Vector3.new(lado * 17, 0, z + rng:NextNumber(-1.5, 1.5))
			if not perto and livre(sala, pos, 3.5) then
				parte(modelo, "Coluna", Vector3.new(altura, 2.6, 2.6), CFrame.new(pos + Vector3.new(0, altura / 2, 0)) * EM_PE, tema.parede.material, PALETA.lilas, { formato = Enum.PartType.Cylinder })
				parte(modelo, "BaseColuna", Vector3.new(4, 1.4, 4), CFrame.new(pos + Vector3.new(0, 0.7, 0)), tema.detalhe.material, tema.detalhe.cor)
				parte(modelo, "AnelColuna", Vector3.new(0.6, 3, 3), CFrame.new(pos + Vector3.new(0, 4, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.ouro, { formato = Enum.PartType.Cylinder, colide = false })
				parte(modelo, "CapitelColuna", Vector3.new(3.8, 1.2, 3.8), CFrame.new(pos + Vector3.new(0, altura + 0.6, 0)), tema.detalhe.material, tema.detalhe.cor)
				parte(modelo, "TopoColuna", Vector3.new(0.5, 3.2, 3.2), CFrame.new(pos + Vector3.new(0, altura + 1.45, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.ouro, { formato = Enum.PartType.Cylinder, colide = false })
				criarArandela(sala, pos + Vector3.new(-lado * 1.3, 9, 0), Vector3.new(-lado, 0, 0))
				obstaculo(sala, pos, 2.2)
			end
		end
	end
end

-- Estátua de um herói antigo num pedestal: marco no meio da sala (dá para subir no pedestal)
local function criarEstatua(sala, rng: Random, pos: Vector3)
	local tema, modelo = sala.tema, sala.modelo
	local pedra = PALETA.pedraClara
	local frente = planar(sala.spawn.Position - pos).Unit
	local base = CFrame.lookAt(pos, pos + frente)
	parte(modelo, "BaseEstatua", Vector3.new(1.6, 13, 13), CFrame.new(pos + Vector3.new(0, 0.8, 0)) * EM_PE, tema.detalhe.material, tema.detalhe.cor, { formato = Enum.PartType.Cylinder })
	parte(modelo, "AroEstatua", Vector3.new(0.3, 13.6, 13.6), CFrame.new(pos + Vector3.new(0, 1.45, 0)) * EM_PE, Enum.Material.SmoothPlastic, PALETA.ouro, { formato = Enum.PartType.Cylinder, colide = false })
	parte(modelo, "Pedestal", Vector3.new(4.5, 4, 4.5), base * CFrame.new(0, 3.6, 0), tema.parede.material, PALETA.lilas)
	parte(modelo, "TopoPedestal", Vector3.new(5.2, 0.6, 5.2), base * CFrame.new(0, 5.9, 0), Enum.Material.SmoothPlastic, PALETA.ouro)
	-- o herói: pernas, corpo, capa, cabeça, espada fincada e escudo
	local corpo = base * CFrame.new(0, 6.2, 0)
	for _, x in { -0.55, 0.55 } do
		parte(modelo, "PernaEstatua", Vector3.new(0.9, 2.6, 1), corpo * CFrame.new(x, 1.3, 0), Enum.Material.SmoothPlastic, pedra)
	end
	parte(modelo, "TroncoEstatua", Vector3.new(2.4, 2.8, 1.4), corpo * CFrame.new(0, 4, 0), Enum.Material.SmoothPlastic, pedra)
	parte(modelo, "CapaEstatua", Vector3.new(2.6, 4.6, 0.4), corpo * CFrame.new(0, 3.3, 0.85) * CFrame.Angles(math.rad(8), 0, 0), Enum.Material.SmoothPlastic, PALETA.bandeira)
	parte(modelo, "OmbreiraEstatua", Vector3.new(3.2, 0.7, 1.6), corpo * CFrame.new(0, 5.3, 0), Enum.Material.SmoothPlastic, PALETA.ouro)
	parte(modelo, "CabecaEstatua", Vector3.one * 1.5, corpo * CFrame.new(0, 6.3, 0), Enum.Material.SmoothPlastic, pedra, { formato = Enum.PartType.Ball })
	parte(modelo, "ElmoEstatua", Vector3.new(0.5, 1.7, 1.7), corpo * CFrame.new(0, 6.6, 0) * EM_PE, Enum.Material.SmoothPlastic, PALETA.ouro, { formato = Enum.PartType.Cylinder })
	parte(modelo, "EspadaEstatua", Vector3.new(0.35, 4.4, 0.7), corpo * CFrame.new(0, 2.4, -1.4), Enum.Material.SmoothPlastic, PALETA.prata)
	parte(modelo, "GuardaEstatua", Vector3.new(2, 0.35, 0.5), corpo * CFrame.new(0, 4.4, -1.4), Enum.Material.SmoothPlastic, PALETA.ouro)
	for _, x in { -0.5, 0.5 } do
		parte(modelo, "MaoEstatua", Vector3.new(0.6, 0.6, 0.6), corpo * CFrame.new(x * 0.6, 4.6, -1.35), Enum.Material.SmoothPlastic, pedra, { colide = false })
	end
	parte(modelo, "EscudoEstatua", Vector3.new(0.3, 2.6, 2.6), corpo * CFrame.new(-1.6, 3.6, -0.2) * CFrame.Angles(0, math.rad(80), 0) * EM_PE, Enum.Material.SmoothPlastic, PALETA.bandeira, { formato = Enum.PartType.Cylinder })
	-- braseiros dos lados e um pouco de verde em volta
	for _, x in { -5.5, 5.5 } do
		criarBraseiro(sala, (base * CFrame.new(x, 1.6, -2)).Position, 0.75)
	end
	cantinhoVerde(sala, rng, (base * CFrame.new(0, 0, 8)).Position, false)
	obstaculoRetangulo(sala, pos, 6.8, 6.8)
end

local function criarExploracao(sala, rng: Random)
	local origem = sala.origem
	local meiaL, meiaC = sala.largura / 2, sala.comprimento / 2
	local terco = sala.comprimento / 3
	sala.areas = {
		{ inicio = -meiaC, fim = -meiaC + terco },
		{ inicio = -meiaC + terco, fim = -meiaC + 2 * terco },
		{ inicio = -meiaC + 2 * terco, fim = meiaC },
	}

	-- sacadas: uma na 1ª área e outra na 3ª, em lados opostos; acessos sorteados
	local ladoA = if rng:NextNumber() < 0.5 then -1 else 1
	local acessoA = if rng:NextNumber() < 0.5 then "mao" else "pedra"
	local acessoB = if acessoA == "mao" then "pedra" else "mao"
	criarSacada(sala, rng, ladoA, -meiaC + sala.comprimento * 0.2, 40, acessoA, 1)
	criarSacada(sala, rng, -ladoA, meiaC - sala.comprimento * 0.2, 40, acessoB, -1)
	-- torre no meio da sala, de um lado
	local ladoTorre = if rng:NextNumber() < 0.5 then -1 else 1
	criarTorre(sala, rng, Vector3.new(ladoTorre * meiaL * 0.42, 0, rng:NextNumber(-10, 10)))
	criarEstatua(sala, rng, origem + Vector3.new(-ladoTorre * meiaL * 0.4, 0, rng:NextNumber(-8, 8)))
	criarTapete(sala)
	-- muros em ruínas entre as áreas
	criarRuinas(sala, rng, sala.areas[2].inicio)
	criarRuinas(sala, rng, sala.areas[3].inicio)
	-- relicário do mini-chefe na última área
	if sala.miniChefe then
		criarRelicario(sala, origem + Vector3.new(ladoA * meiaL * 0.3, 0, meiaC - 36))
	end

	criarColunata(sala, rng)

	-- baús no chão, encostados nas paredes, com espinhos na frente
	local baus = 0
	for _ = 1, 60 do
		if baus >= 2 then
			break
		end
		local lado = if rng:NextNumber() < 0.5 then -1 else 1
		local pos = origem + Vector3.new(lado * (meiaL - 4), 0, rng:NextNumber(-meiaC + 30, meiaC - 20))
		local dentro = Vector3.new(-lado, 0, 0)
		local frente = pos + dentro * 7
		local longeDosOutros = true
		for _, outro in sala.baus do
			if planar(outro.pos - pos).Magnitude < 40 then
				longeDosOutros = false
			end
		end
		if longeDosOutros and livre(sala, pos, 4) and livre(sala, frente, 5) then
			criarBauReliquia(sala, CFrame.lookAt(pos, pos + dentro), "chao")
			obstaculo(sala, pos, 2.6)
			criarEspinhos(sala, frente)
			cantinhoVerde(sala, rng, pos + Vector3.new(0, 0, (if rng:NextNumber() < 0.5 then -1 else 1) * 5), true)
			baus += 1
		end
	end

	-- armadilhas soltas pela 2ª e 3ª áreas (e uma no pé de cada escada de mão)
	local function colocar(criar, raio: number, quantidade: number)
		local postas = 0
		for _ = 1, 50 do
			if postas >= quantidade then
				break
			end
			local area = sala.areas[rng:NextInteger(2, 3)]
			local pos = origem + Vector3.new(rng:NextNumber(-meiaL + 20, meiaL - 20), 0, rng:NextNumber(area.inicio + 8, area.fim - 12))
			local longe = true
			for _, outra in sala.armadilhas do
				if planar(outra.centro - pos).Magnitude < 16 then
					longe = false
				end
			end
			-- o tapete (caminho principal) fica livre: as armadilhas guardam o que está fora dele
			if longe and math.abs(pos.X - origem.X) > raio + 6 and livre(sala, pos, raio) then
				criar(sala, pos)
				postas += 1
			end
		end
	end
	colocar(criarEspinhos, 5, rng:NextInteger(2, 3))
	colocar(criarRespiradouro, 4, rng:NextInteger(2, 3))
	-- as armadilhas também não recebem inimigos nem decoração por cima
	for _, armadilha in sala.armadilhas do
		table.insert(sala.blocos, { centro = armadilha.centro, meio = armadilha.meio + Vector3.new(1, 0, 1) })
	end

	-- braseiros onde couber (cantos e meio das laterais) e cantinhos verdes
	for _, p in {
		Vector3.new(-meiaL + 5, 0, -meiaC + 5), Vector3.new(meiaL - 5, 0, -meiaC + 5),
		Vector3.new(-meiaL + 5, 0, 0), Vector3.new(meiaL - 5, 0, 0),
		Vector3.new(-meiaL + 5, 0, meiaC - 5), Vector3.new(meiaL - 5, 0, meiaC - 5),
		Vector3.new(-12, 0, sala.areas[2].inicio - 6), Vector3.new(12, 0, sala.areas[2].inicio - 6),
		Vector3.new(-12, 0, sala.areas[3].inicio - 6), Vector3.new(12, 0, sala.areas[3].inicio - 6),
	} do
		local pos = origem + p
		if Masmorra.posicaoValida(sala, pos, 2) then
			criarBraseiro(sala, pos, if math.abs(p.Z) < 1 then 1.2 else 1)
		end
	end
	for _ = 1, 12 do
		local pos, dentro = pontoNaParede(sala, rng, 4)
		if livre(sala, pos, 4) then
			cantinhoVerde(sala, rng, pos + dentro * 0.5, rng:NextNumber() < 0.6)
		end
	end
end

-- Área (1 a 3) em que fica um ponto da sala de exploração
function Masmorra.areaDe(sala, pos: Vector3): number
	local z = (pos - sala.origem).Z
	for i, area in sala.areas or {} do
		if z < area.fim then
			return i
		end
	end
	return 3
end

-- Ponto no chão para um inimigo dentro de uma área da sala de exploração
function Masmorra.posicaoNaArea(sala, rng: Random, indice: number): Vector3
	local area = sala.areas[indice]
	local meiaL = sala.largura / 2
	local entrada = sala.spawn.Position
	for _ = 1, 40 do
		local pos = sala.origem + Vector3.new(rng:NextNumber(-meiaL + 6, meiaL - 6), 0, rng:NextNumber(area.inicio + 6, area.fim - 6))
		if livre(sala, pos, 3) and planar(pos - entrada).Magnitude > 30 then
			return pos
		end
	end
	return sala.origem + Vector3.new(0, 0, (area.inicio + area.fim) / 2)
end

-- Abre um baú de relíquia (tampa sobe, o brilho apaga)
function Masmorra.abrirBauReliquia(bau)
	bau.aberto = true
	bau.prompt.Enabled = false
	bau.brilho.Rate = 0
	TweenService:Create(bau.tampa, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
		CFrame = bau.tampa.CFrame * CFrame.new(0, 0.9, 1.4) * CFrame.Angles(math.rad(-70), 0, 0),
	}):Play()
	TweenService:Create(bau.luz, TweenInfo.new(1.2), { Brightness = 0 }):Play()
end

-- O mini-chefe caiu: as correntes caem e o relicário pode ser aberto
function Masmorra.destravarRelicario(sala)
	local bau = sala.relicario
	if not bau or not bau.travado then
		return
	end
	bau.travado = false
	bau.prompt.Enabled = true
	bau.brilho.Rate = 30
	for _, corrente in bau.correntes do
		corrente.Anchored = false
		corrente.CanCollide = true
		task.delay(3, function()
			corrente:Destroy()
		end)
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

-- Cria uma sala nova. "origem" é o centro do chão (a superfície fica em origem.Y).
function Masmorra.construir(origem: Vector3, numero: number, tipo: string, rng: Random, opcoes)
	opcoes = opcoes or {}
	local tema = Config.temaDaSala(numero)
	local exploracao = tipo == "combate" and tema.exploracao == true
	local largura, comprimento
	-- salas amplas: espaço para esquivar, cercar e lutar em grupo
	if exploracao then
		local info = Config.EXPLORACAO
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
		altura = if exploracao then Config.EXPLORACAO.altura else ALTURA_PAREDE,
		exploracao = exploracao,
		miniChefe = exploracao and opcoes.miniChefe == true,
		pilares = {},
		perigos = {},
		blocos = {}, -- áreas onde nada aparece (sacadas, torre, ruínas, armadilhas)
		baus = {}, -- baús de relíquia (sala de exploração e o tesouro do chefe)
		armadilhas = {},
		spawn = CFrame.lookAt(origem + Vector3.new(0, 3, -comprimento / 2 + 7), origem + Vector3.new(0, 3, comprimento / 2)),
	}
	estiloLiso = tema.estilo == "fantasia"

	criarChao(sala, rng)
	criarParedes(sala)
	criarPorta(sala)
	criarEntrada(sala)
	criarPilares(sala, rng)
	criarLava(sala, rng)
	if exploracao then
		criarExploracao(sala, rng)
	end
	criarDecoracao(sala, rng)
	criarAtmosfera(sala)
	if tipo == "chefe" then
		criarSalaDoChefe(sala)
	elseif tipo == "tesouro" then
		criarBau(sala)
	elseif not exploracao then
		-- braseiros nos cantos da entrada e no meio das laterais (iluminam a sala grande)
		local meiaL, meiaC = largura / 2, comprimento / 2
		criarBraseiro(sala, origem + Vector3.new(-meiaL + 5, 0, -meiaC + 5), 1)
		criarBraseiro(sala, origem + Vector3.new(meiaL - 5, 0, -meiaC + 5), 1)
		criarBraseiro(sala, origem + Vector3.new(-meiaL + 5, 0, 0), 1.2)
		criarBraseiro(sala, origem + Vector3.new(meiaL - 5, 0, 0), 1.2)
		criarBraseiro(sala, origem + Vector3.new(-meiaL + 5, 0, meiaC - 5), 1)
		criarBraseiro(sala, origem + Vector3.new(meiaL - 5, 0, meiaC - 5), 1)
	end
	estiloLiso = false
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
