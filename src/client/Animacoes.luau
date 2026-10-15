-- Animações dos personagens feitas por código (não precisam de arquivos de animação).
-- As poses e os golpes ficam em Poses.luau; aqui elas são aplicadas nas juntas do personagem,
-- por cima da animação padrão do Roblox (andar, pular). Também cuida dos detalhes das armas
-- (rastro da lâmina, corda e flecha do arco, brilho do cajado, partículas de carga).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Classes = require(Shared:WaitForChild("Classes"))

local Vfx = require(script.Parent.Vfx)
local Poses = require(script.Parent.Poses)

local Animacoes = {}

local jogador = Players.LocalPlayer
local pasta = Instance.new("Folder")
pasta.Name = "AnimacoesLocais"
pasta.Parent = workspace

local PESO_POSTURA = 0.75
local OURO = Color3.fromRGB(255, 214, 90)

-- Junta lógica -> { peça que contém o Motor6D, nome do Motor6D }
local JUNTAS_R15 = {
	raiz = { "LowerTorso", "Root" },
	cintura = { "UpperTorso", "Waist" },
	pescoco = { "Head", "Neck" },
	ombroD = { "RightUpperArm", "RightShoulder" },
	cotoveloD = { "RightLowerArm", "RightElbow" },
	pulsoD = { "RightHand", "RightWrist" },
	ombroE = { "LeftUpperArm", "LeftShoulder" },
	cotoveloE = { "LeftLowerArm", "LeftElbow" },
	pulsoE = { "LeftHand", "LeftWrist" },
	quadrilD = { "RightUpperLeg", "RightHip" },
	joelhoD = { "RightLowerLeg", "RightKnee" },
	quadrilE = { "LeftUpperLeg", "LeftHip" },
	joelhoE = { "LeftLowerLeg", "LeftKnee" },
	tornozeloD = { "RightFoot", "RightAnkle" },
	tornozeloE = { "LeftFoot", "LeftAnkle" },
}
local JUNTAS_R6 = {
	raiz = { "HumanoidRootPart", "RootJoint" },
	pescoco = { "Torso", "Neck" },
	ombroD = { "Torso", "Right Shoulder" },
	ombroE = { "Torso", "Left Shoulder" },
	quadrilD = { "Torso", "Right Hip" },
	quadrilE = { "Torso", "Left Hip" },
}

local A = Poses.A
local POSTURAS = Poses.POSTURAS
local PARADO = Poses.PARADO
local ACOES = Poses.ACOES
local ESQUIVAS = Poses.ESQUIVAS
local ATINGIDO = Poses.ATINGIDO
local BLOQUEIO = Poses.BLOQUEIO
local amostrar = Poses.amostrar
local misturar = Poses.misturar

------------------------------------------------------------------------
-- Estado de cada personagem
------------------------------------------------------------------------

local personagens = {} -- [Model] = estado

local function obterJuntas(personagem: Model)
	local juntas = {}
	local mapa = if personagem:FindFirstChild("UpperTorso") then JUNTAS_R15 else JUNTAS_R6
	for nome, info in mapa do
		local parte = personagem:FindFirstChild(info[1])
		local motor = parte and parte:FindFirstChild(info[2])
		if motor and motor:IsA("Motor6D") then
			local rotacao = motor.C0.Rotation
			juntas[nome] = { motor = motor, rot = rotacao, inv = rotacao:Inverse() }
		end
	end
	return juntas
end

local function estadoDe(personagem: Model)
	local e = personagens[personagem]
	if not e then
		e = {
			personagem = personagem,
			jogador = Players:GetPlayerFromCharacter(personagem),
			humanoid = personagem:FindFirstChildOfClass("Humanoid"),
			juntas = obterJuntas(personagem),
			acao = nil,
			dash = nil,
			carregando = false,
			cargaInicio = 0,
			puxar = 0,
			brilho = 0,
			flechaMao = 0,
			ultimaPose = {},
		}
		personagens[personagem] = e
	end
	return e
end

local function classeDe(e): string
	local classe = e.jogador and e.jogador:GetAttribute("Classe")
	return if Classes.existe(classe) then classe else "cavaleiro"
end

local function cargaDe(e): number
	if not e.carregando then
		return 0
	end
	return math.clamp((os.clock() - e.cargaInicio - Config.CARGA_ATAQUE_MIN) / (Config.CARGA_ATAQUE_MAX - Config.CARGA_ATAQUE_MIN) + 0.15, 0, 1)
end

local function comecar(e, definicao, dados)
	if not definicao then
		return
	end
	if definicao.quadros then
		Poses.preparar(definicao)
	end
	local agora = os.clock()
	e.acao = {
		def = definicao,
		inicio = agora,
		base = e.ultimaPose, -- parte de onde o corpo está (sem "pulos" entre animações)
		dados = dados or {},
		duracao = if definicao.manter then math.huge else (definicao.duracao or (dados and dados.duracao) or 0.5),
		soltando = nil,
	}
end

------------------------------------------------------------------------
-- Detalhes das armas: rastro da espada, corda e flecha do arco, brilho do cajado e
-- partículas de carga. Tudo criado só neste computador.
------------------------------------------------------------------------

local function prepararArma(e)
	local acessorios = e.personagem:FindFirstChild("AcessoriosDeClasse")
	local arma = acessorios and acessorios:FindFirstChild("ArmaDeClasse")
	if arma == e.arma then
		return
	end
	-- arma nova (trocou de classe ou renasceu): limpa os detalhes antigos
	for _, objeto in e.detalhes or {} do
		objeto:Destroy()
	end
	e.detalhes = {}
	e.arma = arma
	e.trilha, e.trilha2, e.encaixe, e.flecha, e.glow, e.esfera, e.emissorCarga = nil, nil, nil, nil, nil, nil, nil
	if not arma then
		return
	end
	local classe = Classes.obter(classeDe(e))

	local function rastroDaLamina(modelo: Instance?): (Trail?, Attachment?)
		local lamina = modelo and modelo:FindFirstChild("Lamina")
		local base = lamina and lamina:FindFirstChild("TrilhaBase") :: Attachment?
		local ponta = lamina and lamina:FindFirstChild("TrilhaPonta") :: Attachment?
		if not base or not ponta then
			return nil, nil
		end
		local trilha = Instance.new("Trail")
		trilha.Attachment0 = base
		trilha.Attachment1 = ponta
		trilha.Color = ColorSequence.new(Color3.new(1, 1, 1), classe.cor)
		trilha.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		trilha.Lifetime = 0.16
		trilha.LightEmission = 1
		trilha.LightInfluence = 0
		trilha.Enabled = false
		trilha.Parent = lamina
		table.insert(e.detalhes, trilha)
		return trilha, ponta
	end
	local trilha, ponta = rastroDaLamina(arma)
	if trilha then
		e.trilha = trilha
		e.pontaArma = ponta
	end
	-- Assassino: rastro também na adaga da mão esquerda
	e.trilha2 = rastroDaLamina(acessorios:FindFirstChild("ArmaSecundaria"))

	local arco = arma:FindFirstChild("Arco")
	if arco then
		local cima = arco:FindFirstChild("CordaCima") :: Attachment?
		local baixo = arco:FindFirstChild("CordaBaixo") :: Attachment?
		local encaixe = arco:FindFirstChild("Encaixe") :: Attachment?
		if cima and baixo and encaixe then
			for _, par in { { cima, encaixe }, { encaixe, baixo } } do
				local corda = Instance.new("Beam")
				corda.Attachment0 = par[1]
				corda.Attachment1 = par[2]
				corda.Width0 = 0.07
				corda.Width1 = 0.07
				corda.Color = ColorSequence.new(Color3.fromRGB(255, 240, 210))
				corda.LightEmission = 0.4
				corda.FaceCamera = true
				corda.Segments = 1
				corda.Parent = arco
				table.insert(e.detalhes, corda)
			end
			local flecha = Instance.new("Part")
			flecha.Size = Vector3.new(0.12, 0.12, 2.7)
			flecha.Material = Enum.Material.Wood
			flecha.Color = Color3.fromRGB(160, 120, 80)
			flecha.Anchored = true
			flecha.CanCollide = false
			flecha.CanQuery = false
			flecha.CanTouch = false
			flecha.CastShadow = false
			flecha.Transparency = 1
			flecha.Parent = pasta
			local pontaFlecha = Instance.new("Part")
			pontaFlecha.Size = Vector3.new(0.22, 0.22, 0.4)
			pontaFlecha.Material = Enum.Material.Neon
			pontaFlecha.Color = classe.cor
			pontaFlecha.Anchored = true
			pontaFlecha.CanCollide = false
			pontaFlecha.CanQuery = false
			pontaFlecha.CanTouch = false
			pontaFlecha.Transparency = 1
			pontaFlecha.Parent = flecha
			e.encaixe = encaixe
			e.arco = arco
			e.flecha = flecha
			e.pontaFlecha = pontaFlecha
			e.pontaArma = encaixe
			table.insert(e.detalhes, flecha)
		end
	end

	local haste = arma:FindFirstChild("Haste")
	if haste then
		local ponta = haste:FindFirstChild("Ponta") :: Attachment?
		if ponta then
			local glow = Instance.new("Part")
			glow.Shape = Enum.PartType.Ball
			glow.Size = Vector3.one
			glow.Material = Enum.Material.Neon
			glow.Color = classe.cor
			glow.Anchored = true
			glow.CanCollide = false
			glow.CanQuery = false
			glow.CanTouch = false
			glow.CastShadow = false
			glow.Transparency = 1
			glow.Parent = pasta
			local luz = Instance.new("PointLight")
			luz.Color = classe.cor
			luz.Range = 12
			luz.Brightness = 0
			luz.Parent = glow
			e.glow = glow
			e.luzGlow = luz
			e.pontaArma = ponta
			table.insert(e.detalhes, glow)
		end
	end

	-- Esfera invisível na ponta da arma: as partículas de carga convergem para ela
	local esfera = Instance.new("Part")
	esfera.Shape = Enum.PartType.Ball
	esfera.Size = Vector3.one * 5
	esfera.Transparency = 1
	esfera.Anchored = true
	esfera.CanCollide = false
	esfera.CanQuery = false
	esfera.CanTouch = false
	esfera.Parent = pasta
	local emissor = Instance.new("ParticleEmitter")
	emissor.Shape = Enum.ParticleEmitterShape.Sphere
	emissor.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emissor.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	emissor.Color = ColorSequence.new(classe.cor:Lerp(Color3.new(1, 1, 1), 0.4), classe.cor)
	emissor.LightEmission = 1
	emissor.LightInfluence = 0
	emissor.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emissor.Lifetime = NumberRange.new(0.3, 0.4)
	emissor.Speed = NumberRange.new(6, 9)
	emissor.Rate = 0
	emissor.Parent = esfera
	e.esfera = esfera
	e.emissorCarga = emissor
	e.corClasse = classe.cor
	table.insert(e.detalhes, esfera)
end

local function atualizarArma(e, agora: number)
	prepararArma(e)
	if not e.arma then
		return
	end
	local acao = e.acao
	if e.trilha then
		-- "trilha" = true (o tempo todo) ou { início, fim } (só durante o corte)
		local ligada = false
		if acao and acao.def.trilha and acao.soltando == nil then
			local tau = agora - acao.inicio
			local janela = acao.def.trilha
			ligada = if type(janela) == "table" then tau >= janela[1] and tau <= janela[2] else true
		end
		if e.trilha.Enabled ~= ligada then
			e.trilha.Enabled = ligada
		end
		if e.trilha2 and e.trilha2.Enabled ~= ligada then
			e.trilha2.Enabled = ligada
		end
	end
	if e.encaixe and e.arco and e.flecha then
		local puxar = math.clamp(e.puxar, 0, 1.3)
		local z = 0.62 + puxar * 1.6
		e.encaixe.Position = Vector3.new(0, 0, z)
		local noArco = puxar > 0.15
		-- flecha na mão direita: acabou de tirar da aljava e ainda não encaixou
		local maoDireita = e.personagem:FindFirstChild("RightHand") or e.personagem:FindFirstChild("Right Arm")
		local naMao = not noArco and e.flechaMao > 0.5 and maoDireita ~= nil
		local visivel = noArco or naMao
		e.flecha.Transparency = if visivel then 0 else 1
		e.pontaFlecha.Transparency = if visivel then 0 else 1
		if noArco then
			local cf = e.arco.CFrame * CFrame.new(0, 0, z - 1.35)
			e.flecha.CFrame = cf
			e.pontaFlecha.CFrame = cf * CFrame.new(0, 0, -1.45)
		elseif naMao then
			-- presa entre os dedos, apontando para cima ao longo do braço
			local cf = (maoDireita :: BasePart).CFrame * CFrame.new(0, 0.9, 0) * CFrame.Angles(math.rad(90), 0, 0)
			e.flecha.CFrame = cf
			e.pontaFlecha.CFrame = cf * CFrame.new(0, 0, -1.45)
		end
	end
	local carga = cargaDe(e)
	if e.glow and e.pontaArma then
		local intensidade = math.clamp(e.brilho * 0.6 + carga, 0, 1.5)
		e.glow.Transparency = if intensidade > 0.02 then 1 - math.min(0.75, intensidade * 0.6) else 1
		e.glow.Size = Vector3.one * (0.6 + intensidade * 1.6 + math.sin(agora * 20) * 0.08 * carga)
		e.glow.CFrame = CFrame.new(e.pontaArma.WorldPosition)
		e.luzGlow.Brightness = intensidade * 3
	end
	if e.esfera and e.pontaArma then
		e.esfera.CFrame = CFrame.new(e.pontaArma.WorldPosition)
		e.emissorCarga.Rate = if e.carregando then 20 + 60 * carga else 0
		if e.carregando and carga >= 1 and not e.cheioAvisado then
			e.cheioAvisado = true
			e.emissorCarga.Color = ColorSequence.new(Color3.new(1, 1, 1), OURO)
			Vfx.cargaCheia({ pos = e.pontaArma.WorldPosition, local_ = e.jogador == jogador })
		end
	end
end

-- Barrinha de carga acima do próprio personagem (só quem carrega vê)
local barra: BillboardGui? = nil
local preenchimento: Frame? = nil

local function criarBarra()
	local gui = Instance.new("BillboardGui")
	gui.Name = "BarraDeCarga"
	gui.Size = UDim2.fromOffset(70, 9)
	gui.StudsOffset = Vector3.new(0, 3.6, 0)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	local fundo = Instance.new("Frame")
	fundo.Size = UDim2.fromScale(1, 1)
	fundo.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
	fundo.BackgroundTransparency = 0.25
	fundo.BorderSizePixel = 0
	fundo.Parent = gui
	Instance.new("UICorner", fundo).CornerRadius = UDim.new(1, 0)
	local contorno = Instance.new("UIStroke")
	contorno.Color = Color3.new(0, 0, 0)
	contorno.Thickness = 1.5
	contorno.Parent = fundo
	local cheio = Instance.new("Frame")
	cheio.Size = UDim2.fromScale(0, 1)
	cheio.BorderSizePixel = 0
	cheio.Parent = fundo
	Instance.new("UICorner", cheio).CornerRadius = UDim.new(1, 0)
	gui.Parent = pasta
	barra, preenchimento = gui, cheio
end

local function atualizarBarra(e, agora: number)
	if e.jogador ~= jogador then
		return
	end
	if not barra then
		criarBarra()
	end
	local gui, cheio = barra :: BillboardGui, preenchimento :: Frame
	local raiz = e.personagem:FindFirstChild("HumanoidRootPart")
	gui.Adornee = raiz
	gui.Enabled = e.carregando and raiz ~= nil
	if not gui.Enabled then
		return
	end
	local carga = cargaDe(e)
	cheio.Size = UDim2.fromScale(carga, 1)
	if carga >= 1 then
		-- cheia: pisca entre dourado e branco
		cheio.BackgroundColor3 = OURO:Lerp(Color3.new(1, 1, 1), (math.sin(agora * 18) + 1) * 0.3)
	else
		cheio.BackgroundColor3 = (e.corClasse or OURO):Lerp(Color3.new(1, 1, 1), 0.25)
	end
end

------------------------------------------------------------------------
-- Aplicar a pose nas juntas (depois da animação padrão, antes da física)
------------------------------------------------------------------------

-- Peso geral da ação. Quem tem quadros já entra e sai suave junta por junta (peso de cada
-- valor); só as animações contínuas e as interrompidas precisam de rampa aqui.
local function pesoDaAcao(a, agora: number): (number, number)
	local tau = agora - a.inicio
	local peso = 1
	if a.def.continuo then
		peso = math.min(1, tau / 0.08)
	end
	if a.soltando then
		peso *= math.max(0, 1 - (agora - a.soltando) / 0.15)
	elseif not a.def.manter and not a.def.voltar then
		local saida = a.def.saida or 0.12
		local resto = a.duracao - tau
		if resto < saida then
			peso *= math.max(0, resto / saida)
		end
	end
	return peso, tau
end

local function poseDaAcao(a, tau: number)
	if a.def.continuo then
		return a.def.continuo(tau, a.dados)
	end
	return amostrar(a.def, tau, a.base)
end

local function animarPersonagem(e, agora: number)
	local final = {} -- junta -> { valores, peso }
	local classe = classeDe(e)
	local postura = POSTURAS[classe]
	if postura then
		for junta, valor in postura do
			final[junta] = { valor, PESO_POSTURA }
		end
	end

	-- Mistura uma camada por cima: o peso de cada junta é o peso da camada vezes o peso
	-- do próprio valor (o 7º número)
	local function aplicarCamada(pose, peso: number)
		for junta, valor in pose do
			local w = peso * (valor[7] or 1)
			if w > 0.001 then
				local atual = final[junta]
				if atual then
					final[junta] = { misturar(atual[1], valor, w), atual[2] + (1 - atual[2]) * w }
				else
					final[junta] = { valor, w }
				end
			end
		end
	end

	-- Pose parada: entra suave quando o personagem para e sai quando ele anda ou pula
	local raiz = e.personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	local parado = 0
	if raiz then
		-- pela velocidade (funciona também para os personagens dos outros jogadores)
		local v = raiz.AssemblyLinearVelocity
		if math.abs(v.Y) < 3 then
			parado = math.clamp(1 - Vector3.new(v.X, 0, v.Z).Magnitude / 3, 0, 1)
		end
	end
	e.parado = (e.parado or 0) + (parado - (e.parado or 0)) * 0.15
	local poseParada = PARADO[classe]
	if poseParada and e.parado > 0.01 then
		aplicarCamada(poseParada(agora), e.parado * 0.9)
	end

	local a = e.acao
	if a then
		local peso, tau = pesoDaAcao(a, agora)
		if (peso <= 0 and a.soltando) or tau > a.duracao then
			e.acao = nil
			e.ultimaPose = {}
		else
			local pose = poseDaAcao(a, tau)
			if e.carregando and a.def.manter then
				-- tremendo de força enquanto carrega
				local carga = cargaDe(e)
				local tremor = math.sin(agora * 45) * 0.025 * (0.4 + carga)
				pose = table.clone(pose)
				if pose.cintura then
					pose.cintura = misturar(pose.cintura, A(pose.cintura[1] + tremor, pose.cintura[2] + tremor, pose.cintura[3]), 1)
				end
			end
			-- guarda onde o corpo está (com o peso atual) para a próxima ação partir daqui
			local guardada = {}
			for junta, valor in pose do
				guardada[junta] = { valor[1], valor[2], valor[3], valor[4], valor[5], valor[6], (valor[7] or 1) * peso }
			end
			e.ultimaPose = guardada
			aplicarCamada(pose, peso)
		end
	end

	local d = e.dash
	if d then
		local tau = agora - d.inicio
		local duracao = d.def.duracao
		local peso = math.min(1, tau / 0.03)
		if tau > duracao - 0.1 then
			peso *= math.max(0, (duracao - tau) / 0.1)
		end
		if tau >= duracao then
			e.dash = nil
		else
			-- a esquiva manda no corpo todo: tira a postura e o ataque de baixo
			aplicarCamada(amostrar(d.def, tau, {}), peso)
		end
	end

	-- reações rápidas por cima de tudo: levou dano / escudo bloqueou
	for _, info in { { "atingido", ATINGIDO, 0.8 }, { "bloqueou", BLOQUEIO, 1 } } do
		local inicio = e[info[1]]
		if inicio then
			local tau = agora - inicio
			Poses.preparar(info[2])
			if tau >= info[2].duracao then
				e[info[1]] = nil
			else
				aplicarCamada(amostrar(info[2], tau, {}), info[3])
			end
		end
	end

	e.puxar = if final.puxar then final.puxar[1][1] * final.puxar[2] else 0
	e.brilho = if final.brilho then final.brilho[1][1] * final.brilho[2] else 0
	e.flechaMao = if final.flechaMao then final.flechaMao[1][1] * final.flechaMao[2] else 0

	-- as juntas podem ter sido trocadas (roupa/escala aplicada depois de nascer): procura de novo
	local precisaBuscar = next(e.juntas) == nil
	for _, j in e.juntas do
		if not j.motor.Parent or not j.motor:IsDescendantOf(e.personagem) then
			precisaBuscar = true
			break
		end
	end
	if precisaBuscar and agora >= (e.proximaBusca or 0) then
		e.proximaBusca = agora + 0.5
		e.juntas = obterJuntas(e.personagem)
	end

	for junta, info in final do
		local j = e.juntas[junta]
		local peso = info[2]
		if j and peso > 0.001 and j.motor.Parent then
			local v = info[1]
			local alvo = j.inv * CFrame.new(v[4], v[5], v[6]) * CFrame.fromEulerAnglesYXZ(v[1], v[2], v[3]) * j.rot
			j.motor.Transform = j.motor.Transform:Lerp(alvo, math.min(peso, 1))
		end
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------

--[[ Toca uma animação num personagem.
	acao: "ataque" (dados.combo), "carregar", "soltar" (dados.fracao), "cancelar",
	      "esquiva", "habilidade", "supremo" (dados.duracao), "defender", "pararDefesa",
	      "bloqueou", "atingido" ]]
function Animacoes.tocar(personagem: Model, acao: string, dados)
	if not personagem or not personagem.Parent then
		return
	end
	dados = dados or {}
	local e = estadoDe(personagem)
	local classe = if Classes.existe(dados.classe) then dados.classe else classeDe(e)
	local acoes = ACOES[classe]
	if acao == "ataque" then
		comecar(e, acoes["ataque" .. math.clamp(dados.combo or 1, 1, 3)], dados)
	elseif acao == "carregar" then
		e.carregando = true
		e.cargaInicio = os.clock()
		e.cheioAvisado = false
		comecar(e, acoes.carregar, dados)
	elseif acao == "soltar" then
		e.carregando = false
		if e.emissorCarga and e.corClasse then
			e.emissorCarga.Color = ColorSequence.new(e.corClasse:Lerp(Color3.new(1, 1, 1), 0.4), e.corClasse)
		end
		comecar(e, acoes.soltar, dados)
	elseif acao == "cancelar" then
		e.carregando = false
		if e.acao and e.acao.def.manter then
			e.acao.soltando = os.clock()
		end
	elseif acao == "esquiva" then
		e.carregando = false
		if e.acao and e.acao.def.manter then
			e.acao.soltando = os.clock()
		end
		e.dash = { inicio = os.clock(), def = ESQUIVAS[classe] or ESQUIVAS.cavaleiro }
		Vfx.esquiva({ jogador = e.jogador, classe = classe })
	elseif acao == "habilidade" or acao == "supremo" then
		comecar(e, acoes[acao], dados)
	elseif acao == "defender" then
		e.carregando = false
		e.defendendo = true
		comecar(e, acoes.defender, dados)
	elseif acao == "pararDefesa" then
		e.defendendo = false
		if e.acao and e.acao.def == acoes.defender then
			e.acao.soltando = os.clock()
		end
	elseif acao == "bloqueou" then
		e.bloqueou = os.clock()
	elseif acao == "atingido" then
		e.atingido = os.clock()
	end
end

-- Ações que o próprio jogador já anima na hora do clique (o servidor não manda de volta)
local PREVISTAS = { ataque = true, carregar = true, soltar = true, cancelar = true, esquiva = true, defender = true, pararDefesa = true }

-- Mensagem "anim" vinda do servidor
function Animacoes.receber(dados)
	local player = dados.jogador
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if player == jogador and PREVISTAS[dados.acao] then
		return
	end
	local personagem = player.Character
	if personagem then
		Animacoes.tocar(personagem, dados.acao, dados)
	end
end

function Animacoes.atingido(player: any)
	if typeof(player) == "Instance" and player:IsA("Player") and player.Character then
		Animacoes.tocar(player.Character, "atingido", nil)
	end
end

function Animacoes.iniciar()
	RunService.PreSimulation:Connect(function()
		local agora = os.clock()
		for personagem, e in personagens do
			if not personagem.Parent then
				for _, objeto in e.detalhes or {} do
					objeto:Destroy()
				end
				personagens[personagem] = nil
			else
				local humanoid = e.humanoid
				if humanoid and humanoid.Health > 0 and not humanoid.Sit then
					animarPersonagem(e, agora)
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		local agora = os.clock()
		for _, e in personagens do
			atualizarArma(e, agora)
			atualizarBarra(e, agora)
		end
	end)

	-- Todo personagem ganha estado assim que aparece (para a postura de combate)
	local function acompanhar(player: Player)
		player.CharacterAdded:Connect(function(personagem)
			personagem:WaitForChild("Humanoid", 10)
			task.wait(0.1)
			if personagem.Parent then
				estadoDe(personagem)
			end
		end)
		if player.Character then
			estadoDe(player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		acompanhar(player)
	end
	Players.PlayerAdded:Connect(acompanhar)
end

return Animacoes
