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
local Sons = require(script.Parent.Sons)

local Animacoes = {}

local jogador = Players.LocalPlayer
local pasta = Instance.new("Folder")
pasta.Name = "AnimacoesLocais"
pasta.Parent = workspace

local PESO_POSTURA = 0.75

-- Escudo do Cavaleiro: duas posições no antebraço, trocadas aos poucos (preso numa só, ele ficava
-- de cabeça para baixo com o braço solto ou obrigava o braço a ficar encolhido).
--   carregado: ao lado do corpo, em pé, virado para fora (comprido ao longo do braço)
--   defesa:    na parte de fora do antebraço, em pé e de frente com o antebraço erguido
local ESCUDO_CARREGADO = CFrame.new(-0.62, 0, 0)
local ESCUDO_DEFESA = CFrame.new(0, 0, 0.62) * CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, -1, 0))
local OURO = Color3.fromRGB(255, 214, 90)

-- Peça do corpo que a junta move -> junta lógica. A junta é achada pela peça (Part1), e não
-- pelo nome: assim funciona com Motor6D (corpo clássico) e com AnimationConstraint (corpos com
-- o "Avatar Joint Upgrade" do Roblox), que têm C0 e Transform do mesmo jeito.
local JUNTAS_R15 = {
	LowerTorso = "raiz",
	UpperTorso = "cintura",
	Head = "pescoco",
	RightUpperArm = "ombroD",
	RightLowerArm = "cotoveloD",
	RightHand = "pulsoD",
	LeftUpperArm = "ombroE",
	LeftLowerArm = "cotoveloE",
	LeftHand = "pulsoE",
	RightUpperLeg = "quadrilD",
	RightLowerLeg = "joelhoD",
	LeftUpperLeg = "quadrilE",
	LeftLowerLeg = "joelhoE",
	RightFoot = "tornozeloD",
	LeftFoot = "tornozeloE",
}
local JUNTAS_R6 = {
	Torso = "raiz",
	Head = "pescoco",
	["Right Arm"] = "ombroD",
	["Left Arm"] = "ombroE",
	["Right Leg"] = "quadrilD",
	["Left Leg"] = "quadrilE",
}

local A = Poses.A
local POSTURAS = Poses.POSTURAS
local PARADO = Poses.PARADO
local ANDAR = Poses.ANDAR
local FLUTUAR = Poses.FLUTUAR
local ACOES = Poses.ACOES
local ESQUIVAS = Poses.ESQUIVAS
local ATINGIDO = Poses.ATINGIDO
local BLOQUEIO = Poses.BLOQUEIO
local BLOQUEIO_PERFEITO = Poses.BLOQUEIO_PERFEITO
local amostrar = Poses.amostrar
local misturar = Poses.misturar
local angulo = Poses.angulo

-- Valores que não são juntas (corda do arco, brilho do cajado, flecha na mão)
local ESPECIAIS = { puxar = true, brilho = true, flechaMao = true }
-- Pernas: enquanto o personagem anda, o golpe mexe menos nelas (os pés não "patinam")
local PERNAS = { quadrilD = true, joelhoD = true, tornozeloD = true, quadrilE = true, joelhoE = true, tornozeloE = true }

------------------------------------------------------------------------
-- Estado de cada personagem
------------------------------------------------------------------------

local personagens = {} -- [Model] = estado

-- Junta que a animação pode mexer: Motor6D (rig clássico) ou AnimationConstraint (rig novo
-- do Roblox, "Avatar Joint Upgrade"). As duas têm a propriedade Transform.
local function ehJunta(objeto: Instance): boolean
	return objeto:IsA("Motor6D") or objeto:IsA("AnimationConstraint")
end

-- Rotação de referência da junta (onde ela fica presa na peça "pai")
local function rotacaoBase(junta: any): CFrame
	if junta:IsA("Motor6D") then
		return junta.C0.Rotation
	end
	local a0 = junta.Attachment0
	return if a0 then a0.CFrame.Rotation else CFrame.identity
end

-- Peça que a junta move (a "filha")
local function pecaFilha(junta: any): Instance?
	if junta:IsA("Motor6D") then
		return junta.Part1
	end
	local a1 = junta.Attachment1
	return a1 and a1.Parent
end

local function acharJunta(personagem: Model, nomePeca: string, nomeJunta: string): Instance?
	local peca = personagem:FindFirstChild(nomePeca)
	local junta = peca and peca:FindFirstChild(nomeJunta)
	if junta and ehJunta(junta) then
		return junta
	end
	-- em outro lugar com o mesmo nome, ou com outro nome mas movendo a mesma peça
	local porPeca = nil
	for _, objeto in personagem:GetDescendants() do
		if ehJunta(objeto) then
			if objeto.Name == nomeJunta then
				return objeto
			end
			local filha = pecaFilha(objeto)
			if not porPeca and filha and filha.Name == nomePeca then
				porPeca = objeto
			end
		end
	end
	return porPeca
end

local avisouSemJuntas = {}

local function obterJuntas(personagem: Model)
	local juntas = {}
	local mapa = if personagem:FindFirstChild("UpperTorso") then JUNTAS_R15 else JUNTAS_R6
	local quantas = 0
	for _, objeto in personagem:GetDescendants() do
		if ehJunta(objeto) then
			local junta = objeto :: any
			local filha = pecaFilha(junta)
			local nome = if filha then mapa[filha.Name] else nil
			if nome and not juntas[nome] then
				local rotacao = rotacaoBase(junta)
				juntas[nome] = { motor = junta, rot = rotacao, inv = rotacao:Inverse() }
				quantas += 1
			end
		end
	end
	if quantas == 0 and personagem:FindFirstChildOfClass("Humanoid") and not avisouSemJuntas[personagem] then
		avisouSemJuntas[personagem] = true
		task.delay(3, function()
			if personagem.Parent and next(obterJuntas(personagem)) == nil then
				warn("[Animacoes] Nenhuma junta encontrada em " .. personagem.Name .. " (sem Motor6D nem AnimationConstraint): as animações não vão aparecer.")
			end
		end)
	end
	return juntas
end

-- Uma linha no Output dizendo o que foi achado no corpo do próprio jogador (ajuda a descobrir
-- por que uma animação não aparece)
local function avisarCorpo(e)
	if e.jogador ~= jogador then
		return
	end
	local quantas, tipo = 0, "nenhum"
	for _, j in e.juntas do
		quantas += 1
		tipo = j.motor.ClassName
	end
	local corpo = if e.personagem:FindFirstChild("UpperTorso") then "R15" else "R6"
	local assinatura = corpo .. quantas .. tipo
	if e.avisado == assinatura then
		return
	end
	e.avisado = assinatura
	if quantas == 0 then
		warn("[Animacoes] Nenhuma junta encontrada no personagem (" .. corpo .. "): as animações não vão aparecer.")
	elseif corpo == "R6" then
		warn("[Animacoes] Personagem R6: só ombros, quadris e pescoço mexem. Use R15 (Game Settings > Avatar > R15).")
	else
		print(string.format("[Animacoes] Personagem %s com %d juntas (%s): animações ligadas.", corpo, quantas, tipo))
	end
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
		avisarCorpo(e)
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
	-- parte de onde o corpo está (sem "pulos" entre animações); giros grandes (360°, a espada
	-- girando na mão) voltam para perto de zero, para a próxima animação não "desgirar"
	local base = {}
	for junta, v in e.ultimaPose do
		base[junta] = if ESPECIAIS[junta] then v else { angulo(v[1]), angulo(v[2]), angulo(v[3]), v[4], v[5], v[6], v[7] }
	end
	e.acao = {
		def = definicao,
		inicio = agora,
		base = base,
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
	e.chamasLamina = nil
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
		if classe.id == "cavaleiro" or (classe.id == "assassino" and Vfx.temPrefab("CorteAdaga")) then
			-- Cavaleiro e Assassino não têm rastro na lâmina: o efeito do golpe é só o corte do pacote de VFX
			return nil, ponta
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
	-- escudo: a solda do servidor é trocada (só neste computador) por uma que o código move
	e.soldaEscudo = nil
	local escudo = acessorios:FindFirstChild("Escudo")
	local braco = e.personagem:FindFirstChild("LeftLowerArm")
	if escudo and escudo:IsA("BasePart") and braco and braco:IsA("BasePart") then
		for _, solda in escudo:GetChildren() do
			if solda:IsA("WeldConstraint") and (solda.Part0 == braco or solda.Part1 == braco) then
				solda.Enabled = false
			end
		end
		local solda = Instance.new("Weld")
		solda.Name = "SoldaEscudoLocal"
		solda.Part0 = braco
		solda.Part1 = escudo
		solda.C0 = ESCUDO_CARREGADO
		solda.Parent = escudo
		e.soldaEscudo = solda
		e.pesoEscudo = 0
		table.insert(e.detalhes, solda)
	end

	local trilha, ponta = rastroDaLamina(arma)
	e.trilha = trilha
	if ponta then
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
	-- Mago: anel de energia roxo no chão, debaixo dos pés, enquanto levita
	if FLUTUAR[classeDe(e)] and not e.levitacaoAtiva and e.humanoid then
		local raiz = e.personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = e.humanoid
		if raiz then
			e.levitacaoAtiva = true
			local parar = Vfx.prefab("LevitacaoMago", function()
				if not raiz.Parent or humanoid.Health <= 0 or not FLUTUAR[classeDe(e)] then
					e.levitacaoAtiva = false
					return nil
				end
				return CFrame.new(raiz.Position.X, raiz.Position.Y - (humanoid.HipHeight + raiz.Size.Y / 2) + 0.15, raiz.Position.Z)
			end, 0, 1.1)
			if not parar then
				e.levitacaoAtiva = "sem efeito" -- não existe o efeito: não tenta de novo
			end
		end
	end
	-- Mago com a Barreira Arcana ativa: bolha roxa em volta dele (some quando bloqueia um golpe)
	local comBarreira = classeDe(e) == "mago" and e.jogador ~= nil and e.jogador:GetAttribute("BarreiraArcana") == true
	if comBarreira and not e.pararBarreira then
		local tronco = e.personagem:FindFirstChild("UpperTorso") or e.personagem:FindFirstChild("Torso")
		if tronco and tronco:IsA("BasePart") then
			e.pararBarreira = Vfx.prefab("BarreiraArcana", function()
				return if tronco.Parent then CFrame.new(tronco.Position) else nil
			end, 0, 1.7) or false
		end
	elseif not comBarreira and e.pararBarreira then
		e.pararBarreira()
		e.pararBarreira = nil
	end
	-- carta de fogo: a lâmina pega fogo (chamas do pacote de VFX)
	local comFogo = e.jogador ~= nil and e.jogador:GetAttribute("PoderFogo") == true
	if comFogo ~= (e.chamasLamina ~= nil) then
		if e.chamasLamina then
			for _, chama in e.chamasLamina do
				chama.Enabled = false
				game:GetService("Debris"):AddItem(chama, 1)
			end
			e.chamasLamina = nil
		else
			local efeitos = ReplicatedStorage:FindFirstChild("EfeitosVFX")
			local molde = if efeitos then efeitos:FindFirstChild("LaminaFogo") else nil
			-- espada: a lâmina pega fogo; arco: a ponta da flecha encaixada vira brasa
			local lamina = e.arma:FindFirstChild("Lamina") or e.pontaFlecha
			local fator = if lamina == e.pontaFlecha then 0.2 else 0.45
			if molde and lamina then
				e.chamasLamina = {}
				for _, original in molde:GetDescendants() do
					if original:IsA("ParticleEmitter") then
						local chama = original:Clone()
						-- menor, para caber na lâmina
						local chaves = {}
						for _, k in chama.Size.Keypoints do
							table.insert(chaves, NumberSequenceKeypoint.new(k.Time, k.Value * fator, k.Envelope * fator))
						end
						chama.Size = NumberSequence.new(chaves)
						chama.Rate = chama.Rate * 0.5
						chama.Enabled = true
						chama.Parent = lamina
						table.insert(e.chamasLamina, chama)
						table.insert(e.detalhes, chama)
					end
				end
			end
		end
	end
	if e.soldaEscudo then
		-- o escudo vai para a frente quando defende e volta para o lado quando solta
		local dt = math.clamp(agora - (e.quadroArma or agora), 0, 0.1)
		local alvo = if e.defendendo then 1 else 0
		e.pesoEscudo = (e.pesoEscudo or 0) + (alvo - (e.pesoEscudo or 0)) * math.min(1, dt * 16)
		e.soldaEscudo.C0 = ESCUDO_CARREGADO:Lerp(ESCUDO_DEFESA, e.pesoEscudo)
	end
	e.quadroArma = agora
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
		if e.chamasLamina then
			for _, chama in e.chamasLamina do
				if chama.Enabled ~= visivel then
					chama.Enabled = visivel
				end
			end
		end
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
		-- (Cavaleiro e Arqueiro usam o efeito de carga do pacote de VFX, sem estas partículas)
		local classe = classeDe(e)
		local cargaPronta = classe == "cavaleiro"
			or (classe == "arqueiro" and Vfx.temPrefab("CargaArqueiro"))
			or (classe == "assassino" and Vfx.temPrefab("CargaAssassino"))
		e.emissorCarga.Rate = if e.carregando and not cargaPronta then 20 + 60 * carga else 0
		if e.carregando and carga >= 1 and not e.cheioAvisado then
			e.cheioAvisado = true
			e.emissorCarga.Color = ColorSequence.new(Color3.new(1, 1, 1), OURO)
			-- o Arqueiro brilha na ponta da flecha (a corda está puxada até o rosto)
			local onde = if classe == "arqueiro" and e.pontaFlecha and e.pontaFlecha.Transparency < 1
				then e.pontaFlecha.Position
				else e.pontaArma.WorldPosition
			-- o Assassino acende um selo vermelho no chão, debaixo dele
			local raizCarga = e.personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
			if classe == "assassino" and raizCarga then
				onde = raizCarga.Position - Vector3.new(0, 2.6, 0)
			end
			Vfx.cargaCheia({ pos = onde, local_ = e.jogador == jogador, classe = classe })
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

local function cframeDe(v): CFrame
	return CFrame.new(v[4], v[5], v[6]) * CFrame.fromEulerAnglesYXZ(v[1], v[2], v[3])
end

local function animarPersonagem(e, agora: number)
	-- junta -> { CFrame, peso }. As camadas são misturadas como rotações (CFrame:Lerp), não
	-- ângulo por ângulo: assim a volta de um golpe para a guarda faz sempre o caminho curto.
	local final = {}
	local especiais = {} -- puxar/brilho/flechaMao -> { valor, peso }
	local classe = classeDe(e)

	-- Mistura uma camada por cima: o peso de cada junta é o peso da camada vezes o peso
	-- do próprio valor (o 7º número)
	local function aplicarCamada(pose, peso: number, pesoPernas: number?)
		for junta, valor in pose do
			local w = peso * (valor[7] or 1)
			if pesoPernas and PERNAS[junta] then
				w *= pesoPernas
			end
			if w > 0.001 then
				if ESPECIAIS[junta] then
					local atual = especiais[junta]
					especiais[junta] = if atual then { atual[1] + (valor[1] - atual[1]) * w, atual[2] + (1 - atual[2]) * w } else { valor[1], w }
				else
					local atual = final[junta]
					local alvo = cframeDe(valor)
					if atual then
						final[junta] = { atual[1]:Lerp(alvo, w), atual[2] + (1 - atual[2]) * w }
					else
						final[junta] = { alvo, w }
					end
				end
			end
		end
	end

	local postura = POSTURAS[classe]
	if postura then
		aplicarCamada(postura, PESO_POSTURA)
	end

	local raiz = e.personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	local dt = math.clamp(agora - (e.ultimoQuadro or agora), 0, 0.1)
	e.ultimoQuadro = agora

	-- Andar próprio da classe (no lugar da animação de andar do avatar do jogador): a passada
	-- acompanha a velocidade e a direção em que o corpo anda; no ar, volta a animação de pulo
	local andar = ANDAR[classe]
	if andar and raiz then
		local v = raiz.AssemblyLinearVelocity
		local plano = Vector3.new(v.X, 0, v.Z)
		local velocidade = plano.Magnitude
		local humanoid = e.humanoid
		local noChao = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
		local alvo = if noChao and velocidade > 1.5 then 1 else 0
		e.andando = (e.andando or 0) + (alvo - (e.andando or 0)) * math.min(1, dt * 12)
		if e.andando > 0.01 then
			local frente, lado = 1, 0
			if velocidade > 0.5 then
				local relativo = raiz.CFrame:VectorToObjectSpace(plano)
				frente, lado = -relativo.Z / velocidade, relativo.X / velocidade
			end
			-- uma volta da fase = dois passos, a cada 8 studs andados (passos longos e pesados);
			-- o Arqueiro dá passos mais curtos e rápidos (Poses.PASSADA)
			local passada = Poses.PASSADA[classe] or 8
			e.fase = ((e.fase or 0) + dt * velocidade * (2 * math.pi / passada)) % (2 * math.pi)
			aplicarCamada(andar(e.fase, frente, lado, math.clamp(velocidade / 16, 0, 1)), e.andando)
		end
	end

	-- Pose parada: entra suave quando o personagem para e sai quando ele anda ou pula
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
			-- andando, as pernas seguem mais a corrida do que o golpe
			aplicarCamada(pose, peso, 0.3 + 0.7 * (e.parado or 0))
		end
	end

	-- Levitação (Mago): pernas soltas por cima do golpe (a altura entra no fim, na raiz)
	local flutuar = FLUTUAR[classe]
	if flutuar then
		aplicarCamada(flutuar.pernas(agora, e.andando or 0), 1)
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
			aplicarCamada(if d.def.continuo then d.def.continuo(tau, {}) else amostrar(d.def, tau, {}), peso)
		end
	end

	-- reações rápidas por cima de tudo: levou dano / escudo bloqueou
	local bloqueio = if e.bloqueioPerfeito then BLOQUEIO_PERFEITO else BLOQUEIO
	for _, info in { { "atingido", ATINGIDO, 0.8 }, { "bloqueou", bloqueio, 1 } } do
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

	e.puxar = if especiais.puxar then especiais.puxar[1] * especiais.puxar[2] else 0
	e.brilho = if especiais.brilho then especiais.brilho[1] * especiais.brilho[2] else 0
	e.flechaMao = if especiais.flechaMao then especiais.flechaMao[1] * especiais.flechaMao[2] else 0

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
		avisarCorpo(e)
	end

	if flutuar then
		-- o corpo inteiro sobe e desce devagar, acima do chão
		local altura = flutuar.altura + math.sin(agora * 2) * flutuar.balanco
		local atual = final.raiz
		final.raiz = { CFrame.new(0, altura, 0) * (if atual then atual[1] else CFrame.identity), 1 }
	end

	for junta, info in final do
		local j = e.juntas[junta]
		local peso = info[2]
		if j and peso > 0.001 and j.motor.Parent then
			local alvo = j.inv * info[1] * j.rot
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
-- Sons de cada golpe, no ritmo da animação: o vulto da lâmina chega no auge junto com o
-- impacto; o arqueiro puxa a corda e solta no disparo. (As magias tocam ao sair, em Vfx.)
local function sonsDoAtaque(personagem: Model, classe: string, combo: number)
	local raiz = personagem:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return
	end
	local impacto = Classes.obter(classe).ataque.impacto
	local momento = if impacto then impacto[combo] or 0 else 0
	local function depois(segundos: number, nome: string, opcoes)
		task.delay(math.max(0, segundos), function()
			if raiz.Parent then
				opcoes = opcoes or {}
				opcoes.pai = raiz
				Sons.tocar(nome, opcoes)
			end
		end)
	end
	if classe == "cavaleiro" then
		if combo == 3 then
			depois(momento - 0.2, "espadaPesada", { tom = 0.85 })
		else
			depois(momento - 0.13, "espada")
		end
	elseif classe == "assassino" then
		if combo == 3 then
			depois(momento - 0.13, "espada", { tom = 1.3 })
		else
			depois(momento - 0.06, "adaga")
		end
	elseif classe == "arqueiro" then
		depois(momento * 0.55, "arcoPuxar")
		depois(momento, "arcoSoltar")
	end
end

-- Efeitos presos ao corpo (vento da carga, barreira do escudo): cada um devolve uma função
-- que apaga o efeito
local function pararEfeito(e, campo: string)
	local parar = e[campo]
	if parar then
		e[campo] = nil
		parar()
	end
end

-- Tem carta de fogo? (o servidor marca o jogador; muda os efeitos para as versões de fogo)
local function comFogo(e): boolean
	return e.jogador ~= nil and e.jogador:GetAttribute("PoderFogo") == true
end

--[[ Disparo do Arqueiro: daqui a "momento" segundos (quando a corda solta), sai do arco o anel
	de vento (tiro normal) ou a rajada (tiro forte), na direção em que o corpo olha.
	"subir" inclina a direção para o alto (Chuva de Flechas). ]]
local function disparoDoArco(e, momento: number, forte: boolean, escala: number, subir: Vector3?)
	task.delay(math.max(0, momento), function()
		local raiz = e.personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not raiz or not e.personagem.Parent then
			return
		end
		local direcao = raiz.CFrame.LookVector + (subir or Vector3.zero)
		local origem = if e.arco and e.arco.Parent then e.arco.Position else raiz.Position + Vector3.new(0, 1, 0)
		Vfx.disparoArqueiro(origem + direcao.Unit * 0.8, direcao, forte, escala, comFogo(e))
	end)
end

function Animacoes.tocar(personagem: Model, acao: string, dados)
	if not personagem or not personagem.Parent then
		return
	end
	dados = dados or {}
	local e = estadoDe(personagem)
	local classe = if Classes.existe(dados.classe) then dados.classe else classeDe(e)
	local acoes = ACOES[classe]
	local cor = Classes.obter(classe).cor
	-- o zumbido de carregar para quando o golpe sai, é cancelado ou o personagem esquiva
	if acao == "soltar" or acao == "cancelar" or acao == "esquiva" or acao == "defender" then
		Sons.parar(e.somCarga)
		e.somCarga = nil
		pararEfeito(e, "efeitoCarga")
	end
	if acao ~= "defender" and acao ~= "bloqueou" and acao ~= "atingido" then
		pararEfeito(e, "efeitoEscudo")
	end
	local raizSom = personagem:FindFirstChild("HumanoidRootPart")
	if acao == "ataque" then
		local combo = math.clamp(dados.combo or 1, 1, 3)
		sonsDoAtaque(personagem, classe, combo)
		comecar(e, acoes["ataque" .. combo], dados)
		if classe == "arqueiro" then
			local impacto = Classes.obter(classe).ataque.impacto
			disparoDoArco(e, if impacto then impacto[combo] or 0 else 0, combo == 3, if combo == 3 then 0.3 else 0.55)
		end
	elseif acao == "carregar" then
		if raizSom then
			e.somCarga = Sons.tocar("carregar", { pai = raizSom })
			if classe == "arqueiro" then
				Sons.tocar("arcoPuxar", { pai = raizSom, tom = 0.85 })
			end
		end
		e.carregando = true
		e.cargaInicio = os.clock()
		e.cheioAvisado = false
		comecar(e, acoes.carregar, dados)
		if classe == "cavaleiro" then
			-- o vento do tornado se formando em volta enquanto a espada gira
			pararEfeito(e, "efeitoCarga")
			e.efeitoCarga = Vfx.ventoCarga(personagem, cor, function()
				return cargaDe(e)
			end)
		elseif classe == "arqueiro" then
			-- energia juntando na ponta da flecha (na mão ao pegar da aljava, depois no arco)
			pararEfeito(e, "efeitoCarga")
			e.efeitoCarga = Vfx.cargaArqueiro(function()
				if not personagem.Parent then
					return nil
				end
				if e.pontaFlecha and e.pontaFlecha.Transparency < 1 then
					return e.pontaFlecha.Position
				end
				return if e.encaixe then e.encaixe.WorldPosition else nil
			end, comFogo(e))
		elseif classe == "assassino" and raizSom then
			-- a escuridão se junta em volta dele enquanto ele se encolhe
			pararEfeito(e, "efeitoCarga")
			local raizCarga = raizSom :: BasePart
			e.efeitoCarga = Vfx.prefab("CargaAssassino", function()
				return if raizCarga.Parent then CFrame.new(raizCarga.Position) else nil
			end, 0, 0.2)
		end
	elseif acao == "soltar" then
		e.carregando = false
		if e.emissorCarga and e.corClasse then
			e.emissorCarga.Color = ColorSequence.new(e.corClasse:Lerp(Color3.new(1, 1, 1), 0.4), e.corClasse)
		end
		comecar(e, acoes.soltar, dados)
		if classe == "arqueiro" then
			disparoDoArco(e, 0.03, true, 0.35 + 0.25 * math.clamp(dados.fracao or 0, 0, 1))
		end
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
		if acao == "habilidade" and classe == "arqueiro" and raizSom then
			Vfx.saltoArqueiro(raizSom :: BasePart)
			task.delay(0.18, function()
				Sons.tocar("arcoSoltar", { pai = raizSom, tom = 1.1 })
			end)
			-- o arco aponta para o alto: a rajada sobe para a frente
			disparoDoArco(e, 0.18, true, 0.4, Vector3.new(0, 1.6, 0))
		end
		comecar(e, acoes[acao], dados)
	elseif acao == "defender" then
		if raizSom then
			Sons.tocar("escudo", { pai = raizSom, volume = 0.25, tom = 1.5 })
		end
		e.carregando = false
		e.defendendo = true
		comecar(e, acoes.defender, dados)
		pararEfeito(e, "efeitoEscudo")
		e.efeitoEscudo = Vfx.barreiraEscudo(personagem, cor)
	elseif acao == "pararDefesa" then
		e.defendendo = false
		if e.acao and e.acao.def == acoes.defender then
			e.acao.soltando = os.clock()
		end
	elseif acao == "bloqueou" then
		e.bloqueou = os.clock()
		e.bloqueioPerfeito = dados.perfeita == true
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
				if not humanoid or not humanoid.Parent then
					-- o estado pode ter sido criado antes do Humanoid aparecer
					humanoid = personagem:FindFirstChildOfClass("Humanoid")
					e.humanoid = humanoid
				end
				if humanoid and humanoid.Health > 0 and not humanoid.Sit then
					local ok, erro = pcall(animarPersonagem, e, agora)
					if not ok and not e.erroAvisado then
						-- mostra o erro uma vez só (em vez de a animação sumir em silêncio)
						e.erroAvisado = true
						warn("[Animacoes] Erro ao animar " .. personagem.Name .. ": " .. tostring(erro))
					end
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
