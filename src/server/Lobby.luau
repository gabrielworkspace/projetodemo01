-- Lobby (o acampamento): terreno, altares das classes, portal da masmorra e loja do mercador.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Classes = require(Shared:WaitForChild("Classes"))

local servidor = script.Parent
local Remotos = require(servidor.Remotos)
local Dados = require(servidor.Dados)
local Vfx = require(servidor.Vfx)
local Armas = require(servidor.Armas)
local Partida = require(servidor.Partida)

local Lobby = {}

local POSICAO_PORTAL = Vector3.new(0, 0, -46)
local RAIO_PORTAL = 9
local EM_PE = CFrame.Angles(0, 0, math.rad(90))
local ROXO = Color3.fromRGB(150, 70, 255)
local PEDRA = Color3.fromRGB(120, 116, 122)
local PEDRA_ESCURA = Color3.fromRGB(72, 68, 76)
local MADEIRA = Color3.fromRGB(100, 68, 44)

local modelo = Instance.new("Model")
modelo.Name = "Lobby"

local function parte(nome: string, tamanho: Vector3, cframe: CFrame, material: Enum.Material, cor: Color3, opcoes): Part
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
	if opcoes.colide == false then
		p.CanQuery = false
		p.CanTouch = false
	end
	p.CastShadow = opcoes.sombra ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = opcoes.pai or modelo
	return p
end

local function luz(pai: Instance, cor: Color3, alcance: number, brilho: number, tremula: boolean?)
	local l = Instance.new("PointLight")
	l.Color = cor
	l.Range = alcance
	l.Brightness = brilho
	l.Parent = pai
	if tremula then
		CollectionService:AddTag(l, "Chama")
	end
end

local function sequencia(pontos): NumberSequence
	local chaves = {}
	for _, ponto in pontos do
		table.insert(chaves, NumberSequenceKeypoint.new(ponto[1], ponto[2]))
	end
	return NumberSequence.new(chaves)
end

local function particulas(pai: Instance, propriedades)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for chave, valor in propriedades do
		(e :: any)[chave] = valor
	end
	e.Parent = pai
	return e
end

local function letreiro(posicao: Vector3, titulo: string, subtitulo: string, cor: Color3)
	local ancora = parte("Letreiro", Vector3.one, CFrame.new(posicao), Enum.Material.SmoothPlastic, cor, { colide = false, transparencia = 1 })
	local placa = Instance.new("BillboardGui")
	placa.Size = UDim2.fromScale(20, 5)
	placa.MaxDistance = 160
	placa.LightInfluence = 0
	placa.Parent = ancora

	local textoTitulo = Instance.new("TextLabel")
	textoTitulo.Size = UDim2.fromScale(1, 0.62)
	textoTitulo.BackgroundTransparency = 1
	textoTitulo.FontFace = Font.new(Font.fromEnum(Enum.Font.Merriweather).Family, Enum.FontWeight.Bold)
	textoTitulo.Text = titulo
	textoTitulo.TextColor3 = cor
	textoTitulo.TextScaled = true
	textoTitulo.TextStrokeTransparency = 0.25
	textoTitulo.Parent = placa

	local textoSub = Instance.new("TextLabel")
	textoSub.Position = UDim2.fromScale(0, 0.64)
	textoSub.Size = UDim2.fromScale(1, 0.34)
	textoSub.BackgroundTransparency = 1
	textoSub.FontFace = Font.new(Font.fromEnum(Enum.Font.BuilderSans).Family, Enum.FontWeight.Bold)
	textoSub.Text = subtitulo
	textoSub.TextColor3 = Color3.fromRGB(245, 238, 220)
	textoSub.TextScaled = true
	textoSub.TextStrokeTransparency = 0.35
	textoSub.Parent = placa
end

------------------------------------------------------------------------
-- Terreno
------------------------------------------------------------------------

local function construirTerreno()
	local terreno = workspace.Terrain
	terreno:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(96, 150, 66))
	terreno:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(80, 132, 58))
	terreno:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(122, 96, 70))
	terreno:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(112, 108, 104))

	terreno:FillBlock(CFrame.new(0, -8, 0), Vector3.new(320, 16, 320), Enum.Material.Grass)

	-- Colinas em volta (fecham o acampamento num vale)
	local rng = Random.new(7)
	for i = 0, 23 do
		local angulo = i / 24 * math.pi * 2
		local distancia = rng:NextNumber(128, 148)
		local centro = Vector3.new(math.cos(angulo) * distancia, rng:NextNumber(-6, 4), math.sin(angulo) * distancia)
		local material = if i % 3 == 0 then Enum.Material.Rock else Enum.Material.LeafyGrass
		terreno:FillBall(centro, rng:NextNumber(26, 40), material)
	end

	-- Caminhos de terra até o portal, os altares e a loja
	terreno:FillBlock(CFrame.new(0, -2, -24), Vector3.new(12, 4, 44), Enum.Material.Ground)
	terreno:FillBlock(CFrame.new(-26, -2, 0), Vector3.new(30, 4, 10), Enum.Material.Ground)
	terreno:FillBlock(CFrame.new(26, -2, 0), Vector3.new(30, 4, 10), Enum.Material.Ground)
	terreno:FillBlock(CFrame.new(0, -2, 26), Vector3.new(10, 4, 26), Enum.Material.Ground)

	-- Lago
	terreno:FillCylinder(CFrame.new(72, -3, 58), 6, 17, Enum.Material.Air)
	terreno:FillCylinder(CFrame.new(72, -4.5, 58), 3, 16, Enum.Material.Water)
	for i = 1, 6 do
		local angulo = i / 6 * math.pi * 2 + 0.4
		terreno:FillBall(Vector3.new(72 + math.cos(angulo) * 17, -1, 58 + math.sin(angulo) * 17), rng:NextNumber(2.5, 4), Enum.Material.Rock)
	end
end

------------------------------------------------------------------------
-- Decoração
------------------------------------------------------------------------

local function lanterna(posicao: Vector3)
	parte("Poste", Vector3.new(0.6, 7, 0.6), CFrame.new(posicao + Vector3.new(0, 3.5, 0)), Enum.Material.Wood, MADEIRA)
	parte("Braco", Vector3.new(0.4, 0.4, 1.8), CFrame.new(posicao + Vector3.new(0, 6.8, -0.7)), Enum.Material.Wood, MADEIRA)
	local caixa = parte("Lanterna", Vector3.new(0.9, 1.2, 0.9), CFrame.new(posicao + Vector3.new(0, 6, -1.4)), Enum.Material.Glass, Color3.fromRGB(255, 220, 150), { colide = false, transparencia = 0.3 })
	local chama = parte("Chama", Vector3.one * 0.45, caixa.CFrame, Enum.Material.Neon, Color3.fromRGB(255, 190, 90), { colide = false, sombra = false })
	luz(chama, Color3.fromRGB(255, 190, 110), 18, 1.4, true)
end

local function braseiro(posicao: Vector3)
	parte("Pe", Vector3.new(3, 1.2, 1.2), CFrame.new(posicao + Vector3.new(0, 1.5, 0)) * EM_PE, Enum.Material.Slate, PEDRA_ESCURA, { formato = Enum.PartType.Cylinder })
	local tigela = parte("Tigela", Vector3.new(1, 2.8, 2.8), CFrame.new(posicao + Vector3.new(0, 3.3, 0)) * EM_PE, Enum.Material.Metal, Color3.fromRGB(70, 60, 54), { formato = Enum.PartType.Cylinder })
	local brasa = parte("Brasa", Vector3.new(0.3, 2.2, 2.2), tigela.CFrame * CFrame.new(0.5, 0, 0), Enum.Material.Neon, Color3.fromRGB(255, 150, 60), { formato = Enum.PartType.Cylinder, colide = false })
	local fogo = Instance.new("Fire")
	fogo.Size = 4
	fogo.Heat = 8
	fogo.Parent = brasa
	particulas(brasa, {
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 90, 30)),
		LightEmission = 1,
		Size = sequencia({ { 0, 0.25 }, { 1, 0 } }),
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(20, 20),
		Acceleration = Vector3.new(0, 3, 0),
		Rate = 12,
		EmissionDirection = Enum.NormalId.Top,
	})
	luz(brasa, Color3.fromRGB(255, 160, 80), 26, 2, true)
end

local function carvalho(x: number, z: number, escala: number, rng: Random)
	local tronco = Color3.fromRGB(96, 66, 44)
	parte("Tronco", Vector3.new(10 * escala, 2.4 * escala, 2.4 * escala), CFrame.new(x, 5 * escala, z) * EM_PE, Enum.Material.Wood, tronco, { formato = Enum.PartType.Cylinder })
	parte("Galho", Vector3.new(4 * escala, 1 * escala, 1 * escala), CFrame.new(x + 1.4 * escala, 8.5 * escala, z) * CFrame.Angles(0, 0, math.rad(40)), Enum.Material.Wood, tronco, { formato = Enum.PartType.Cylinder })
	for _ = 1, 4 do
		local deslocamento = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(10, 14), rng:NextNumber(-3, 3)) * escala
		local verde = Color3.fromRGB(64, 128, 52):Lerp(Color3.fromRGB(110, 160, 60), rng:NextNumber())
		parte("Copa", Vector3.one * rng:NextNumber(7, 10) * escala, CFrame.new(Vector3.new(x, 0, z) + deslocamento), Enum.Material.LeafyGrass, verde, { formato = Enum.PartType.Ball, colide = false })
	end
end

local function pinheiro(x: number, z: number, escala: number)
	parte("Tronco", Vector3.new(6 * escala, 1.6 * escala, 1.6 * escala), CFrame.new(x, 3 * escala, z) * EM_PE, Enum.Material.Wood, Color3.fromRGB(86, 58, 40), { formato = Enum.PartType.Cylinder })
	for i = 0, 3 do
		local largura = (9 - i * 2) * escala
		parte("Folhas", Vector3.new(3 * escala, largura, largura), CFrame.new(x, (5 + i * 3) * escala, z) * EM_PE, Enum.Material.LeafyGrass, Color3.fromRGB(48, 96, 60), { formato = Enum.PartType.Cylinder, colide = false })
	end
end

local function construirPraca()
	parte("Praca", Vector3.new(1, 62, 62), CFrame.new(0, -0.38, 0) * EM_PE, Enum.Material.Cobblestone, PEDRA, { formato = Enum.PartType.Cylinder })
	parte("AnelPraca", Vector3.new(1.05, 40, 40), CFrame.new(0, -0.36, 0) * EM_PE, Enum.Material.Slate, PEDRA_ESCURA, { formato = Enum.PartType.Cylinder })
	parte("MioloPraca", Vector3.new(1.1, 37, 37), CFrame.new(0, -0.34, 0) * EM_PE, Enum.Material.Cobblestone, Color3.fromRGB(135, 130, 128), { formato = Enum.PartType.Cylinder })

	-- Obelisco com cristal flutuante no centro
	parte("BaseObelisco", Vector3.new(7, 1.4, 7), CFrame.new(0, 0.7, 0), Enum.Material.Slate, PEDRA_ESCURA)
	parte("Degrau", Vector3.new(5, 1, 5), CFrame.new(0, 1.9, 0), Enum.Material.Slate, PEDRA)
	parte("Obelisco", Vector3.new(2.6, 10, 2.6), CFrame.new(0, 7.4, 0), Enum.Material.Marble, Color3.fromRGB(190, 186, 196))
	for _, lado in { 0, 1, 2, 3 } do
		parte("Runa", Vector3.new(0.2, 6, 0.6), CFrame.new(0, 7.4, 0) * CFrame.Angles(0, lado * math.pi / 2, 0) * CFrame.new(1.32, 0, 0), Enum.Material.Neon, Color3.fromRGB(120, 200, 255), { colide = false, sombra = false })
	end
	local cristal = Instance.new("Model")
	cristal.Name = "CristalFlutuante"
	local nucleo = parte("Cristal", Vector3.new(2.4, 4, 2.4), CFrame.new(0, 16, 0) * CFrame.Angles(0, math.rad(45), 0), Enum.Material.Neon, Color3.fromRGB(110, 200, 255), { colide = false, pai = cristal })
	parte("Anel", Vector3.new(0.3, 6, 6), CFrame.new(0, 16, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(20), 0, 0), Enum.Material.Metal, Color3.fromRGB(230, 190, 90), { formato = Enum.PartType.Cylinder, colide = false, pai = cristal })
	cristal.PrimaryPart = nucleo
	cristal:SetAttribute("Giro", 0.6)
	cristal:SetAttribute("Flutuar", 0.8)
	CollectionService:AddTag(cristal, "Girar")
	cristal.Parent = modelo
	luz(nucleo, Color3.fromRGB(110, 200, 255), 30, 2.5)
	particulas(nucleo, {
		Color = ColorSequence.new(Color3.fromRGB(160, 220, 255)),
		LightEmission = 1,
		Size = sequencia({ { 0, 0 }, { 0.4, 0.5 }, { 1, 0 } }),
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 15,
	})

	for _, angulo in { 45, 135, 225, 315 } do
		local r = math.rad(angulo)
		braseiro(Vector3.new(math.cos(r) * 17, 0, math.sin(r) * 17))
	end

	-- Ponto de nascimento (invisível, no meio da praça, de frente para o portal)
	local nascimento = Instance.new("SpawnLocation")
	nascimento.Name = "Nascimento"
	nascimento.Anchored = true
	nascimento.Size = Vector3.new(10, 1, 6)
	nascimento.CFrame = CFrame.new(0, 0.2, 22)
	nascimento.Transparency = 1
	nascimento.CanCollide = false
	nascimento.CanQuery = false
	nascimento.Neutral = true
	nascimento.Duration = 0
	nascimento.Parent = modelo
end

local function construirPortal()
	local z = -64
	local corPedra = Color3.fromRGB(78, 72, 84)
	parte("Muralha", Vector3.new(60, 28, 7), CFrame.new(0, 14, z), Enum.Material.Brick, corPedra)
	parte("Ameias", Vector3.new(60, 2, 7.6), CFrame.new(0, 28.6, z), Enum.Material.Slate, PEDRA_ESCURA)
	for i = -6, 6, 2 do
		parte("Ameia", Vector3.new(3, 3, 7.6), CFrame.new(i * 4.6, 31, z), Enum.Material.Brick, corPedra)
	end
	for _, x in { -30, 30 } do
		parte("Torre", Vector3.new(38, 12, 12), CFrame.new(x, 19, z) * EM_PE, Enum.Material.Brick, corPedra:Lerp(Color3.new(0, 0, 0), 0.12), { formato = Enum.PartType.Cylinder })
		parte("Teto", Vector3.new(2, 14, 14), CFrame.new(x, 39, z) * EM_PE, Enum.Material.Slate, PEDRA_ESCURA, { formato = Enum.PartType.Cylinder })
		local bandeira = parte("Bandeira", Vector3.new(0.2, 12, 5), CFrame.new(x, 20, z + 6.2) * CFrame.Angles(0, math.rad(90), 0), Enum.Material.Fabric, Color3.fromRGB(110, 40, 150), { colide = false })
		parte("Simbolo", Vector3.new(0.25, 2.4, 2.4), bandeira.CFrame * CFrame.new(-0.05, 2, 0) * CFrame.Angles(math.rad(45), 0, 0), Enum.Material.Neon, Color3.fromRGB(230, 190, 90), { colide = false })
		lanterna(Vector3.new(x * 0.62, 0, z + 8))
	end

	-- Arco do portal
	local corArco = Color3.fromRGB(52, 46, 60)
	for _, x in { -9.5, 9.5 } do
		parte("Coluna", Vector3.new(3, 22, 3.4), CFrame.new(x, 11, z + 4), Enum.Material.Slate, corArco)
	end
	parte("Verga", Vector3.new(22, 3, 3.4), CFrame.new(0, 23.5, z + 4), Enum.Material.Slate, corArco)
	parte("Chave", Vector3.new(3.4, 3.4, 3.6), CFrame.new(0, 24, z + 4.2) * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Neon, ROXO, { colide = false })

	-- Vórtice (o centro gira no computador de cada jogador)
	local vortice = Instance.new("Model")
	vortice.Name = "Vortice"
	local disco = parte("Disco", Vector3.new(0.4, 18, 18), CFrame.new(0, 11, z + 4) * CFrame.Angles(0, math.rad(90), 0), Enum.Material.Neon, Color3.fromRGB(90, 30, 170), { formato = Enum.PartType.Cylinder, colide = false, pai = vortice, transparencia = 0.15 })
	parte("Espiral", Vector3.new(0.5, 13, 2), disco.CFrame * CFrame.new(-0.1, 0, 0), Enum.Material.Neon, Color3.fromRGB(190, 120, 255), { colide = false, pai = vortice, transparencia = 0.3 })
	parte("Espiral", Vector3.new(0.5, 2, 13), disco.CFrame * CFrame.new(-0.1, 0, 0), Enum.Material.Neon, Color3.fromRGB(190, 120, 255), { colide = false, pai = vortice, transparencia = 0.3 })
	parte("Miolo", Vector3.new(0.6, 6, 6), disco.CFrame * CFrame.new(-0.15, 0, 0), Enum.Material.Neon, Color3.fromRGB(255, 220, 255), { formato = Enum.PartType.Cylinder, colide = false, pai = vortice, transparencia = 0.2 })
	vortice.PrimaryPart = disco
	vortice:SetAttribute("Giro", 1.4)
	vortice:SetAttribute("EixoGiro", "X")
	CollectionService:AddTag(vortice, "Girar")
	vortice.Parent = modelo
	luz(disco, ROXO, 45, 3)
	particulas(disco, {
		Color = ColorSequence.new(Color3.fromRGB(210, 160, 255), ROXO),
		LightEmission = 1,
		Size = sequencia({ { 0, 0.6 }, { 1, 0 } }),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(60, 60),
		Rate = 30,
		EmissionDirection = Enum.NormalId.Right,
	})

	-- Círculo onde o grupo se junta
	parte("Aro", Vector3.new(0.4, RAIO_PORTAL * 2 + 3, RAIO_PORTAL * 2 + 3), CFrame.new(POSICAO_PORTAL + Vector3.new(0, 0.1, 0)) * EM_PE, Enum.Material.Slate, PEDRA_ESCURA, { formato = Enum.PartType.Cylinder })
	local circulo = parte("CirculoPortal", Vector3.new(0.3, RAIO_PORTAL * 2, RAIO_PORTAL * 2), CFrame.new(POSICAO_PORTAL + Vector3.new(0, 0.2, 0)) * EM_PE, Enum.Material.Neon, ROXO, { formato = Enum.PartType.Cylinder, colide = false, sombra = false })
	TweenService:Create(circulo, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.55 }):Play()
	particulas(circulo, {
		Color = ColorSequence.new(Color3.fromRGB(200, 150, 255)),
		LightEmission = 1,
		Size = sequencia({ { 0, 0.4 }, { 1, 0 } }),
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(10, 10),
		Rate = 25,
		Shape = Enum.ParticleEmitterShape.Cylinder,
		EmissionDirection = Enum.NormalId.Right,
	})
	for i = 0, 3 do
		local angulo = i * math.pi / 2 + math.pi / 4
		local p = POSICAO_PORTAL + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * (RAIO_PORTAL + 2.5)
		parte("PedraRunica", Vector3.new(1.6, 4, 1.2), CFrame.new(p + Vector3.new(0, 2, 0)) * CFrame.Angles(0, -angulo, 0), Enum.Material.Slate, PEDRA_ESCURA)
		parte("RunaPedra", Vector3.new(1.7, 1, 0.5), CFrame.new(p + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, -angulo, 0), Enum.Material.Neon, ROXO, { colide = false })
	end
	letreiro(POSICAO_PORTAL + Vector3.new(0, 11, 0), "⚔️ A MASMORRA", "Fique no círculo roxo com seu grupo (1 a 4)", Color3.fromRGB(210, 170, 255))
end

-- Altares: chegue perto e escolha sua classe
local function construirAltares()
	local centroX = -40
	for i, id in Classes.ordem do
		local classe = Classes.dados[id]
		local z = (i - 2) * 15
		local base = Vector3.new(centroX, 0, z)
		parte("Degrau", Vector3.new(9, 1, 9), CFrame.new(base + Vector3.new(0, 0.5, 0)), Enum.Material.Slate, PEDRA_ESCURA)
		parte("Pedestal", Vector3.new(4, 4, 4), CFrame.new(base + Vector3.new(0, 3, 0)), Enum.Material.Marble, Color3.fromRGB(196, 190, 200))
		parte("Topo", Vector3.new(5, 0.8, 5), CFrame.new(base + Vector3.new(0, 5.4, 0)), Enum.Material.Slate, PEDRA_ESCURA)
		local runa = parte("Runa", Vector3.new(0.3, 2.4, 2.4), CFrame.new(base + Vector3.new(2.05, 3, 0)) * CFrame.Angles(math.rad(45), 0, 0), Enum.Material.Neon, classe.cor, { colide = false })
		local estandarte = parte("Estandarte", Vector3.new(0.3, 10, 5), CFrame.new(base + Vector3.new(-6, 7, 0)), Enum.Material.Fabric, classe.cor:Lerp(Color3.new(0, 0, 0), 0.35))
		parte("Haste", Vector3.new(0.5, 13, 0.5), CFrame.new(base + Vector3.new(-6.3, 6.5, 2.7)), Enum.Material.Wood, MADEIRA)
		parte("Emblema", Vector3.new(0.35, 2.4, 2.4), estandarte.CFrame * CFrame.new(0.05, 1.5, 0) * CFrame.Angles(math.rad(45), 0, 0), Enum.Material.Neon, classe.cor, { colide = false })

		-- Arma flutuando sobre o altar (gira no computador de cada jogador)
		local exibicao = Armas.modeloExibicao(id)
		exibicao.Name = "Arma" .. classe.nome
		local orientacao = if id == "cavaleiro" then CFrame.Angles(math.rad(-90), 0, 0) else CFrame.new()
		exibicao:PivotTo(CFrame.new(base + Vector3.new(0, 9.5, 0)) * orientacao)
		exibicao:SetAttribute("Giro", 0.8)
		exibicao:SetAttribute("Flutuar", 0.6)
		CollectionService:AddTag(exibicao, "Girar")
		exibicao.Parent = modelo

		luz(runa, classe.cor, 22, 2)
		particulas(runa, {
			Color = ColorSequence.new(classe.cor),
			LightEmission = 1,
			Size = sequencia({ { 0, 0.3 }, { 1, 0 } }),
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(30, 30),
			Acceleration = Vector3.new(0, 2, 0),
			Rate = 10,
			EmissionDirection = Enum.NormalId.Top,
		})

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Tornar-se " .. classe.nome
		prompt.ObjectText = classe.titulo
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.Parent = runa
		prompt.Triggered:Connect(function(player)
			Lobby.escolherClasse(player, id)
		end)

		letreiro(base + Vector3.new(0, 14.5, 0), classe.icone .. " " .. string.upper(classe.nome), classe.titulo, classe.cor:Lerp(Color3.new(1, 1, 1), 0.35))
	end
	letreiro(Vector3.new(centroX - 2, 20, 0), "ALTARES DAS CLASSES", "Chegue perto de um altar para escolher", Color3.fromRGB(255, 220, 140))
end

local function construirLoja()
	local x, z = 42, 0
	local lona = Color3.fromRGB(150, 44, 50)
	parte("Chao", Vector3.new(14, 0.6, 12), CFrame.new(x, 0.3, z), Enum.Material.WoodPlanks, Color3.fromRGB(120, 86, 56))
	for _, dx in { -6, 6 } do
		for _, dz in { -5, 5 } do
			parte("Poste", Vector3.new(0.7, 11, 0.7), CFrame.new(x + dx, 5.5, z + dz), Enum.Material.Wood, MADEIRA)
		end
	end
	-- Telhado em duas águas (cunhas)
	for _, lado in { -1, 1 } do
		local cunha = Instance.new("WedgePart")
		cunha.Name = "Telhado"
		cunha.Anchored = true
		cunha.Size = Vector3.new(14.5, 4, 6.5)
		cunha.CFrame = CFrame.new(x, 13, z + lado * 3.25) * CFrame.Angles(0, if lado == 1 then math.pi else 0, 0)
		cunha.Material = Enum.Material.Fabric
		cunha.Color = lona
		cunha.Parent = modelo
	end
	local balcao = parte("Balcao", Vector3.new(3, 3.5, 10), CFrame.new(x - 5, 2.35, z), Enum.Material.WoodPlanks, Color3.fromRGB(140, 95, 55))
	parte("Tampo", Vector3.new(3.6, 0.4, 10.6), CFrame.new(x - 5, 4.3, z), Enum.Material.Wood, Color3.fromRGB(96, 62, 38))
	for _, dz in { -3, -1.5, 2.5 } do
		parte("Moeda", Vector3.new(0.2, 0.9, 0.9), CFrame.new(x - 5, 4.6, z + dz) * EM_PE, Enum.Material.Neon, Color3.fromRGB(255, 205, 60), { formato = Enum.PartType.Cylinder, colide = false })
	end
	local pocao = parte("Pocao", Vector3.one * 0.9, CFrame.new(x - 5, 5, z + 0.5), Enum.Material.Glass, Color3.fromRGB(255, 70, 110), { formato = Enum.PartType.Ball, colide = false, transparencia = 0.2 })
	luz(pocao, Color3.fromRGB(255, 80, 120), 8, 1)

	-- Mercador encapuzado
	local capa = Color3.fromRGB(60, 44, 80)
	parte("Corpo", Vector3.new(2.4, 4.6, 1.8), CFrame.new(x - 1, 2.9, z), Enum.Material.Fabric, capa)
	parte("Capuz", Vector3.new(2, 2, 2), CFrame.new(x - 1, 6, z), Enum.Material.Fabric, capa:Lerp(Color3.new(0, 0, 0), 0.2))
	parte("Rosto", Vector3.new(0.2, 1.3, 1.5), CFrame.new(x - 2, 5.9, z), Enum.Material.SmoothPlastic, Color3.fromRGB(10, 8, 14))
	for _, dz in { -0.35, 0.35 } do
		local olho = parte("Olho", Vector3.new(0.15, 0.22, 0.3), CFrame.new(x - 2.12, 6.05, z + dz), Enum.Material.Neon, Color3.fromRGB(255, 210, 90), { colide = false })
		luz(olho, Color3.fromRGB(255, 210, 90), 4, 0.6)
	end
	lanterna(Vector3.new(x - 7, 0, z + 6))
	lanterna(Vector3.new(x - 7, 0, z - 6))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir loja"
	prompt.ObjectText = "Mercador"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = balcao
	prompt.Triggered:Connect(function(player)
		if not Partida.emPartida(player) then
			Remotos.enviar(player, "abrirLoja", {})
		end
	end)
	letreiro(Vector3.new(x, 18, z), "🛒 MERCADOR", "Melhorias permanentes", Color3.fromRGB(255, 205, 90))
end

local function construirNatureza()
	local rng = Random.new(42)
	for i = 0, 27 do
		local angulo = i / 28 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local distancia = rng:NextNumber(70, 108)
		local x, z = math.cos(angulo) * distancia, math.sin(angulo) * distancia
		-- deixa livre a frente do portal e o lago
		local pertoDoPortal = z < -50 and math.abs(x) < 45
		local pertoDoLago = (Vector3.new(x, 0, z) - Vector3.new(72, 0, 58)).Magnitude < 24
		if not pertoDoPortal and not pertoDoLago then
			if rng:NextNumber() < 0.5 then
				carvalho(x, z, rng:NextNumber(0.9, 1.3), rng)
			else
				pinheiro(x, z, rng:NextNumber(1, 1.5))
			end
		end
	end
	for _, pos in { Vector3.new(-6, 0, -14), Vector3.new(6, 0, -14), Vector3.new(-6, 0, -32), Vector3.new(6, 0, -32), Vector3.new(-18, 0, 6), Vector3.new(18, 0, 6) } do
		lanterna(pos)
	end

	-- Vagalumes
	local ar = parte("Vagalumes", Vector3.new(200, 10, 200), CFrame.new(0, 7, 0), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), { colide = false, transparencia = 1, sombra = false })
	particulas(ar, {
		Color = ColorSequence.new(Color3.fromRGB(230, 255, 140)),
		LightEmission = 1,
		Size = sequencia({ { 0, 0 }, { 0.5, 0.22 }, { 1, 0 } }),
		Lifetime = NumberRange.new(3, 6),
		Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 35,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})

	-- Paredes invisíveis (as colinas já cercam, mas por segurança)
	for _, info in {
		{ Vector3.new(240, 60, 2), Vector3.new(0, 30, 118) },
		{ Vector3.new(240, 60, 2), Vector3.new(0, 30, -118) },
		{ Vector3.new(2, 60, 240), Vector3.new(118, 30, 0) },
		{ Vector3.new(2, 60, 240), Vector3.new(-118, 30, 0) },
	} do
		parte("Limite", info[1], CFrame.new(info[2]), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), { transparencia = 1 })
	end
end

local function construirPlaca()
	local base = Vector3.new(16, 0, 30)
	local quadro = parte("Quadro", Vector3.new(14, 9, 0.8), CFrame.new(base + Vector3.new(0, 6, 0)) * CFrame.Angles(0, math.rad(20), 0), Enum.Material.WoodPlanks, Color3.fromRGB(120, 85, 55))
	for _, dx in { -6, 6 } do
		parte("Pe", Vector3.new(0.8, 6, 0.8), quadro.CFrame * CFrame.new(dx, -4, 0), Enum.Material.Wood, MADEIRA)
	end
	local tela = Instance.new("SurfaceGui")
	tela.Face = Enum.NormalId.Front
	tela.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	tela.PixelsPerStud = 50
	tela.LightInfluence = 0.2
	tela.Parent = quadro

	local titulo = Instance.new("TextLabel")
	titulo.Size = UDim2.fromScale(1, 0.2)
	titulo.BackgroundTransparency = 1
	titulo.FontFace = Font.new(Font.fromEnum(Enum.Font.Merriweather).Family, Enum.FontWeight.Bold)
	titulo.Text = "COMO JOGAR"
	titulo.TextColor3 = Color3.fromRGB(255, 220, 130)
	titulo.TextScaled = true
	titulo.Parent = tela

	local regras = Instance.new("TextLabel")
	regras.Position = UDim2.fromScale(0.05, 0.22)
	regras.Size = UDim2.fromScale(0.9, 0.74)
	regras.BackgroundTransparency = 1
	regras.FontFace = Font.new(Font.fromEnum(Enum.Font.BuilderSans).Family, Enum.FontWeight.Bold)
	regras.TextColor3 = Color3.fromRGB(245, 238, 220)
	regras.TextScaled = true
	regras.TextWrapped = true
	regras.TextXAlignment = Enum.TextXAlignment.Left
	regras.Text = "1. Escolha sua classe nos altares (à esquerda)\n"
		.. "2. Entre no círculo roxo com seu grupo\n"
		.. "3. Combo de 3 golpes, habilidade (E), esquiva (Q) e supremo (R)\n"
		.. "4. Limpe a sala e escolha uma carta de poder\n"
		.. "5. Aliado caído? Fique perto para reviver!\n"
		.. "6. Depois do chefe: SUBA com o ouro ou DESÇA mais fundo"
	regras.Parent = tela
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

function Lobby.construir()
	construirTerreno()
	construirPraca()
	construirPortal()
	construirAltares()
	construirLoja()
	construirNatureza()
	construirPlaca()
	modelo.Parent = workspace
end

-- Coloca a arma e os acessórios da classe no personagem (no lobby, só para exibir)
function Lobby.vestirClasse(player: Player)
	local personagem = player.Character
	local perfil = Dados.obter(player)
	if not personagem or not perfil or Partida.emPartida(player) then
		return
	end
	Armas.vestir(personagem, perfil.Classe)
end

function Lobby.escolherClasse(player: Player, classe: any)
	if Partida.emPartida(player) or not Dados.definirClasse(player, classe) then
		return
	end
	Lobby.vestirClasse(player)
	Dados.enviarPerfil(player)
	local dados = Classes.obter(classe)
	Remotos.enviar(player, "aviso", { texto = dados.icone .. " Agora você é " .. dados.nome .. "!" })
	Vfx.todos("escolheuClasse", { jogador = player, cor = dados.cor })
end

-- Fica olhando quem está no círculo do portal e começa a partida após a contagem
function Lobby.iniciarFila()
	local fimContagem: number? = nil
	local ultimoEnviado = {}

	while true do
		task.wait(0.25)
		local naFila = {}
		for _, player in Players:GetPlayers() do
			local personagem = player.Character
			local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = personagem and personagem:FindFirstChildOfClass("Humanoid")
			if raiz and humanoid and humanoid.Health > 0 and Dados.obter(player) and not Partida.emPartida(player) then
				local delta = raiz.Position - POSICAO_PORTAL
				if Vector3.new(delta.X, 0, delta.Z).Magnitude <= RAIO_PORTAL and math.abs(delta.Y) < 8 then
					table.insert(naFila, player)
				end
			end
		end

		local grupo = {}
		for i = 1, math.min(#naFila, Config.MAX_JOGADORES_POR_PARTIDA) do
			grupo[i] = naFila[i]
		end

		local agora = os.clock()
		if #grupo == 0 then
			fimContagem = nil
		else
			fimContagem = fimContagem or agora + Config.CONTAGEM_PORTAL
			if #grupo >= Config.MAX_JOGADORES_POR_PARTIDA then
				fimContagem = math.min(fimContagem :: number, agora + Config.CONTAGEM_PORTAL_CHEIO)
			end
		end

		local membros = {}
		for _, player in grupo do
			local perfil = Dados.obter(player)
			table.insert(membros, { userId = player.UserId, nome = player.DisplayName, classe = perfil and perfil.Classe or "cavaleiro" })
		end

		local mensagens = {}
		for _, player in grupo do
			mensagens[player] = {
				segundos = math.max(0, math.ceil((fimContagem :: number) - agora)),
				membros = membros,
				max = Config.MAX_JOGADORES_POR_PARTIDA,
			}
		end
		for _, player in naFila do
			if not mensagens[player] then
				mensagens[player] = { cheio = true }
			end
		end
		for _, player in Players:GetPlayers() do
			local mensagem = mensagens[player]
			local chave = "nada"
			if mensagem then
				if mensagem.cheio then
					chave = "cheio"
				else
					local ids = {}
					for _, membro in membros do
						table.insert(ids, membro.userId .. membro.classe)
					end
					chave = mensagem.segundos .. "|" .. table.concat(ids, ",")
				end
			end
			if ultimoEnviado[player] ~= chave then
				ultimoEnviado[player] = chave
				Remotos.enviar(player, "fila", mensagem or { esconder = true })
			end
		end
		for player in ultimoEnviado do
			if not player.Parent then
				ultimoEnviado[player] = nil
			end
		end

		if fimContagem and agora >= fimContagem then
			fimContagem = nil
			for _, player in grupo do
				ultimoEnviado[player] = "nada"
				Remotos.enviar(player, "fila", { esconder = true })
			end
			Partida.iniciar(grupo)
		end
	end
end

return Lobby
