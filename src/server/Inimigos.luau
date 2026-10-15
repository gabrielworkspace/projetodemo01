-- Inimigos: tipos, ataques, elites, chefes e inteligência.
-- No servidor o inimigo é só uma "caixa" invisível que anda (Humanoid). A aparência e as
-- animações são desenhadas no computador de cada jogador (Client/Modelos e Client/VisualInimigos).

local CollectionService = game:GetService("CollectionService")

local servidor = script.Parent
local Vfx = require(servidor.Vfx)
local Projeteis = require(servidor.Projeteis)
local Combate = require(servidor.Combate)
local Masmorra = require(servidor.Masmorra)

local Inimigos = {}

local function planar(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function unidade(v: Vector3, padrao: Vector3): Vector3
	local p = planar(v)
	return if p.Magnitude > 0.01 then p.Unit else padrao
end

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

------------------------------------------------------------------------
-- Tipos de inimigo
-- raiz/quadril/raio: tamanho da caixa invisível | vida/dano: valores na primeira sala
-- comportamento: "perseguir" (corpo a corpo), "distancia" ou "flutuar" (mantém distância)
-- ataques: testados em ordem; o primeiro pronto e dentro do alcance é usado
------------------------------------------------------------------------
Inimigos.TIPOS = {
	-- Calabouço
	gosma = {
		nome = "Gosma", raiz = V(3, 2.4, 3), quadril = 0.4, raio = 1.8, alturaBarra = 3.6,
		vida = 34, dano = 8, velocidade = 11, ouro = 3, divide = "gosminha",
		ataques = { { tipo = "golpe", alcance = 5, arco = 360, preparo = 0.55, recarga = 1.4 } },
	},
	gosminha = {
		nome = "Gosminha", raiz = V(1.8, 1.4, 1.8), quadril = 0.3, raio = 1.1, alturaBarra = 2.4,
		vida = 12, dano = 5, velocidade = 14, ouro = 1,
		ataques = { { tipo = "golpe", alcance = 3.6, arco = 360, preparo = 0.45, recarga = 1.2 } },
	},
	esqueleto = {
		nome = "Esqueleto Guerreiro", raiz = V(2, 2, 1), quadril = 2, raio = 1.3, alturaBarra = 4,
		vida = 55, dano = 11, velocidade = 14, ouro = 5,
		ataques = { { tipo = "golpe", alcance = 6.5, arco = 110, preparo = 0.5, recarga = 1.3 } },
	},
	esqueletoArqueiro = {
		nome = "Esqueleto Arqueiro", raiz = V(2, 2, 1), quadril = 2, raio = 1.3, alturaBarra = 4,
		vida = 36, dano = 10, velocidade = 13, ouro = 5, comportamento = "distancia", distancia = 24,
		ataques = { { tipo = "disparo", alcance = 42, preparo = 0.7, recarga = 2.4, projetil = "flechaOssea", velocidade = 55 } },
	},
	rato = {
		nome = "Rato do Esgoto", raiz = V(1.6, 1.2, 2.4), quadril = 0.5, raio = 1.2, alturaBarra = 2.4,
		vida = 18, dano = 6, velocidade = 21, ouro = 2, grupo = 3,
		ataques = { { tipo = "golpe", alcance = 4, arco = 90, preparo = 0.35, recarga = 1 } },
	},

	-- Caverna
	kobold = {
		nome = "Kobold Mineiro", raiz = V(2, 1.8, 1.2), quadril = 1.4, raio = 1.3, alturaBarra = 4,
		vida = 60, dano = 13, velocidade = 15, ouro = 6,
		ataques = {
			{ tipo = "investida", alcance = 20, minimo = 8, preparo = 0.7, recarga = 6, distancia = 18, largura = 4, mult = 1.3 },
			{ tipo = "golpe", alcance = 6, arco = 100, preparo = 0.5, recarga = 1.3 },
		},
	},
	aranha = {
		nome = "Aranha da Caverna", raiz = V(3.6, 1.4, 3.6), quadril = 1.2, raio = 2.2, alturaBarra = 3.4,
		vida = 48, dano = 12, velocidade = 17, ouro = 6,
		ataques = {
			{ tipo = "salto", alcance = 26, minimo = 7, preparo = 0.5, voo = 0.55, recarga = 5.5, raio = 5.5, mult = 1.2, efeito = "lento" },
			{ tipo = "golpe", alcance = 5.5, arco = 120, preparo = 0.45, recarga = 1.2 },
		},
	},
	cogumelo = {
		nome = "Fungo Explosivo", raiz = V(2.4, 2, 2.4), quadril = 0.6, raio = 1.5, alturaBarra = 2.6,
		vida = 28, dano = 28, velocidade = 12, ouro = 4,
		ataques = { { tipo = "explodir", alcance = 5, preparo = 0.9, raio = 9, cor = Color3.fromRGB(150, 255, 90) } },
	},
	xama = {
		nome = "Xamã Kobold", raiz = V(2, 1.8, 1.2), quadril = 1.4, raio = 1.3, alturaBarra = 4.2,
		vida = 44, dano = 12, velocidade = 13, ouro = 7, comportamento = "distancia", distancia = 24,
		ataques = {
			{ tipo = "invocar", recarga = 14, inicial = 4, preparo = 1, invocado = "rato", quantidade = 2, maxVivos = 12 },
			{ tipo = "disparo", alcance = 40, preparo = 0.75, recarga = 2.6, projetil = "veneno", velocidade = 40, quantidade = 3, espalhamento = 18 },
		},
	},

	-- Cripta
	carnical = {
		nome = "Carniçal", raiz = V(2, 2, 1.4), quadril = 1.6, raio = 1.4, alturaBarra = 4,
		vida = 68, dano = 14, velocidade = 19, ouro = 7,
		ataques = {
			{ tipo = "salto", alcance = 24, minimo = 8, preparo = 0.45, voo = 0.5, recarga = 6, raio = 5, mult = 1.3 },
			{ tipo = "golpe", alcance = 5.5, arco = 110, preparo = 0.4, recarga = 1, acertos = 2, entreAcertos = 0.25 },
		},
	},
	espectro = {
		nome = "Espectro Gélido", raiz = V(2, 2, 1), quadril = 3, raio = 1.4, alturaBarra = 3,
		vida = 50, dano = 14, velocidade = 14, ouro = 8, comportamento = "flutuar", distancia = 26,
		ataques = {
			{ tipo = "teleporte", recarga = 9, inicial = 5, preparo = 0.4 },
			{ tipo = "disparo", alcance = 44, preparo = 0.7, recarga = 2.4, projetil = "gelo", velocidade = 48, efeito = "lento" },
		},
	},
	cavaleiroMorto = {
		nome = "Cavaleiro Morto-Vivo", raiz = V(3.2, 3.4, 2), quadril = 2.6, raio = 2, alturaBarra = 6.5,
		vida = 210, dano = 24, velocidade = 11, ouro = 16, pesado = true, armadura = 0.15,
		ataques = {
			{ tipo = "investida", alcance = 28, minimo = 9, preparo = 0.9, recarga = 7, distancia = 24, largura = 5, mult = 1.5 },
			{ tipo = "golpe", alcance = 8, arco = 130, preparo = 0.8, recarga = 1.8, mult = 1.2 },
		},
	},

	-- Fornalha
	diabrete = {
		nome = "Diabrete", raiz = V(1.8, 1.6, 1.2), quadril = 1.3, raio = 1.2, alturaBarra = 3.6,
		vida = 42, dano = 14, velocidade = 17, ouro = 7, comportamento = "distancia", distancia = 22,
		ataques = { { tipo = "disparo", alcance = 40, preparo = 0.55, recarga = 1.9, projetil = "fogo", velocidade = 50, efeito = "queimar" } },
	},
	elementalFogo = {
		nome = "Elemental de Fogo", raiz = V(2.8, 3, 2), quadril = 1.8, raio = 1.8, alturaBarra = 5.5,
		vida = 95, dano = 16, velocidade = 13, ouro = 10,
		ataques = {
			{ tipo = "golpe", alcance = 9, arco = 360, preparo = 0.9, recarga = 3.2, mult = 1.3, efeito = "queimar" },
			{ tipo = "golpe", alcance = 6, arco = 110, preparo = 0.5, recarga = 1.3 },
		},
	},
	ogro = {
		nome = "Ogro Brutamontes", raiz = V(4.4, 4.6, 3.2), quadril = 2.8, raio = 3, alturaBarra = 8,
		vida = 280, dano = 30, velocidade = 10, ouro = 18, pesado = true,
		ataques = {
			{ tipo = "investida", alcance = 30, minimo = 10, preparo = 1, recarga = 8, distancia = 26, largura = 6, mult = 1.4 },
			{ tipo = "golpe", alcance = 10, arco = 120, preparo = 0.95, recarga = 2.2, mult = 1.3 },
		},
	},

	-- Chefes ---------------------------------------------------------------
	reiEsqueleto = {
		nome = "Rei Esqueleto", titulo = "Senhor do Calabouço", chefe = true, pesado = true,
		raiz = V(4.5, 5, 3), quadril = 4, raio = 3.2, alturaBarra = 11,
		vida = 1300, dano = 22, velocidade = 10, ouro = 150, armadura = 0.1,
		ataques = {
			{ tipo = "invocar", recarga = 16, inicial = 6, preparo = 1, invocado = "esqueleto", quantidade = 3, maxVivos = 10 },
			{ tipo = "golpe", alcance = 11, arco = 360, preparo = 1.1, recarga = 9, inicial = 5, acertos = 3, entreAcertos = 0.35, mult = 0.8 },
			{ tipo = "salto", alcance = 40, minimo = 10, preparo = 0.6, voo = 0.8, recarga = 10, inicial = 8, raio = 9, mult = 1.5 },
			{ tipo = "golpe", alcance = 12, arco = 110, preparo = 0.85, recarga = 2.2, mult = 1.3 },
		},
		fase2 = {
			anuncio = "O Rei Esqueleto se enfurece!",
			velocidade = 1.3,
			recarga = 0.7,
			ataques = { { tipo = "invocar", recarga = 14, inicial = 1, preparo = 1, invocado = "esqueletoArqueiro", quantidade = 2, maxVivos = 12 } },
		},
	},
	rainhaAranha = {
		nome = "Rainha Aranha", titulo = "Mãe da Ninhada", chefe = true, pesado = true,
		raiz = V(7, 2.6, 7), quadril = 2.2, raio = 4.5, alturaBarra = 9,
		vida = 1600, dano = 20, velocidade = 13, ouro = 200,
		ataques = {
			{ tipo = "invocar", recarga = 13, inicial = 5, preparo = 0.9, invocado = "aranha", quantidade = 3, maxVivos = 10 },
			{ tipo = "area", recarga = 9, inicial = 3, preparo = 0.6, quantidade = 4, raio = 7, atraso = 1.3, mult = 1, visual = "teia", efeito = "lento" },
			{ tipo = "salto", alcance = 45, minimo = 10, preparo = 0.6, voo = 0.7, recarga = 7, raio = 10, mult = 1.4 },
			{ tipo = "disparo", alcance = 45, preparo = 0.7, recarga = 3.5, projetil = "veneno", velocidade = 45, quantidade = 5, espalhamento = 14 },
			{ tipo = "golpe", alcance = 9, arco = 120, preparo = 0.7, recarga = 1.8 },
		},
		fase2 = { anuncio = "A Rainha Aranha protege sua ninhada!", velocidade = 1.25, recarga = 0.75 },
	},
	lich = {
		nome = "Lich Gélido", titulo = "Guardião da Cripta", chefe = true, comportamento = "flutuar", distancia = 22,
		raiz = V(3, 3, 2), quadril = 4, raio = 2.5, alturaBarra = 10,
		vida = 1700, dano = 22, velocidade = 12, ouro = 260,
		ataques = {
			{ tipo = "teleporte", recarga = 8, inicial = 6, preparo = 0.5 },
			{ tipo = "rajada", recarga = 7, inicial = 3, preparo = 0.9, projetil = "gelo", quantidade = 14, velocidade = 34, mult = 0.8, efeito = "lento" },
			{ tipo = "area", recarga = 6, inicial = 2, preparo = 0.5, quantidade = 3, raio = 7, atraso = 1.2, mult = 1.2, visual = "gelo", efeito = "lento" },
			{ tipo = "invocar", recarga = 18, inicial = 10, preparo = 1, invocado = "esqueleto", quantidade = 3, maxVivos = 10 },
			{ tipo = "disparo", alcance = 50, preparo = 0.5, recarga = 1.6, projetil = "gelo", velocidade = 50, quantidade = 3, espalhamento = 12 },
		},
		fase2 = {
			anuncio = "O Lich invoca o inverno eterno!",
			recarga = 0.7,
			ataques = { { tipo = "golpe", alcance = 14, arco = 360, preparo = 1.2, recarga = 10, inicial = 2, mult = 1.6, efeito = "lento" } },
		},
	},
	senhorChamas = {
		nome = "Senhor das Chamas", titulo = "Coração da Fornalha", chefe = true, pesado = true,
		raiz = V(6, 7, 4), quadril = 4, raio = 4, alturaBarra = 14,
		vida = 2200, dano = 26, velocidade = 9, ouro = 320,
		ataques = {
			{ tipo = "area", recarga = 8, inicial = 3, preparo = 0.8, quantidade = 5, raio = 7, atraso = 1.3, mult = 1.3, visual = "meteoro", efeito = "queimar" },
			{ tipo = "rajada", recarga = 9, inicial = 6, preparo = 1, projetil = "fogo", quantidade = 16, velocidade = 36, mult = 0.8 },
			{ tipo = "invocar", recarga = 16, inicial = 9, preparo = 1, invocado = "diabrete", quantidade = 2, maxVivos = 8 },
			{ tipo = "golpe", alcance = 15, arco = 110, preparo = 1, recarga = 2.6, mult = 1.5, efeito = "queimar" },
		},
		fase2 = {
			anuncio = "O Senhor das Chamas desperta a fornalha!",
			velocidade = 1.2,
			recarga = 0.7,
			ataques = { { tipo = "golpe", alcance = 16, arco = 360, preparo = 1.3, recarga = 11, inicial = 2, mult = 1.6, efeito = "queimar" } },
		},
	},
}

-- Elites: versões mais fortes com um poder especial
Inimigos.ELITES = {
	Blindado = { cor = Color3.fromRGB(205, 215, 235), vida = 1.8, armadura = 0.3 },
	Veloz = { cor = Color3.fromRGB(255, 232, 80), velocidade = 1.45, recarga = 0.7 },
	["Gélido"] = { cor = Color3.fromRGB(120, 210, 255), gelido = true },
	Explosivo = { cor = Color3.fromRGB(255, 120, 40), explosivo = true },
	Gigante = { cor = Color3.fromRGB(255, 80, 80), escala = 1.45, vida = 2.5, dano = 1.3 },
}
Inimigos.LISTA_ELITES = { "Blindado", "Veloz", "Gélido", "Explosivo", "Gigante" }

------------------------------------------------------------------------
-- Criação
------------------------------------------------------------------------

local function criarCaixa(nome: string, tamanho: Vector3, quadril: number)
	local modelo = Instance.new("Model")
	modelo.Name = nome

	local raiz = Instance.new("Part")
	raiz.Name = "HumanoidRootPart"
	raiz.Size = tamanho
	raiz.Transparency = 1
	raiz.CanCollide = true
	raiz.CFrame = CFrame.new()
	raiz.Parent = modelo
	modelo.PrimaryPart = raiz

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = quadril
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = modelo
	-- A vida é controlada pelo nosso código; o Humanoid só serve para andar
	for _, estado in {
		Enum.HumanoidStateType.Dead,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Seated,
	} do
		humanoid:SetStateEnabled(estado, false)
	end
	return modelo, raiz, humanoid
end

-- "posicao" é um ponto no chão. mult = { vida, dano }. elite = nome da elite ou nil.
function Inimigos.criar(run, tipo: string, posicao: Vector3, mult, elite: string?)
	local def = Inimigos.TIPOS[tipo]
	local modificador = elite and Inimigos.ELITES[elite]
	local escala = if modificador then modificador.escala or 1 else 1
	local vida = def.vida * mult.vida * (if modificador then 1.5 * (modificador.vida or 1) else 1)
	local dano = def.dano * mult.dano * (if modificador then modificador.dano or 1 else 1)

	local modelo, raiz, humanoid = criarCaixa(def.nome, def.raiz * escala, def.quadril * escala)
	local alturaRaiz = def.quadril * escala + def.raiz.Y * escala / 2

	modelo:SetAttribute("Tipo", tipo)
	modelo:SetAttribute("Nome", def.nome)
	modelo:SetAttribute("Titulo", def.titulo or "")
	modelo:SetAttribute("Chefe", def.chefe == true)
	modelo:SetAttribute("Elite", elite or "")
	modelo:SetAttribute("Escala", escala)
	modelo:SetAttribute("Vida", vida)
	modelo:SetAttribute("VidaMax", vida)
	modelo:SetAttribute("AlturaBarra", def.alturaBarra * escala)
	modelo:SetAttribute("Acao", "")
	modelo:SetAttribute("Furioso", false)
	CollectionService:AddTag(modelo, "Inimigo")

	local centroSala = if run.sala then run.sala.origem else posicao
	local olhar = unidade(centroSala - posicao, Vector3.new(0, 0, -1))
	modelo:PivotTo(CFrame.lookAt(posicao + Vector3.new(0, alturaRaiz + 0.2, 0), posicao + Vector3.new(0, alturaRaiz + 0.2, 0) + olhar))
	modelo.Parent = run.pasta
	pcall(function()
		raiz:SetNetworkOwner(nil) -- o servidor controla o movimento
	end)

	local ataques = {}
	for _, ataque in def.ataques do
		table.insert(ataques, ataque)
	end

	local agora = os.clock()
	local inimigo = {
		tipo = tipo,
		def = def,
		modelo = modelo,
		raiz = raiz,
		humanoid = humanoid,
		vida = vida,
		vidaMax = vida,
		dano = dano,
		mult = mult,
		escala = escala,
		raio = def.raio * escala,
		alturaRaiz = alturaRaiz,
		alturaBarra = def.alturaBarra * escala,
		armadura = (def.armadura or 0) + (if modificador then modificador.armadura or 0 else 0),
		pesado = def.pesado == true or escala > 1.2,
		chefe = def.chefe == true,
		elite = elite,
		modificador = modificador,
		velocidadeMult = if modificador then modificador.velocidade or 1 else 1,
		recargaMult = if modificador then modificador.recarga or 1 else 1,
		ouro = def.ouro * (if elite then 3 else 1),
		vivo = true,
		ameaca = {},
		ataques = ataques,
		prontoEm = {},
		ocupadoAte = agora + 0.4,
		proximaDecisao = agora + math.random() * 0.2,
		lentoAte = 0,
		lentoFator = 1,
		atordoadoAte = 0,
		acaoN = 0,
		lado = if math.random() < 0.5 then -1 else 1,
		trocaLadoEm = agora + 2,
	}
	for _, ataque in ataques do
		inimigo.prontoEm[ataque] = agora + (ataque.inicial or math.random() * (ataque.recarga or 1) * 0.5)
	end
	run.inimigos[inimigo] = true
	return inimigo
end

------------------------------------------------------------------------
-- Ajudantes
------------------------------------------------------------------------

local function definirAcao(inimigo, nome: string)
	inimigo.acaoN += 1
	if inimigo.modelo.Parent then
		inimigo.modelo:SetAttribute("Acao", nome .. "|" .. inimigo.acaoN)
	end
end

local function podeContinuar(run, inimigo): boolean
	return inimigo.vivo and run.ativa and os.clock() >= inimigo.atordoadoAte
end

local function noChao(run, pos: Vector3): Vector3
	return Vector3.new(pos.X, if run.sala then run.sala.origem.Y else pos.Y, pos.Z)
end

local function limitarNaSala(run, pos: Vector3, margem: number): Vector3
	local sala = run.sala
	if not sala then
		return pos
	end
	local local_ = pos - sala.origem
	local x = math.clamp(local_.X, -sala.largura / 2 + margem + 1, sala.largura / 2 - margem - 1)
	local z = math.clamp(local_.Z, -sala.comprimento / 2 + margem + 1, sala.comprimento / 2 - margem - 1)
	return sala.origem + Vector3.new(x, local_.Y, z)
end

local function parar(inimigo)
	inimigo.humanoid:MoveTo(inimigo.raiz.Position)
end

local function olharPara(inimigo, alvo: Vector3)
	local pos = inimigo.raiz.Position
	local direcao = planar(alvo - pos)
	if direcao.Magnitude > 0.1 then
		inimigo.raiz.CFrame = CFrame.lookAt(pos, pos + direcao)
	end
end

local function jogadoresAtingiveis(run)
	local lista = {}
	for _, estado in run.jogadores do
		if estado.vivo and not estado.caido then
			local raiz = Combate.raizDe(estado)
			if raiz then
				table.insert(lista, { estado = estado, raiz = raiz })
			end
		end
	end
	return lista
end

local function opcoesDoEfeito(inimigo, efeito: string?)
	local opcoes = {}
	if efeito == "lento" or (inimigo.modificador and inimigo.modificador.gelido) then
		opcoes.lento = { fator = 0.6, duracao = 2 }
	end
	if efeito == "queimar" then
		opcoes.queimar = inimigo.dano * 0.15
	end
	return opcoes
end

-- Acerta os jogadores dentro de um cone (ou círculo, se arco >= 360)
local function acertarJogadores(run, inimigo, centro: Vector3, direcao: Vector3?, alcance: number, arco: number, mult: number, efeito: string?)
	local limite = math.cos(math.rad(math.min(arco, 359) / 2 + 10))
	for _, info in jogadoresAtingiveis(run) do
		local delta = planar(info.raiz.Position - centro)
		local distancia = delta.Magnitude
		if distancia <= alcance + 1.6 then
			local dentro = arco >= 360 or not direcao or distancia < 2 or delta.Unit:Dot(direcao) >= limite
			if dentro then
				Combate.danoAoJogador(run, info.estado, inimigo.dano * mult, inimigo, opcoesDoEfeito(inimigo, efeito))
			end
		end
	end
end

local function corDoEfeito(efeito: string?): Color3
	if efeito == "queimar" then
		return Color3.fromRGB(255, 120, 40)
	elseif efeito == "lento" then
		return Color3.fromRGB(130, 210, 255)
	end
	return Color3.fromRGB(255, 70, 70)
end

local function contarInimigos(run): number
	local total = 0
	for _ in run.inimigos do
		total += 1
	end
	return total
end

------------------------------------------------------------------------
-- Ataques. Cada um devolve false se não pôde ser usado agora.
------------------------------------------------------------------------

local function ataqueGolpe(run, inimigo, ataque, alvoPos: Vector3, agora: number): boolean
	local alcance = ataque.alcance * inimigo.escala
	local arco = ataque.arco or 100
	local preparo = ataque.preparo * inimigo.recargaMult
	local acertos = ataque.acertos or 1
	local entre = ataque.entreAcertos or 0.3
	local direcao = unidade(alvoPos - inimigo.raiz.Position, inimigo.raiz.CFrame.LookVector)
	local giro = arco >= 360

	parar(inimigo)
	olharPara(inimigo, alvoPos)
	definirAcao(inimigo, if giro then "prepararGiro" else "preparar")
	inimigo.ocupadoAte = agora + preparo + (acertos - 1) * entre + 0.4
	Vfx.partida(run, "telegrafo", {
		forma = if giro then "circulo" else "cone",
		pos = noChao(run, inimigo.raiz.Position),
		dir = direcao,
		raio = alcance,
		arco = arco,
		duracao = preparo,
		chefe = inimigo.chefe,
	})

	task.delay(preparo, function()
		for i = 1, acertos do
			if not podeContinuar(run, inimigo) then
				return
			end
			definirAcao(inimigo, if giro then "giro" else "golpe")
			local centro = inimigo.raiz.Position
			Vfx.partida(run, "golpeInimigo", { pos = centro, dir = direcao, alcance = alcance, arco = arco, cor = corDoEfeito(ataque.efeito) })
			acertarJogadores(run, inimigo, centro, direcao, alcance, arco, ataque.mult or 1, ataque.efeito)
			if i < acertos then
				task.wait(entre)
			end
		end
		task.delay(0.3, function()
			if inimigo.vivo then
				definirAcao(inimigo, "")
			end
		end)
	end)
	return true
end

local function ataqueDisparo(run, inimigo, ataque, alvo, agora: number): boolean
	local preparo = ataque.preparo * inimigo.recargaMult
	parar(inimigo)
	definirAcao(inimigo, "conjurar")
	inimigo.ocupadoAte = agora + preparo + 0.35
	task.delay(preparo, function()
		if not podeContinuar(run, inimigo) then
			return
		end
		local raizAlvo = Combate.raizDe(alvo)
		local origem = inimigo.raiz.Position + Vector3.new(0, 0.8, 0)
		local destino = if raizAlvo and alvo.vivo then raizAlvo.Position else origem + inimigo.raiz.CFrame.LookVector * 10
		olharPara(inimigo, destino)
		definirAcao(inimigo, "disparo")
		local direcao = unidade(destino - origem, inimigo.raiz.CFrame.LookVector)
		local quantidade = ataque.quantidade or 1
		local abertura = ataque.espalhamento or 10
		local lista = {}
		for i = 1, quantidade do
			local angulo = math.rad((i - (quantidade + 1) / 2) * abertura)
			table.insert(lista, {
				lado = "inimigo",
				tipo = ataque.projetil,
				pos = origem + direcao * inimigo.raio,
				dir = CFrame.Angles(0, angulo, 0):VectorToWorldSpace(direcao),
				velocidade = ataque.velocidade or 45,
				alcance = (ataque.alcance or 45) * 1.3,
				raio = 1.1,
				aoAcertar = function(estado)
					Combate.danoAoJogador(run, estado, inimigo.dano * (ataque.mult or 1), inimigo, opcoesDoEfeito(inimigo, ataque.efeito))
				end,
			})
		end
		Projeteis.disparar(run, lista)
		task.delay(0.3, function()
			if inimigo.vivo then
				definirAcao(inimigo, "")
			end
		end)
	end)
	return true
end

local function ataqueRajada(run, inimigo, ataque, agora: number): boolean
	local preparo = ataque.preparo * inimigo.recargaMult
	parar(inimigo)
	definirAcao(inimigo, "conjurar")
	inimigo.ocupadoAte = agora + preparo + 0.5
	Vfx.partida(run, "telegrafo", { forma = "circulo", pos = noChao(run, inimigo.raiz.Position), raio = inimigo.raio + 3, duracao = preparo, chefe = true })
	task.delay(preparo, function()
		if not podeContinuar(run, inimigo) then
			return
		end
		definirAcao(inimigo, "disparo")
		local quantidade = ataque.quantidade or 12
		local giro = math.random() * math.pi
		local origem = inimigo.raiz.Position
		local lista = {}
		for i = 1, quantidade do
			local angulo = giro + i * (math.pi * 2 / quantidade)
			local direcao = Vector3.new(math.sin(angulo), 0, math.cos(angulo))
			table.insert(lista, {
				lado = "inimigo",
				tipo = ataque.projetil,
				pos = origem + direcao * (inimigo.raio + 1),
				dir = direcao,
				velocidade = ataque.velocidade or 35,
				alcance = 70,
				raio = 1.2,
				aoAcertar = function(estado)
					Combate.danoAoJogador(run, estado, inimigo.dano * (ataque.mult or 1), inimigo, opcoesDoEfeito(inimigo, ataque.efeito))
				end,
			})
		end
		Projeteis.disparar(run, lista)
		task.delay(0.4, function()
			if inimigo.vivo then
				definirAcao(inimigo, "")
			end
		end)
	end)
	return true
end

local function ataqueInvestida(run, inimigo, ataque, alvoPos: Vector3, agora: number): boolean
	local preparo = ataque.preparo * inimigo.recargaMult
	local direcao = unidade(alvoPos - inimigo.raiz.Position, inimigo.raiz.CFrame.LookVector)
	local distancia = ataque.distancia * inimigo.escala
	local largura = ataque.largura * inimigo.escala

	parar(inimigo)
	olharPara(inimigo, alvoPos)
	definirAcao(inimigo, "prepararInvestida")
	inimigo.ocupadoAte = agora + preparo + 0.7
	Vfx.partida(run, "telegrafo", {
		forma = "linha",
		pos = noChao(run, inimigo.raiz.Position),
		dir = direcao,
		comprimento = distancia,
		largura = largura,
		duracao = preparo,
		chefe = inimigo.chefe,
	})

	task.delay(preparo, function()
		if not podeContinuar(run, inimigo) then
			return
		end
		definirAcao(inimigo, "investida")
		local destino = limitarNaSala(run, inimigo.raiz.Position + direcao * distancia, inimigo.raio)
		inimigo.investindo = true
		inimigo.humanoid.WalkSpeed = 75
		inimigo.humanoid:MoveTo(destino)
		local atingidos = {}
		local fim = os.clock() + 0.5
		while os.clock() < fim and inimigo.vivo and run.ativa do
			for _, info in jogadoresAtingiveis(run) do
				if not atingidos[info.estado] and planar(info.raiz.Position - inimigo.raiz.Position).Magnitude <= inimigo.raio + largura / 2 + 0.5 then
					atingidos[info.estado] = true
					Combate.danoAoJogador(run, info.estado, inimigo.dano * (ataque.mult or 1), inimigo, opcoesDoEfeito(inimigo, ataque.efeito))
				end
			end
			task.wait(0.05)
		end
		inimigo.investindo = false
		if inimigo.vivo then
			parar(inimigo)
			definirAcao(inimigo, "")
		end
	end)
	return true
end

local function ataqueSalto(run, inimigo, ataque, alvoPos: Vector3, agora: number): boolean
	local preparo = ataque.preparo * inimigo.recargaMult
	local voo = ataque.voo or 0.6
	local raio = ataque.raio * inimigo.escala
	local destino = limitarNaSala(run, noChao(run, alvoPos), inimigo.raio)

	parar(inimigo)
	olharPara(inimigo, alvoPos)
	definirAcao(inimigo, "prepararSalto")
	inimigo.ocupadoAte = agora + preparo + voo + 0.45
	Vfx.partida(run, "telegrafo", { forma = "circulo", pos = destino, raio = raio, duracao = preparo + voo, chefe = inimigo.chefe })

	task.delay(preparo, function()
		if not podeContinuar(run, inimigo) then
			return
		end
		definirAcao(inimigo, "salto")
		local chegada = destino + Vector3.new(0, inimigo.alturaRaiz, 0)
		Vfx.partida(run, "salto", { modelo = inimigo.modelo, de = inimigo.raiz.Position, para = chegada, duracao = voo })
		task.delay(voo, function()
			if not inimigo.vivo or not run.ativa then
				return
			end
			local olhar = unidade(destino - inimigo.raiz.Position, inimigo.raiz.CFrame.LookVector)
			inimigo.modelo:PivotTo(CFrame.lookAt(chegada, chegada + olhar))
			Vfx.partida(run, "impacto", { pos = destino, raio = raio, cor = corDoEfeito(ataque.efeito), forte = inimigo.chefe })
			acertarJogadores(run, inimigo, destino, nil, raio, 360, ataque.mult or 1, ataque.efeito)
			definirAcao(inimigo, "")
		end)
	end)
	return true
end

local function ataqueExplodir(run, inimigo, ataque, agora: number): boolean
	local raio = ataque.raio * inimigo.escala
	parar(inimigo)
	definirAcao(inimigo, "prepararExplosao")
	inimigo.ocupadoAte = agora + 99
	Vfx.partida(run, "telegrafo", { forma = "circulo", pos = noChao(run, inimigo.raiz.Position), raio = raio, duracao = ataque.preparo })
	task.delay(ataque.preparo, function()
		if not inimigo.vivo or not run.ativa then
			return
		end
		local centro = inimigo.raiz.Position
		Vfx.partida(run, "explosao", { pos = centro, raio = raio, cor = ataque.cor or Color3.fromRGB(255, 140, 40), forte = true })
		acertarJogadores(run, inimigo, centro, nil, raio, 360, ataque.mult or 1, ataque.efeito)
		run:aoMorrerInimigo(inimigo, nil)
	end)
	return true
end

local function ataqueInvocar(run, inimigo, ataque, agora: number): boolean
	if contarInimigos(run) >= (ataque.maxVivos or 12) or not run.sala then
		return false
	end
	parar(inimigo)
	definirAcao(inimigo, "conjurar")
	inimigo.ocupadoAte = agora + ataque.preparo + 0.4
	task.delay(ataque.preparo, function()
		if not podeContinuar(run, inimigo) or not run.sala then
			return
		end
		for i = 1, ataque.quantidade or 2 do
			local angulo = i * (math.pi * 2 / (ataque.quantidade or 2)) + math.random()
			local pos = noChao(run, inimigo.raiz.Position + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * (inimigo.raio + 5))
			pos = limitarNaSala(run, pos, 2)
			if Masmorra.posicaoValida(run.sala, pos, 1.5) then
				run:invocar(ataque.invocado, pos, nil)
			end
		end
		definirAcao(inimigo, "")
	end)
	return true
end

local function ataqueArea(run, inimigo, ataque, agora: number): boolean
	if not run.sala then
		return false
	end
	parar(inimigo)
	definirAcao(inimigo, "conjurar")
	inimigo.ocupadoAte = agora + ataque.preparo + 0.4
	task.delay(ataque.preparo, function()
		if not podeContinuar(run, inimigo) or not run.sala then
			return
		end
		local pontos = {}
		local alvos = jogadoresAtingiveis(run)
		for _, info in alvos do
			table.insert(pontos, noChao(run, info.raiz.Position))
		end
		while #pontos < (ataque.quantidade or 3) and #alvos > 0 do
			local base = alvos[math.random(#alvos)].raiz.Position
			table.insert(pontos, limitarNaSala(run, noChao(run, base + Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))), 2))
		end
		local raio = ataque.raio
		local atraso = ataque.atraso or 1.2
		for i = 1, math.min(#pontos, ataque.quantidade or 3) do
			local ponto = pontos[i]
			Vfx.partida(run, "telegrafo", { forma = "circulo", pos = ponto, raio = raio, duracao = atraso, chefe = true })
			if ataque.visual == "meteoro" then
				Vfx.partida(run, "meteoro", { pos = ponto, duracao = atraso, raio = raio })
			end
			task.delay(atraso, function()
				if not run.ativa then
					return
				end
				Vfx.partida(run, "impactoArea", { pos = ponto, raio = raio, visual = ataque.visual })
				for _, info in jogadoresAtingiveis(run) do
					if planar(info.raiz.Position - ponto).Magnitude <= raio + 1 then
						Combate.danoAoJogador(run, info.estado, inimigo.dano * (ataque.mult or 1), nil, opcoesDoEfeito(inimigo, ataque.efeito))
					end
				end
			end)
		end
		definirAcao(inimigo, "")
	end)
	return true
end

local function ataqueTeleporte(run, inimigo, ataque, agora: number): boolean
	local sala = run.sala
	if not sala then
		return false
	end
	local alvos = jogadoresAtingiveis(run)
	local destino = nil
	for _ = 1, 20 do
		local ponto = Masmorra.pontoLivre(sala, run.rng, inimigo.raio + 1)
		if ponto then
			local longe = true
			for _, info in alvos do
				if planar(info.raiz.Position - ponto).Magnitude < 14 then
					longe = false
				end
			end
			if longe then
				destino = ponto
				break
			end
		end
	end
	if not destino then
		return false
	end
	parar(inimigo)
	definirAcao(inimigo, "conjurar")
	inimigo.ocupadoAte = agora + ataque.preparo + 0.5
	Vfx.partida(run, "teleporte", { pos = inimigo.raiz.Position })
	task.delay(ataque.preparo, function()
		if not podeContinuar(run, inimigo) then
			return
		end
		local chegada = destino + Vector3.new(0, inimigo.alturaRaiz, 0)
		inimigo.modelo:PivotTo(CFrame.new(chegada) * inimigo.raiz.CFrame.Rotation)
		Vfx.partida(run, "teleporte", { pos = chegada })
		definirAcao(inimigo, "")
	end)
	return true
end

local function executarAtaque(run, inimigo, ataque, alvo, alvoPos: Vector3, agora: number): boolean
	local tipo = ataque.tipo
	if tipo == "golpe" then
		return ataqueGolpe(run, inimigo, ataque, alvoPos, agora)
	elseif tipo == "disparo" then
		return ataqueDisparo(run, inimigo, ataque, alvo, agora)
	elseif tipo == "rajada" then
		return ataqueRajada(run, inimigo, ataque, agora)
	elseif tipo == "investida" then
		return ataqueInvestida(run, inimigo, ataque, alvoPos, agora)
	elseif tipo == "salto" then
		return ataqueSalto(run, inimigo, ataque, alvoPos, agora)
	elseif tipo == "explodir" then
		return ataqueExplodir(run, inimigo, ataque, agora)
	elseif tipo == "invocar" then
		return ataqueInvocar(run, inimigo, ataque, agora)
	elseif tipo == "area" then
		return ataqueArea(run, inimigo, ataque, agora)
	elseif tipo == "teleporte" then
		return ataqueTeleporte(run, inimigo, ataque, agora)
	end
	return false
end

------------------------------------------------------------------------
-- Movimento e decisões
------------------------------------------------------------------------

-- Anda até o destino desviando de pilares e de outros inimigos
local function mover(run, inimigo, destino: Vector3)
	local pos = inimigo.raiz.Position
	local caminho = planar(destino - pos)
	local distancia = caminho.Magnitude
	if distancia < 0.5 then
		return
	end
	local direcao = caminho / distancia

	if run.sala then
		for _, pilar in run.sala.pilares do
			local paraPilar = planar(pilar.pos - pos)
			local projecao = paraPilar:Dot(direcao)
			if projecao > 0 and projecao < math.min(distancia, 14) then
				local lateral = paraPilar - direcao * projecao
				if lateral.Magnitude < pilar.raio + inimigo.raio + 1.5 then
					local desvio = -lateral
					if desvio.Magnitude < 0.01 then
						desvio = Vector3.new(-direcao.Z, 0, direcao.X)
					end
					direcao = (direcao + desvio.Unit * 1.4).Unit
				end
			end
		end
	end

	for outro in run.inimigos do
		if outro ~= inimigo and outro.vivo then
			local afastar = planar(pos - outro.raiz.Position)
			local m = afastar.Magnitude
			if m > 0.01 and m < inimigo.raio + outro.raio + 0.5 then
				direcao += afastar / m * 0.6
			end
		end
	end

	if direcao.Magnitude > 0.01 then
		inimigo.humanoid:MoveTo(limitarNaSala(run, pos + direcao.Unit * 6, inimigo.raio))
	end
end

local function escolherAlvo(run, inimigo)
	local pos = inimigo.raiz.Position
	local melhor, melhorNota, melhorDistancia = nil, -math.huge, math.huge
	for estado, valor in inimigo.ameaca do
		inimigo.ameaca[estado] = valor * 0.985
	end
	for _, info in jogadoresAtingiveis(run) do
		local distancia = planar(info.raiz.Position - pos).Magnitude
		local nota = (inimigo.ameaca[info.estado] or 0) - distancia * 3
		if info.estado == inimigo.alvoAtual then
			nota += 15 -- não troca de alvo a toda hora
		end
		if nota > melhorNota then
			melhor, melhorNota, melhorDistancia = info, nota, distancia
		end
	end
	inimigo.alvoAtual = melhor and melhor.estado
	return melhor, melhorDistancia
end

local function entrarNaFase2(run, inimigo)
	local fase2 = inimigo.def.fase2
	inimigo.fase2 = true
	inimigo.velocidadeMult *= fase2.velocidade or 1
	inimigo.recargaMult *= fase2.recarga or 1
	if fase2.ataques then
		for i, ataque in fase2.ataques do
			table.insert(inimigo.ataques, i, ataque)
			inimigo.prontoEm[ataque] = os.clock() + (ataque.inicial or 1)
		end
	end
	inimigo.modelo:SetAttribute("Furioso", true)
	run:anunciar("🔥 " .. (fase2.anuncio or (inimigo.def.nome .. " se enfurece!")), Color3.fromRGB(255, 90, 60))
	Vfx.partida(run, "furia", { pos = inimigo.raiz.Position })
end

local function decidir(run, inimigo, agora: number)
	local def = inimigo.def

	if agora < inimigo.atordoadoAte then
		parar(inimigo)
		return
	elseif inimigo.modelo:GetAttribute("Atordoado") then
		inimigo.modelo:SetAttribute("Atordoado", false)
	end
	if agora >= inimigo.lentoAte and inimigo.lentoFator < 1 then
		inimigo.lentoFator = 1
		inimigo.modelo:SetAttribute("Lento", false)
	end

	if inimigo.chefe and def.fase2 and not inimigo.fase2 and inimigo.vida <= inimigo.vidaMax * 0.5 then
		entrarNaFase2(run, inimigo)
	end

	if agora < inimigo.ocupadoAte or inimigo.investindo then
		return
	end

	local velocidade = def.velocidade * inimigo.velocidadeMult
	if agora < inimigo.lentoAte then
		velocidade *= inimigo.lentoFator
	end
	inimigo.humanoid.WalkSpeed = velocidade

	local info, distancia = escolherAlvo(run, inimigo)
	if not info then
		parar(inimigo)
		return
	end
	local alvoPos = info.raiz.Position

	for _, ataque in inimigo.ataques do
		if agora >= (inimigo.prontoEm[ataque] or 0) and distancia <= (ataque.alcance or 999) * inimigo.escala and distancia >= (ataque.minimo or 0) then
			if executarAtaque(run, inimigo, ataque, info.estado, alvoPos, agora) then
				inimigo.prontoEm[ataque] = agora + (ataque.recarga or 2) * inimigo.recargaMult
				return
			else
				inimigo.prontoEm[ataque] = agora + 2
			end
		end
	end

	-- Ninguém no alcance: anda
	local comportamento = def.comportamento or "perseguir"
	if comportamento == "perseguir" then
		local alcanceGolpe = 4
		for _, ataque in inimigo.ataques do
			if ataque.tipo == "golpe" or ataque.tipo == "explodir" then
				alcanceGolpe = math.max(alcanceGolpe, ataque.alcance * inimigo.escala)
			end
		end
		if distancia > alcanceGolpe * 0.75 then
			mover(run, inimigo, alvoPos)
		else
			parar(inimigo)
			olharPara(inimigo, alvoPos)
		end
	else
		local ideal = def.distancia or 24
		local pos = inimigo.raiz.Position
		if agora >= inimigo.trocaLadoEm then
			inimigo.lado = -inimigo.lado
			inimigo.trocaLadoEm = agora + 1.5 + math.random() * 2
		end
		if distancia > ideal + 4 then
			mover(run, inimigo, alvoPos)
		elseif distancia < ideal - 8 then
			mover(run, inimigo, pos + unidade(pos - alvoPos, Vector3.new(1, 0, 0)) * 10)
		else
			-- anda de lado para não ficar parado
			local paraAlvo = unidade(alvoPos - pos, Vector3.new(0, 0, 1))
			mover(run, inimigo, pos + Vector3.new(-paraAlvo.Z, 0, paraAlvo.X) * inimigo.lado * 6)
		end
	end
end

-- Chamado a cada frame pelo controlador da partida
function Inimigos.atualizar(run, agora: number)
	local lista = {}
	for inimigo in run.inimigos do
		table.insert(lista, inimigo)
	end
	for _, inimigo in lista do
		if inimigo.vivo and agora >= inimigo.proximaDecisao then
			inimigo.proximaDecisao = agora + 0.12
			decidir(run, inimigo, agora)
		end
	end
end

------------------------------------------------------------------------
-- Morte
------------------------------------------------------------------------

function Inimigos.morrer(run, inimigo)
	if not inimigo.vivo then
		return
	end
	inimigo.vivo = false
	run.inimigos[inimigo] = nil
	local posicao = inimigo.raiz.Position
	inimigo.modelo:Destroy() -- os jogadores veem a animação de morte no próprio computador

	if not run.ativa or not run.sala then
		return
	end
	local chao = noChao(run, posicao)

	-- Gosmas se dividem em gosminhas
	if inimigo.def.divide then
		for i = 1, 2 do
			local angulo = i * math.pi + math.random()
			run:invocar(inimigo.def.divide, chao + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * 2, nil, true)
		end
	end

	-- Elite explosiva: explode logo depois de morrer
	if inimigo.modificador and inimigo.modificador.explosivo then
		local raio = 8 * inimigo.escala
		Vfx.partida(run, "telegrafo", { forma = "circulo", pos = chao, raio = raio, duracao = 1 })
		task.delay(1, function()
			if not run.ativa then
				return
			end
			Vfx.partida(run, "explosao", { pos = chao, raio = raio, cor = Color3.fromRGB(255, 120, 40), forte = true })
			for _, info in jogadoresAtingiveis(run) do
				if planar(info.raiz.Position - chao).Magnitude <= raio + 1 then
					Combate.danoAoJogador(run, info.estado, inimigo.dano * 1.5, nil, {})
				end
			end
		end)
	end
end

function Inimigos.limparTodos(run)
	for inimigo in run.inimigos do
		inimigo.vivo = false
		inimigo.modelo:Destroy()
	end
	table.clear(run.inimigos)
end

return Inimigos
