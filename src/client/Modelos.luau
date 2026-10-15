-- Aparência dos inimigos, montada com peças. Inspiração: Warcraft (proporções exageradas,
-- ombreiras grandes, olhos brilhando, armas enormes).
--
-- Cada modelo tem "ossos" (juntas que se mexem) e "peças" presas a um osso.
-- As posições são medidas a partir do chão (y = 0 é o pé), com a frente para -Z.
-- formas: bloco, bola, elipse (bola achatada), cilindro (em pé use R(0,0,90)), cunha, canto

local Modelos = {}

local V = Vector3.new
local C = Color3.fromRGB

local function R(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local EM_PE = R(0, 0, 90)
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local TECIDO = Enum.Material.Fabric
local MADEIRA = Enum.Material.Wood
local PEDRA = Enum.Material.Slate

-- Peça. extra: rot, mat, neon, transp, olho (fica vermelho na fúria), geleia (estica e encolhe)
local function P(osso: string, forma: string, tamanho: Vector3, pos: Vector3, cor: Color3, extra)
	extra = extra or {}
	return {
		osso = osso,
		forma = forma,
		tamanho = tamanho,
		cf = CFrame.new(pos) * (extra.rot or CFrame.identity),
		cor = cor,
		material = if extra.neon then NEON else extra.mat,
		transp = extra.transp,
		olho = extra.olho,
		geleia = extra.geleia,
	}
end

-- Barra entre dois pontos
local function S(osso: string, a: Vector3, b: Vector3, espessura: number, cor: Color3, extra)
	extra = extra or {}
	local peca = P(osso, extra.forma or "bloco", V(espessura, espessura, (b - a).Magnitude), (a + b) / 2, cor, extra)
	peca.cf = CFrame.new((a + b) / 2) * CFrame.lookAt(Vector3.zero, b - a).Rotation
	return peca
end

local function juntar(destino, origem)
	for _, item in origem do
		table.insert(destino, item)
	end
end

local function osso(pai: string, pivo: Vector3, extra)
	local o = { pai = pai, pivo = pivo }
	if extra then
		for chave, valor in extra do
			o[chave] = valor
		end
	end
	return o
end

------------------------------------------------------------------------
-- Esqueletos
------------------------------------------------------------------------

local OSSO = C(228, 221, 198)
local OSSO_ESCURO = C(168, 156, 128)
local FERRUGEM = C(124, 80, 48)
local ESCURO = C(28, 24, 26)

local function esqueleto(corOlho: Color3)
	local ossos = {
		corpo = osso("raiz", V(0, 3, 0)),
		cabeca = osso("corpo", V(0, 5.05, 0)),
		bracoE = osso("corpo", V(-1.05, 4.75, 0)),
		bracoD = osso("corpo", V(1.05, 4.75, 0)),
		pernaE = osso("raiz", V(-0.45, 2.95, 0)),
		pernaD = osso("raiz", V(0.45, 2.95, 0)),
	}
	local p = {
		P("corpo", "bloco", V(1.4, 0.45, 0.8), V(0, 3, 0), OSSO_ESCURO),
		P("corpo", "cilindro", V(1.5, 0.32, 0.32), V(0, 3.75, 0.12), OSSO, { rot = EM_PE }),
		P("corpo", "elipse", V(1.2, 1, 0.7), V(0, 4.35, 0), ESCURO),
		P("corpo", "bloco", V(1.9, 0.3, 0.9), V(0, 4.95, 0), OSSO),
		P("cabeca", "elipse", V(1.25, 1.3, 1.35), V(0, 5.65, 0), OSSO),
		P("cabeca", "bloco", V(0.9, 0.35, 0.75), V(0, 5.05, -0.15), OSSO_ESCURO),
		P("cabeca", "bloco", V(0.62, 0.12, 0.1), V(0, 5.2, -0.56), OSSO),
	}
	for i, y in { 4, 4.35, 4.7 } do
		table.insert(p, P("corpo", "elipse", V(1.85 - i * 0.12, 0.2, 1.1), V(0, y, 0), OSSO))
	end
	for _, x in { -0.28, 0.28 } do
		table.insert(p, P("cabeca", "bola", V(0.42, 0.42, 0.42), V(x, 5.7, -0.52), ESCURO))
		table.insert(p, P("cabeca", "bola", V(0.22, 0.22, 0.22), V(x, 5.7, -0.66), corOlho, { neon = true, olho = true }))
	end
	for _, lado in { -1, 1 } do
		local braco = if lado < 0 then "bracoE" else "bracoD"
		local perna = if lado < 0 then "pernaE" else "pernaD"
		juntar(p, {
			P(braco, "bola", V(0.48, 0.48, 0.48), V(lado * 1.05, 4.75, 0), OSSO),
			P(braco, "cilindro", V(1, 0.26, 0.26), V(lado * 1.05, 4.2, 0), OSSO, { rot = EM_PE }),
			P(braco, "bola", V(0.32, 0.32, 0.32), V(lado * 1.05, 3.65, 0), OSSO_ESCURO),
			P(braco, "cilindro", V(1, 0.22, 0.22), V(lado * 1.05, 3.1, 0), OSSO, { rot = EM_PE }),
			P(braco, "bola", V(0.42, 0.42, 0.42), V(lado * 1.05, 2.5, 0), OSSO_ESCURO),
			P(perna, "cilindro", V(1.3, 0.3, 0.3), V(lado * 0.45, 2.25, 0), OSSO, { rot = EM_PE }),
			P(perna, "bola", V(0.38, 0.38, 0.38), V(lado * 0.45, 1.55, 0), OSSO_ESCURO),
			P(perna, "cilindro", V(1.3, 0.26, 0.26), V(lado * 0.45, 0.85, 0), OSSO, { rot = EM_PE }),
			P(perna, "bloco", V(0.45, 0.22, 0.85), V(lado * 0.45, 0.12, -0.15), OSSO_ESCURO),
		})
	end
	return {
		estilo = "bipede",
		ossos = ossos,
		pecas = p,
		luzes = { { osso = "cabeca", pos = V(0, 5.7, -0.7), cor = corOlho, alcance = 6, brilho = 1 } },
		efeitos = {},
		cor = OSSO,
	}
end

function Modelos.esqueleto()
	local m = esqueleto(C(255, 60, 50))
	juntar(m.pecas, {
		-- capacete com chifres
		P("cabeca", "bloco", V(1.45, 0.45, 1.45), V(0, 6.2, 0), FERRUGEM, { mat = METAL }),
		P("cabeca", "canto", V(0.3, 0.9, 0.45), V(-0.85, 6.6, 0), FERRUGEM, { mat = METAL, rot = R(0, 90, 25) }),
		P("cabeca", "canto", V(0.3, 0.9, 0.45), V(0.85, 6.6, 0), FERRUGEM, { mat = METAL, rot = R(0, -90, -25) }),
		-- escudo redondo no braço esquerdo
		P("bracoE", "cilindro", V(0.25, 2.3, 2.3), V(-1.45, 3.2, 0), C(96, 66, 42), { mat = Enum.Material.WoodPlanks }),
		P("bracoE", "cilindro", V(0.3, 0.8, 0.8), V(-1.6, 3.2, 0), FERRUGEM, { mat = METAL }),
		-- espada enferrujada
		P("bracoD", "bloco", V(0.14, 0.5, 3.2), V(1.05, 2.5, -1.75), C(150, 140, 128), { mat = Enum.Material.CorrodedMetal }),
		P("bracoD", "bloco", V(0.7, 0.16, 0.18), V(1.05, 2.5, -0.2), FERRUGEM, { mat = METAL }),
		-- tanga rasgada
		P("corpo", "bloco", V(1.2, 0.9, 0.1), V(0, 2.5, -0.42), C(96, 30, 30), { mat = TECIDO }),
	})
	return m
end

function Modelos.esqueletoArqueiro()
	local m = esqueleto(C(255, 210, 60))
	local madeira = C(98, 66, 40)
	-- arco: deitado com o braço parado, fica em pé quando o braço aponta para frente
	local mao = V(-1.05, 2.5, 0)
	juntar(m.pecas, {
		P("cabeca", "elipse", V(1.55, 1.45, 1.5), V(0, 5.8, 0.18), C(44, 62, 44), { mat = TECIDO }),
		S("bracoE", mao, mao + V(0, -0.35, -1.3), 0.2, madeira, { mat = MADEIRA }),
		S("bracoE", mao + V(0, -0.35, -1.3), mao + V(0, -0.9, -2.1), 0.18, madeira, { mat = MADEIRA }),
		S("bracoE", mao, mao + V(0, -0.35, 1.3), 0.2, madeira, { mat = MADEIRA }),
		S("bracoE", mao + V(0, -0.35, 1.3), mao + V(0, -0.9, 2.1), 0.18, madeira, { mat = MADEIRA }),
		S("bracoE", mao + V(0, -0.9, -2.1), mao + V(0, -0.9, 2.1), 0.06, C(255, 230, 160), { neon = true }),
		P("corpo", "cilindro", V(2, 0.6, 0.6), V(0.4, 4.3, 0.6), C(90, 56, 32), { rot = EM_PE * R(-20, 0, 0), mat = TECIDO }),
		P("corpo", "bloco", V(0.5, 0.3, 0.3), V(0.55, 5.35, 0.8), C(255, 80, 70), { neon = true }),
	})
	return m
end

function Modelos.reiEsqueleto()
	local m = esqueleto(C(110, 255, 120))
	m.escala = 2.1
	local ouro = C(232, 186, 74)
	m.ossos.capa = osso("corpo", V(0, 4.9, 0.55))
	juntar(m.pecas, {
		-- coroa
		P("cabeca", "cilindro", V(0.45, 1.5, 1.5), V(0, 6.35, 0), ouro, { rot = EM_PE, mat = METAL }),
		P("cabeca", "canto", V(0.25, 0.6, 0.25), V(0, 6.8, -0.62), ouro, { mat = METAL }),
		P("cabeca", "canto", V(0.25, 0.6, 0.25), V(-0.55, 6.8, -0.3), ouro, { mat = METAL }),
		P("cabeca", "canto", V(0.25, 0.6, 0.25), V(0.55, 6.8, -0.3), ouro, { mat = METAL }),
		P("cabeca", "bola", V(0.22, 0.22, 0.22), V(0, 6.4, -0.76), C(120, 255, 140), { neon = true }),
		-- alma verde dentro das costelas
		P("corpo", "elipse", V(0.9, 0.8, 0.5), V(0, 4.35, 0), C(110, 255, 120), { neon = true, transp = 0.2 }),
		-- ombreiras
		P("bracoE", "elipse", V(1, 0.65, 1.1), V(-1.15, 5, 0), ouro, { mat = METAL }),
		P("bracoD", "elipse", V(1, 0.65, 1.1), V(1.15, 5, 0), ouro, { mat = METAL }),
		P("bracoE", "canto", V(0.25, 0.6, 0.3), V(-1.3, 5.45, 0), ouro, { mat = METAL }),
		P("bracoD", "canto", V(0.25, 0.6, 0.3), V(1.3, 5.45, 0), ouro, { mat = METAL }),
		-- capa
		P("capa", "bloco", V(1.9, 3.4, 0.12), V(0, 3.35, 0.6), C(120, 20, 30), { mat = TECIDO }),
		-- espadão rúnico
		P("bracoD", "bloco", V(0.18, 0.7, 4.6), V(1.05, 2.5, -2.5), C(170, 175, 180), { mat = METAL }),
		P("bracoD", "bloco", V(0.2, 0.18, 3.6), V(1.05, 2.5, -2.6), C(110, 255, 120), { neon = true }),
		P("bracoD", "bloco", V(1.1, 0.2, 0.22), V(1.05, 2.5, -0.2), ouro, { mat = METAL }),
	})
	table.insert(m.efeitos, { osso = "corpo", pos = V(0, 4.35, 0), tipo = "alma", cor = C(110, 255, 120) })
	m.luzes[1].alcance = 14
	return m
end

------------------------------------------------------------------------
-- Gosmas e fungos
------------------------------------------------------------------------

local function gosma(cor: Color3)
	local p = {
		P("corpo", "elipse", V(3.8, 3.2, 3.8), V(0, 1.6, 0), cor, { transp = 0.22, geleia = true, mat = Enum.Material.Glass }),
		P("corpo", "elipse", V(1.5, 1.3, 1.5), V(0, 1.3, 0.2), cor:Lerp(ESCURO, 0.45), { geleia = true }),
		P("corpo", "bola", V(0.35, 0.35, 0.35), V(0.8, 1, 0.6), cor:Lerp(Color3.new(1, 1, 1), 0.5), { transp = 0.3 }),
		P("corpo", "bola", V(0.25, 0.25, 0.25), V(-0.6, 2.2, 0.8), cor:Lerp(Color3.new(1, 1, 1), 0.5), { transp = 0.3 }),
		P("corpo", "elipse", V(1.2, 0.4, 0.2), V(0, 1.45, -1.82), ESCURO),
	}
	for _, x in { -0.65, 0.65 } do
		table.insert(p, P("corpo", "bola", V(0.85, 0.85, 0.85), V(x, 2.3, -1.4), Color3.new(1, 1, 1)))
		table.insert(p, P("corpo", "bola", V(0.42, 0.42, 0.42), V(x, 2.32, -1.78), ESCURO, { olho = true }))
	end
	return {
		estilo = "gosma",
		ossos = { corpo = osso("raiz", V(0, 0, 0)) },
		pecas = p,
		luzes = { { osso = "corpo", pos = V(0, 1.4, 0), cor = cor, alcance = 7, brilho = 0.8 } },
		efeitos = {},
		cor = cor,
		altura = 3.2,
	}
end

function Modelos.gosma()
	return gosma(C(96, 222, 104))
end

function Modelos.gosminha()
	local m = gosma(C(140, 240, 120))
	m.escala = 0.55
	return m
end

function Modelos.cogumelo()
	local chapeu = C(206, 52, 58)
	local p = {
		P("corpo", "elipse", V(1.7, 2, 1.7), V(0, 1, 0), C(232, 222, 192), { geleia = true }),
		P("corpo", "elipse", V(3.6, 1.7, 3.6), V(0, 2.35, 0), chapeu, { geleia = true }),
		P("corpo", "elipse", V(3.2, 0.3, 3.2), V(0, 1.6, 0), C(150, 255, 110), { neon = true, transp = 0.2 }),
		P("corpo", "bloco", V(0.4, 0.2, 0.1), V(-0.35, 1.45, -0.82), C(255, 230, 60), { neon = true, rot = R(0, 0, -20), olho = true }),
		P("corpo", "bloco", V(0.4, 0.2, 0.1), V(0.35, 1.45, -0.82), C(255, 230, 60), { neon = true, rot = R(0, 0, 20), olho = true }),
		P("corpo", "elipse", V(0.6, 0.3, 0.9), V(-0.45, 0.15, -0.2), C(210, 200, 170)),
		P("corpo", "elipse", V(0.6, 0.3, 0.9), V(0.45, 0.15, -0.2), C(210, 200, 170)),
	}
	for _, info in { V(-1, 2.9, -0.6), V(0.9, 2.95, -0.4), V(0.2, 3.15, 0.5), V(-0.6, 2.8, 1), V(1.1, 2.6, 0.9) } do
		table.insert(p, P("corpo", "bola", V(0.55, 0.55, 0.55), info, C(250, 246, 236)))
	end
	return {
		estilo = "gosma",
		ossos = { corpo = osso("raiz", V(0, 0, 0)) },
		pecas = p,
		luzes = { { osso = "corpo", pos = V(0, 1.6, 0), cor = C(150, 255, 110), alcance = 8, brilho = 1 } },
		efeitos = { { osso = "corpo", pos = V(0, 2.4, 0), tipo = "esporos", cor = C(170, 255, 120) } },
		cor = chapeu,
		altura = 3.2,
	}
end

------------------------------------------------------------------------
-- Rato
------------------------------------------------------------------------

function Modelos.rato()
	local pelo = C(112, 96, 86)
	local rosa = C(222, 150, 150)
	local ossos = {
		corpo = osso("raiz", V(0, 1.1, 0)),
		cabeca = osso("corpo", V(0, 1.3, -1.2)),
		pernaFE = osso("raiz", V(-0.5, 0.8, -0.7)),
		pernaFD = osso("raiz", V(0.5, 0.8, -0.7)),
		pernaTE = osso("raiz", V(-0.5, 0.8, 0.7)),
		pernaTD = osso("raiz", V(0.5, 0.8, 0.7)),
		cauda = osso("corpo", V(0, 1.05, 1.3)),
	}
	local p = {
		P("corpo", "elipse", V(1.6, 1.3, 2.6), V(0, 1.15, 0), pelo),
		P("corpo", "elipse", V(1.2, 0.8, 2), V(0, 0.9, -0.1), C(150, 132, 118)),
		P("cabeca", "elipse", V(1, 0.9, 1.3), V(0, 1.35, -1.5), pelo),
		P("cabeca", "elipse", V(0.5, 0.45, 0.6), V(0, 1.25, -2.15), rosa),
		P("cabeca", "bola", V(0.2, 0.2, 0.2), V(0, 1.32, -2.45), ESCURO),
		P("cabeca", "elipse", V(0.15, 0.6, 0.5), V(-0.42, 1.9, -1.3), rosa, { rot = R(0, 0, 20) }),
		P("cabeca", "elipse", V(0.15, 0.6, 0.5), V(0.42, 1.9, -1.3), rosa, { rot = R(0, 0, -20) }),
		P("cabeca", "bola", V(0.2, 0.2, 0.2), V(-0.3, 1.55, -1.95), C(255, 50, 50), { neon = true, olho = true }),
		P("cabeca", "bola", V(0.2, 0.2, 0.2), V(0.3, 1.55, -1.95), C(255, 50, 50), { neon = true, olho = true }),
		P("cabeca", "bloco", V(0.26, 0.26, 0.1), V(0, 1.02, -2.32), C(250, 240, 210)),
		S("cauda", V(0, 1.05, 1.3), V(0, 0.95, 2.2), 0.14, rosa),
		S("cauda", V(0, 0.95, 2.2), V(0, 0.9, 3.1), 0.11, rosa),
	}
	for nome, pos in { pernaFE = V(-0.5, 0.4, -0.7), pernaFD = V(0.5, 0.4, -0.7), pernaTE = V(-0.5, 0.4, 0.7), pernaTD = V(0.5, 0.4, 0.7) } do
		table.insert(p, P(nome, "cilindro", V(0.8, 0.26, 0.26), pos, pelo:Lerp(ESCURO, 0.2), { rot = EM_PE }))
		table.insert(p, P(nome, "elipse", V(0.32, 0.18, 0.45), pos - V(0, 0.38, 0.12), rosa))
	end
	return { estilo = "quadrupede", ossos = ossos, pecas = p, luzes = {}, efeitos = {}, cor = pelo, ritmo = 1.6 }
end

------------------------------------------------------------------------
-- Kobolds ("você não pega a vela!")
------------------------------------------------------------------------

local function kobold(pelo: Color3)
	local bege = C(196, 164, 122)
	local ossos = {
		corpo = osso("raiz", V(0, 2.2, 0)),
		cabeca = osso("corpo", V(0, 3.6, -0.1)),
		bracoE = osso("corpo", V(-0.85, 3.3, 0)),
		bracoD = osso("corpo", V(0.85, 3.3, 0)),
		pernaE = osso("raiz", V(-0.35, 2.2, 0)),
		pernaD = osso("raiz", V(0.35, 2.2, 0)),
		cauda = osso("corpo", V(0, 2.3, 0.5)),
	}
	local p = {
		P("corpo", "elipse", V(1.5, 1.6, 1.1), V(0, 2.9, 0), pelo),
		P("corpo", "elipse", V(1, 1, 0.5), V(0, 2.8, -0.38), bege),
		P("corpo", "bloco", V(1.35, 0.55, 1.05), V(0, 2.2, 0), C(92, 60, 38), { mat = TECIDO }),
		P("cabeca", "elipse", V(1.2, 1.1, 1.3), V(0, 3.95, -0.15), pelo),
		P("cabeca", "elipse", V(0.7, 0.6, 0.85), V(0, 3.78, -0.85), bege),
		P("cabeca", "bola", V(0.22, 0.22, 0.22), V(0, 3.92, -1.27), ESCURO),
		P("cabeca", "bola", V(0.2, 0.2, 0.2), V(-0.3, 4.12, -0.72), C(255, 220, 60), { neon = true, olho = true }),
		P("cabeca", "bola", V(0.2, 0.2, 0.2), V(0.3, 4.12, -0.72), C(255, 220, 60), { neon = true, olho = true }),
		P("cabeca", "elipse", V(0.16, 0.75, 0.5), V(-0.6, 4.4, 0), pelo, { rot = R(0, 0, 35) }),
		P("cabeca", "elipse", V(0.16, 0.75, 0.5), V(0.6, 4.4, 0), pelo, { rot = R(0, 0, -35) }),
		S("cauda", V(0, 2.3, 0.5), V(0, 1.6, 1.6), 0.22, pelo),
	}
	for _, lado in { -1, 1 } do
		local braco = if lado < 0 then "bracoE" else "bracoD"
		local perna = if lado < 0 then "pernaE" else "pernaD"
		juntar(p, {
			P(braco, "elipse", V(0.42, 1.25, 0.42), V(lado * 0.95, 2.85, 0), pelo),
			P(braco, "bola", V(0.45, 0.45, 0.45), V(lado * 0.95, 2.2, 0), bege),
			P(perna, "elipse", V(0.5, 1.2, 0.5), V(lado * 0.35, 1.6, 0), pelo),
			P(perna, "elipse", V(0.42, 1, 0.42), V(lado * 0.35, 0.65, 0.05), pelo),
			P(perna, "elipse", V(0.5, 0.3, 0.8), V(lado * 0.35, 0.15, -0.15), bege),
		})
	end
	return { estilo = "bipede", ossos = ossos, pecas = p, luzes = {}, efeitos = {}, cor = pelo, ritmo = 1.3 }
end

function Modelos.kobold()
	local m = kobold(C(134, 100, 70))
	juntar(m.pecas, {
		-- a famosa vela na cabeça
		P("cabeca", "cilindro", V(0.6, 0.38, 0.38), V(0, 4.75, 0), C(240, 236, 220), { rot = EM_PE }),
		P("cabeca", "bola", V(0.3, 0.3, 0.3), V(0, 5.2, 0), C(255, 200, 80), { neon = true }),
		-- picareta
		P("bracoD", "bloco", V(0.2, 0.2, 2.6), V(0.95, 2.2, -1.1), C(110, 76, 46), { mat = MADEIRA }),
		P("bracoD", "bloco", V(0.24, 1.7, 0.3), V(0.95, 2.2, -2.35), C(130, 130, 136), { mat = METAL }),
	})
	m.luzes = { { osso = "cabeca", pos = V(0, 5.2, 0), cor = C(255, 190, 90), alcance = 12, brilho = 1.5 } }
	m.efeitos = { { osso = "cabeca", pos = V(0, 5.25, 0), tipo = "chama", cor = C(255, 190, 90) } }
	return m
end

function Modelos.xama()
	local m = kobold(C(104, 104, 112))
	local verde = C(120, 255, 120)
	juntar(m.pecas, {
		P("cabeca", "bloco", V(1.3, 0.3, 0.5), V(0, 4.55, 0.2), C(170, 60, 60), { mat = TECIDO }),
		P("cabeca", "bloco", V(0.18, 1.2, 0.3), V(-0.4, 5.1, 0.2), C(255, 210, 80), { rot = R(0, 0, 15) }),
		P("cabeca", "bloco", V(0.18, 1.4, 0.3), V(0, 5.2, 0.2), C(90, 200, 255)),
		P("cabeca", "bloco", V(0.18, 1.2, 0.3), V(0.4, 5.1, 0.2), C(255, 90, 90), { rot = R(0, 0, -15) }),
		P("corpo", "bloco", V(1.7, 1.6, 0.2), V(0, 2.9, 0.55), C(70, 52, 92), { mat = TECIDO }),
		P("bracoD", "cilindro", V(4, 0.2, 0.2), V(0.95, 2.6, -0.2), C(100, 70, 44), { rot = EM_PE, mat = MADEIRA }),
		P("bracoD", "bola", V(0.6, 0.6, 0.6), V(0.95, 4.7, -0.2), verde, { neon = true }),
	})
	m.luzes = { { osso = "bracoD", pos = V(0.95, 4.7, -0.2), cor = verde, alcance = 10, brilho = 1.5 } }
	m.efeitos = { { osso = "bracoD", pos = V(0.95, 4.7, -0.2), tipo = "brilho", cor = verde } }
	return m
end

------------------------------------------------------------------------
-- Aranhas
------------------------------------------------------------------------

local function aranha(corCorpo: Color3, corMarca: Color3, corOlho: Color3)
	local ossos = { corpo = osso("raiz", V(0, 1.9, 0)) }
	local p = {
		P("corpo", "elipse", V(2, 1.2, 1.8), V(0, 1.9, -0.5), corCorpo),
		P("corpo", "elipse", V(2.6, 2, 2.8), V(0, 2.3, 1.5), corCorpo:Lerp(ESCURO, 0.2)),
		P("corpo", "bloco", V(0.75, 0.08, 0.75), V(0, 3.28, 1.4), corMarca, { neon = true, rot = R(0, 45, 0) }),
		P("corpo", "bloco", V(0.5, 0.08, 0.5), V(0, 3.24, 2.1), corMarca, { neon = true, rot = R(0, 45, 0) }),
		P("corpo", "elipse", V(1.2, 0.9, 1), V(0, 1.9, -1.5), corCorpo),
		P("corpo", "canto", V(0.2, 0.6, 0.2), V(-0.25, 1.4, -1.9), C(240, 234, 220), { rot = R(180, 0, 0) }),
		P("corpo", "canto", V(0.2, 0.6, 0.2), V(0.25, 1.4, -1.9), C(240, 234, 220), { rot = R(180, 90, 0) }),
	}
	for _, info in { V(-0.22, 2.15, -1.95), V(0.22, 2.15, -1.95), V(-0.48, 2, -1.85), V(0.48, 2, -1.85) } do
		table.insert(p, P("corpo", "bola", V(0.24, 0.24, 0.24), info, corOlho, { neon = true, olho = true }))
	end
	local indice = 0
	for i, z in { -0.9, -0.3, 0.3, 0.9 } do
		for _, lado in { -1, 1 } do
			indice += 1
			local nome = "perna" .. indice
			local quadril = V(lado * 0.85, 1.9, z - 0.3)
			local joelho = V(lado * 2.3, 3.1, z * 1.4 - 0.3)
			local pe = V(lado * 3.4, 0.1, z * 2 - 0.3)
			ossos[nome] = osso("corpo", quadril, { lado = lado, grupo = (i + (if lado > 0 then 1 else 0)) % 2 })
			juntar(p, {
				S(nome, quadril, joelho, 0.28, corCorpo),
				S(nome, joelho, pe, 0.22, corCorpo:Lerp(ESCURO, 0.25)),
				P(nome, "bola", V(0.32, 0.32, 0.32), joelho, corMarca:Lerp(ESCURO, 0.4)),
			})
		end
	end
	return {
		estilo = "aranha",
		ossos = ossos,
		pecas = p,
		luzes = { { osso = "corpo", pos = V(0, 2.1, -1.9), cor = corOlho, alcance = 7, brilho = 1 } },
		efeitos = {},
		cor = corCorpo,
		ritmo = 1.5,
	}
end

function Modelos.aranha()
	return aranha(C(58, 46, 52), C(255, 60, 60), C(255, 60, 60))
end

function Modelos.rainhaAranha()
	local m = aranha(C(54, 32, 66), C(200, 90, 255), C(220, 120, 255))
	m.escala = 1.9
	local roxo = C(200, 90, 255)
	juntar(m.pecas, {
		P("corpo", "canto", V(0.3, 1, 0.3), V(-0.6, 3.6, 1), roxo, { neon = true }),
		P("corpo", "canto", V(0.3, 1.3, 0.3), V(0, 3.75, 1.3), roxo, { neon = true }),
		P("corpo", "canto", V(0.3, 1, 0.3), V(0.6, 3.6, 1), roxo, { neon = true }),
		P("corpo", "elipse", V(1, 0.9, 1), V(0, 2.2, 3), C(230, 226, 200), { transp = 0.2 }),
		P("corpo", "bola", V(0.4, 0.4, 0.4), V(0, 2.55, -1.75), C(255, 230, 255), { neon = true }),
	})
	table.insert(m.efeitos, { osso = "corpo", pos = V(0, 2.5, 1.5), tipo = "veneno", cor = C(160, 255, 110) })
	m.luzes[1].alcance = 16
	return m
end

------------------------------------------------------------------------
-- Cripta
------------------------------------------------------------------------

function Modelos.carnical()
	local pele = C(132, 150, 120)
	local escura = C(88, 100, 78)
	local ossos = {
		corpo = osso("raiz", V(0, 2.5, 0)),
		cabeca = osso("corpo", V(0, 3.75, -0.8)),
		bracoE = osso("corpo", V(-1, 3.55, -0.45)),
		bracoD = osso("corpo", V(1, 3.55, -0.45)),
		pernaE = osso("raiz", V(-0.45, 2.5, 0)),
		pernaD = osso("raiz", V(0.45, 2.5, 0)),
	}
	local p = {
		P("corpo", "elipse", V(1.9, 1.6, 1.4), V(0, 3.25, -0.25), pele, { rot = R(25, 0, 0) }),
		P("corpo", "elipse", V(1.3, 1, 1), V(0, 2.6, 0), escura),
		P("corpo", "bloco", V(1.4, 0.7, 1.1), V(0, 2.35, 0), C(70, 50, 40), { mat = TECIDO }),
		P("cabeca", "elipse", V(1.05, 1, 1.25), V(0, 3.95, -1), pele),
		P("cabeca", "elipse", V(0.95, 0.42, 1), V(0, 3.48, -1.2), escura),
		P("cabeca", "bloco", V(0.72, 0.14, 0.1), V(0, 3.62, -1.66), C(236, 226, 196)),
		P("cabeca", "bola", V(0.22, 0.22, 0.22), V(-0.26, 4.08, -1.56), C(210, 255, 80), { neon = true, olho = true }),
		P("cabeca", "bola", V(0.22, 0.22, 0.22), V(0.26, 4.08, -1.56), C(210, 255, 80), { neon = true, olho = true }),
	}
	for i = 0, 2 do
		table.insert(p, P("corpo", "canto", V(0.25, 0.55, 0.35), V(0, 4 - i * 0.4, 0.35 + i * 0.12), escura, { rot = R(-30, 0, 0) }))
	end
	for _, lado in { -1, 1 } do
		local braco = if lado < 0 then "bracoE" else "bracoD"
		local perna = if lado < 0 then "pernaE" else "pernaD"
		juntar(p, {
			P(braco, "elipse", V(0.48, 1.5, 0.48), V(lado * 1.1, 2.85, -0.45), pele),
			P(braco, "elipse", V(0.42, 1.5, 0.42), V(lado * 1.1, 1.6, -0.45), escura),
			P(braco, "canto", V(0.14, 0.6, 0.14), V(lado * 1.0, 0.65, -0.55), C(230, 220, 190), { rot = R(180, 0, 0) }),
			P(braco, "canto", V(0.14, 0.6, 0.14), V(lado * 1.2, 0.65, -0.55), C(230, 220, 190), { rot = R(180, 0, 0) }),
			P(perna, "elipse", V(0.52, 1.3, 0.52), V(lado * 0.45, 1.9, 0), pele),
			P(perna, "elipse", V(0.46, 1.3, 0.46), V(lado * 0.45, 0.75, 0.1), escura),
			P(perna, "elipse", V(0.5, 0.25, 0.9), V(lado * 0.45, 0.12, -0.2), escura),
		})
	end
	return { estilo = "bipede", ossos = ossos, pecas = p, luzes = {}, efeitos = {}, cor = pele, ritmo = 1.4, curvado = true }
end

local function fantasma(corManto: Color3, corOlho: Color3, transparencia: number)
	local ossos = {
		corpo = osso("raiz", V(0, 3.5, 0)),
		cabeca = osso("corpo", V(0, 4.8, 0)),
		bracoE = osso("corpo", V(-0.95, 4.6, 0)),
		bracoD = osso("corpo", V(0.95, 4.6, 0)),
		manto = osso("corpo", V(0, 3, 0)),
	}
	local p = {
		P("cabeca", "elipse", V(1.6, 1.8, 1.6), V(0, 5.1, 0.08), corManto, { transp = transparencia, mat = Enum.Material.Glass }),
		P("cabeca", "elipse", V(1, 1.1, 0.4), V(0, 5, -0.56), ESCURO),
		P("cabeca", "bola", V(0.26, 0.26, 0.26), V(-0.25, 5.1, -0.72), corOlho, { neon = true, olho = true }),
		P("cabeca", "bola", V(0.26, 0.26, 0.26), V(0.25, 5.1, -0.72), corOlho, { neon = true, olho = true }),
		P("corpo", "elipse", V(1.9, 2.6, 1.6), V(0, 3.7, 0), corManto, { transp = transparencia, mat = Enum.Material.Glass }),
		P("manto", "elipse", V(1.5, 1.6, 1.25), V(0, 2.4, 0.1), corManto, { transp = transparencia + 0.1, mat = Enum.Material.Glass }),
		P("manto", "elipse", V(1, 1.3, 0.85), V(0, 1.5, 0.25), corManto, { transp = transparencia + 0.2, mat = Enum.Material.Glass }),
		P("manto", "elipse", V(0.55, 1, 0.5), V(0, 0.8, 0.4), corManto, { transp = transparencia + 0.3, mat = Enum.Material.Glass }),
	}
	for _, lado in { -1, 1 } do
		local braco = if lado < 0 then "bracoE" else "bracoD"
		juntar(p, {
			P(braco, "elipse", V(0.45, 1.6, 0.45), V(lado * 1.05, 3.95, 0), corManto, { transp = transparencia, mat = Enum.Material.Glass }),
			P(braco, "bola", V(0.42, 0.42, 0.42), V(lado * 1.05, 3.1, 0), corOlho, { neon = true }),
		})
	end
	return {
		estilo = "flutuante",
		ossos = ossos,
		pecas = p,
		luzes = { { osso = "corpo", pos = V(0, 4.5, -0.4), cor = corOlho, alcance = 12, brilho = 1.2 } },
		efeitos = { { osso = "corpo", pos = V(0, 3.5, 0), tipo = "gelo", cor = corOlho } },
		cor = corManto,
	}
end

function Modelos.espectro()
	return fantasma(C(120, 170, 230), C(140, 230, 255), 0.35)
end

function Modelos.lich()
	local m = fantasma(C(48, 40, 92), C(120, 210, 255), 0)
	m.escala = 1.7
	local ouro = C(220, 178, 80)
	local gelo = C(160, 225, 255)
	-- troca o rosto escuro por um crânio
	m.pecas[2] = P("cabeca", "elipse", V(0.95, 1.05, 1), V(0, 5, -0.38), OSSO)
	juntar(m.pecas, {
		P("cabeca", "bloco", V(0.6, 0.25, 0.4), V(0, 4.55, -0.55), OSSO_ESCURO),
		P("cabeca", "canto", V(0.22, 0.9, 0.22), V(-0.5, 6.1, -0.2), gelo, { neon = true }),
		P("cabeca", "canto", V(0.22, 1.2, 0.22), V(0, 6.3, -0.35), gelo, { neon = true }),
		P("cabeca", "canto", V(0.22, 0.9, 0.22), V(0.5, 6.1, -0.2), gelo, { neon = true }),
		P("corpo", "bloco", V(0.25, 2.4, 0.2), V(0, 3.7, -0.8), ouro, { mat = METAL }),
		P("bracoE", "elipse", V(1.1, 0.7, 1.2), V(-1.1, 4.9, 0), C(70, 60, 120), { mat = METAL }),
		P("bracoD", "elipse", V(1.1, 0.7, 1.2), V(1.1, 4.9, 0), C(70, 60, 120), { mat = METAL }),
		P("bracoE", "canto", V(0.25, 0.8, 0.3), V(-1.25, 5.45, 0), gelo, { neon = true }),
		P("bracoD", "canto", V(0.25, 0.8, 0.3), V(1.25, 5.45, 0), gelo, { neon = true }),
		P("bracoD", "bola", V(0.9, 0.9, 0.9), V(1.05, 2.7, -0.3), gelo, { neon = true, transp = 0.1 }),
	})
	m.ossos.orbita = osso("corpo", V(0, 4.5, 0))
	for i = 0, 3 do
		local angulo = i * math.pi / 2
		table.insert(m.pecas, P("orbita", "bloco", V(0.35, 1, 0.35), V(math.cos(angulo) * 2.2, 4.5, math.sin(angulo) * 2.2), gelo, { neon = true, rot = R(30, 0, 20) }))
	end
	m.luzes[1].alcance = 20
	return m
end

function Modelos.cavaleiroMorto()
	local armadura = C(52, 56, 66)
	local azul = C(110, 190, 255)
	local ossos = {
		corpo = osso("raiz", V(0, 4, 0)),
		cabeca = osso("corpo", V(0, 6.4, 0)),
		bracoE = osso("corpo", V(-1.6, 6, 0)),
		bracoD = osso("corpo", V(1.6, 6, 0)),
		pernaE = osso("raiz", V(-0.65, 4, 0)),
		pernaD = osso("raiz", V(0.65, 4, 0)),
		capa = osso("corpo", V(0, 6, 0.8)),
	}
	local p = {
		P("corpo", "bloco", V(2.6, 2.2, 1.6), V(0, 5.3, 0), armadura, { mat = METAL }),
		P("corpo", "bloco", V(2, 0.9, 1.3), V(0, 4.6, 0), armadura:Lerp(ESCURO, 0.3), { mat = METAL }),
		P("corpo", "bloco", V(2.4, 0.5, 1.5), V(0, 4.1, 0), C(40, 30, 30), { mat = TECIDO }),
		P("corpo", "bloco", V(0.6, 0.6, 0.15), V(0, 5.4, -0.82), azul, { neon = true, rot = R(0, 0, 45) }),
		P("cabeca", "bloco", V(1.3, 1.4, 1.3), V(0, 6.9, 0), armadura, { mat = METAL }),
		P("cabeca", "bloco", V(0.95, 0.14, 0.1), V(0, 7, -0.66), azul, { neon = true, olho = true }),
		P("cabeca", "canto", V(0.3, 1.2, 0.6), V(0, 7.85, 0.1), armadura:Lerp(ESCURO, 0.2), { mat = METAL }),
		P("capa", "bloco", V(2.4, 4.2, 0.2), V(0, 3.9, 0.9), C(92, 20, 30), { mat = TECIDO }),
	}
	for _, lado in { -1, 1 } do
		local braco = if lado < 0 then "bracoE" else "bracoD"
		local perna = if lado < 0 then "pernaE" else "pernaD"
		juntar(p, {
			P(braco, "elipse", V(1.5, 1, 1.6), V(lado * 1.65, 6.3, 0), armadura:Lerp(ESCURO, 0.15), { mat = METAL }),
			P(braco, "canto", V(0.4, 1, 0.4), V(lado * 1.85, 6.95, 0), C(190, 196, 206), { mat = METAL }),
			P(braco, "canto", V(0.35, 0.8, 0.35), V(lado * 1.4, 6.85, 0.4), C(190, 196, 206), { mat = METAL }),
			P(braco, "bloco", V(0.8, 1.4, 0.8), V(lado * 1.65, 5.3, 0), armadura, { mat = METAL }),
			P(braco, "bloco", V(0.9, 1.3, 0.9), V(lado * 1.65, 4.2, 0), armadura:Lerp(ESCURO, 0.2), { mat = METAL }),
			P(perna, "bloco", V(0.9, 1.6, 0.9), V(lado * 0.65, 3.2, 0), armadura, { mat = METAL }),
			P(perna, "bloco", V(0.95, 1.8, 1), V(lado * 0.65, 1.4, 0), armadura:Lerp(ESCURO, 0.15), { mat = METAL }),
			P(perna, "bloco", V(1, 0.6, 1.4), V(lado * 0.65, 0.3, -0.2), armadura:Lerp(ESCURO, 0.3), { mat = METAL }),
		})
	end
	juntar(p, {
		P("bracoD", "bloco", V(0.25, 0.8, 4.8), V(1.65, 3.55, -2.6), C(150, 160, 175), { mat = METAL }),
		P("bracoD", "bloco", V(0.28, 0.2, 3.8), V(1.65, 3.6, -2.7), azul, { neon = true }),
		P("bracoD", "bloco", V(1.4, 0.3, 0.3), V(1.65, 3.55, -0.3), armadura, { mat = METAL }),
	})
	return {
		estilo = "bipede",
		ossos = ossos,
		pecas = p,
		luzes = { { osso = "cabeca", pos = V(0, 7, -0.8), cor = azul, alcance = 10, brilho = 1.5 } },
		efeitos = { { osso = "bracoD", pos = V(1.65, 3.6, -2.7), tipo = "gelo", cor = azul } },
		cor = armadura,
		ritmo = 0.8,
	}
end

------------------------------------------------------------------------
-- Fornalha
------------------------------------------------------------------------

function Modelos.diabrete()
	local vermelho = C(196, 52, 44)
	local roxo = C(110, 40, 84)
	local ossos = {
		corpo = osso("raiz", V(0, 1.9, 0)),
		cabeca = osso("corpo", V(0, 3, 0)),
		bracoE = osso("corpo", V(-0.75, 2.8, 0)),
		bracoD = osso("corpo", V(0.75, 2.8, 0)),
		pernaE = osso("raiz", V(-0.3, 1.9, 0)),
		pernaD = osso("raiz", V(0.3, 1.9, 0)),
		asaE = osso("corpo", V(-0.4, 2.9, 0.4), { lado = -1 }),
		asaD = osso("corpo", V(0.4, 2.9, 0.4), { lado = 1 }),
		cauda = osso("corpo", V(0, 2, 0.4)),
	}
	local p = {
		P("corpo", "elipse", V(1.2, 1.3, 1), V(0, 2.5, 0), vermelho),
		P("corpo", "elipse", V(0.8, 0.8, 0.4), V(0, 2.45, -0.35), C(230, 120, 90)),
		P("cabeca", "elipse", V(1.25, 1.1, 1.1), V(0, 3.4, 0), vermelho),
		P("cabeca", "canto", V(0.25, 0.85, 0.3), V(-0.42, 4.05, 0.1), C(40, 30, 30), { rot = R(-10, 0, 15) }),
		P("cabeca", "canto", V(0.25, 0.85, 0.3), V(0.42, 4.05, 0.1), C(40, 30, 30), { rot = R(-10, 90, -15) }),
		P("cabeca", "bloco", V(0.28, 0.16, 0.1), V(-0.27, 3.55, -0.55), C(255, 230, 60), { neon = true, rot = R(0, 0, -15), olho = true }),
		P("cabeca", "bloco", V(0.28, 0.16, 0.1), V(0.27, 3.55, -0.55), C(255, 230, 60), { neon = true, rot = R(0, 0, 15), olho = true }),
		P("cabeca", "bloco", V(0.62, 0.1, 0.1), V(0, 3.15, -0.54), ESCURO),
		P("asaE", "bloco", V(1.6, 1.3, 0.08), V(-1.15, 3.1, 0.55), roxo, { mat = TECIDO, rot = R(0, 20, 10) }),
		P("asaD", "bloco", V(1.6, 1.3, 0.08), V(1.15, 3.1, 0.55), roxo, { mat = TECIDO, rot = R(0, -20, -10) }),
		S("cauda", V(0, 2, 0.4), V(0, 1.4, 1.4), 0.16, vermelho),
		P("cauda", "canto", V(0.4, 0.4, 0.15), V(0, 1.35, 1.5), ESCURO),
		P("bracoD", "bola", V(0.7, 0.7, 0.7), V(0.85, 1.95, -0.3), C(255, 140, 40), { neon = true }),
	}
	for _, lado in { -1, 1 } do
		local braco = if lado < 0 then "bracoE" else "bracoD"
		local perna = if lado < 0 then "pernaE" else "pernaD"
		juntar(p, {
			P(braco, "elipse", V(0.35, 1.1, 0.35), V(lado * 0.82, 2.35, 0), vermelho),
			P(perna, "elipse", V(0.42, 1, 0.42), V(lado * 0.3, 1.35, 0), vermelho:Lerp(ESCURO, 0.2)),
			P(perna, "elipse", V(0.36, 0.9, 0.36), V(lado * 0.3, 0.5, 0.15), vermelho:Lerp(ESCURO, 0.35)),
		})
	end
	return {
		estilo = "bipede",
		ossos = ossos,
		pecas = p,
		luzes = { { osso = "bracoD", pos = V(0.85, 1.95, -0.3), cor = C(255, 140, 40), alcance = 10, brilho = 1.5 } },
		efeitos = { { osso = "bracoD", pos = V(0.85, 1.95, -0.3), tipo = "chama", cor = C(255, 140, 40) } },
		cor = vermelho,
		ritmo = 1.4,
	}
end

local function elemental(corFogo: Color3, corNucleo: Color3)
	local rocha = C(46, 34, 32)
	local ossos = {
		corpo = osso("raiz", V(0, 3, 0)),
		cabeca = osso("corpo", V(0, 4.8, 0)),
		bracoE = osso("corpo", V(-1.4, 4.4, 0)),
		bracoD = osso("corpo", V(1.4, 4.4, 0)),
		base = osso("raiz", V(0, 1.5, 0)),
	}
	local p = {
		P("corpo", "elipse", V(2.1, 2.3, 1.6), V(0, 3.8, 0), corFogo, { neon = true, transp = 0.1 }),
		P("corpo", "elipse", V(1.2, 1.4, 1), V(0, 3.8, -0.15), corNucleo, { neon = true }),
		P("corpo", "bloco", V(1, 0.9, 0.5), V(-0.65, 4.3, -0.6), rocha, { rot = R(10, 20, 15), mat = PEDRA }),
		P("corpo", "bloco", V(1, 0.9, 0.5), V(0.65, 4.3, -0.6), rocha, { rot = R(10, -20, -15), mat = PEDRA }),
		P("cabeca", "elipse", V(1.25, 1.45, 1.2), V(0, 5.15, 0), corFogo, { neon = true }),
		P("cabeca", "bloco", V(0.3, 0.16, 0.1), V(-0.25, 5.25, -0.58), C(255, 255, 220), { neon = true, olho = true }),
		P("cabeca", "bloco", V(0.3, 0.16, 0.1), V(0.25, 5.25, -0.58), C(255, 255, 220), { neon = true, olho = true }),
		P("cabeca", "canto", V(0.4, 1.1, 0.4), V(0, 6.05, 0), corNucleo, { neon = true }),
		P("base", "elipse", V(1.7, 1, 1.7), V(0, 2.3, 0), corFogo, { neon = true, transp = 0.2 }),
		P("base", "elipse", V(1.15, 1, 1.15), V(0.15, 1.5, 0), corFogo:Lerp(corNucleo, 0.3), { neon = true, transp = 0.25 }),
		P("base", "elipse", V(0.6, 1, 0.6), V(-0.1, 0.75, 0.1), corNucleo, { neon = true, transp = 0.3 }),
	}
	for _, lado in { -1, 1 } do
		local braco = if lado < 0 then "bracoE" else "bracoD"
		juntar(p, {
			P(braco, "elipse", V(0.75, 1.9, 0.75), V(lado * 1.5, 3.6, 0), corFogo, { neon = true, transp = 0.1 }),
			P(braco, "bloco", V(0.95, 0.7, 0.95), V(lado * 1.5, 3.1, 0), rocha, { mat = PEDRA }),
			P(braco, "elipse", V(0.95, 0.95, 0.95), V(lado * 1.5, 2.55, 0), corNucleo, { neon = true }),
		})
	end
	return {
		estilo = "flutuante",
		ossos = ossos,
		pecas = p,
		luzes = { { osso = "corpo", pos = V(0, 3.8, 0), cor = corFogo, alcance = 16, brilho = 2 } },
		efeitos = { { osso = "corpo", pos = V(0, 4, 0), tipo = "fogo", cor = corFogo } },
		cor = corFogo,
		girarBase = true,
	}
end

function Modelos.elementalFogo()
	return elemental(C(255, 120, 40), C(255, 220, 120))
end

function Modelos.senhorChamas()
	local m = elemental(C(255, 96, 30), C(255, 214, 110))
	m.escala = 2.3
	local rocha = C(40, 28, 26)
	local lava = C(255, 120, 40)
	juntar(m.pecas, {
		P("cabeca", "canto", V(0.45, 1.6, 0.6), V(-0.75, 5.9, 0.1), rocha, { rot = R(-15, 0, 25), mat = PEDRA }),
		P("cabeca", "canto", V(0.45, 1.6, 0.6), V(0.75, 5.9, 0.1), rocha, { rot = R(-15, 90, -25), mat = PEDRA }),
		P("cabeca", "elipse", V(1, 1, 0.6), V(0, 4.55, -0.45), C(255, 200, 80), { neon = true }),
		P("corpo", "bloco", V(2.4, 0.6, 1.4), V(0, 4.85, 0), rocha, { mat = PEDRA }),
		-- martelo gigante
		P("bracoD", "cilindro", V(4.4, 0.35, 0.35), V(1.5, 2.6, -1.2), C(70, 52, 40), { rot = R(0, 90, 0), mat = MADEIRA }),
		P("bracoD", "bloco", V(2.6, 1.6, 1.6), V(1.5, 2.6, -3.4), rocha, { mat = PEDRA }),
		P("bracoD", "bloco", V(2.7, 0.3, 1.7), V(1.5, 2.6, -3.4), lava, { neon = true }),
	})
	m.luzes[1].alcance = 30
	return m
end

function Modelos.ogro()
	local pele = C(140, 152, 96)
	local escura = C(104, 116, 72)
	local couro = C(96, 64, 40)
	local ossos = {
		corpo = osso("raiz", V(0, 4.8, 0)),
		cabeca = osso("corpo", V(0, 8.6, -0.4)),
		bracoE = osso("corpo", V(-2.6, 7.6, 0)),
		bracoD = osso("corpo", V(2.6, 7.6, 0)),
		pernaE = osso("raiz", V(-1.1, 4.8, 0)),
		pernaD = osso("raiz", V(1.1, 4.8, 0)),
	}
	local p = {
		P("corpo", "elipse", V(4.2, 3.8, 3.6), V(0, 5.6, -0.2), pele),
		P("corpo", "elipse", V(4.6, 2.6, 3), V(0, 7.3, 0), pele),
		P("corpo", "bloco", V(0.4, 0.25, 5.2), V(0, 6.4, -0.3), couro, { rot = R(0, 90, 35), mat = TECIDO }),
		P("corpo", "bloco", V(3.8, 1.5, 3.4), V(0, 4.6, 0), couro, { mat = TECIDO }),
		P("corpo", "bloco", V(3.9, 0.45, 3.5), V(0, 5.3, 0), C(60, 40, 26), { mat = TECIDO }),
		P("cabeca", "elipse", V(2, 1.8, 1.9), V(0, 8.95, -0.6), pele),
		P("cabeca", "elipse", V(1.8, 0.85, 1.6), V(0, 8.3, -0.9), escura),
		P("cabeca", "canto", V(0.3, 0.75, 0.3), V(-0.55, 8.8, -1.6), C(240, 232, 210)),
		P("cabeca", "canto", V(0.3, 0.75, 0.3), V(0.55, 8.8, -1.6), C(240, 232, 210), { rot = R(0, 90, 0) }),
		P("cabeca", "bola", V(0.28, 0.28, 0.28), V(-0.4, 9.2, -1.42), C(255, 220, 60), { neon = true, olho = true }),
		P("cabeca", "bola", V(0.28, 0.28, 0.28), V(0.4, 9.2, -1.42), C(255, 220, 60), { neon = true, olho = true }),
		P("cabeca", "bloco", V(0.35, 0.9, 1.7), V(0, 9.95, -0.45), C(40, 30, 30)),
	}
	for _, lado in { -1, 1 } do
		local braco = if lado < 0 then "bracoE" else "bracoD"
		local perna = if lado < 0 then "pernaE" else "pernaD"
		juntar(p, {
			P(braco, "elipse", V(1.9, 1.7, 1.9), V(lado * 2.5, 7.8, 0), pele),
			P(braco, "elipse", V(1.3, 2.6, 1.3), V(lado * 2.7, 6.3, 0), pele),
			P(braco, "elipse", V(1.2, 2.2, 1.2), V(lado * 2.8, 4.6, -0.2), escura),
			P(braco, "bola", V(1.35, 1.35, 1.35), V(lado * 2.8, 3.3, -0.3), escura),
			P(braco, "cilindro", V(0.7, 1.3, 1.3), V(lado * 2.8, 4.1, -0.2), couro, { rot = EM_PE, mat = TECIDO }),
			P(perna, "elipse", V(1.5, 2.6, 1.5), V(lado * 1.1, 3.4, 0), pele),
			P(perna, "elipse", V(1.3, 2.2, 1.3), V(lado * 1.1, 1.4, 0), escura),
			P(perna, "elipse", V(1.4, 0.7, 2), V(lado * 1.1, 0.35, -0.3), escura),
		})
	end
	-- clava cravejada
	juntar(p, {
		P("bracoD", "elipse", V(1.1, 1.1, 4.8), V(2.8, 3.3, -2.6), C(110, 76, 46), { mat = MADEIRA }),
		P("bracoD", "canto", V(0.3, 0.6, 0.3), V(2.8, 3.95, -3.6), C(150, 150, 156), { mat = METAL }),
		P("bracoD", "canto", V(0.3, 0.6, 0.3), V(3.4, 3.4, -4.2), C(150, 150, 156), { mat = METAL, rot = R(0, 0, -90) }),
		P("bracoD", "canto", V(0.3, 0.6, 0.3), V(2.2, 3.4, -4.4), C(150, 150, 156), { mat = METAL, rot = R(0, 0, 90) }),
	})
	return { estilo = "bipede", ossos = ossos, pecas = p, luzes = {}, efeitos = {}, cor = pele, ritmo = 0.7 }
end

-- Modelo genérico caso surja um tipo sem aparência própria
function Modelos.padrao()
	return gosma(C(200, 200, 200))
end

return Modelos
