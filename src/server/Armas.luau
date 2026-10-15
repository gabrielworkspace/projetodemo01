-- Armas e acessórios de cada classe, montados com peças e presos às mãos do personagem.
-- (Não usamos Tool: as animações de ataque são feitas por código em Client/Animacoes.)
--
-- Peças com nome fixo que a animação procura:
--   Espada e adagas: "Lamina" com os anexos "TrilhaBase" e "TrilhaPonta" (rastro do golpe)
--   (o Assassino tem uma segunda adaga, "ArmaSecundaria", na mão esquerda)
--   Cajado: "Haste" com o anexo "Ponta" (brilho do cristal)
--   Arco:   "Arco" com os anexos "CordaCima", "CordaBaixo" e "Encaixe" (corda que estica)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))

local Armas = {}

local OURO = Color3.fromRGB(232, 186, 82)
local COURO = Color3.fromRGB(92, 58, 34)
local MADEIRA = Color3.fromRGB(96, 64, 40)
local EM_PE = CFrame.Angles(0, 0, math.rad(90)) -- deixa um cilindro em pé

local function novaPeca(nome: string, tamanho: Vector3, cor: Color3, material: Enum.Material, formato: Enum.PartType?): Part
	local parte = Instance.new("Part")
	parte.Name = nome
	parte.Shape = formato or Enum.PartType.Block
	parte.Size = tamanho
	parte.Color = cor
	parte.Material = material
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Massless = true
	parte.CastShadow = false
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	return parte
end

-- Prende uma peça a outra, na posição relativa indicada
local function prender(base: BasePart, parte: BasePart, deslocamento: CFrame, pai: Instance): BasePart
	parte.CFrame = base.CFrame * deslocamento
	local solda = Instance.new("WeldConstraint")
	solda.Part0 = base
	solda.Part1 = parte
	solda.Parent = parte
	parte.Parent = pai
	return parte
end

local function anexo(pai: BasePart, nome: string, posicao: Vector3)
	local a = Instance.new("Attachment")
	a.Name = nome
	a.Position = posicao
	a.Parent = pai
	return a
end

local function brilho(parte: BasePart, cor: Color3, alcance: number, intensidade: number)
	local luz = Instance.new("PointLight")
	luz.Color = cor
	luz.Range = alcance
	luz.Brightness = intensidade
	luz.Parent = parte
end

local function segmento(base: BasePart, pai: Instance, nome: string, a: Vector3, b: Vector3, espessura: number, cor: Color3, material: Enum.Material)
	local parte = novaPeca(nome, Vector3.new(espessura, espessura, (b - a).Magnitude), cor, material)
	return prender(base, parte, CFrame.lookAt((a + b) / 2, b), pai)
end

------------------------------------------------------------------------
-- Construção (cada arma é montada na origem; depois é movida para a mão ou o altar)
------------------------------------------------------------------------

-- Espada: a lâmina vai na direção +Z e a mão segura em z = -1.6
local function construirEspada(cor: Color3): (Model, BasePart, CFrame)
	local modelo = Instance.new("Model")
	modelo.Name = "Espada"
	local lamina = novaPeca("Lamina", Vector3.new(0.32, 0.16, 4.4), Color3.fromRGB(214, 222, 236), Enum.Material.Metal)
	lamina.CFrame = CFrame.new()
	lamina.Parent = modelo
	prender(lamina, novaPeca("Sulco", Vector3.new(0.08, 0.18, 2.9), cor, Enum.Material.Neon), CFrame.new(0, 0, 0.55), modelo)
	prender(lamina, novaPeca("Guarda", Vector3.new(1.6, 0.3, 0.34), OURO, Enum.Material.Metal), CFrame.new(0, 0, -1.15), modelo)
	prender(lamina, novaPeca("Cabo", Vector3.new(0.36, 0.36, 1.05), COURO, Enum.Material.Fabric), CFrame.new(0, 0, -1.75), modelo)
	prender(lamina, novaPeca("Pomo", Vector3.one * 0.5, OURO, Enum.Material.Metal, Enum.PartType.Ball), CFrame.new(0, 0, -2.35), modelo)
	anexo(lamina, "TrilhaBase", Vector3.new(0, 0, -0.6))
	anexo(lamina, "TrilhaPonta", Vector3.new(0, 0, 2.2))
	modelo.PrimaryPart = lamina
	-- na mão: lâmina para frente e um pouco para baixo
	local naMao = CFrame.Angles(math.rad(-20), 0, 0) * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, 1.6)
	return modelo, lamina, naMao
end

-- Cajado: em pé (eixo Y), a mão segura em y = -1.2
local function construirCajado(cor: Color3): (Model, BasePart, CFrame)
	local modelo = Instance.new("Model")
	modelo.Name = "Cajado"
	local haste = novaPeca("Haste", Vector3.new(0.3, 6.4, 0.3), MADEIRA, Enum.Material.Wood)
	haste.CFrame = CFrame.new()
	haste.Parent = modelo
	prender(haste, novaPeca("Ponteira", Vector3.new(0.4, 0.4, 0.4), OURO, Enum.Material.Metal), CFrame.new(0, -3.2, 0), modelo)
	prender(haste, novaPeca("Garra", Vector3.new(0.9, 0.25, 0.25), OURO, Enum.Material.Metal), CFrame.new(0, 3.05, 0), modelo)
	prender(haste, novaPeca("Garra2", Vector3.new(0.25, 0.25, 0.9), OURO, Enum.Material.Metal), CFrame.new(0, 3.05, 0), modelo)
	local cristal = prender(haste, novaPeca("Cristal", Vector3.new(0.75, 1.2, 0.75), cor, Enum.Material.Neon), CFrame.new(0, 3.75, 0) * CFrame.Angles(0, math.rad(45), 0), modelo)
	local anel = novaPeca("Anel", Vector3.new(0.12, 1.7, 1.7), OURO, Enum.Material.Metal, Enum.PartType.Cylinder)
	prender(haste, anel, CFrame.new(0, 3.75, 0) * CFrame.Angles(math.rad(70), 0, 0), modelo)
	brilho(cristal, cor, 12, 2)
	anexo(haste, "Ponta", Vector3.new(0, 3.75, 0))
	modelo.PrimaryPart = haste
	return modelo, haste, CFrame.new(0, 1.2, 0)
end

-- Arco: em pé (eixo Y); os braços curvam para +Z (para quem segura). A corda é desenhada
-- no computador de cada jogador, para poder esticar na animação.
local function construirArco(cor: Color3): (Model, BasePart, CFrame)
	local modelo = Instance.new("Model")
	modelo.Name = "Arco"
	local empunhadura = novaPeca("Arco", Vector3.new(0.34, 1, 0.34), COURO, Enum.Material.Fabric)
	empunhadura.CFrame = CFrame.new()
	empunhadura.Parent = modelo
	local pontos = { Vector3.new(0, 0.5, 0), Vector3.new(0, 1.5, 0.18), Vector3.new(0, 2.35, 0.6) }
	for lado = -1, 1, 2 do
		for i = 1, #pontos - 1 do
			local a = Vector3.new(0, pontos[i].Y * lado, pontos[i].Z)
			local b = Vector3.new(0, pontos[i + 1].Y * lado, pontos[i + 1].Z)
			segmento(empunhadura, modelo, "Braco", a, b, 0.26, MADEIRA, Enum.Material.Wood)
		end
		prender(empunhadura, novaPeca("Ponta", Vector3.one * 0.32, OURO, Enum.Material.Metal), CFrame.new(0, 2.35 * lado, 0.6), modelo)
	end
	prender(empunhadura, novaPeca("Gema", Vector3.one * 0.3, cor, Enum.Material.Neon, Enum.PartType.Ball), CFrame.new(0, 0, -0.2), modelo)
	anexo(empunhadura, "CordaCima", Vector3.new(0, 2.32, 0.62))
	anexo(empunhadura, "CordaBaixo", Vector3.new(0, -2.32, 0.62))
	anexo(empunhadura, "Encaixe", Vector3.new(0, 0, 0.62))
	modelo.PrimaryPart = empunhadura
	-- na mão esquerda: fica em pé quando o braço aponta para frente
	return modelo, empunhadura, CFrame.Angles(math.rad(-90), 0, 0)
end

-- Adaga: como a espada, mas curta; a mão segura em z = -1.25
local function construirAdaga(cor: Color3): (Model, BasePart, CFrame)
	local modelo = Instance.new("Model")
	modelo.Name = "Adaga"
	local lamina = novaPeca("Lamina", Vector3.new(0.26, 0.1, 1.9), Color3.fromRGB(70, 70, 82), Enum.Material.Metal)
	lamina.CFrame = CFrame.new()
	lamina.Parent = modelo
	prender(lamina, novaPeca("Fio", Vector3.new(0.06, 0.12, 1.5), cor, Enum.Material.Neon), CFrame.new(0, 0, 0.1), modelo)
	prender(lamina, novaPeca("Guarda", Vector3.new(0.9, 0.18, 0.18), Color3.fromRGB(40, 36, 46), Enum.Material.Metal), CFrame.new(0, 0, -0.98), modelo)
	prender(lamina, novaPeca("Cabo", Vector3.new(0.26, 0.26, 0.7), Color3.fromRGB(34, 30, 38), Enum.Material.Fabric), CFrame.new(0, 0, -1.35), modelo)
	prender(lamina, novaPeca("Pomo", Vector3.one * 0.3, cor, Enum.Material.Neon, Enum.PartType.Ball), CFrame.new(0, 0, -1.75), modelo)
	anexo(lamina, "TrilhaBase", Vector3.new(0, 0, -0.5))
	anexo(lamina, "TrilhaPonta", Vector3.new(0, 0, 0.95))
	modelo.PrimaryPart = lamina
	local naMao = CFrame.Angles(math.rad(-30), 0, 0) * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, 1.3)
	return modelo, lamina, naMao
end

local function construir(classe: string): (Model, BasePart, CFrame)
	local dados = Classes.obter(classe)
	if dados.id == "mago" then
		return construirCajado(dados.cor)
	elseif dados.id == "arqueiro" then
		return construirArco(dados.cor)
	elseif dados.id == "assassino" then
		return construirAdaga(dados.cor)
	end
	return construirEspada(dados.cor)
end

------------------------------------------------------------------------
-- Uso
------------------------------------------------------------------------

local function parteDoCorpo(personagem: Model, nomes: { string }): BasePart?
	for _, nome in nomes do
		local parte = personagem:FindFirstChild(nome)
		if parte and parte:IsA("BasePart") then
			return parte
		end
	end
	return nil
end

-- Ponto onde a mão segura (R15: centro da mão; R6: ponta do braço)
local function pegada(mao: BasePart): CFrame
	if mao.Name == "Right Arm" or mao.Name == "Left Arm" then
		return mao.CFrame * CFrame.new(0, -1, 0)
	end
	return mao.CFrame * CFrame.new(0, -0.15, 0)
end

-- Modelo parado para exibir num altar
function Armas.modeloExibicao(classe: string): Model
	local modelo = construir(classe)
	for _, peca in modelo:GetDescendants() do
		if peca:IsA("BasePart") then
			peca.Anchored = true
		end
	end
	return modelo
end

-- Coloca a arma na mão e os acessórios da classe no corpo
function Armas.vestir(personagem: Model, classe: string)
	local antigo = personagem:FindFirstChild("AcessoriosDeClasse")
	if antigo then
		antigo:Destroy()
	end
	local pasta = Instance.new("Model")
	pasta.Name = "AcessoriosDeClasse"
	local dados = Classes.obter(classe)

	-- Arma (o arqueiro segura o arco na mão esquerda)
	local nomesMao = if dados.id == "arqueiro" then { "LeftHand", "Left Arm" } else { "RightHand", "Right Arm" }
	local mao = parteDoCorpo(personagem, nomesMao)
	if mao then
		local arma, base, naMao = construir(classe)
		arma.Name = "ArmaDeClasse"
		arma:PivotTo(pegada(mao) * naMao)
		local solda = Instance.new("WeldConstraint")
		solda.Part0 = mao
		solda.Part1 = base
		solda.Parent = base
		arma.Parent = pasta
	end
	-- Assassino: segunda adaga na mão esquerda
	if dados.id == "assassino" then
		local maoEsquerda = parteDoCorpo(personagem, { "LeftHand", "Left Arm" })
		if maoEsquerda then
			local adaga, base, naMao = construirAdaga(dados.cor)
			adaga.Name = "ArmaSecundaria"
			adaga:PivotTo(pegada(maoEsquerda) * naMao)
			local solda = Instance.new("WeldConstraint")
			solda.Part0 = maoEsquerda
			solda.Part1 = base
			solda.Parent = base
			adaga.Parent = pasta
		end
	end

	local tronco = parteDoCorpo(personagem, { "UpperTorso", "Torso" })
	if dados.id == "cavaleiro" then
		local braco = parteDoCorpo(personagem, { "LeftLowerArm", "Left Arm" })
		if braco then
			local desloc = if braco.Name == "Left Arm" then CFrame.new(-0.62, -0.3, 0) else CFrame.new(-0.6, 0, 0)
			local escudo = prender(braco, novaPeca("Escudo", Vector3.new(0.3, 2.9, 2.3), Color3.fromRGB(46, 78, 150), Enum.Material.Metal), desloc, pasta)
			prender(escudo, novaPeca("Borda", Vector3.new(0.36, 0.22, 2.4), OURO, Enum.Material.Metal), CFrame.new(0, 1.42, 0), pasta)
			prender(escudo, novaPeca("Borda", Vector3.new(0.36, 0.22, 2.4), OURO, Enum.Material.Metal), CFrame.new(0, -1.42, 0), pasta)
			prender(escudo, novaPeca("Borda", Vector3.new(0.36, 3, 0.22), OURO, Enum.Material.Metal), CFrame.new(0, 0, 1.12), pasta)
			prender(escudo, novaPeca("Borda", Vector3.new(0.36, 3, 0.22), OURO, Enum.Material.Metal), CFrame.new(0, 0, -1.12), pasta)
			prender(escudo, novaPeca("Emblema", Vector3.new(0.34, 1.6, 0.26), dados.cor, Enum.Material.Neon), CFrame.new(-0.03, 0, 0), pasta)
			prender(escudo, novaPeca("Emblema", Vector3.new(0.34, 0.26, 1.2), dados.cor, Enum.Material.Neon), CFrame.new(-0.03, 0.25, 0), pasta)
		end
	elseif dados.id == "mago" and tronco then
		for lado = -1, 1, 2 do
			local ombro = prender(tronco, novaPeca("Ombreira", Vector3.new(1.1, 0.5, 1.2), Color3.fromRGB(70, 40, 110), Enum.Material.Fabric), CFrame.new(lado * 1.05, 0.75, 0), pasta)
			prender(ombro, novaPeca("Gema", Vector3.one * 0.32, dados.cor, Enum.Material.Neon), CFrame.new(0, 0.3, -0.45), pasta)
		end
	elseif dados.id == "arqueiro" and tronco then
		local aljava = prender(
			tronco,
			novaPeca("Aljava", Vector3.new(2.3, 0.75, 0.75), COURO, Enum.Material.Fabric, Enum.PartType.Cylinder),
			CFrame.new(0.35, 0.2, 0.75) * EM_PE * CFrame.Angles(math.rad(-20), 0, 0),
			pasta
		)
		for i = -1, 1 do
			prender(aljava, novaPeca("Pena", Vector3.new(0.5, 0.12, 0.35), dados.cor, Enum.Material.Neon), CFrame.new(1.35, i * 0.18, 0), pasta)
		end
	elseif dados.id == "assassino" and tronco then
		local escuro = Color3.fromRGB(30, 26, 36)
		-- cachecol com a ponta voando para trás
		local cachecol = prender(tronco, novaPeca("Cachecol", Vector3.new(1.7, 0.45, 1.15), dados.cor:Lerp(escuro, 0.35), Enum.Material.Fabric), CFrame.new(0, 0.85, 0), pasta)
		prender(cachecol, novaPeca("PontaCachecol", Vector3.new(0.45, 0.1, 1.6), dados.cor:Lerp(escuro, 0.35), Enum.Material.Fabric), CFrame.new(0.35, -0.1, 1.1) * CFrame.Angles(math.rad(-25), 0, 0), pasta)
		-- cinto com facas de reserva
		local cinto = prender(tronco, novaPeca("Cinto", Vector3.new(2.05, 0.3, 1.1), escuro, Enum.Material.Fabric), CFrame.new(0, -0.85, 0), pasta)
		for i = -1, 1 do
			prender(cinto, novaPeca("Faca", Vector3.new(0.12, 0.6, 0.18), Color3.fromRGB(200, 200, 210), Enum.Material.Metal), CFrame.new(i * 0.3, -0.15, 0.58) * CFrame.Angles(0, 0, math.rad(i * 12)), pasta)
		end
	end
	pasta.Parent = personagem
end

return Armas
