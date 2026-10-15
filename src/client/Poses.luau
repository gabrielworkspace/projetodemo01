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

------------------------------------------------------------------------
-- Postura (sempre, da cintura para cima) e pose parada (corpo todo)
------------------------------------------------------------------------

Poses.POSTURAS = {
	cavaleiro = { ombroD = A(0.35, 0, 0.12), cotoveloD = A(0.6), ombroE = A(0.55, 0.35, -0.1), cotoveloE = A(1.1), pescoco = A(-0.05) },
	mago = { ombroD = A(0.25, 0, 0.1), cotoveloD = A(0.8), pulsoD = A(-1.05), ombroE = A(0.15, 0, -0.12), cintura = A(0.06) },
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
			raiz = A(0, 0.3, 0, 0, -0.22, 0),
			cintura = A(-0.04 + respirar, -0.22),
			pescoco = A(-0.05, -0.08),
			ombroE = A(0.95, 0.55, -0.1),
			cotoveloE = A(1.25),
			ombroD = A(0.4, 0, 0.3),
			cotoveloD = A(0.75),
			pulsoD = A(-0.45),
			quadrilD = A(0.32, 0, 0.14),
			joelhoD = A(-0.5),
			tornozeloD = A(0.18),
			quadrilE = A(-0.12, 0, -0.14),
			joelhoE = A(-0.32),
			tornozeloE = A(0.18),
		}
	end,
	-- Ereto e confiante: cajado apoiado, a outra mão conjura uma luz, flutua de leve
	mago = function(t: number)
		local flutuar = math.sin(t * 2) * 0.06
		return {
			raiz = A(0, 0, 0, 0, flutuar, 0),
			cintura = A(0.1 + math.sin(t * 1.4) * 0.02),
			pescoco = A(-0.14),
			ombroD = A(0.2, 0, 0.2),
			cotoveloD = A(0.9),
			pulsoD = A(-1.1),
			ombroE = A(0.75, 0.35, -0.25),
			cotoveloE = A(1.35),
			pulsoE = A(0.45 + math.sin(t * 2) * 0.1),
			quadrilD = A(0, 0, 0.04),
			quadrilE = A(0, 0, -0.04),
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
-- Cavaleiro
------------------------------------------------------------------------

local cavaleiro = {
	-- Corte da direita para a esquerda: espada atrás do ombro, passo à frente, corta na
	-- frente (impacto em 0,13s), acompanha para a esquerda e volta para a guarda
	ataque1 = {
		voltar = 0.42,
		trilha = { 0.08, 0.24 },
		quadros = {
			{
				t = 0.08,
				pose = {
					ombroD = A(0.45, -0.34, -1.18),
					cotoveloD = A(1.78),
					pulsoD = A(-0.34),
					ombroE = A(0.8, 0.6, -0.2),
					cotoveloE = A(1.1),
					cintura = A(0, -0.6),
					raiz = A(0, -0.2, 0, 0, -0.15, 0),
					quadrilD = A(-0.2),
					quadrilE = A(0.35),
					joelhoE = A(-0.4),
				},
			},
			{
				t = 0.13,
				suave = "forte",
				pose = {
					ombroD = A(0.75, -0.34, -0.57),
					cotoveloD = A(1.42),
					pulsoD = A(-1.61),
					ombroE = A(0.5, 0.3, -0.4),
					cintura = A(-0.1, 0.1),
					raiz = A(-0.05, 0.05, 0, 0, -0.22, 0),
					quadrilD = A(-0.3),
					joelhoD = A(-0.25),
					quadrilE = A(0.5),
					joelhoE = A(-0.55),
				},
			},
			{
				t = 0.21,
				pose = {
					ombroD = A(0.88, 0.19, -0.52),
					cotoveloD = A(1.23),
					pulsoD = A(-1.7),
					ombroE = A(0.3, 0.2, -0.5),
					cintura = A(-0.15, 0.6),
					raiz = A(-0.1, 0.25, 0, 0, -0.25, 0),
				},
			},
		},
	},
	-- Revés: espada cruza para a esquerda e corta de volta para a direita
	ataque2 = {
		voltar = 0.42,
		trilha = { 0.08, 0.24 },
		quadros = {
			{
				t = 0.08,
				pose = {
					ombroD = A(0.41, 1.6, 1.05),
					cotoveloD = A(1.33),
					pulsoD = A(-0.98),
					ombroE = A(0.4, 0.2, -0.4),
					cintura = A(0, 0.55),
					raiz = A(0, 0.15, 0, 0, -0.15, 0),
				},
			},
			{
				t = 0.13,
				suave = "forte",
				pose = {
					ombroD = A(1.22, 0.96, 0.61),
					cotoveloD = A(0.58),
					pulsoD = A(-1.33),
					ombroE = A(0.6, 0.4, -0.3),
					cintura = A(-0.1, -0.1),
					raiz = A(-0.05, -0.05, 0, 0, -0.22, 0),
					quadrilD = A(0.45),
					joelhoD = A(-0.5),
					quadrilE = A(-0.25),
					joelhoE = A(-0.2),
				},
			},
			{
				t = 0.21,
				pose = {
					ombroD = A(0.62, -0.06, 0.03),
					cotoveloD = A(1.62),
					pulsoD = A(-1.7),
					ombroE = A(0.8, 0.5, -0.2),
					cintura = A(-0.15, -0.6),
					raiz = A(-0.1, -0.25, 0, 0, -0.25, 0),
				},
			},
		},
	},
	-- Golpe final: espada por cima da cabeça, salta e esmaga à frente (impacto em 0,27s)
	ataque3 = {
		voltar = 0.6,
		trilha = { 0.16, 0.4 },
		quadros = {
			{
				t = 0.15,
				pose = {
					ombroD = A(2.25, -0.25, -0.45),
					cotoveloD = A(0.37),
					pulsoD = A(0.29),
					ombroE = A(1.6, 0.3, -0.2),
					cotoveloE = A(1),
					cintura = A(0.3),
					raiz = A(0.1, 0, 0, 0, 0.15, 0),
					quadrilD = A(0.3),
					joelhoD = A(-0.3),
					quadrilE = A(-0.1),
				},
			},
			{
				t = 0.27,
				suave = "forte",
				pose = {
					ombroD = A(1.11, -0.1, -0.5),
					cotoveloD = A(1.43),
					pulsoD = A(-1.7),
					ombroE = A(0.4, 0.3, -0.3),
					cotoveloE = A(0.9),
					cintura = A(-0.55),
					raiz = A(-0.2, 0, 0, 0, -0.55, 0),
					quadrilD = A(1),
					joelhoD = A(-1.1),
					tornozeloD = A(0.2),
					quadrilE = A(-0.45),
					joelhoE = A(-0.6),
				},
			},
			{ t = 0.42, pose = { cintura = A(-0.5), ombroD = A(1.05, -0.1, -0.45) } },
		},
	},
	-- Carregando: espada para trás e para baixo, corpo torcido, base larga
	carregar = {
		manter = true,
		quadros = {
			{
				t = 0.15,
				pose = {
					ombroD = A(-0.42, -1, -1.25),
					cotoveloD = A(1.5),
					pulsoD = A(-0.57),
					ombroE = A(1, 0.6, -0.2),
					cotoveloE = A(1.1),
					cintura = A(-0.1, -1),
					raiz = A(-0.1, -0.2, 0, 0, -0.4, 0),
					quadrilD = A(-0.4, 0, 0.25),
					joelhoD = A(-0.3),
					quadrilE = A(0.6, 0, -0.2),
					joelhoE = A(-0.8),
					tornozeloE = A(0.3),
				},
			},
		},
	},
	-- Solta: giro completo com a espada estendida
	soltar = {
		voltar = 0.52,
		trilha = { 0, 0.4 },
		quadros = {
			{ t = 0.05, suave = "forte", pose = { ombroD = A(0.08, -1.56, 0.79), cotoveloD = A(1.61), pulsoD = A(-1.23), ombroE = A(0.4, 0, -1.2), cintura = A(0, 0.5), raiz = A(-0.1, 0, 0, 0, -0.3, 0) } },
			{ t = 0.35, suave = "linear", pose = { raiz = A(-0.1, PI * 2, 0, 0, -0.3, 0), cintura = A(0, 0) } },
		},
	},
	-- Redemoinho: gira sem parar enquanto durar
	habilidade = {
		trilha = true,
		continuo = function(tau)
			return {
				raiz = A(-0.08, tau * 14, 0, 0, -0.25, 0),
				ombroD = A(0.35, 0, 1.45),
				cotoveloD = A(0),
				pulsoD = A(-1.2),
				ombroE = A(0.5, 0, -1),
				quadrilD = A(0.3, 0, 0.2),
				joelhoD = A(-0.4),
				quadrilE = A(0.3, 0, -0.2),
				joelhoE = A(-0.4),
			}
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
	-- Defesa: escudo erguido à frente, corpo encolhido atrás dele, espada pronta
	defender = {
		manter = true,
		quadros = {
			{
				t = 0.1,
				suave = "forte",
				pose = {
					ombroE = A(1.01, -1.57, -0.21),
					cotoveloE = A(1.52),
					pulsoE = A(0),
					ombroD = A(0.5, -0.3, 0.35),
					cotoveloD = A(1),
					pulsoD = A(-0.6),
					cintura = A(-0.15, 0.25),
					pescoco = A(0.1),
					raiz = A(0, -0.35, 0, 0, -0.3, 0),
					quadrilD = A(-0.25, 0, 0.15),
					joelhoD = A(-0.4),
					quadrilE = A(0.55, 0, -0.1),
					joelhoE = A(-0.75),
					tornozeloE = A(0.2),
				},
			},
		},
	},
}

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

Poses.ESQUIVAS = {
	-- Investida: ombro e escudo à frente, passada longa
	cavaleiro = {
		duracao = 0.34,
		quadros = {
			{
				t = 0.04,
				suave = "forte",
				pose = {
					raiz = A(-0.5, 0.35, 0, 0, -0.45, 0),
					cintura = A(-0.2, 0.25),
					pescoco = A(0.25, -0.4),
					ombroE = A(1.25, 0.6, -0.15),
					cotoveloE = A(1.3),
					ombroD = A(-0.55, 0, 0.3),
					cotoveloD = A(0.5),
					quadrilD = A(0.9),
					joelhoD = A(-1.1),
					quadrilE = A(-0.6),
					joelhoE = A(-0.5),
				},
			},
			{ t = 0.22, pose = { raiz = A(-0.3, 0.2, 0, 0, -0.3, 0), quadrilD = A(0.5), joelhoD = A(-0.7), quadrilE = A(-0.3), joelhoE = A(-0.3) } },
		},
	},
	-- Deslize arcano: corpo inclinado, braços abertos para trás, como se flutuasse
	mago = {
		duracao = 0.32,
		quadros = {
			{
				t = 0.05,
				suave = "forte",
				pose = {
					raiz = A(-0.55, 0, 0, 0, -0.35, 0),
					cintura = A(-0.25),
					pescoco = A(0.35),
					ombroD = A(-0.7, 0, 0.55),
					ombroE = A(-0.7, 0, -0.55),
					cotoveloD = A(0.2),
					cotoveloE = A(0.2),
					quadrilD = A(-0.35),
					joelhoD = A(-0.6),
					quadrilE = A(-0.5),
					joelhoE = A(-0.9),
					brilho = A(1),
				},
			},
		},
	},
	-- Rolamento: encolhe e dá uma cambalhota para frente
	arqueiro = {
		duracao = 0.36,
		quadros = {
			{
				t = 0.04,
				suave = "forte",
				pose = {
					raiz = A(-0.7, 0, 0, 0, -1.1, 0),
					cintura = A(-0.6),
					pescoco = A(-0.5),
					ombroD = A(0.9, 0, 0.2),
					cotoveloD = A(1.6),
					ombroE = A(0.9, 0, -0.2),
					cotoveloE = A(1.6),
					quadrilD = A(1.6),
					joelhoD = A(-2),
					quadrilE = A(1.6),
					joelhoE = A(-2),
				},
			},
			{ t = 0.24, suave = "linear", pose = { raiz = A(-0.7 - PI * 2, 0, 0, 0, -1.1, 0) } },
			{ t = 0.33, pose = { raiz = A(-PI * 2, 0, 0, 0, -0.3, 0), cintura = A(-0.15), pescoco = A(0), quadrilD = A(0.4), joelhoD = A(-0.6), quadrilE = A(-0.2), joelhoE = A(-0.3) } },
		},
	},
	-- Passo de sombra: corrida baixa de ninja, braços para trás
	assassino = {
		duracao = 0.3,
		quadros = {
			{
				t = 0.035,
				suave = "forte",
				pose = {
					raiz = A(-0.6, 0, 0, 0, -0.6, 0),
					cintura = A(-0.3),
					pescoco = A(0.6),
					ombroD = A(-1.25, 0, 0.25),
					ombroE = A(-1.25, 0, -0.25),
					cotoveloD = A(0.1),
					cotoveloE = A(0.1),
					quadrilD = A(1.15),
					joelhoD = A(-1.4),
					quadrilE = A(-0.55),
					joelhoE = A(-0.7),
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

-- Escudo bloqueou um golpe: o braço do escudo é empurrado e o corpo escorrega para trás
Poses.BLOQUEIO = {
	voltar = 0.3,
	quadros = {
		{ t = 0.04, suave = "forte", pose = { ombroE = A(1.1, 1.2, 0.2), cotoveloE = A(1), cintura = A(0.2, 0.35), raiz = A(0.05, 0, 0, 0, 0, 0.5) } },
	},
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
		(a[7] or 1) + ((b[7] or 1) - (a[7] or 1)) * alfa,
	}
end
Poses.misturar = misturar

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
