-- Poses e animações dos personagens (só dados e contas: pode ser testado fora do Roblox).
--
-- Cada animação é uma lista de "quadros-chave": em cada tempo, o ângulo de algumas juntas
-- (ombro, cotovelo, cintura...). Entre os quadros, os valores são suavizados.
--
-- Cada valor tem 7 números: rx, ry, rz (ângulos em radianos), px, py, pz (deslocamento) e
-- w (peso, de 0 a 1). Com peso 0 a junta volta para a animação de baixo (postura, andar...).
-- Toda animação começa com peso 0 nas juntas que ainda não estavam em uso e, no campo
-- "voltar", solta todas as juntas devagar: o golpe sai da pose de combate e volta para ela.
--
-- Espaço da peça "pai" (X = direita, Y = cima, Z = trás):
--   rx > 0 leva o braço/perna para FRENTE (1,57 = esticado para frente; 3,14 = para cima)
--   ry > 0 gira para a ESQUERDA (visto de cima)   rz > 0 abre o braço direito para o lado
--   no tronco (cintura), rx < 0 inclina para frente; joelho < 0 dobra
-- Valores especiais: "puxar" (corda do arco, 0 a 1,3) e "brilho" (cristal do cajado).

local Poses = {}

local function A(rx: number?, ry: number?, rz: number?, px: number?, py: number?, pz: number?)
	return { rx or 0, ry or 0, rz or 0, px or 0, py or 0, pz or 0, 1 }
end
Poses.A = A

local SOLTO = { 0, 0, 0, 0, 0, 0, 0 }
Poses.SOLTO = SOLTO

local function solto(v)
	return { v[1], v[2], v[3], v[4], v[5], v[6], 0 }
end

local function juntar(base, extra)
	local resultado = table.clone(base)
	for chave, valor in extra do
		resultado[chave] = valor
	end
	return resultado
end

local PI = math.pi

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
		(a[7] or 1) + ((b[7] or 1) - (a[7] or 1)) * alfa,
	}
end
Poses.misturar = misturar

-- Ângulo equivalente entre -π e π (depois de um giro de 360°, a próxima animação parte de
-- perto de zero em vez de "desgirar")
local function angulo(a: number): number
	return (a + PI) % (2 * PI) - PI
end
Poses.angulo = angulo

------------------------------------------------------------------------
-- Postura (sempre, da cintura para cima) e pose parada (corpo todo)
------------------------------------------------------------------------

Poses.POSTURAS = {
	-- espada à frente e escudo erguido à frente do lado esquerdo (também enquanto anda)
	cavaleiro = {
		ombroD = A(0.49, -0.25, 0.37),
		cotoveloD = A(1.28),
		pulsoD = A(-0.59, -0.03, 0.9),
		ombroE = A(0.15, 0, -0.14),
		cotoveloE = A(0.35),
		pescoco = A(-0.05),
	},
	-- cajado em pé do lado de fora do corpo (não atravessa o tronco nem as pernas)
	mago = { ombroD = A(0.08, -0.14, 0.38), cotoveloD = A(1.42), pulsoD = A(-1.7, -0.35, -0.1), ombroE = A(0.15, 0, -0.12), cintura = A(0.06) },
	arqueiro = { ombroE = A(0.45, 0.2, -0.1), cotoveloE = A(0.3), ombroD = A(0.15, 0, 0.1) },
	-- o Assassino anda sempre curvado, com as adagas baixas e à frente
	assassino = {
		cintura = A(-0.3),
		pescoco = A(0.22),
		ombroD = A(0.55, 0, 0.3),
		cotoveloD = A(1.2),
		pulsoD = A(-0.3),
		ombroE = A(0.75, 0.25, -0.3),
		cotoveloE = A(1.35),
		pulsoE = A(-0.3),
	},
}

-- "t" é o tempo em segundos (para respirar e balançar de leve)
Poses.PARADO = {
	-- Guarda firme: base larga, escudo à frente, espada pronta
	cavaleiro = function(t: number)
		local respirar = math.sin(t * 1.6) * 0.025
		return {
			-- base aberta, peso um pouco à frente, peito aberto
			raiz = A(0, -0.2, 0, 0, -0.15 + respirar * 0.5, 0),
			cintura = A(-0.04 + respirar, 0.08),
			pescoco = A(-0.04, 0.12),
			ombroD = A(0.49, -0.25, 0.37),
			cotoveloD = A(1.28),
			pulsoD = A(-0.59, -0.03, 0.9),
			ombroE = A(0.12 + respirar, 0, -0.16),
			cotoveloE = A(0.3),
			pulsoE = A(0),
			quadrilD = A(-0.12, 0, 0.24),
			joelhoD = A(-0.25),
			tornozeloD = A(0.1),
			quadrilE = A(0.22, 0, -0.24),
			joelhoE = A(-0.35),
			tornozeloE = A(0.12),
		}
	end,
	-- Levitando, ereto e confiante: cajado em pé, a outra mão conjura uma luz (a altura e as
	-- pernas soltas vêm de Poses.FLUTUAR)
	mago = function(t: number)
		return {
			raiz = A(0, math.sin(t * 0.7) * 0.06, math.sin(t * 1.1) * 0.03),
			cintura = A(0.1 + math.sin(t * 1.4) * 0.02),
			pescoco = A(-0.14),
			ombroD = A(0.08, -0.14, 0.38),
			cotoveloD = A(1.42),
			pulsoD = A(-1.7, -0.35, -0.1),
			ombroE = A(0.75, 0.35, -0.25),
			cotoveloE = A(1.35),
			pulsoE = A(0.45 + math.sin(t * 2) * 0.1),
			brilho = A(0.35 + math.sin(t * 2) * 0.1),
		}
	end,
	-- Relaxado, peso numa perna, arco baixo, olhando em volta
	arqueiro = function(t: number)
		return {
			raiz = A(0, -0.25, 0.07),
			cintura = A(0.02, 0.15, -0.05),
			pescoco = A(0, math.sin(t * 0.6) * 0.45),
			ombroE = A(0.25, 0, -0.18),
			cotoveloE = A(0.25),
			ombroD = A(-0.12, 0, 0.18),
			cotoveloD = A(0.5),
			quadrilD = A(0, 0, 0.1),
			quadrilE = A(0.18, 0, -0.16),
			joelhoE = A(-0.35),
			tornozeloE = A(0.15),
		}
	end,
	-- Agachado e inclinado para frente, pronto para dar o bote
	assassino = function(t: number)
		local respirar = math.sin(t * 3.2) * 0.04
		return {
			raiz = A(0, 0.3, 0, 0, -0.42 + respirar, 0),
			cintura = A(-0.5 + respirar, -0.2),
			pescoco = A(0.42, 0.15 + math.sin(t * 0.8) * 0.15),
			ombroD = A(0.7, 0, 0.4),
			cotoveloD = A(1.35),
			pulsoD = A(-0.35),
			ombroE = A(1, 0.35, -0.35),
			cotoveloE = A(1.55),
			pulsoE = A(-0.35),
			quadrilD = A(0.65, 0, 0.15),
			joelhoD = A(-1.1),
			tornozeloD = A(0.42),
			quadrilE = A(0.35, 0, -0.2),
			joelhoE = A(-1),
			tornozeloE = A(0.6),
		}
	end,
}

------------------------------------------------------------------------
-- Andar feito por código: substitui a animação de andar do Roblox (que vem do avatar de
-- cada jogador e pode ser de qualquer estilo). Só as classes que estão aqui usam.
--   fase: ciclo da passada em radianos (uma volta = dois passos)
--   frente, lado: direção do movimento em relação ao corpo (de -1 a 1)
--   forca: 0 (devagar) a 1 (correndo)
------------------------------------------------------------------------

Poses.ANDAR = {
	-- Mago: não anda, desliza no ar. O corpo inclina para onde vai (e de lado nas curvas), o
	-- cajado vai à frente e a outra mão fica para trás, como quem voa.
	mago = function(fase: number, frente: number, lado: number, forca: number)
		local balanco = math.sin(fase * 0.5)
		return {
			raiz = A(-0.22 * frente * forca, 0, 0.14 * lado * forca + 0.03 * balanco),
			cintura = A(-0.08 * frente * forca, 0.05 * balanco),
			pescoco = A(0.15 * frente * forca),
			-- cajado inclinado para a frente, do lado de fora do corpo
			ombroD = A(-0.07, 0.1, 1.03),
			cotoveloD = A(1.41),
			pulsoD = A(-1.72, -1.15, -0.03),
			ombroE = A(-0.35 * forca, 0.2, -0.45),
			cotoveloE = A(0.45),
			pulsoE = A(0.2),
			brilho = A(0.4),
		}
	end,
	-- Cavaleiro: andar solto e confiante. Pernas bem afastadas, passos longos, peito aberto e o
	-- quadril sem rebolar. A espada vai em guarda aberta (para cima e para fora) e o escudo
	-- vai solto ao lado do corpo, balançando com o passo.
	cavaleiro = function(fase: number, frente: number, lado: number, forca: number)
		local s = math.sin(fase)
		local amplitude = 0.45 + 0.3 * forca
		local function perna(f: number, abertura: number)
			local sf, cf = math.sin(f), math.cos(f)
			local quadril = A(amplitude * frente * sf, 0, abertura + amplitude * 0.7 * lado * sf)
			local joelho = A(-(0.15 + (0.7 + 0.5 * forca) * math.max(0, cf)))
			local tornozelo = A(0.12 + 0.22 * math.max(0, cf) - 0.18 * forca * math.max(0, -sf))
			return quadril, joelho, tornozelo
		end
		local quadrilD, joelhoD, tornozeloD = perna(fase, 0.2)
		local quadrilE, joelhoE, tornozeloE = perna(fase + PI, -0.2)
		local pisada = math.cos(2 * fase)
		local balanco = 0.22 * frente * forca
		return {
			raiz = A(-0.08 - 0.04 * forca, 0.06 * s * frente, 0, 0, -0.15 - 0.05 * forca * pisada, 0),
			cintura = A(-0.08, -0.08 * s * frente),
			pescoco = A(0.03, 0.03 * s * frente),
			ombroD = A(0.49 - 0.05 * balanco * s, -0.25, 0.37),
			cotoveloD = A(1.28),
			pulsoD = A(-0.59, -0.03, 0.9),
			-- braço do escudo solto: vai para a frente quando a perna direita vai
			ombroE = A(0.15 + balanco * s, 0, -0.14),
			cotoveloE = A(0.35 + 0.1 * forca),
			pulsoE = A(0),
			quadrilD = quadrilD,
			joelhoD = joelhoD,
			tornozeloD = tornozeloD,
			quadrilE = quadrilE,
			joelhoE = joelhoE,
			tornozeloE = tornozeloE,
		}
	end,
	-- Arqueiro: passos leves e rápidos de caçador, o corpo um pouco inclinado para a frente e a
	-- cabeça firme olhando adiante. O arco vai baixo na mão esquerda, com a ponta de cima para a
	-- frente, e a mão da corda balança solta perto do quadril.
	arqueiro = function(fase: number, frente: number, lado: number, forca: number)
		local s = math.sin(fase)
		local amplitude = 0.5 + 0.35 * forca
		local function perna(f: number, abertura: number)
			local sf, cf = math.sin(f), math.cos(f)
			local quadril = A(amplitude * frente * sf - 0.05, 0, abertura + amplitude * 0.7 * lado * sf)
			-- joelho sobe mais (passo ágil, quase na ponta dos pés quando corre)
			local joelho = A(-(0.2 + (0.8 + 0.6 * forca) * math.max(0, cf)))
			local tornozelo = A(0.15 + 0.25 * math.max(0, cf) - 0.25 * forca * math.max(0, -sf))
			return quadril, joelho, tornozelo
		end
		local quadrilD, joelhoD, tornozeloD = perna(fase, 0.1)
		local quadrilE, joelhoE, tornozeloE = perna(fase + PI, -0.1)
		local pisada = math.cos(2 * fase)
		local balanco = (0.3 + 0.2 * forca) * frente
		local inclinacao = 0.1 + 0.1 * forca
		return {
			raiz = A(-inclinacao * frente, 0.08 * s * frente, -0.04 * lado, 0, -0.12 - 0.08 * forca * pisada, 0),
			cintura = A(-0.04, -0.1 * s * frente),
			-- a cabeça compensa a inclinação e fica olhando para a frente
			pescoco = A(inclinacao * 0.8, 0.05 * s * frente),
			-- arco: braço quase solto, um pouco à frente, balançando pouco (o arco pesa)
			ombroE = A(0.3 + 0.35 * balanco * s, 0.15, -0.16),
			cotoveloE = A(0.35 + 0.15 * forca),
			pulsoE = A(0.1),
			-- mão da corda: vai e volta com o passo, mais dobrada quando corre
			ombroD = A(0.05 - balanco * s, 0, 0.14),
			cotoveloD = A(0.35 + 0.35 * forca + 0.15 * math.max(0, -s)),
			pulsoD = A(0),
			quadrilD = quadrilD,
			joelhoD = joelhoD,
			tornozeloD = tornozeloD,
			quadrilE = quadrilE,
			joelhoE = joelhoE,
			tornozeloE = tornozeloE,
		}
	end,
}

-- Corrida leve (Shift), por cima do andar. Como numa corrida de verdade: o corpo inclina para
-- a frente (a partir do tornozelo, não dobrando a cintura), os cotovelos dobram perto de 90° e
-- os braços balançam ao contrário das pernas, o joelho sobe mais na volta da perna e o corpo
-- "flutua" um pouco entre um apoio e outro.
local function pernasDeCorrida(fase: number, frente: number, lado: number, dobra: number)
	local function perna(f: number, abertura: number)
		local sf, cf = math.sin(f), math.cos(f)
		local quadril = A(dobra + 0.9 * frente * sf, 0, abertura + 0.5 * lado * sf)
		local joelho = A(-(0.3 + dobra + 1.5 * math.max(0, cf)))
		local tornozelo = A(0.25 + 0.35 * math.max(0, cf) - 0.35 * math.max(0, -sf))
		return quadril, joelho, tornozelo
	end
	local quadrilD, joelhoD, tornozeloD = perna(fase, 0.12)
	local quadrilE, joelhoE, tornozeloE = perna(fase + PI, -0.12)
	return {
		quadrilD = quadrilD,
		joelhoD = joelhoD,
		tornozeloD = tornozeloD,
		quadrilE = quadrilE,
		joelhoE = joelhoE,
		tornozeloE = tornozeloE,
	}
end

Poses.CORRER = {
	-- espada pronta perto do corpo, o escudo balança com o passo
	cavaleiro = function(fase: number, frente: number, lado: number)
		local s = math.sin(fase)
		local pose = pernasDeCorrida(fase, frente, lado, 0)
		pose.raiz = A(-0.2 * frente, 0.1 * s * frente, -0.05 * lado, 0, -0.2 + 0.18 * math.abs(math.cos(fase)), 0)
		pose.cintura = A(-0.06, -0.14 * s * frente)
		pose.pescoco = A(0.14, 0.06 * s * frente)
		pose.ombroD = A(0.35 - 0.3 * s, -0.2, 0.3)
		pose.cotoveloD = A(1.5)
		pose.pulsoD = A(-0.59, -0.03, 0.9)
		pose.ombroE = A(0.25 + 0.55 * s, 0, -0.15)
		pose.cotoveloE = A(1.4)
		return pose
	end,
	-- arco baixo na mão, a mão da corda bate o ritmo
	arqueiro = function(fase: number, frente: number, lado: number)
		local s = math.sin(fase)
		local pose = pernasDeCorrida(fase, frente, lado, 0.05)
		pose.raiz = A(-0.25 * frente, 0.1 * s * frente, -0.05 * lado, 0, -0.18 + 0.2 * math.abs(math.cos(fase)), 0)
		pose.cintura = A(-0.05, -0.14 * s * frente)
		pose.pescoco = A(0.2, 0.06 * s * frente)
		pose.ombroE = A(0.2 + 0.5 * s, 0.1, -0.15)
		pose.cotoveloE = A(0.7)
		pose.ombroD = A(-0.6 * s, 0, 0.12)
		pose.cotoveloD = A(1.55)
		return pose
	end,
	-- corrida de ninja: bem inclinado, braços esticados para trás, cabeça erguida
	assassino = function(fase: number, frente: number, lado: number)
		local s = math.sin(fase)
		local pose = pernasDeCorrida(fase, frente, lado, 0.35)
		pose.raiz = A(-0.55 * frente, 0.08 * s * frente, -0.06 * lado, 0, -0.45 + 0.12 * math.abs(math.cos(fase)), 0)
		pose.cintura = A(-0.15, -0.08 * s * frente)
		pose.pescoco = A(0.65, 0.04 * s * frente)
		pose.ombroD = A(-1.25 - 0.12 * s, 0, 0.25)
		pose.ombroE = A(-1.25 + 0.12 * s, 0, -0.25)
		pose.cotoveloD = A(0.15)
		pose.cotoveloE = A(0.15)
		pose.pulsoD = A(-1.05)
		pose.pulsoE = A(-1.05)
		return pose
	end,
	-- o Mago voa mais deitado, a mão livre para trás (as pernas vêm da levitação)
	mago = function(fase: number, frente: number, lado: number)
		local balanco = math.sin(fase * 0.5)
		return {
			raiz = A(-0.45 * frente, 0, 0.18 * lado + 0.04 * balanco),
			cintura = A(-0.15 * frente, 0.05 * balanco),
			pescoco = A(0.35 * frente),
			ombroE = A(-0.8, 0.2, -0.5),
			cotoveloE = A(0.3),
			pulsoE = A(0.3),
			brilho = A(0.7),
		}
	end,
}

-- Distância (em studs) de um ciclo inteiro da passada (dois passos). Quem não está aqui usa 8.
Poses.PASSADA = { arqueiro = 6.5, assassino = 7 }

-- Assassino: corrida de ninja, baixa e silenciosa. Agachado, o tronco bem inclinado e a cabeça
-- erguida olhando o alvo. Andando devagar, as adagas ficam em guarda na frente; correndo, os
-- braços vão para trás com as lâminas apontando para trás.
Poses.ANDAR.assassino = function(fase: number, frente: number, lado: number, forca: number)
	local s = math.sin(fase)
	local amplitude = 0.55 + 0.3 * forca
	local function perna(f: number, abertura: number)
		local sf, cf = math.sin(f), math.cos(f)
		-- quadril já dobrado (agachado) e joelho sempre flexionado
		local quadril = A(0.3 + amplitude * frente * sf, 0, abertura + amplitude * 0.6 * lado * sf)
		local joelho = A(-(0.45 + (0.8 + 0.5 * forca) * math.max(0, cf)))
		local tornozelo = A(0.25 + 0.2 * math.max(0, cf) - 0.2 * forca * math.max(0, -sf))
		return quadril, joelho, tornozelo
	end
	local quadrilD, joelhoD, tornozeloD = perna(fase, 0.12)
	local quadrilE, joelhoE, tornozeloE = perna(fase + PI, -0.12)
	local pisada = math.cos(2 * fase)
	local inclinacao = 0.3 + 0.15 * forca
	-- braços: da guarda na frente (devagar) para trás (correndo)
	local bracos = 0.45 - 1.45 * forca
	local balanco = 0.25 * (1 - forca) * frente
	-- correndo, o pulso deita a lâmina ao longo do braço (apontando para trás)
	local pulso = -0.3 - 0.75 * forca
	return {
		raiz = A(-inclinacao * frente, 0.06 * s * frente, -0.05 * lado, 0, -0.38 - 0.06 * pisada, 0),
		cintura = A(-0.12, -0.08 * s * frente),
		pescoco = A(inclinacao + 0.1, 0.04 * s * frente),
		ombroD = A(bracos - balanco * s, 0, 0.3 - 0.15 * forca),
		cotoveloD = A(0.9 - 0.7 * forca),
		pulsoD = A(pulso),
		ombroE = A(bracos + balanco * s, 0, -0.3 + 0.15 * forca),
		cotoveloE = A(0.9 - 0.7 * forca),
		pulsoE = A(pulso),
		quadrilD = quadrilD,
		joelhoD = joelhoD,
		tornozeloD = tornozeloD,
		quadrilE = quadrilE,
		joelhoE = joelhoE,
		tornozeloE = tornozeloE,
	}
end

------------------------------------------------------------------------
-- Levitação (Mago): o corpo fica sempre um pouco acima do chão, subindo e descendo devagar,
-- com as pernas soltas (pendentes parado, para trás quando desliza). Vale também nos ataques,
-- nas magias e na esquiva.
--   altura: quanto o corpo sobe   pernas(t, movendo): pose das pernas (movendo de 0 a 1)
------------------------------------------------------------------------

Poses.FLUTUAR = {
	mago = {
		altura = 1.3,
		balanco = 0.18,
		pernas = function(t: number, movendo: number)
			local m = movendo
			local onda = math.sin(t * 1.8)
			return {
				quadrilD = A(0.18 - 0.5 * m + 0.04 * onda, 0, 0.06),
				joelhoD = A(-0.35 - 0.35 * m),
				tornozeloD = A(-0.45),
				quadrilE = A(0.32 - 0.6 * m - 0.04 * onda, 0, -0.08),
				joelhoE = A(-0.7 - 0.25 * m),
				tornozeloE = A(-0.5),
			}
		end,
	},
}

------------------------------------------------------------------------
-- Cavaleiro
------------------------------------------------------------------------

local cavaleiro
do
	-- Ângulos calculados para a espada e o escudo apontarem para onde devem (conferidos com
	-- ferramentas/ver_poses.py). Nos golpes 1 e 2 o quadril e o tronco torcem juntos (~135°)
	-- e a lâmina varre a frente toda; o golpe 3 é um giro completo.
	local GIRO = PI * 2
	local BRACO_GIRO = { ombroD = A(0.66, -2.97, -1.52), cotoveloD = A(0), pulsoD = A(-1.04, 1.4, -0.78) }

	-- Carga: espada erguida, deitada acima da cabeça, girando cada vez mais rápido
	local ERGUIDA = { ombroD = A(2.94, -1.66, -0.12), cotoveloD = A(0.11) }
	local GUARDA_D = { ombroD = A(0.49, -0.25, 0.37), cotoveloD = A(1.28) }
	local CORPO_CARGA = {
		raiz = A(0, -0.2, 0, 0, -0.35, 0),
		cintura = A(0.08, -0.15),
		pescoco = A(-0.25, 0.1),
		ombroE = A(-0.12, 2.23, 1.43),
		cotoveloE = A(1.73, -1.6, 0.35),
		quadrilD = A(-0.25, 0, 0.25),
		joelhoD = A(-0.5),
		quadrilE = A(0.45, 0, -0.25),
		joelhoE = A(-0.8),
		tornozeloE = A(0.3),
	}

	-- Redemoinho: braços abertos, espada para fora, girando
	local REDEMOINHO = {
		ombroD = A(-0.09, 0.08, 1.67),
		cotoveloD = A(0.11),
		pulsoD = A(-1.11, -1.07, -0.8),
		ombroE = A(0.56, 2.98, 1.46),
		cotoveloE = A(1.75, -1.15, -0.19),
		cintura = A(-0.05),
		quadrilD = A(0.3, 0, 0.2),
		joelhoD = A(-0.4),
		quadrilE = A(0.3, 0, -0.2),
		joelhoE = A(-0.4),
	}

	cavaleiro = {
		-- Corte da direita para a esquerda: torce o corpo para a direita com a espada atrás,
		-- avança o pé e desenrola quadril e tronco; a lâmina passa na frente em 0,13s
		ataque1 = {
			voltar = 0.44,
			trilha = { 0.06, 0.25 },
			quadros = {
				{
					t = 0.07,
					pose = {
						raiz = A(0.05, -0.5, 0, 0, -0.25, 0),
						cintura = A(0.05, -0.6),
						pescoco = A(0, 0.75),
						ombroD = A(1.87, 0.63, 1.91),
						cotoveloD = A(0.42),
						pulsoD = A(-1.26, 1.19, -0.9),
						ombroE = A(0.9, 0.4, -0.2),
						cotoveloE = A(1.3),
						quadrilD = A(-0.35, 0, 0.12),
						joelhoD = A(-0.55),
						tornozeloD = A(0.25),
						quadrilE = A(0.45, 0, -0.1),
						joelhoE = A(-0.4),
					},
				},
				{
					t = 0.13,
					suave = "forte",
					pose = {
						raiz = A(-0.1, 0.2, 0, 0, -0.35, -0.3),
						cintura = A(-0.15, 0.2),
						pescoco = A(0.05, -0.2),
						ombroD = A(0.71, 0.82, 1.56),
						cotoveloD = A(0.23),
						pulsoD = A(-0.94, -0.19, -0.87),
						ombroE = A(0.3, 0, -0.5),
						cotoveloE = A(1),
						quadrilD = A(-0.45, 0, 0.1),
						joelhoD = A(-0.35),
						tornozeloD = A(0),
						quadrilE = A(0.75, 0, -0.1),
						joelhoE = A(-0.8),
						tornozeloE = A(0.15),
					},
				},
				{
					t = 0.21,
					pose = {
						raiz = A(-0.1, 0.6, 0, 0, -0.33, -0.3),
						cintura = A(-0.12, 0.6),
						pescoco = A(0.05, -0.6),
						ombroD = A(0.04, 0.94, 1.46),
						cotoveloD = A(0.64),
						pulsoD = A(-0.52, -0.25, -0.9),
						ombroE = A(-0.1, 0, -0.6),
						cotoveloE = A(0.8),
					},
				},
			},
		},
		-- Revés: torce para a esquerda com a espada sobre o ombro esquerdo e corta de volta
		-- para a direita, com o passo do pé direito
		ataque2 = {
			voltar = 0.44,
			trilha = { 0.06, 0.25 },
			quadros = {
				{
					t = 0.07,
					pose = {
						raiz = A(0.05, 0.5, 0, 0, -0.25, 0),
						cintura = A(0.05, 0.55),
						pescoco = A(0, -0.8),
						ombroD = A(0.32, 1.27, 1.79),
						cotoveloD = A(1.54),
						pulsoD = A(-1.3, -1.04, -0.9),
						ombroE = A(-0.2, 0, -0.35),
						cotoveloE = A(0.8),
						quadrilD = A(0.5, 0, 0.1),
						joelhoD = A(-0.5),
						quadrilE = A(-0.3, 0, -0.1),
						joelhoE = A(-0.5),
						tornozeloE = A(0.2),
					},
				},
				{
					t = 0.13,
					suave = "forte",
					pose = {
						raiz = A(-0.1, -0.15, 0, 0, -0.35, -0.3),
						cintura = A(-0.15, -0.2),
						pescoco = A(0.05, 0.25),
						ombroD = A(0.55, 1.83, 1.66),
						cotoveloD = A(0),
						pulsoD = A(-1.01, -1.38, 0.41),
						ombroE = A(0.9, 0.4, -0.2),
						cotoveloE = A(1.3),
						quadrilD = A(0.75, 0, 0.12),
						joelhoD = A(-0.8),
						tornozeloD = A(0.12),
						quadrilE = A(-0.45, 0, -0.1),
						joelhoE = A(-0.35),
						tornozeloE = A(0),
					},
				},
				{
					t = 0.21,
					pose = {
						raiz = A(-0.1, -0.6, 0, 0, -0.33, -0.3),
						cintura = A(-0.12, -0.55),
						pescoco = A(0.05, 0.6),
						ombroD = A(1.17, 1.33, 1.46),
						cotoveloD = A(0),
						pulsoD = A(-0.53, -1.6, 0.9),
						ombroE = A(0.8, 0.5, -0.2),
					},
				},
			},
		},
		-- Golpe final: agacha torcendo para a direita e gira 360° com a espada esticada para
		-- fora; acerta tudo em volta (impacto em 0,24s, no meio do giro)
		ataque3 = {
			voltar = 0.66,
			trilha = { 0.09, 0.42 },
			quadros = {
				{
					t = 0.09,
					pose = {
						raiz = A(0, -0.9, 0, 0, -0.45, 0),
						cintura = A(-0.1, -0.5),
						pescoco = A(0, 0.9),
						ombroD = A(0.28, -2.2, -1.21),
						cotoveloD = A(0.31),
						pulsoD = A(-1.1, 0.76, 0.32),
						ombroE = A(0.7, 0.6, -0.2),
						cotoveloE = A(1.6),
						quadrilD = A(-0.1, 0, 0.3),
						joelhoD = A(-0.8),
						tornozeloD = A(0.3),
						quadrilE = A(0.6, 0, -0.25),
						joelhoE = A(-1),
						tornozeloE = A(0.4),
					},
				},
				{
					t = 0.15,
					suave = "forte",
					pose = juntar(BRACO_GIRO, {
						cintura = A(-0.15, 0.15),
						pescoco = A(0.05, -0.1),
						ombroE = A(0.6, 0.6, -0.2),
						quadrilD = A(0.2, 0, 0.3),
						joelhoD = A(-0.6),
						tornozeloD = A(0.2),
						quadrilE = A(0.2, 0, -0.3),
						joelhoE = A(-0.6),
						tornozeloE = A(0.2),
					}),
				},
				{ t = 0.33, suave = "linear", pose = { raiz = A(-0.1, GIRO - 0.2, 0, 0, -0.38, 0) } },
				{
					t = 0.42,
					pose = juntar(BRACO_GIRO, {
						raiz = A(-0.15, GIRO + 0.5, 0, 0, -0.45, -0.2),
						cintura = A(-0.3, 0.25),
						pescoco = A(0.15, -0.3),
					}),
				},
			},
		},
		-- Carregando: ergue a espada e gira ela deitada acima da cabeça, cada vez mais rápido
		-- (o vento do tornado vai se formando em volta)
		carregar = {
			manter = true,
			trilha = true,
			continuo = function(tau)
				local s = math.clamp(tau / 0.2, 0, 1)
				s = 1 - (1 - s) * (1 - s)
				local t = math.min(tau, 1.1)
				local giro = 9 * t + 7 * t * t + math.max(0, tau - 1.1) * 24.4
				local tremor = math.sin(tau * 40) * 0.02 * math.min(1, tau)
				local pose = table.clone(CORPO_CARGA)
				pose.ombroD = misturar(GUARDA_D.ombroD, ERGUIDA.ombroD, s)
				pose.cotoveloD = misturar(GUARDA_D.cotoveloD, ERGUIDA.cotoveloD, s)
				pose.pulsoD = A(0.33, 1.03 + giro, -0.37)
				pose.cintura = A(0.08 + tremor, -0.15)
				return pose
			end,
		},
		-- Solta: puxa a espada para trás da cabeça e corta para baixo à frente, lançando o tornado
		soltar = {
			voltar = 0.6,
			trilha = { 0, 0.3 },
			quadros = {
				{
					t = 0.06,
					pose = {
						raiz = A(0.1, -0.25, 0, 0, -0.15, 0),
						cintura = A(0.25, -0.2),
						pescoco = A(-0.2, 0.2),
						ombroD = A(0.41, 1.39, 3.17),
						cotoveloD = A(0),
						pulsoD = A(-0.59, -1.6, 0.9),
						ombroE = A(0.02, 2.43, 1.16),
						cotoveloE = A(1.83, -1.61, 0.36),
						quadrilD = A(-0.2, 0, 0.2),
						joelhoD = A(-0.4),
						quadrilE = A(0.4, 0, -0.2),
						joelhoE = A(-0.5),
						tornozeloE = A(0),
					},
				},
				{
					t = 0.14,
					suave = "forte",
					pose = {
						raiz = A(-0.2, 0.2, 0, 0, -0.55, -0.35),
						cintura = A(-0.55, 0.25),
						pescoco = A(0.35, -0.2),
						ombroD = A(0.41, 4.05, 4.42),
						cotoveloD = A(0),
						pulsoD = A(-1.28, -1.6, 0.9),
						ombroE = A(0.28, 1.8, 1.27),
						cotoveloE = A(2.42, -1.31, -0.35),
						quadrilD = A(0.9, 0, 0.1),
						joelhoD = A(-1),
						tornozeloD = A(0.15),
						quadrilE = A(-0.5, 0, -0.15),
						joelhoE = A(-0.5),
					},
				},
				{ t = 0.34, pose = { cintura = A(-0.48, 0.3), raiz = A(-0.15, 0.25, 0, 0, -0.5, -0.35) } },
			},
		},
		-- Redemoinho: gira sem parar enquanto durar, braços abertos
		habilidade = {
			trilha = true,
			continuo = function(tau)
				local pose = table.clone(REDEMOINHO)
				pose.raiz = A(-0.08, tau * 14, 0, 0, -0.25, 0)
				return pose
			end,
		},
		-- Julgamento: salta com a espada nas duas mãos e esmaga o chão
		supremo = {
			voltar = 0.8,
			trilha = { 0.2, 0.5 },
			quadros = {
				{
					t = 0.2,
					pose = {
						ombroD = A(1.94, 0.18, -0.24),
						pulsoD = A(-0.35),
						ombroE = A(2.3, -0.4),
						cotoveloD = A(0.38),
						cotoveloE = A(0.6),
						cintura = A(0.35),
						raiz = A(0.15, 0, 0, 0, 1, 0),
						quadrilD = A(0.6),
						joelhoD = A(-1),
						quadrilE = A(0.6),
						joelhoE = A(-1),
					},
				},
				{
					t = 0.36,
					suave = "forte",
					pose = {
						ombroD = A(0.31, 0.21, -1.3),
						ombroE = A(0.6, -0.2),
						cotoveloD = A(1.85),
						cotoveloE = A(0.3),
						pulsoD = A(-1.25),
						cintura = A(-0.6),
						raiz = A(-0.3, 0, 0, 0, -0.8, 0),
						quadrilD = A(1.1),
						joelhoD = A(-1.4),
						quadrilE = A(-0.3),
						joelhoE = A(-1),
					},
				},
				{ t = 0.6, pose = { cintura = A(-0.55) } },
			},
		},
		-- Defesa: o escudo sobe rápido para o centro do peito (passa um pouco do ponto e assenta),
		-- o ombro esquerdo vai à frente, o corpo se encolhe atrás dele e a espada fica pronta
		defender = {
			manter = true,
			quadros = {
				{
					t = 0.07,
					suave = "forte",
					pose = {
						raiz = A(0, -0.55, 0, 0, -0.36, 0),
						cintura = A(-0.12, -0.25),
						pescoco = A(0.1, 0.64),
						ombroD = A(-0.26, 0.67, 0.48),
						cotoveloD = A(1.56),
						pulsoD = A(-1.12, 0.61, 0.62),
						ombroE = A(-0.66, 1.99, 1.82),
						cotoveloE = A(1.77, -1.63, 0.39),
						pulsoE = A(0),
						quadrilD = A(-0.35, 0, 0.16),
						joelhoD = A(-0.5),
						tornozeloD = A(0.22),
						quadrilE = A(0.6, 0, -0.1),
						joelhoE = A(-0.85),
						tornozeloE = A(0.28),
					},
				},
				{ t = 0.16, pose = { ombroE = A(-0.8, 2.12, 1.38), cotoveloE = A(2.06, -1.62, 0.39) } },
			},
		},
	}
end

------------------------------------------------------------------------
-- Mago
------------------------------------------------------------------------

local mago = {
	-- Estocada com o cajado: puxa para trás, avança o corpo e aponta o cristal
	ataque1 = {
		voltar = 0.44,
		quadros = {
			{
				t = 0.08,
				pose = {
					ombroD = A(-0.1, -0.81, -0.3),
					cotoveloD = A(1.51),
					pulsoD = A(-1.5),
					ombroE = A(1.2, 0.6, -0.2),
					cotoveloE = A(0.6),
					pulsoE = A(-0.6),
					cintura = A(0.1, -0.45),
					raiz = A(0, -0.15, 0, 0, -0.05, 0),
					brilho = A(0.8),
				},
			},
			{
				t = 0.15,
				suave = "forte",
				pose = {
					ombroD = A(1.11, -0.53, -0.23),
					cotoveloD = A(0.05),
					pulsoD = A(-1.7),
					ombroE = A(0.5, 0.3, -0.5),
					cotoveloE = A(0.9),
					pulsoE = A(0),
					cintura = A(-0.15, 0.35),
					raiz = A(-0.08, 0.15, 0, 0, -0.1, 0),
					quadrilE = A(0.4),
					joelhoE = A(-0.35),
					quadrilD = A(-0.2),
					brilho = A(1.6),
				},
			},
			{ t = 0.25, pose = { ombroD = A(1, -0.45, -0.2), cotoveloD = A(0.3), cintura = A(0, 0.25), brilho = A(0.6) } },
		},
	},
	-- Empurrão com a mão livre: a magia sai da palma
	ataque2 = {
		voltar = 0.44,
		quadros = {
			{
				t = 0.08,
				pose = {
					ombroE = A(0.4, 0.6, -0.6),
					cotoveloE = A(2),
					pulsoE = A(0),
					ombroD = A(0.5, 0, 0.3),
					cotoveloD = A(0.9),
					cintura = A(0.1, 0.45),
					raiz = A(0, 0.15, 0, 0, -0.05, 0),
				},
			},
			{
				t = 0.15,
				suave = "forte",
				pose = {
					ombroE = A(1.6, -0.1),
					cotoveloE = A(0.05),
					pulsoE = A(0.6),
					ombroD = A(0.3, 0, 0.45),
					cintura = A(-0.15, -0.4),
					raiz = A(-0.08, -0.15, 0, 0, -0.1, 0),
					quadrilD = A(0.4),
					joelhoD = A(-0.35),
					quadrilE = A(-0.2),
				},
			},
			{ t = 0.25, pose = { ombroE = A(1.4, -0.05), cotoveloE = A(0.3), cintura = A(0, -0.25) } },
		},
	},
	-- Golpe final: ergue o cajado com as duas mãos e crava à frente
	ataque3 = {
		voltar = 0.58,
		quadros = {
			{
				t = 0.15,
				pose = {
					ombroD = A(1.78, 0.08, -0.3),
					cotoveloD = A(0),
					pulsoD = A(-1.7),
					ombroE = A(2.6, -0.2, -0.2),
					cotoveloE = A(0.8),
					cintura = A(0.35),
					pescoco = A(-0.3),
					raiz = A(0.08, 0, 0, 0, 0.2, 0),
					brilho = A(1.2),
				},
			},
			{
				t = 0.28,
				suave = "forte",
				pose = {
					ombroD = A(1.28, -0.11, -0.6),
					cotoveloD = A(0),
					pulsoD = A(-1.7),
					ombroE = A(1.3, -0.3),
					cotoveloE = A(0.3),
					cintura = A(-0.5),
					pescoco = A(0.2),
					raiz = A(-0.2, 0, 0, 0, -0.45, 0),
					quadrilD = A(0.8),
					joelhoD = A(-0.9),
					quadrilE = A(-0.4),
					joelhoE = A(-0.4),
					brilho = A(2.2),
				},
			},
			{ t = 0.42, pose = { cintura = A(-0.45), brilho = A(1) } },
		},
	},
	-- Carregando: cajado no alto, a outra mão aberta juntando energia, corpo para trás
	carregar = {
		manter = true,
		quadros = {
			{
				t = 0.2,
				pose = {
					ombroD = A(1.87, -0.05, -0.25),
					cotoveloD = A(0),
					pulsoD = A(-1.7),
					ombroE = A(1.2, 0.2, -0.9),
					cotoveloE = A(0.5),
					pulsoE = A(0.6),
					cintura = A(0.25),
					pescoco = A(-0.35),
					raiz = A(0.05, 0, 0, 0, -0.1, 0),
					quadrilD = A(-0.2, 0, 0.15),
					quadrilE = A(0.3, 0, -0.15),
					joelhoE = A(-0.3),
					brilho = A(1),
				},
			},
		},
	},
	-- Solta: empurra as duas mãos à frente com o corpo todo
	soltar = {
		voltar = 0.55,
		quadros = {
			{
				t = 0.06,
				suave = "forte",
				pose = {
					ombroD = A(1.42, -0.15, -0.6),
					cotoveloD = A(0),
					pulsoD = A(-1.7),
					ombroE = A(1.5, -0.2),
					cotoveloE = A(0),
					pulsoE = A(0.5),
					cintura = A(-0.45),
					pescoco = A(0.3),
					raiz = A(-0.15, 0, 0, 0, -0.35, 0),
					quadrilE = A(0.75),
					joelhoE = A(-0.7),
					quadrilD = A(-0.45),
					brilho = A(2.5),
				},
			},
			{ t = 0.3, pose = { cintura = A(-0.35), brilho = A(1) } },
		},
	},
	-- Meteoro: chama do céu com as duas mãos e puxa para baixo
	habilidade = {
		voltar = 0.62,
		quadros = {
			{
				t = 0.15,
				pose = {
					ombroD = A(1.77, -0.01, -0.17),
					ombroE = A(3, 0, -0.2),
					cotoveloD = A(0),
					cotoveloE = A(0.2),
					pulsoD = A(-1.7),
					cintura = A(0.35),
					pescoco = A(-0.5),
					raiz = A(0.05, 0, 0, 0, 0.1, 0),
					brilho = A(1.2),
				},
			},
			{
				t = 0.32,
				suave = "forte",
				pose = {
					ombroD = A(1, -0.14, -0.6),
					cotoveloD = A(0),
					pulsoD = A(-1.7),
					ombroE = A(1, -0.2),
					cotoveloE = A(0.3),
					cintura = A(-0.4),
					pescoco = A(0.1),
					raiz = A(-0.15, 0, 0, 0, -0.4, 0),
					quadrilD = A(0.7),
					joelhoD = A(-0.8),
					quadrilE = A(-0.3),
					brilho = A(2),
				},
			},
		},
	},
	-- Tempestade: flutua com os braços para o céu enquanto os raios caem
	supremo = {
		continuo = function(tau)
			local s = math.sin(tau * 6) * 0.08
			return {
				ombroD = A(2.9 + s, 0, 0.3),
				cotoveloD = A(0.2),
				pulsoD = A(0),
				ombroE = A(2.9 - s, 0, -0.3),
				cotoveloE = A(0.2),
				cintura = A(0.25),
				pescoco = A(-0.45),
				raiz = A(0.05, 0, 0, 0, 0.6 + math.sin(tau * 3) * 0.12, 0),
				quadrilD = A(0.2),
				joelhoD = A(-0.5),
				quadrilE = A(-0.1),
				joelhoE = A(-0.3),
				brilho = A(1.5),
			}
		end,
	},
}

------------------------------------------------------------------------
-- Arqueiro
------------------------------------------------------------------------

-- Mirando: corpo de lado, braço do arco esticado, mão puxando a corda até o rosto
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

-- Solta a flecha: a mão da corda voa para trás da orelha e o arco recua
local SOLTOU = {
	ombroD = A(1.3, 1.6, 0.4),
	cotoveloD = A(1),
	ombroE = A(1.75, 0.85),
	cintura = A(0.05, -0.85),
	puxar = A(0),
}

-- Ciclo de um tiro: leva a mão à aljava nas costas, pega a flecha, encaixa no arco,
-- puxa a corda até o rosto e solta. "flechaMao" mostra a flecha na mão direita.
-- "solta" é o momento do disparo (igual a Classes.arqueiro.ataque.impacto).
local function cicloDeTiro(solta: number, puxada: number, extra)
	extra = extra or {}
	local quadros = {
		-- mão sobe por cima do ombro até a aljava; o arco já sobe para a frente
		{
			t = solta * 0.27,
			pose = {
				ombroD = A(2.75, 0.2, 0.35),
				cotoveloD = A(2.1),
				pulsoD = A(0.3),
				pescoco = A(0, -0.35),
				cintura = A(0, -0.35),
				ombroE = A(1.2, 0.6),
				cotoveloE = A(0.3),
				flechaMao = A(0),
				puxar = A(0),
			},
		},
		{ t = solta * 0.36, pose = { flechaMao = A(1) } },
		-- traz a flecha e encaixa na corda, já de lado para o alvo
		{
			t = solta * 0.6,
			pose = {
				ombroD = A(1.4, 1.1),
				cotoveloD = A(1.3),
				pulsoD = A(0),
				pescoco = A(0, 0.75),
				cintura = A(0, -0.85),
				ombroE = A(1.57, 0.85),
				cotoveloE = A(0),
				pulsoE = A(0),
				puxar = A(0.15),
			},
		},
		{ t = solta * 0.62, pose = { flechaMao = A(0) } },
		-- puxa até o rosto
		{ t = solta * 0.93, pose = juntar(MIRA, { puxar = A(puxada), cintura = A(0.04, -0.9) }) },
		-- solta: a mão voa para trás e o arco recua
		{ t = solta, suave = "forte", pose = juntar(SOLTOU, extra.soltou or {}) },
		{ t = solta + 0.09, pose = { ombroD = A(1.15, 1.5, 0.3), ombroE = A(1.6, 0.85) } },
	}
	if extra.antes then
		for junta, valor in extra.antes do
			quadros[5].pose[junta] = valor
		end
	end
	return { voltar = solta + 0.24, quadros = quadros }
end

local arqueiro = {
	ataque1 = cicloDeTiro(0.26, 1),
	ataque2 = cicloDeTiro(0.26, 1),
	-- Tiro final: puxa até o limite agachando e recua com o disparo
	ataque3 = cicloDeTiro(0.34, 1.25, {
		antes = { raiz = A(0, 0, 0, 0, -0.25, 0), quadrilE = A(0.45), joelhoE = A(-0.7), quadrilD = A(-0.2) },
		soltou = { ombroD = A(1.1, 1.8, 0.6), raiz = A(0.1, 0, 0, 0, -0.15, 0.6), quadrilD = A(-0.4), joelhoD = A(-0.2) },
	}),
	-- Carregando: pega a flecha, encaixa e puxa até o limite, agachado
	carregar = {
		manter = true,
		quadros = {
			{ t = 0.07, pose = { ombroD = A(2.75, 0.2, 0.35), cotoveloD = A(2.1), pulsoD = A(0.3), pescoco = A(0, -0.35), ombroE = A(1.2, 0.6), flechaMao = A(0), puxar = A(0) } },
			{ t = 0.09, pose = { flechaMao = A(1) } },
			{ t = 0.17, pose = { ombroD = A(1.4, 1.1), cotoveloD = A(1.3), pescoco = A(0, 0.75), cintura = A(0, -0.85), ombroE = A(1.57, 0.85), cotoveloE = A(0), puxar = A(0.15) } },
			{ t = 0.18, pose = { flechaMao = A(0) } },
			{
				t = 0.4,
				pose = juntar(MIRA, {
					puxar = A(1.2),
					cintura = A(0.08, -0.95),
					raiz = A(0, 0, 0, 0, -0.3, 0),
					quadrilE = A(0.5),
					joelhoE = A(-0.9),
					tornozeloE = A(0.3),
					quadrilD = A(-0.25),
				}),
			},
		},
	},
	soltar = {
		voltar = 0.45,
		quadros = {
			{ t = 0.04, suave = "forte", pose = juntar(SOLTOU, { ombroD = A(1, 1.8, 0.6), ombroE = A(1.95, 0.85), raiz = A(0.15, 0, 0, 0, -0.2, 0.9), quadrilD = A(-0.45), joelhoD = A(-0.2) }) },
			{ t = 0.22, pose = { ombroD = A(0.9, 1.6, 0.5), raiz = A(0.08, 0, 0, 0, -0.1, 0.5) } },
		},
	},
	-- Chuva de Flechas: mira para o alto e atira
	habilidade = {
		voltar = 0.55,
		quadros = {
			{ t = 0.12, pose = { cintura = A(0.25, -0.85), pescoco = A(-0.5, 0.75), ombroE = A(2.35, 0.85), cotoveloE = A(0), ombroD = A(2.2, 1.1), cotoveloD = A(2.2), puxar = A(1.1) } },
			{ t = 0.18, suave = "forte", pose = { ombroD = A(2, 1.6, 0.4), cotoveloD = A(0.9), puxar = A(0) } },
			{ t = 0.3, pose = { ombroE = A(2.2, 0.85) } },
		},
	},
	-- Saraivada: gira atirando sem parar
	supremo = {
		continuo = function(tau)
			local pose = table.clone(MIRA)
			pose.raiz = A(0, tau * 10, 0, 0, -0.15, 0)
			pose.puxar = A((math.sin(tau * 21) + 1) / 2)
			return pose
		end,
	},
}

------------------------------------------------------------------------
-- Assassino
------------------------------------------------------------------------

local assassino = {
	-- Corte rápido com a adaga direita
	ataque1 = {
		voltar = 0.3,
		trilha = { 0.04, 0.18 },
		quadros = {
			{ t = 0.04, pose = { ombroD = A(0.9, -1.2, 0.5), cotoveloD = A(1.2), pulsoD = A(-0.6), cintura = A(-0.35, -0.5), raiz = A(0, -0.15, 0, 0, -0.3, 0) } },
			{
				t = 0.09,
				suave = "forte",
				pose = {
					ombroD = A(1.45, 1),
					cotoveloD = A(0.2),
					pulsoD = A(-0.9),
					cintura = A(-0.4, 0.5),
					raiz = A(-0.05, 0.2, 0, 0, -0.35, 0),
					quadrilD = A(0.5),
					joelhoD = A(-0.6),
				},
			},
			{ t = 0.16, pose = { ombroD = A(1, 1.4), cotoveloD = A(0.7) } },
		},
	},
	-- Corte rápido com a adaga esquerda
	ataque2 = {
		voltar = 0.3,
		trilha = { 0.04, 0.18 },
		quadros = {
			{ t = 0.04, pose = { ombroE = A(0.9, 1.2, -0.5), cotoveloE = A(1.2), pulsoE = A(-0.6), cintura = A(-0.35, 0.5), raiz = A(0, 0.15, 0, 0, -0.3, 0) } },
			{
				t = 0.09,
				suave = "forte",
				pose = {
					ombroE = A(1.45, -1),
					cotoveloE = A(0.2),
					pulsoE = A(-0.9),
					cintura = A(-0.4, -0.5),
					raiz = A(-0.05, -0.2, 0, 0, -0.35, 0),
					quadrilE = A(0.5),
					joelhoE = A(-0.6),
				},
			},
			{ t = 0.16, pose = { ombroE = A(1, -1.4), cotoveloE = A(0.7) } },
		},
	},
	-- Golpe final: salta e cruza as duas adagas para baixo
	ataque3 = {
		voltar = 0.46,
		trilha = { 0.1, 0.32 },
		quadros = {
			{ t = 0.1, pose = { ombroD = A(2.4, 0.35), ombroE = A(2.4, -0.35), cotoveloD = A(1.1), cotoveloE = A(1.1), cintura = A(0.2), raiz = A(0.05, 0, 0, 0, 0.35, 0) } },
			{
				t = 0.2,
				suave = "forte",
				pose = {
					ombroD = A(1.25, 0.55),
					ombroE = A(1.25, -0.55),
					cotoveloD = A(0.1),
					cotoveloE = A(0.1),
					cintura = A(-0.55),
					raiz = A(-0.2, 0, 0, 0, -0.5, 0),
					quadrilD = A(0.9),
					joelhoD = A(-1),
					quadrilE = A(-0.45),
					joelhoE = A(-0.5),
				},
			},
			{ t = 0.32, pose = { ombroD = A(1.1, 0.7), ombroE = A(1.1, -0.7) } },
		},
	},
	-- Carregando: encolhido como uma mola, adagas para trás
	carregar = {
		manter = true,
		quadros = {
			{
				t = 0.15,
				pose = {
					raiz = A(0, 0, 0, 0, -0.65, 0),
					cintura = A(-0.6),
					pescoco = A(0.5),
					ombroD = A(-0.45, 0, 0.55),
					ombroE = A(-0.45, 0, -0.55),
					cotoveloD = A(0.5),
					cotoveloE = A(0.5),
					quadrilD = A(0.95),
					joelhoD = A(-1.45),
					tornozeloD = A(0.5),
					quadrilE = A(-0.15),
					joelhoE = A(-1),
					tornozeloE = A(0.7),
				},
			},
		},
	},
	-- Investida Letal: dispara para frente com as duas adagas esticadas
	soltar = {
		voltar = 0.48,
		trilha = { 0, 0.3 },
		quadros = {
			{
				t = 0.04,
				suave = "forte",
				pose = {
					ombroD = A(1.6, -0.25),
					ombroE = A(1.6, 0.25),
					cotoveloD = A(0),
					cotoveloE = A(0),
					pulsoD = A(-1.4),
					pulsoE = A(-1.4),
					cintura = A(-0.55),
					pescoco = A(0.5),
					raiz = A(-0.3, 0, 0, 0, -0.55, 0),
					quadrilD = A(1.05),
					joelhoD = A(-0.7),
					quadrilE = A(-0.85),
					joelhoE = A(-0.25),
				},
			},
			{ t = 0.26, pose = { ombroD = A(1.2, 0.6), ombroE = A(1.2, -0.6), cotoveloD = A(0.5), cotoveloE = A(0.5) } },
		},
	},
	-- Passo Sombrio: agacha, some e reaparece cravando a adaga
	habilidade = {
		voltar = 0.42,
		trilha = { 0.1, 0.3 },
		quadros = {
			{ t = 0.05, pose = { raiz = A(0, 0, 0, 0, -0.7, 0), cintura = A(-0.6), ombroD = A(-0.4, 0, 0.5), ombroE = A(-0.4, 0, -0.5), quadrilD = A(1), joelhoD = A(-1.5), quadrilE = A(0.6), joelhoE = A(-1.3) } },
			{
				t = 0.16,
				suave = "forte",
				pose = {
					raiz = A(-0.1, 0, 0, 0, -0.3, 0),
					cintura = A(-0.45),
					ombroD = A(1.55, 0.3),
					cotoveloD = A(0.05),
					pulsoD = A(-1.3),
					ombroE = A(0.4, 0, -0.6),
					quadrilD = A(0.7),
					joelhoD = A(-0.8),
					quadrilE = A(-0.3),
					joelhoE = A(-0.4),
				},
			},
		},
	},
	-- Lâminas da Noite: cortes em X sem parar
	supremo = {
		trilha = true,
		continuo = function(tau)
			local f = math.sin(tau * 24)
			return {
				raiz = A(-0.1, f * 0.35, 0, 0, -0.35, 0),
				cintura = A(-0.45, f * 0.5),
				ombroD = A(1.35, f * 1.1, 0.2),
				cotoveloD = A(0.2),
				pulsoD = A(-1),
				ombroE = A(1.35, -f * 1.1, -0.2),
				cotoveloE = A(0.2),
				pulsoE = A(-1),
				quadrilD = A(0.7),
				joelhoD = A(-0.9),
				quadrilE = A(-0.3),
				joelhoE = A(-0.5),
			}
		end,
	},
}

Poses.ACOES = { cavaleiro = cavaleiro, mago = mago, arqueiro = arqueiro, assassino = assassino }

------------------------------------------------------------------------
-- Esquivas (uma por classe) e reação ao levar dano
------------------------------------------------------------------------

-- Rolamento calculado (e não feito por quadros): gira em volta do meio do corpo encolhido, e
-- não do quadril, assim a cabeça não entra no chão. "bracos" diz onde ficam os braços
-- encolhidos (cada classe segura a arma de um jeito). Fases, como num rolamento de verdade:
-- agacha e mergulha (antecipação), rola encolhido rente ao chão e levanta já em guarda.
local function rolamento(duracao: number, bracos)
	return function(tau)
		local s = math.clamp(tau / duracao, 0, 1)
		local function passo(a: number, b: number, x: number): number
			local k = math.clamp((x - a) / (b - a), 0, 1)
			return k * k * (3 - 2 * k)
		end
		local k = passo(0, 0.16, s) * (1 - passo(0.7, 1, s)) -- o quanto está encolhido
		local giro = -2 * PI * passo(0.07, 0.74, s)
		-- centro do corpo encolhido (acima do quadril) e quanto ele desce até encostar no chão
		local cy, cz = 0.55, -0.15
		local c, sn = math.cos(giro), math.sin(giro)
		local py = cy - (cy * c - cz * sn) - 1.15 * k
		local pz = cz - (cy * sn + cz * c)
		local function encolhido(rx: number, ry: number?, rz: number?)
			local v = A(rx, ry, rz)
			v[7] = k
			return v
		end
		local pose = {
			raiz = A(giro, 0, 0, 0, py, pz),
			cintura = encolhido(-0.85),
			pescoco = encolhido(-0.55),
			quadrilD = encolhido(1.7, 0, 0.12),
			joelhoD = encolhido(-2.1),
			tornozeloD = encolhido(0.4),
			quadrilE = encolhido(1.6, 0, -0.12),
			joelhoE = encolhido(-2.1),
			tornozeloE = encolhido(0.4),
		}
		for junta, v in bracos do
			pose[junta] = encolhido(v[1], v[2], v[3])
		end
		return pose
	end
end

Poses.ESQUIVAS = {
	-- Rolamento: mergulha encolhido, dá uma cambalhota inteira para a frente rente ao chão e
	-- levanta já em guarda; a espada vai deitada para o lado (no eixo do giro)
	cavaleiro = {
		duracao = 0.44,
		continuo = rolamento(0.44, {
			ombroD = { 1.31, 1.12, 1.32 },
			cotoveloD = { 0.7 },
			pulsoD = { 0.21, -1.6, 0.9 },
			ombroE = { 1.1, 0, -0.3 },
			cotoveloE = { 1.7 },
		}),
	},
	-- Deslize arcano: inclina para trás um instante juntando energia, dispara deitado no ar com
	-- o cajado apontado para trás e a mão livre à frente, e freia endireitando o corpo
	mago = {
		duracao = 0.34,
		quadros = {
			{
				t = 0.04,
				pose = {
					raiz = A(0.15, 0, 0, 0, 0.1, 0),
					cintura = A(0.2),
					pescoco = A(-0.15),
					ombroD = A(0.08, -0.14, 0.38),
					cotoveloD = A(1.42),
					pulsoD = A(-1.7, -0.35, -0.1),
					ombroE = A(0.4, 0.3, -0.6),
					cotoveloE = A(1.2),
					brilho = A(1.6),
				},
			},
			{
				t = 0.09,
				suave = "forte",
				pose = {
					raiz = A(-0.75, 0, 0, 0, -0.2, 0),
					cintura = A(-0.2),
					pescoco = A(0.55),
					-- cajado junto ao corpo, inclinado com ele (o cristal vai na frente, no alto)
					ombroD = A(0.1, -0.14, 0.45),
					cotoveloD = A(1.42),
					pulsoD = A(-1.7, -0.35, -0.1),
					-- mão livre à frente abrindo o caminho
					ombroE = A(1.5, 0.2, -0.2),
					cotoveloE = A(0.2),
					pulsoE = A(0.4),
					brilho = A(2),
				},
			},
			{ t = 0.22, suave = "linear", pose = { raiz = A(-0.7, 0, 0.05, 0, -0.15, 0), pescoco = A(0.5) } },
			{
				t = 0.3,
				pose = {
					raiz = A(0.12, 0, 0, 0, 0, 0.15),
					cintura = A(0.15),
					pescoco = A(-0.1),
					ombroD = A(0.08, -0.14, 0.38),
					cotoveloD = A(1.42),
					pulsoD = A(-1.7, -0.35, -0.1),
					ombroE = A(0.5, 0.2, -0.5),
					cotoveloE = A(0.8),
					brilho = A(0.8),
				},
			},
		},
	},
	-- Rolamento do Arqueiro: igual ao do Cavaleiro, mais rápido, com o arco apertado no peito
	arqueiro = {
		duracao = 0.38,
		continuo = rolamento(0.38, {
			ombroE = { 1.2, 0.3, -0.2 },
			cotoveloE = { 1.9 },
			pulsoE = { 0.3 },
			ombroD = { 1.1, -0.3, 0.25 },
			cotoveloD = { 1.8 },
		}),
	},
	-- Passo de sombra: dá o impulso agachando, dispara numa corrida baixa de ninja com os
	-- braços para trás e freia derrapando, com a mão esquerda quase no chão
	assassino = {
		duracao = 0.34,
		quadros = {
			{
				t = 0.035,
				pose = {
					raiz = A(-0.3, 0, 0, 0, -0.75, 0),
					cintura = A(-0.45),
					pescoco = A(0.5),
					ombroD = A(-0.4, 0, 0.4),
					ombroE = A(-0.4, 0, -0.4),
					cotoveloD = A(0.6),
					cotoveloE = A(0.6),
					quadrilD = A(1.2),
					joelhoD = A(-1.6),
					tornozeloD = A(0.5),
					quadrilE = A(0.2),
					joelhoE = A(-1.2),
					tornozeloE = A(0.6),
				},
			},
			{
				t = 0.08,
				suave = "forte",
				pose = {
					raiz = A(-0.65, 0, 0, 0, -0.55, 0),
					cintura = A(-0.3),
					pescoco = A(0.65),
					ombroD = A(-1.3, 0, 0.25),
					ombroE = A(-1.3, 0, -0.25),
					cotoveloD = A(0.1),
					cotoveloE = A(0.1),
					pulsoD = A(-1),
					pulsoE = A(-1),
					quadrilD = A(1.2),
					joelhoD = A(-1.5),
					tornozeloD = A(0.3),
					quadrilE = A(-0.6),
					joelhoE = A(-0.6),
					tornozeloE = A(0.2),
				},
			},
			{ t = 0.2, suave = "linear", pose = { raiz = A(-0.6, 0.08, 0, 0, -0.55, 0), quadrilD = A(-0.4), joelhoD = A(-0.8), quadrilE = A(1.1), joelhoE = A(-1.5) } },
			{
				t = 0.27,
				pose = {
					-- derrapa: corpo para trás, base larga, mão esquerda perto do chão
					raiz = A(0.05, 0.35, 0, 0, -0.8, 0.35),
					cintura = A(-0.35, -0.2),
					pescoco = A(0.35, 0.3),
					ombroE = A(1.1, 0, -0.5),
					cotoveloE = A(0.3),
					ombroD = A(0.5, 0, 0.6),
					cotoveloD = A(1.2),
					pulsoD = A(-0.3),
					pulsoE = A(-0.3),
					quadrilD = A(0.9, 0, 0.35),
					joelhoD = A(-1.4),
					quadrilE = A(-0.2, 0, -0.45),
					joelhoE = A(-0.5),
				},
			},
		},
	},
}

-- Levou dano: o tronco é jogado para trás e os braços abrem
Poses.ATINGIDO = {
	voltar = 0.3,
	quadros = {
		{
			t = 0.05,
			suave = "forte",
			pose = {
				cintura = A(0.35, 0.15),
				pescoco = A(0.3),
				raiz = A(0.1, 0, 0, 0, 0, 0.25),
				ombroD = A(0.1, 0, 0.5),
				ombroE = A(0.2, 0, -0.5),
			},
		},
	},
}

-- Escudo bloqueou um golpe: o escudo é empurrado para trás e inclina, o corpo escorrega
Poses.BLOQUEIO = {
	voltar = 0.3,
	quadros = {
		{
			t = 0.04,
			suave = "forte",
			pose = {
				ombroE = A(-0.54, 1.97, 1.51),
				cotoveloE = A(1.81, -1.63, 0.39),
				cintura = A(0.14, -0.15),
				pescoco = A(0, 0.6),
				raiz = A(0.05, -0.55, 0, 0, -0.36, 0.45),
			},
		},
	},
}

-- Defesa perfeita: empurrão com o escudo para a frente
Poses.BLOQUEIO_PERFEITO = {
	voltar = 0.42,
	quadros = {
		{
			t = 0.06,
			suave = "forte",
			pose = {
				ombroE = A(-0.74, 2.26, 1.47),
				cotoveloE = A(2.19, -1.59, 0.34),
				cintura = A(-0.3, -0.35),
				pescoco = A(0.25, 0.7),
				raiz = A(-0.12, -0.6, 0, 0, -0.4, -0.5),
			},
		},
		{ t = 0.16, pose = { raiz = A(-0.1, -0.58, 0, 0, -0.38, -0.45) } },
	},
}

------------------------------------------------------------------------
-- Interpolação
------------------------------------------------------------------------


-- Junta todas as juntas usadas e, se a animação tem "voltar", cria o quadro final que solta
-- todas elas (mesmos ângulos, peso 0: não desfaz giros)
local function preparar(definicao)
	if definicao.preparada then
		return
	end
	local lista, vistas, ultimo = {}, {}, {}
	for _, quadro in definicao.quadros do
		for junta, valor in quadro.pose do
			if not vistas[junta] then
				vistas[junta] = true
				table.insert(lista, junta)
			end
			ultimo[junta] = valor
		end
	end
	if definicao.voltar then
		local final = {}
		for junta, valor in ultimo do
			final[junta] = solto(valor)
		end
		table.insert(definicao.quadros, { t = definicao.voltar, pose = final })
		definicao.duracao = definicao.duracao or definicao.voltar + 0.02
	end
	definicao.juntas = lista
	definicao.preparada = true
end
Poses.preparar = preparar

--[[ Pose da animação no tempo "tau", partindo da pose "base" (onde o corpo estava).
	Juntas que estavam na base mas não são usadas aqui são soltas em 0,1s. ]]
function Poses.amostrar(definicao, tau: number, base)
	preparar(definicao)
	local quadros = definicao.quadros
	local indice = 0
	for k, quadro in quadros do
		if quadro.t <= tau then
			indice = k
		end
	end
	local pose = {}
	for _, junta in definicao.juntas do
		local inicio = base[junta] or SOLTO
		for k = indice, 1, -1 do
			local v = quadros[k].pose[junta]
			if v then
				inicio = v
				break
			end
		end
		-- próximo quadro que mexe nesta junta
		local proximo, t0 = nil, 0
		for k = indice + 1, #quadros do
			if quadros[k].pose[junta] then
				proximo = quadros[k]
				break
			end
		end
		if proximo then
			for k = indice, 1, -1 do
				if quadros[k].pose[junta] then
					t0 = quadros[k].t
					break
				end
			end
			local alfa = suavizar(proximo.suave, math.clamp((tau - t0) / math.max(proximo.t - t0, 0.001), 0, 1))
			pose[junta] = misturar(inicio, proximo.pose[junta], alfa)
		else
			pose[junta] = inicio
		end
	end
	for junta, valor in base do
		if pose[junta] == nil then
			pose[junta] = misturar(valor, solto(valor), math.clamp(tau / 0.1, 0, 1))
		end
	end
	return pose
end

return Poses
