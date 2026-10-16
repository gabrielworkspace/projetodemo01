-- Lobby (o acampamento): altares das classes, portal da masmorra, loja do mercador e placa.
--
-- O CENÁRIO (chão, praça, muralha, árvores, lago, cercas...) é um mapa salvo no próprio jogo:
-- Workspace > Mapa > Lobby (vem de mapas/Lobby.rbxmx). Dá para ver e mexer nele no Studio.
-- Aqui o código só monta o que é vivo (portal girando, altares com prompt, loja, letreiros,
-- placa, efeitos), em cima dos MARCADORES do mapa (pasta Marcadores): se você mover um marcador
-- no Studio, aquilo aparece no lugar novo. Os efeitos vêm dos pacotes de VFX
-- (ReplicatedStorage > EfeitosVFX), sem partículas feitas por código.
-- A água do lago é do Terrain (ondas, reflexo, dá para nadar): ela é criada no volume da peça
-- azul "Agua" do mapa (pasta Lago), que no Studio só mostra onde a água vai ficar.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- onde fica o círculo do portal (o marcador "Portal" do mapa pode mudar isto)
local POSICAO_PORTAL = Vector3.new(0, 0, -46)
local RAIO_PORTAL = 9
local ROXO = Color3.fromRGB(150, 70, 255)

-- Posições padrão, caso algum marcador não esteja no mapa
local PADRAO = {
	Nascimento = CFrame.new(0, 0.5, 22),
	Portal = CFrame.new(0, 0.5, -46),
	Vortice = CFrame.new(0, 11, -60),
	PlacaAltares = CFrame.new(-60, 23, 0),
	Loja = CFrame.new(37, 4.6, 0),
	Vagalumes = CFrame.new(0, 7, 0),
}

local vivo = Instance.new("Model")
vivo.Name = "LobbyVivo"

local efeitos = ReplicatedStorage:WaitForChild("EfeitosVFX", 10)

local function peca(nome: string, tamanho: Vector3, cframe: CFrame, cor: Color3, opcoes): Part
	opcoes = opcoes or {}
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.Size = tamanho
	p.CFrame = cframe
	p.Material = opcoes.material or Enum.Material.SmoothPlastic
	p.Color = cor
	p.Transparency = opcoes.transparencia or 0
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = opcoes.sombra == true
	p.Parent = opcoes.pai or vivo
	return p
end

local function luz(pai: Instance, cor: Color3, alcance: number, brilho: number)
	local l = Instance.new("PointLight")
	l.Color = cor
	l.Range = alcance
	l.Brightness = brilho
	l.Parent = pai
	return l
end

--[[ Liga um efeito do pacote de VFX preso num ponto (fica sempre ligado). Os emissores do
	efeito são copiados para um anexo em "pai" (com "deslocamento", se houver).
	opcoes: escala (tamanho e velocidade), velocidade (se quiser outra que não a da escala),
	cor (tinge), taxa (quantidade de partículas). ]]
local function efeitoPronto(nome: string, pai: BasePart, opcoes)
	opcoes = opcoes or {}
	local molde = efeitos and efeitos:FindFirstChild(nome)
	if not molde then
		return
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
			if opcoes.cor then
				emissor.Color = ColorSequence.new(opcoes.cor)
			end
			if opcoes.taxa then
				emissor.Rate *= opcoes.taxa
			end
			emissor.Enabled = true
			emissor.Parent = anexo
		end
	end
end

local function letreiro(posicao: Vector3, titulo: string, subtitulo: string, cor: Color3, largura: number?)
	local ancora = peca("Letreiro", Vector3.one, CFrame.new(posicao), cor, { transparencia = 1 })
	local placa = Instance.new("BillboardGui")
	placa.Size = UDim2.fromScale(largura or 20, (largura or 20) / 4)
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
-- Mapa e marcadores
------------------------------------------------------------------------

local mapa: Instance? = nil
local marcadores: Instance? = nil

-- CFrame de um marcador (ou a posição padrão, se ele não existir no mapa)
local function marcador(nome: string): CFrame
	local m = marcadores and marcadores:FindFirstChild(nome)
	if m and m:IsA("BasePart") then
		return m.CFrame
	end
	return PADRAO[nome] or CFrame.new()
end

-- O marcador em si (para prender prompt, luz ou efeito nele), invisível no jogo
local function pecaDoMarcador(nome: string): BasePart
	local m = marcadores and marcadores:FindFirstChild(nome)
	if m and m:IsA("BasePart") then
		return m
	end
	return peca(nome, Vector3.one, marcador(nome), Color3.new(1, 1, 1), { transparencia = 1 })
end

-- Água de verdade no lago: enche com água do Terrain o volume da peça "Agua" (um cilindro em pé,
-- como os discos do mapa) e tira a peça
local function encherLago()
	local terreno = workspace.Terrain
	terreno.WaterColor = Color3.fromRGB(56, 178, 214)
	terreno.WaterTransparency = 0.72
	terreno.WaterReflectance = 0.45
	terreno.WaterWaveSize = 0.08
	terreno.WaterWaveSpeed = 7
	for _, objeto in (mapa :: Instance):GetDescendants() do
		if objeto:IsA("BasePart") and objeto.Name == "Agua" then
			local altura = objeto.Size.X -- o eixo do cilindro (X) aponta para cima
			local raio = math.min(objeto.Size.Y, objeto.Size.Z) / 2
			local ok, erro = pcall(function()
				terreno:FillCylinder(CFrame.new(objeto.Position), altura, raio, Enum.Material.Water)
			end)
			if ok then
				objeto:Destroy()
			else
				warn("[Lobby] Não deu para criar a água do lago:", erro)
			end
		end
	end
end

local function prepararMapa()
	local pasta = workspace:FindFirstChild("Mapa")
	mapa = pasta and pasta:FindFirstChild("Lobby")
	if not mapa then
		-- sem o mapa (mapas/Lobby.rbxmx): pelo menos um chão para não cair no vazio
		warn("[Lobby] Workspace > Mapa > Lobby não encontrado; usando um chão simples.")
		local chao = peca("ChaoReserva", Vector3.new(400, 2, 400), CFrame.new(0, -1, 0), Color3.fromRGB(108, 196, 74))
		chao.CanCollide = true
		chao.CanQuery = true
		return
	end
	marcadores = mapa:FindFirstChild("Marcadores")
	-- marcadores ficam rosa no Studio para ajudar a editar; no jogo, invisíveis
	if marcadores then
		for _, m in marcadores:GetChildren() do
			if m:IsA("BasePart") then
				m.Transparency = 1
				m.CanCollide = false
				m.CanQuery = false
				m.CanTouch = false
			end
		end
	end
	for _, objeto in mapa:GetDescendants() do
		-- chamas das lanternas e dos braseiros tremulam (Ambiente.luau)
		if objeto:IsA("PointLight") and objeto.Name == "LuzChama" then
			CollectionService:AddTag(objeto, "Chama")
		end
		-- fogo dos braseiros: chamas do pacote
		if objeto:IsA("BasePart") and objeto.Name == "Brasa" then
			efeitoPronto("LaminaFogo", objeto, { escala = 1.2, deslocamento = CFrame.new(0.2, 0, 0) })
		end
	end
	local p = marcador("Portal").Position
	POSICAO_PORTAL = Vector3.new(p.X, 0, p.Z)
	encherLago()
end

------------------------------------------------------------------------
-- Partes vivas
------------------------------------------------------------------------

local function construirCristal()
	local cristal = mapa and mapa:FindFirstChild("CristalFlutuante", true)
	if not cristal or not cristal:IsA("Model") then
		return
	end
	local nucleo = cristal:FindFirstChild("Cristal")
	if not nucleo or not nucleo:IsA("BasePart") then
		return
	end
	cristal.PrimaryPart = nucleo
	cristal:SetAttribute("Giro", 0.6)
	cristal:SetAttribute("Flutuar", 0.8)
	CollectionService:AddTag(cristal, "Girar")
	luz(nucleo, Color3.fromRGB(110, 200, 255), 24, 1.4)
	efeitoPronto("CargaAura", nucleo, { escala = 0.6, cor = Color3.fromRGB(150, 220, 255), taxa = 0.5 })
end

local function construirPortal()
	-- o portal é o efeito do pacote (PortalChuva): um redemoinho roxo grande enchendo o arco, de
	-- frente para a praça (o efeito solta as linhas para a "frente" do anexo; girado, elas saem
	-- para o lado da praça)
	local vortice = pecaDoMarcador("Vortice")
	luz(vortice, ROXO, 40, 2)
	efeitoPronto("PortalChuva", vortice, {
		escala = 5,
		velocidade = 1.4,
		cor = Color3.fromRGB(170, 100, 255),
		deslocamento = CFrame.Angles(0, math.pi, 0),
	})
	-- o círculo onde o grupo se junta fica só desenhado no chão (pedra e runas do mapa), sem brilho
	letreiro(POSICAO_PORTAL + Vector3.new(0, 11, 0), "⚔️ A MASMORRA", "Fique no círculo de runas com seu grupo (1 a 4)", Color3.fromRGB(210, 170, 255))
end

-- Altares: um santuário por classe (no mapa, pasta Santuarios). O marcador Altar_<classe> fica em
-- cima do pedestal; chegue perto e escolha sua classe.
local function construirAltares()
	for _, id in Classes.ordem do
		local classe = Classes.dados[id]
		local altar = pecaDoMarcador("Altar_" .. id)
		local base = altar.CFrame
		luz(altar, classe.cor, 14, 1)
		-- brilho suave da cor da classe em volta da arma
		efeitoPronto("CargaAura", altar, { escala = 0.4, cor = classe.cor, taxa = 0.35, deslocamento = CFrame.new(0, 3.6, 0) })

		-- arma flutuando sobre o pedestal (gira no computador de cada jogador)
		local exibicao = Armas.modeloExibicao(id)
		exibicao.Name = "Arma" .. classe.nome
		local orientacao = if id == "cavaleiro" or id == "assassino" then CFrame.Angles(math.rad(-90), 0, 0) else CFrame.new()
		exibicao:PivotTo(CFrame.new(base.Position + Vector3.new(0, 3.6, 0)) * orientacao)
		exibicao:SetAttribute("Giro", 0.8)
		exibicao:SetAttribute("Flutuar", 0.6)
		CollectionService:AddTag(exibicao, "Girar")
		exibicao.Parent = vivo

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Tornar-se " .. classe.nome
		prompt.ObjectText = classe.titulo
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.Parent = altar
		prompt.Triggered:Connect(function(player)
			Lobby.escolherClasse(player, id)
		end)

		-- nome da classe dentro do arco, acima da arma
		letreiro(base.Position + Vector3.new(0, 8.6, 0), classe.icone .. " " .. string.upper(classe.nome), classe.titulo, classe.cor:Lerp(Color3.new(1, 1, 1), 0.35), 12)
	end
	letreiro(marcador("PlacaAltares").Position, "SANTUÁRIOS DAS CLASSES", "Chegue perto de um santuário para escolher", Color3.fromRGB(255, 220, 140))
end

local function construirLoja()
	local balcao = pecaDoMarcador("Loja")
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
	letreiro((marcador("Loja") * CFrame.new(5, 13.4, 0)).Position, "🛒 MERCADOR", "Melhorias permanentes", Color3.fromRGB(255, 205, 90))
end

local function construirPlaca()
	local quadro = mapa and mapa:FindFirstChild("QuadroComoJogar", true)
	if not quadro or not quadro:IsA("BasePart") then
		return
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
	titulo.TextColor3 = Color3.fromRGB(255, 236, 170)
	titulo.TextStrokeTransparency = 0.4
	titulo.TextScaled = true
	titulo.Parent = tela

	local regras = Instance.new("TextLabel")
	regras.Position = UDim2.fromScale(0.05, 0.22)
	regras.Size = UDim2.fromScale(0.9, 0.74)
	regras.BackgroundTransparency = 1
	regras.FontFace = Font.new(Font.fromEnum(Enum.Font.BuilderSans).Family, Enum.FontWeight.Bold)
	regras.TextColor3 = Color3.fromRGB(255, 250, 235)
	regras.TextStrokeTransparency = 0.5
	regras.TextScaled = true
	regras.TextWrapped = true
	regras.TextXAlignment = Enum.TextXAlignment.Left
	regras.Text = "1. Escolha sua classe nos santuários (à esquerda)\n"
		.. "2. Entre no círculo de runas (portal) com seu grupo\n"
		.. "3. Combo de 3 golpes, habilidade (E), esquiva (Q) e supremo (R)\n"
		.. "4. Limpe a sala e escolha uma carta de poder\n"
		.. "5. Aliado caído? Fique perto para reviver!\n"
		.. "6. Depois do chefe: SUBA com o ouro ou DESÇA mais fundo"
	regras.Parent = tela
end

local function construirNascimento()
	local nascimento = Instance.new("SpawnLocation")
	nascimento.Name = "Nascimento"
	nascimento.Anchored = true
	nascimento.Size = Vector3.new(10, 1, 6)
	nascimento.CFrame = marcador("Nascimento") * CFrame.new(0, -0.3, 0)
	nascimento.Transparency = 1
	nascimento.CanCollide = false
	nascimento.CanQuery = false
	nascimento.Neutral = true
	nascimento.Duration = 0
	nascimento.Parent = vivo
end

local function construirVagalumes()
	-- brilhinhos dourados flutuando pelo campo (efeito do pacote numa área de 200 x 200 em volta
	-- do marcador)
	local area = peca("Vagalumes", Vector3.new(200, 10, 200), marcador("Vagalumes"), Color3.new(1, 1, 1), { transparencia = 1 })
	local molde = efeitos and efeitos:FindFirstChild("CargaBrilhoCheia")
	if not molde then
		return
	end
	for _, original in molde:GetDescendants() do
		if original:IsA("ParticleEmitter") then
			local emissor = original:Clone()
			emissor.Color = ColorSequence.new(Color3.fromRGB(235, 255, 150))
			emissor.Rate = 14
			emissor.Shape = Enum.ParticleEmitterShape.Box
			emissor.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			emissor.LockedToPart = false
			emissor.Enabled = true
			emissor.Parent = area
		end
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

function Lobby.construir()
	prepararMapa()
	construirCristal()
	construirPortal()
	construirAltares()
	construirLoja()
	construirPlaca()
	construirNascimento()
	construirVagalumes()
	vivo.Parent = workspace
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
