-- Animações dos personagens feitas por código (não precisam de arquivos de animação).
--
-- Cada animação é uma lista de "quadros-chave": em cada tempo, o ângulo de algumas juntas
-- (ombro, cotovelo, cintura...). Entre os quadros, os ângulos são suavizados. A animação é
-- aplicada por cima da animação padrão do Roblox (andar, pular), então as pernas continuam
-- andando enquanto os braços atacam.
--
-- Ângulos em radianos, no espaço da peça "pai" (X = direita, Y = cima, Z = trás):
--   rx > 0 leva o braço/perna para FRENTE (1,57 = esticado para frente; 3,14 = para cima)
--   ry > 0 gira para a ESQUERDA (visto de cima)   rz > 0 abre o braço direito para o lado
--   no tronco, rx < 0 inclina para frente

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Classes = require(Shared:WaitForChild("Classes"))

local Vfx = require(script.Parent.Vfx)

local Animacoes = {}

local jogador = Players.LocalPlayer
local pasta = Instance.new("Folder")
pasta.Name = "AnimacoesLocais"
pasta.Parent = workspace

local PESO_POSTURA = 0.75
local ZERO = { 0, 0, 0, 0, 0, 0 }
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
}
local JUNTAS_R6 = {
	raiz = { "HumanoidRootPart", "RootJoint" },
	pescoco = { "Torso", "Neck" },
	ombroD = { "Torso", "Right Shoulder" },
	ombroE = { "Torso", "Left Shoulder" },
	quadrilD = { "Torso", "Right Hip" },
	quadrilE = { "Torso", "Left Hip" },
}

-- Ângulos (rx, ry, rz) e deslocamento (px, py, pz)
local function A(rx: number?, ry: number?, rz: number?, px: number?, py: number?, pz: number?)
	return { rx or 0, ry or 0, rz or 0, px or 0, py or 0, pz or 0 }
end

local function juntar(base, extra)
	local resultado = table.clone(base)
	for chave, valor in extra do
		resultado[chave] = valor
	end
	return resultado
end

------------------------------------------------------------------------
-- Posturas (como cada classe segura a arma parada) e animações
------------------------------------------------------------------------

local POSTURAS = {
	cavaleiro = { ombroD = A(0.35, 0, 0.12), cotoveloD = A(0.6), ombroE = A(0.55, 0.35, -0.1), cotoveloE = A(1.1) },
	mago = { ombroD = A(0.25, 0, 0.1), cotoveloD = A(0.8), pulsoD = A(-1.05), ombroE = A(0.15, 0, -0.12) },
	arqueiro = { ombroE = A(0.45, 0.2, -0.1), cotoveloE = A(0.3), ombroD = A(0.15, 0, 0.1) },
}

-- Arqueiro mirando: corpo de lado, braço do arco esticado, mão puxando a corda até o rosto
local MIRA = {
	cintura = A(0, -0.85),
	pescoco = A(0, 0.75),
	ombroE = A(1.57, 0.85),
	cotoveloE = A(0),
	pulsoE = A(0),
	ombroD = A(1.45, 1.1),
	cotoveloD = A(2.2),
	puxar = A(1),
}

local function lancarMago(lado: number)
	return {
		duracao = 0.32,
		quadros = {
			{ t = 0.07, suave = "forte", pose = { ombroD = A(1.55, -0.15 * lado), cotoveloD = A(0.1), pulsoD = A(-0.2), ombroE = A(1.4, 0.3, -0.1), cotoveloE = A(0.2), cintura = A(0, -0.2 * lado), brilho = A(1) } },
		},
	}
end

local CONJURAR_MAGO = {
	duracao = 0.5,
	quadros = {
		{ t = 0.13, pose = { ombroD = A(2.9, 0, 0.1), cotoveloD = A(0.2), pulsoD = A(0), ombroE = A(2.6, 0, -0.1), cintura = A(0.25), brilho = A(1) } },
		{ t = 0.24, suave = "forte", pose = { ombroD = A(1.5), cotoveloD = A(0), pulsoD = A(-0.1), ombroE = A(1.5, 0.3), cintura = A(-0.3), raiz = A(-0.12, 0, 0, 0, -0.2, 0), brilho = A(1.5) } },
	},
}

local function tiroArqueiro()
	return {
		duracao = 0.3,
		quadros = {
			{ t = 0.06, pose = MIRA },
			{ t = 0.09, suave = "forte", pose = { ombroD = A(1.3, 1.5, 0.3), cotoveloD = A(0.9), ombroE = A(1.75, 0.85), puxar = A(0) } },
		},
	}
end

local ACOES = {
	cavaleiro = {
		-- corte da direita para a esquerda
		ataque1 = {
			duracao = 0.34,
			trilha = true,
			quadros = {
				{ t = 0.07, pose = { ombroD = A(1.25, -1.25, 0.25), cotoveloD = A(0.5), pulsoD = A(-1.1), cintura = A(0, -0.55), raiz = A(0, -0.15) } },
				{ t = 0.17, suave = "forte", pose = { ombroD = A(1.45, 1.05), cotoveloD = A(0.15), pulsoD = A(-1.2), cintura = A(-0.1, 0.6), raiz = A(-0.12, 0.2) } },
			},
		},
		-- revés, da esquerda para a direita
		ataque2 = {
			duracao = 0.34,
			trilha = true,
			quadros = {
				{ t = 0.07, pose = { ombroD = A(1.35, 1, -0.2), cotoveloD = A(1), pulsoD = A(-1.2), cintura = A(0, 0.55), raiz = A(0, 0.12) } },
				{ t = 0.17, suave = "forte", pose = { ombroD = A(1.35, -1.2, 0.2), cotoveloD = A(0.2), pulsoD = A(-1.2), cintura = A(-0.1, -0.6), raiz = A(-0.1, -0.2) } },
			},
		},
		-- golpe final: espada por cima da cabeça e para baixo
		ataque3 = {
			duracao = 0.48,
			trilha = true,
			quadros = {
				{ t = 0.12, pose = { ombroD = A(3, 0.1), cotoveloD = A(0.35), pulsoD = A(0.2), ombroE = A(1.4, 0.4), cintura = A(0.25), raiz = A(0.08, 0, 0, 0, 0.15, 0) } },
				{
					t = 0.22,
					suave = "forte",
					pose = {
						ombroD = A(0.75),
						cotoveloD = A(0.05),
						pulsoD = A(-0.6),
						ombroE = A(0.5, 0.3),
						cintura = A(-0.4),
						raiz = A(-0.25, 0, 0, 0, -0.35, 0),
						quadrilD = A(0.6),
						joelhoD = A(-0.7),
						quadrilE = A(-0.35),
						joelhoE = A(-0.3),
					},
				},
			},
		},
		-- carregando: espada para trás, corpo torcido, pernas abertas
		carregar = {
			manter = true,
			quadros = {
				{
					t = 0.15,
					pose = {
						ombroD = A(0.9, -1.7, 0.4),
						cotoveloD = A(0.4),
						pulsoD = A(-0.9),
						ombroE = A(0.8, 0.5),
						cintura = A(0, -0.9),
						raiz = A(-0.15, -0.1, 0, 0, -0.3, 0),
						quadrilD = A(-0.35, 0, 0.2),
						quadrilE = A(0.45, 0, -0.2),
						joelhoE = A(-0.5),
					},
				},
			},
		},
		-- solta: giro completo com a espada estendida
		soltar = {
			duracao = 0.45,
			trilha = true,
			quadros = {
				{ t = 0.05, suave = "forte", pose = { ombroD = A(0.35, 0, 1.45), cotoveloD = A(0), pulsoD = A(-1.2), ombroE = A(0.5, 0, -1), cintura = A(0, 0.4), raiz = A(-0.1, 0, 0, 0, -0.2, 0) } },
				{ t = 0.33, suave = "linear", pose = { raiz = A(-0.1, math.pi * 2, 0, 0, -0.2, 0) } },
			},
		},
		-- Redemoinho: gira sem parar enquanto durar
		habilidade = {
			trilha = true,
			continuo = function(tau)
				return { raiz = A(-0.08, tau * 14, 0, 0, -0.15, 0), ombroD = A(0.35, 0, 1.45), cotoveloD = A(0), pulsoD = A(-1.2), ombroE = A(0.5, 0, -1) }
			end,
		},
		-- Julgamento: salta com a espada no alto e esmaga o chão
		supremo = {
			duracao = 0.75,
			trilha = true,
			quadros = {
				{ t = 0.18, pose = { ombroD = A(3), cotoveloD = A(0.2), ombroE = A(2.8), cintura = A(0.25), raiz = A(0.1, 0, 0, 0, 0.8, 0), quadrilD = A(0.5), joelhoD = A(-0.9), quadrilE = A(0.5), joelhoE = A(-0.9) } },
				{
					t = 0.34,
					suave = "forte",
					pose = {
						ombroD = A(0.6),
						cotoveloD = A(0),
						pulsoD = A(-0.8),
						ombroE = A(0.6),
						cintura = A(-0.45),
						raiz = A(-0.3, 0, 0, 0, -0.7, 0),
						quadrilD = A(0.9),
						joelhoD = A(-1.2),
						quadrilE = A(-0.4),
						joelhoE = A(-0.5),
					},
				},
			},
		},
	},

	mago = {
		ataque1 = lancarMago(1),
		ataque2 = lancarMago(-1),
		ataque3 = CONJURAR_MAGO,
		carregar = {
			manter = true,
			quadros = {
				{ t = 0.2, pose = { ombroD = A(2.85, 0, 0.15), cotoveloD = A(0.3), pulsoD = A(0), ombroE = A(1.5, 0.35, -0.1), cotoveloE = A(0.3), cintura = A(0.15), raiz = A(0.05), brilho = A(1) } },
			},
		},
		soltar = {
			duracao = 0.45,
			quadros = {
				{ t = 0.07, suave = "forte", pose = { ombroD = A(1.45), cotoveloD = A(0), pulsoD = A(-0.1), ombroE = A(1.45, 0.3), cintura = A(-0.35), raiz = A(-0.15, 0, 0, 0, -0.25, 0), brilho = A(2) } },
			},
		},
		habilidade = CONJURAR_MAGO,
		-- Tempestade: braços para o céu enquanto os raios caem
		supremo = {
			continuo = function(tau)
				local s = math.sin(tau * 6) * 0.08
				return { ombroD = A(2.9 + s, 0, 0.25), cotoveloD = A(0.2), pulsoD = A(0), ombroE = A(2.9 - s, 0, -0.25), cintura = A(0.2), raiz = A(0.05), brilho = A(1.5) }
			end,
		},
	},

	arqueiro = {
		ataque1 = tiroArqueiro(),
		ataque2 = tiroArqueiro(),
		ataque3 = {
			duracao = 0.42,
			quadros = {
				{ t = 0.12, pose = juntar(MIRA, { raiz = A(0.05), puxar = A(1.1) }) },
				{ t = 0.16, suave = "forte", pose = { ombroD = A(1.1, 1.7, 0.5), cotoveloD = A(0.6), ombroE = A(1.9, 0.85), raiz = A(0.14), puxar = A(0) } },
			},
		},
		carregar = {
			manter = true,
			quadros = { { t = 0.2, pose = juntar(MIRA, { puxar = A(1.15), raiz = A(0.04) }) } },
		},
		soltar = {
			duracao = 0.42,
			quadros = {
				{ t = 0.04, suave = "forte", pose = { ombroD = A(1, 1.8, 0.6), cotoveloD = A(0.5), ombroE = A(1.95, 0.85), raiz = A(0.16), puxar = A(0) } },
			},
		},
		-- Chuva de Flechas: mira para o alto
		habilidade = {
			duracao = 0.5,
			quadros = {
				{ t = 0.12, pose = { cintura = A(0, -0.85), pescoco = A(-0.5, 0.75), ombroE = A(2.35, 0.85), ombroD = A(2.2, 1.1), cotoveloD = A(2.2), puxar = A(1) } },
				{ t = 0.18, suave = "forte", pose = { ombroD = A(2, 1.5, 0.3), cotoveloD = A(0.9), puxar = A(0) } },
			},
		},
		-- Saraivada: gira atirando sem parar
		supremo = {
			continuo = function(tau)
				local pose = table.clone(MIRA)
				pose.raiz = A(0, tau * 10)
				pose.puxar = A((math.sin(tau * 21) + 1) / 2)
				return pose
			end,
		},
	},
}

-- Esquiva: corpo baixo e inclinado, braços para trás
local ESQUIVA = {
	duracao = 0.32,
	entrada = 0.03,
	quadros = {
		{
			t = 0.05,
			pose = {
				raiz = A(-0.55, 0, 0, 0, -0.5, 0),
				cintura = A(-0.25),
				pescoco = A(0.3),
				ombroD = A(-0.6, 0, 0.25),
				ombroE = A(-0.6, 0, -0.25),
				cotoveloD = A(0.3),
				cotoveloE = A(0.3),
				quadrilD = A(0.75),
				joelhoD = A(-1),
				quadrilE = A(-0.55),
				joelhoE = A(-0.4),
			},
		},
	},
}

local ATINGIDO = {
	duracao = 0.22,
	quadros = { { t = 0.05, suave = "forte", pose = { cintura = A(0.28), pescoco = A(0.2), raiz = A(0.08) } } },
}

------------------------------------------------------------------------
-- Interpolação
------------------------------------------------------------------------

local function suavizar(tipo: string?, a: number): number
	if tipo == "linear" then
		return a
	elseif tipo == "forte" then
		return 1 - (1 - a) ^ 4
	end
	return 1 - (1 - a) * (1 - a)
end

local function misturar(a, b, alfa: number)
	return {
		a[1] + (b[1] - a[1]) * alfa,
		a[2] + (b[2] - a[2]) * alfa,
		a[3] + (b[3] - a[3]) * alfa,
		a[4] + (b[4] - a[4]) * alfa,
		a[5] + (b[5] - a[5]) * alfa,
		a[6] + (b[6] - a[6]) * alfa,
	}
end

local function juntasUsadas(definicao)
	if definicao.juntas then
		return definicao.juntas
	end
	local lista, vistas = {}, {}
	for _, quadro in definicao.quadros do
		for junta in quadro.pose do
			if not vistas[junta] then
				vistas[junta] = true
				table.insert(lista, junta)
			end
		end
	end
	definicao.juntas = lista
	return lista
end

-- Pose da animação no tempo "tau", partindo da pose "base"
local function amostrar(definicao, tau: number, base)
	local quadros = definicao.quadros
	local indice = 0
	for k, quadro in quadros do
		if quadro.t <= tau then
			indice = k
		end
	end
	local pose = {}
	for _, junta in juntasUsadas(definicao) do
		local inicio = base[junta] or ZERO
		for k = indice, 1, -1 do
			local v = quadros[k].pose[junta]
			if v then
				inicio = v
				break
			end
		end
		local proximo = quadros[indice + 1]
		if proximo and proximo.pose[junta] then
			local t0 = if indice == 0 then 0 else quadros[indice].t
			local alfa = suavizar(proximo.suave, math.clamp((tau - t0) / math.max(proximo.t - t0, 0.001), 0, 1))
			pose[junta] = misturar(inicio, proximo.pose[junta], alfa)
		else
			pose[junta] = inicio
		end
	end
	return pose
end

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
	e.trilha, e.encaixe, e.flecha, e.glow, e.esfera, e.emissorCarga = nil, nil, nil, nil, nil, nil
	if not arma then
		return
	end
	local classe = Classes.obter(classeDe(e))

	local lamina = arma:FindFirstChild("Lamina")
	if lamina then
		local base = lamina:FindFirstChild("TrilhaBase") :: Attachment?
		local ponta = lamina:FindFirstChild("TrilhaPonta") :: Attachment?
		if base and ponta then
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
			e.trilha = trilha
			table.insert(e.detalhes, trilha)
			e.pontaArma = ponta
		end
	end

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
		local ligada = acao ~= nil and acao.def.trilha == true and (acao.soltando == nil) and (agora - acao.inicio) < (if acao.def.continuo then math.huge else acao.duracao * 0.8)
		if e.trilha.Enabled ~= ligada then
			e.trilha.Enabled = ligada
		end
	end
	if e.encaixe and e.arco and e.flecha then
		local puxar = math.clamp(e.puxar, 0, 1.3)
		local z = 0.62 + puxar * 1.6
		e.encaixe.Position = Vector3.new(0, 0, z)
		local visivel = puxar > 0.15
		e.flecha.Transparency = if visivel then 0 else 1
		e.pontaFlecha.Transparency = if visivel then 0 else 1
		if visivel then
			local cf = e.arco.CFrame * CFrame.new(0, 0, z - 1.35)
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

------------------------------------------------------------------------
-- Aplicar a pose nas juntas (depois da animação padrão, antes da física)
------------------------------------------------------------------------

local function pesoDaAcao(a, agora: number): (number, number)
	local tau = agora - a.inicio
	local entrada = a.def.entrada or 0.05
	local peso = math.min(1, tau / entrada)
	if a.soltando then
		peso *= math.max(0, 1 - (agora - a.soltando) / 0.15)
	elseif not a.def.manter then
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
	local postura = POSTURAS[classeDe(e)]
	if postura then
		for junta, valor in postura do
			final[junta] = { valor, PESO_POSTURA }
		end
	end

	local function aplicarCamada(pose, peso: number)
		for junta, valor in pose do
			local atual = final[junta]
			if atual then
				final[junta] = { misturar(atual[1], valor, peso), atual[2] + (1 - atual[2]) * peso }
			else
				final[junta] = { valor, peso }
			end
		end
	end

	local a = e.acao
	if a then
		local peso, tau = pesoDaAcao(a, agora)
		if peso <= 0 and (a.soltando or tau > a.duracao) then
			e.acao = nil
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
			e.ultimaPose = pose
			aplicarCamada(pose, peso)
		end
	end

	local d = e.dash
	if d then
		local tau = agora - d.inicio
		local peso = math.min(1, tau / 0.03)
		if tau > ESQUIVA.duracao - 0.12 then
			peso *= math.max(0, (ESQUIVA.duracao - tau) / 0.12)
		end
		if tau >= ESQUIVA.duracao then
			e.dash = nil
		else
			aplicarCamada(amostrar(ESQUIVA, tau, {}), peso)
		end
	end

	local h = e.atingido
	if h then
		local tau = agora - h
		if tau >= ATINGIDO.duracao then
			e.atingido = nil
		else
			local peso = math.min(1, tau / 0.03) * math.max(0, 1 - tau / ATINGIDO.duracao)
			aplicarCamada(amostrar(ATINGIDO, tau, {}), peso * 0.8)
		end
	end

	e.puxar = if final.puxar then final.puxar[1][1] * final.puxar[2] else 0
	e.brilho = if final.brilho then final.brilho[1][1] * final.brilho[2] else 0

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
	      "esquiva", "habilidade", "supremo" (dados.duracao), "atingido" ]]
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
		e.dash = { inicio = os.clock() }
		Vfx.esquiva({ jogador = e.jogador, classe = classe })
	elseif acao == "habilidade" or acao == "supremo" then
		comecar(e, acoes[acao], dados)
	elseif acao == "atingido" then
		e.atingido = os.clock()
	end
end

-- Ações que o próprio jogador já anima na hora do clique (o servidor não manda de volta)
local PREVISTAS = { ataque = true, carregar = true, soltar = true, cancelar = true, esquiva = true }

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
