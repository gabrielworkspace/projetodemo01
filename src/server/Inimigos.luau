-- Inimigos: tipos, ataques, elites, chefes e inteligência.
-- No servidor o inimigo é só uma "caixa" invisível que anda (Humanoid). A aparência e as
-- animações são desenhadas no computador de cada jogador (Client/Modelos e Client/VisualInimigos).

local CollectionService = game:GetService("CollectionService")

local servidor = script.Parent
local Vfx = require(servidor.Vfx)
local Projeteis = require(servidor.Projeteis)
local Combate = require(servidor.Combate)
local Masmorra = require(servidor.Masmorra)
local Remotos = require(servidor.Remotos)

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

	-- Suporte (aparecem em todos os temas, a partir da 2ª sala) -------------
	-- Ficam atrás dos aliados e fortalecem o grupo: mate-os primeiro!
	acolito = {
		nome = "Acólito Necromante", raiz = V(2, 2, 1), quadril = 2, raio = 1.3, alturaBarra = 4.4,
		vida = 46, dano = 9, velocidade = 13, ouro = 8, comportamento = "suporte", distancia = 24, salaMinima = 2,
		ataques = {
			-- canaliza um feixe e cura o aliado mais ferido (22% da vida dele)
			{ tipo = "curar", alcance = 999, preparo = 0.9, recarga = 4.5, inicial = 2, raio = 34, cura = 0.22 },
			{ tipo = "disparo", alcance = 36, preparo = 0.8, recarga = 3.2, projetil = "veneno", velocidade = 40 },
		},
	},
	guardiao = {
		nome = "Guardião Rúnico", raiz = V(3, 3.4, 2), quadril = 2.2, raio = 1.9, alturaBarra = 6.2,
		vida = 110, dano = 15, velocidade = 11, ouro = 12, armadura = 0.2, comportamento = "suporte", distancia = 14, salaMinima = 2,
		ataques = {
			-- ergue escudos de runas em até 4 aliados (absorvem 35% da vida deles por 7s)
			{ tipo = "escudo", alcance = 999, preparo = 0.8, recarga = 9, inicial = 3, raio = 28, escudo = 0.35, duracao = 7, maximo = 4 },
			{ tipo = "golpe", alcance = 7, arco = 120, preparo = 0.7, recarga = 1.8, mult = 1.1 },
		},
	},
	portaEstandarte = {
		nome = "Porta-Estandarte", raiz = V(2, 1.8, 1.2), quadril = 1.4, raio = 1.4, alturaBarra = 5.2,
		vida = 58, dano = 11, velocidade = 15, ouro = 9, comportamento = "suporte", distancia = 18, salaMinima = 2,
		ataques = {
			-- grito de guerra: aliados por perto ficam 35% mais rápidos e atacam mais vezes por 6s
			{ tipo = "grito", alcance = 999, preparo = 0.7, recarga = 10, inicial = 2.5, raio = 30, duracao = 6 },
			{ tipo = "golpe", alcance = 6, arco = 100, preparo = 0.5, recarga = 1.4 },
		},
	},

	-- Ceifador Esmeralda: lacaio que o Skullbane chama do chão (não aparece sozinho nas salas)
	ceifadorEsmeralda = {
		nome = "Ceifador Esmeralda", raiz = V(2.6, 3.4, 2), quadril = 2.3, raio = 1.8, alturaBarra = 5.6,
		vida = 130, dano = 15, velocidade = 15, ouro = 14, armadura = 0.1,
		entrada = 1.6, -- saindo do chão: não ataca nem leva dano
		aleatorio = true,
		ataques = {
			{ nome = "corte", tipo = "golpe", alcance = 8, arco = 80, preparo = 0.75, atrasoVariavel = { 0.85, 1.4 }, recarga = 3.2, mult = 1.3, peso = 2 },
			{ nome = "varrida", tipo = "golpe", anim = "Varrida", alcance = 8, arco = 150, preparo = 0.6, recarga = 2.4, mult = 1, peso = 3, seguir = { { "corte", 0.3 } } },
			{ nome = "investida", tipo = "investida", alcance = 22, minimo = 9, preparo = 0.6, recarga = 6, inicial = 3, distancia = 16, largura = 4, mult = 1.1, peso = 2 },
		},
	},

	-- Chefes ---------------------------------------------------------------
	--[[ Skullbane (primeiro chefe): senhor da guerra morto-vivo com a lâmina presa no braço.
		A luta é feita de golpes pesados e bem avisados: a Fissura de Almas corre pelo chão até o
		alvo, o Corte Devastador deixa a lâmina presa no chão (janela para bater com +35% de
		dano), o giro acerta três vezes em volta e a investida atravessa a sala. Na 2ª fase as
		almas acordam: três fissuras em leque, anéis verdes, espiral de almas e chuva de almas. ]]
	skullbane = {
		nome = "Skullbane", titulo = "O Senhor da Guerra Caído", chefe = true, pesado = true,
		raiz = V(5, 6, 4), quadril = 5, raio = 4, alturaBarra = 11,
		vida = 1600, dano = 24, velocidade = 12, ouro = 180, armadura = 0.1,
		entrada = 5.4, -- desperta (sobe do chão, ruge, câmera) antes de lutar; imune nesse tempo
		posturaMax = 100, -- parry tira 35, esquiva perfeita 12, golpes ~6% do dano (Combate.ferirPostura)
		grogue = 4, -- segundos ajoelhado quando a postura quebra
		pausa = { 0.5, 1.3 }, -- entre um ataque e outro ele anda e rodeia o alvo
		-- inspirado nos chefes de Elden Ring: escolhe os golpes ao acaso (nunca o mesmo padrão),
		-- encadeia combos de surpresa, segura alguns golpes por um tempo diferente a cada vez
		-- (para errar o tempo da esquiva), pune quem fica perto e puxa quem foge para longe.
		-- peso = chance de escolher; pesoPerto (alvo a até 10 studs) e pesoLonge (a 22 ou mais)
		-- trocam o peso conforme a distância; seguir = { {golpe, chance} } logo depois deste.
		aleatorio = true,
		ataques = {
			-- Corte Descendente: ergue a lâmina acima da cabeça e desce com tudo; às vezes a
			-- lâmina fica presa no chão (janela para bater com +35% de dano)
			{ nome = "descendente", tipo = "golpe", alcance = 15, arco = 70, preparo = 1, atrasoVariavel = { 0.8, 1.7 }, recarga = 5, inicial = 3, mult = 1.6, preso = 1.4, presoChance = 0.5, peso = 3, pesoPerto = 2.5, seguir = { { "varrida", 0.35 } } },
			-- Varrida: a lâmina varre de lado na altura da cintura; pode voltar pelo outro lado
			{ nome = "varrida", tipo = "golpe", anim = "Varrida", alcance = 13, arco = 170, preparo = 0.7, recarga = 3.5, inicial = 2, mult = 1, peso = 3, pesoPerto = 3, seguir = { { "varridaVolta", 0.55 }, { "descendente", 0.25 } } },
			{ nome = "varridaVolta", tipo = "golpe", anim = "Varrida", volta = true, alcance = 13, arco = 170, preparo = 0.45, recarga = 0, mult = 1.1, peso = 0, seguir = { { "estocada", 0.3 } } },
			-- Estocada: recua a lâmina e avança furando em linha (longe)
			{ nome = "estocada", tipo = "golpe", anim = "Estocada", alcance = 21, minimo = 5, arco = 35, preparo = 0.65, atrasoVariavel = { 0.9, 1.6 }, recarga = 6, inicial = 5, mult = 1.4, peso = 2, pesoLonge = 1.5 },
			-- Giro: três voltas com a lâmina esticada
			{ nome = "giro", tipo = "golpe", alcance = 12, arco = 360, preparo = 1, acertos = 3, entreAcertos = 0.4, recarga = 9, inicial = 8, mult = 0.8, peso = 1.2, pesoPerto = 3 },
			-- Explosão de Almas: crava a lâmina no chão e as almas explodem em volta (quem
			-- fica colado nele é punido)
			{ nome = "explosao", tipo = "golpe", anim = "Nova", alcance = 11, arco = 360, preparo = 0.55, recarga = 7, inicial = 6, mult = 1.1, peso = 0.2, pesoPerto = 4 },
			-- Salto Esmagador: cai rachando o chão e o tremor se espalha em dois anéis
			{ nome = "salto", tipo = "salto", alcance = 48, minimo = 13, preparo = 0.75, voo = 0.95, recarga = 10, inicial = 9, raio = 11, mult = 1.5, tremor = true, peso = 2, pesoLonge = 3, seguir = { { "varrida", 0.4 } } },
			-- Puxão das Almas: abre a mão e puxa todo mundo de longe para perto dele
			{ nome = "puxao", tipo = "puxar", alcance = 60, minimo = 16, preparo = 1.1, duracao = 1.2, raio = 48, forca = 34, recarga = 14, inicial = 12, peso = 1.5, pesoLonge = 4, seguir = { { "giro", 0.55 }, { "explosao", 0.45 } } },
			-- Lâminas de Alma: varre o ar e três cortes de alma voam até o alvo
			{ nome = "laminas", tipo = "disparo", anim = "Varrida", projetil = "alma", alcance = 50, minimo = 14, preparo = 0.8, recarga = 7, inicial = 6, quantidade = 3, espalhamento = 16, velocidade = 48, mult = 0.9, peso = 1.5, pesoLonge = 2.5 },
			{ nome = "fissura", tipo = "fissura", alcance = 48, minimo = 10, preparo = 1, recarga = 8, inicial = 4, comprimento = 44, largura = 5, passos = 10, entre = 0.07, mult = 1.2, peso = 1.5, pesoLonge = 2.5 },
			{ nome = "investida", tipo = "investida", alcance = 34, minimo = 12, preparo = 0.95, recarga = 12, inicial = 15, distancia = 32, largura = 7, mult = 1.3, peso = 1, pesoLonge = 2, seguir = { { "descendente", 0.5 } } },
			-- chama Ceifadores Esmeralda do chão (a tela treme)
			{ nome = "invocar", tipo = "invocar", recarga = 20, inicial = 10, preparo = 1.5, invocado = "ceifadorEsmeralda", quantidade = 2, maxVivos = 8, peso = 0.8, pesoLonge = 1.2 },
		},
		fase2 = {
			anuncio = "Skullbane desperta as almas do calabouço! A lâmina arde em verde!",
			cor = Color3.fromRGB(90, 255, 120),
			velocidade = 1.25,
			recarga = 0.72,
			combos = 1.4, -- encadeia mais golpes na 2ª fase
			ataques = {
				{ nome = "guardiao", tipo = "invocar", recarga = 26, inicial = 2, preparo = 1, invocado = "guardiao", quantidade = 1, maxVivos = 12, peso = 0.8 },
				{ nome = "exercito", tipo = "invocar", recarga = 24, inicial = 8, preparo = 1.5, invocado = "ceifadorEsmeralda", quantidade = 3, maxVivos = 10, peso = 1 },
				{ nome = "fissuraTripla", tipo = "fissura", alcance = 50, minimo = 6, preparo = 0.9, recarga = 9, inicial = 4, comprimento = 46, largura = 5, passos = 11, entre = 0.06, quantidade = 3, abertura = 32, mult = 1.1, peso = 2, pesoLonge = 3 },
				{ nome = "aneis", tipo = "anel", recarga = 12, inicial = 7, preparo = 0.8, aneis = 3, largura = 4, entre = 0.7, mult = 1.2, efeito = "alma", peso = 1.5, pesoPerto = 2.5 },
				{ nome = "espiral", tipo = "espiral", recarga = 13, inicial = 10, preparo = 0.9, projetil = "alma", quantidade = 12, ondas = 5, intervalo = 0.3, giro = 0.22, velocidade = 30, mult = 0.7, peso = 1.2 },
				{ nome = "chuva", tipo = "area", recarga = 11, inicial = 14, preparo = 0.8, quantidade = 6, raio = 6, atraso = 1.3, mult = 1.2, visual = "alma", peso = 1.2, pesoLonge = 2.5 },
				{ nome = "puxaoForte", tipo = "puxar", alcance = 70, minimo = 12, preparo = 0.9, duracao = 1.4, raio = 60, forca = 42, recarga = 12, inicial = 6, peso = 1.5, pesoLonge = 4, seguir = { { "aneis", 0.5 }, { "giro", 0.5 } } },
			},
		},
	},
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
			anuncio = "O Rei Esqueleto se enfurece! Ossos voam pela sala!",
			cor = Color3.fromRGB(255, 70, 50),
			velocidade = 1.3,
			recarga = 0.7,
			ataques = {
				{ tipo = "invocar", recarga = 30, inicial = 1, preparo = 1, invocado = "guardiao", quantidade = 1, maxVivos = 14 },
				{ tipo = "espiral", recarga = 11, inicial = 3, preparo = 0.9, projetil = "flechaOssea", quantidade = 12, ondas = 5, intervalo = 0.32, giro = 0.22, velocidade = 32, mult = 0.7 },
				{ tipo = "anel", recarga = 13, inicial = 8, preparo = 0.8, aneis = 3, largura = 4, entre = 0.75, mult = 1.2 },
				{ tipo = "invocar", recarga = 14, inicial = 5, preparo = 1, invocado = "esqueletoArqueiro", quantidade = 2, maxVivos = 12 },
			},
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
		fase2 = {
			anuncio = "A Rainha Aranha protege sua ninhada! A caverna se enche de teias!",
			cor = Color3.fromRGB(150, 255, 90),
			velocidade = 1.25,
			recarga = 0.75,
			ataques = {
				{ tipo = "espiral", recarga = 10, inicial = 3, preparo = 0.8, projetil = "veneno", quantidade = 10, ondas = 4, intervalo = 0.4, giro = -0.3, velocidade = 34, mult = 0.7 },
				{ tipo = "area", recarga = 8, inicial = 6, preparo = 0.6, quantidade = 7, raio = 7, atraso = 1.2, mult = 1, visual = "teia", efeito = "lento" },
				{ tipo = "invocar", recarga = 16, inicial = 9, preparo = 0.9, invocado = "acolito", quantidade = 1, maxVivos = 12 },
			},
		},
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
			anuncio = "O Lich invoca o inverno eterno! Seus acólitos o protegem!",
			cor = Color3.fromRGB(120, 200, 255),
			recarga = 0.7,
			ataques = {
				{ tipo = "invocar", recarga = 20, inicial = 1, preparo = 1, invocado = "acolito", quantidade = 2, maxVivos = 12 },
				{ tipo = "anel", recarga = 11, inicial = 4, preparo = 0.9, aneis = 4, largura = 3.5, entre = 0.6, mult = 1.1, efeito = "lento" },
				{ tipo = "espiral", recarga = 12, inicial = 8, preparo = 0.9, projetil = "gelo", quantidade = 14, ondas = 4, intervalo = 0.35, giro = 0.2, velocidade = 30, mult = 0.7, efeito = "lento" },
				{ tipo = "golpe", alcance = 14, arco = 360, preparo = 1.2, recarga = 10, inicial = 12, mult = 1.6, efeito = "lento" },
			},
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
			anuncio = "O Senhor das Chamas desperta a fornalha! O chão vira lava!",
			cor = Color3.fromRGB(255, 110, 30),
			velocidade = 1.2,
			recarga = 0.7,
			ataques = {
				{ tipo = "anel", recarga = 10, inicial = 3, preparo = 0.9, aneis = 4, largura = 4.5, entre = 0.65, mult = 1.3, efeito = "queimar" },
				{ tipo = "espiral", recarga = 12, inicial = 7, preparo = 1, projetil = "fogo", quantidade = 12, ondas = 6, intervalo = 0.3, giro = 0.25, velocidade = 32, mult = 0.7 },
				{ tipo = "area", recarga = 9, inicial = 11, preparo = 0.8, quantidade = 8, raio = 7, atraso = 1.3, mult = 1.3, visual = "meteoro", efeito = "queimar" },
				{ tipo = "invocar", recarga = 24, inicial = 14, preparo = 1, invocado = "portaEstandarte", quantidade = 1, maxVivos = 10 },
			},
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
	-- chefes que rodeiam o alvo viram pelo nosso código (sempre encarando quem perseguem)
	if def.pausa then
		humanoid.AutoRotate = false
	end
	-- entrada de chefe: sobe do chão e ruge, sem atacar nem levar dano
	if def.entrada then
		inimigo.ocupadoAte = agora + def.entrada
		inimigo.invulneravelAte = agora + def.entrada
	end
	for _, ataque in ataques do
		inimigo.prontoEm[ataque] = agora + (def.entrada or 0) + (ataque.inicial or math.random() * (ataque.recarga or 1) * 0.5)
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
	if efeito == "alma" then
		return Color3.fromRGB(90, 255, 120)
	elseif efeito == "queimar" then
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
	if ataque.atrasoVariavel then
		-- segura o golpe por um tempo diferente a cada vez (não dá para decorar o ritmo)
		local faixa = ataque.atrasoVariavel
		preparo *= faixa[1] + math.random() * (faixa[2] - faixa[1])
	end
	-- "anim" troca o nome da ação (prepararVarrida, golpeVarrida...) para o visual do chefe
	local nomePreparo = if ataque.anim then "preparar" .. ataque.anim elseif arco >= 360 then "prepararGiro" else "preparar"
	local nomeGolpe = if ataque.anim then "golpe" .. ataque.anim elseif arco >= 360 then "giro" else "golpe"
	local acertos = ataque.acertos or 1
	local entre = ataque.entreAcertos or 0.3
	local direcao = unidade(alvoPos - inimigo.raiz.Position, inimigo.raiz.CFrame.LookVector)
	local giro = arco >= 360

	parar(inimigo)
	olharPara(inimigo, alvoPos)
	definirAcao(inimigo, nomePreparo)
	inimigo.ocupadoAte = agora + preparo + (acertos - 1) * entre + 0.4
	Vfx.partida(run, "telegrafo", {
		dono = inimigo.modelo,
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
			definirAcao(inimigo, nomeGolpe)
			local centro = inimigo.raiz.Position
			Vfx.partida(run, "golpeInimigo", { pos = centro, dir = direcao, alcance = alcance, arco = arco, cor = corDoEfeito(ataque.efeito), tipo = inimigo.tipo, anim = ataque.anim, volta = ataque.volta or i % 2 == 0 })
			acertarJogadores(run, inimigo, centro, direcao, alcance, arco, ataque.mult or 1, ataque.efeito)
			if i < acertos then
				task.wait(entre)
			end
		end
		if ataque.preso and inimigo.vivo and math.random() < (ataque.presoChance or 1) then
			-- a lâmina fica presa no chão: ele demora para soltar e leva mais dano nesse tempo
			local fim = os.clock() + ataque.preso
			inimigo.ocupadoAte = math.max(inimigo.ocupadoAte, fim)
			inimigo.vulneravelAte = fim
			definirAcao(inimigo, "preso")
			Vfx.partida(run, "dano", {
				pos = inimigo.raiz.Position + Vector3.new(0, inimigo.alturaBarra * 0.7, 0),
				valor = "VULNERÁVEL!",
				cor = Color3.fromRGB(255, 225, 90),
			})
			task.delay(ataque.preso, function()
				if inimigo.vivo then
					definirAcao(inimigo, "")
				end
			end)
			return
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
	definirAcao(inimigo, if ataque.anim then "preparar" .. ataque.anim else "conjurar")
	inimigo.ocupadoAte = agora + preparo + 0.35
	task.delay(preparo, function()
		if not podeContinuar(run, inimigo) then
			return
		end
		local raizAlvo = Combate.raizDe(alvo)
		local origem = inimigo.raiz.Position + Vector3.new(0, 0.8, 0)
		local destino = if raizAlvo and alvo.vivo then raizAlvo.Position else origem + inimigo.raiz.CFrame.LookVector * 10
		olharPara(inimigo, destino)
		definirAcao(inimigo, if ataque.anim then "golpe" .. ataque.anim else "disparo")
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
				aoAcertar = function(estado, _, projetil)
					-- o golpe vem de onde o projétil estava (para o escudo saber se foi de frente)
					local opcoes = opcoesDoEfeito(inimigo, ataque.efeito)
					opcoes.origem = projetil.pos - projetil.dir * 4
					Combate.danoAoJogador(run, estado, inimigo.dano * (ataque.mult or 1), inimigo, opcoes)
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
	Vfx.partida(run, "telegrafo", { forma = "circulo", pos = noChao(run, inimigo.raiz.Position), raio = inimigo.raio + 3, duracao = preparo, chefe = true, dono = inimigo.modelo })
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
				aoAcertar = function(estado, _, projetil)
					-- o golpe vem de onde o projétil estava (para o escudo saber se foi de frente)
					local opcoes = opcoesDoEfeito(inimigo, ataque.efeito)
					opcoes.origem = projetil.pos - projetil.dir * 4
					Combate.danoAoJogador(run, estado, inimigo.dano * (ataque.mult or 1), inimigo, opcoes)
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
		dono = inimigo.modelo,
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
	Vfx.partida(run, "telegrafo", { forma = "circulo", pos = destino, raio = raio, duracao = preparo + voo, chefe = inimigo.chefe, dono = inimigo.modelo })

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
			Vfx.partida(run, "impacto", { pos = destino, raio = raio, cor = corDoEfeito(ataque.efeito), forte = inimigo.chefe, tipo = inimigo.tipo, quebrar = ataque.tremor })
			acertarJogadores(run, inimigo, destino, nil, raio, 360, ataque.mult or 1, ataque.efeito)
			definirAcao(inimigo, "")
			if ataque.tremor then
				-- o chão continua rachando: dois anéis de tremor saem do ponto da queda
				for i, extra in { 7, 15 } do
					local anel = raio + extra
					local atraso = 0.25 + 0.3 * i
					Vfx.partida(run, "anelPerigo", { pos = destino, raio = anel, largura = 2.5, duracao = atraso, cor = corDoEfeito("alma"), tipo = inimigo.tipo })
					task.delay(atraso, function()
						if not run.ativa then
							return
						end
						Vfx.partida(run, "anelExplode", { pos = destino, raio = anel, largura = 2.5, cor = corDoEfeito("alma"), tipo = inimigo.tipo })
						for _, info in jogadoresAtingiveis(run) do
							if math.abs(planar(info.raiz.Position - destino).Magnitude - anel) <= 2.5 then
								Combate.danoAoJogador(run, info.estado, inimigo.dano * 0.6, inimigo, { origem = destino })
							end
						end
					end)
				end
			end
		end)
	end)
	return true
end

local function ataqueExplodir(run, inimigo, ataque, agora: number): boolean
	local raio = ataque.raio * inimigo.escala
	parar(inimigo)
	definirAcao(inimigo, "prepararExplosao")
	inimigo.ocupadoAte = agora + 99
	Vfx.partida(run, "telegrafo", { forma = "circulo", pos = noChao(run, inimigo.raiz.Position), raio = raio, duracao = ataque.preparo, dono = inimigo.modelo })
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
	if inimigo.chefe then
		-- o chefe ergue a arma e chama: a tela treme e a terra começa a rachar
		Vfx.partida(run, "chamado", { modelo = inimigo.modelo, pos = noChao(run, inimigo.raiz.Position), duracao = ataque.preparo, tipo = inimigo.tipo })
	end
	task.delay(ataque.preparo, function()
		if not podeContinuar(run, inimigo) or not run.sala then
			return
		end
		for i = 1, ataque.quantidade or 2 do
			local angulo = i * (math.pi * 2 / (ataque.quantidade or 2)) + math.random()
			local pos = noChao(run, inimigo.raiz.Position + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * (inimigo.raio + 5))
			pos = limitarNaSala(run, pos, 2)
			if Masmorra.posicaoValida(run.sala, pos, 1.5) then
				if inimigo.chefe then
					-- o chão racha onde cada servo do chefe sobe
					Vfx.partida(run, "invocacao", { pos = pos, tipo = inimigo.tipo })
				end
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
			Vfx.partida(run, "telegrafo", { forma = "circulo", pos = ponto, raio = raio, duracao = atraso, chefe = true, dono = inimigo.modelo })
			if ataque.visual == "meteoro" then
				Vfx.partida(run, "meteoro", { pos = ponto, duracao = atraso, raio = raio })
			elseif ataque.visual == "alma" then
				Vfx.partida(run, "portalAlma", { pos = ponto, duracao = atraso, raio = raio })
			end
			task.delay(atraso, function()
				if not run.ativa then
					return
				end
				Vfx.partida(run, "impactoArea", { pos = ponto, raio = raio, visual = ataque.visual })
				for _, info in jogadoresAtingiveis(run) do
					if planar(info.raiz.Position - ponto).Magnitude <= raio + 1 then
						local opcoes = opcoesDoEfeito(inimigo, ataque.efeito)
						opcoes.origem = ponto
						Combate.danoAoJogador(run, info.estado, inimigo.dano * (ataque.mult or 1), nil, opcoes)
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

-- Puxão das Almas: estende a mão, um redemoinho se forma e todos que estão longe (dentro do
-- raio) são puxados para perto dele por um tempo. Andar para trás resiste um pouco; a esquiva
-- escapa. O movimento do personagem é feito no computador do jogador ("puxar").
local function ataquePuxar(run, inimigo, ataque, agora: number): boolean
	local preparo = ataque.preparo * inimigo.recargaMult
	local raio = ataque.raio
	parar(inimigo)
	definirAcao(inimigo, "prepararPuxao")
	inimigo.ocupadoAte = agora + preparo + ataque.duracao + 0.2
	local centro = noChao(run, inimigo.raiz.Position)
	Vfx.partida(run, "telegrafo", { forma = "circulo", pos = centro, raio = raio, duracao = preparo, chefe = true, dono = inimigo.modelo, tipoAviso = "puxar" })
	Vfx.partida(run, "puxaoPreparo", { modelo = inimigo.modelo, pos = centro, duracao = preparo, tipo = inimigo.tipo })
	task.delay(preparo, function()
		if not podeContinuar(run, inimigo) then
			return
		end
		definirAcao(inimigo, "puxao")
		local agoraCentro = noChao(run, inimigo.raiz.Position)
		Vfx.partida(run, "puxao", { modelo = inimigo.modelo, pos = agoraCentro, raio = raio, duracao = ataque.duracao, tipo = inimigo.tipo })
		for _, info in jogadoresAtingiveis(run) do
			if planar(info.raiz.Position - agoraCentro).Magnitude <= raio then
				Remotos.enviar(info.estado.player, "puxar", { centro = agoraCentro, duracao = ataque.duracao, forca = ataque.forca })
			end
		end
		task.delay(ataque.duracao, function()
			if inimigo.vivo then
				definirAcao(inimigo, "")
			end
		end)
	end)
	return true
end

-- Fissura de Almas: a lâmina bate no chão e uma linha de explosões corre até o alvo (uma ou
-- várias em leque). Cada jogador leva no máximo um acerto por fissura.
local function ataqueFissura(run, inimigo, ataque, alvoPos: Vector3, agora: number): boolean
	local preparo = ataque.preparo * inimigo.recargaMult
	local quantidade = ataque.quantidade or 1
	local abertura = math.rad(ataque.abertura or 30)
	local comprimento = ataque.comprimento
	local largura = ataque.largura or 5
	local passos = ataque.passos or 10
	local entre = ataque.entre or 0.07
	local centro = noChao(run, inimigo.raiz.Position)
	local frente = unidade(alvoPos - inimigo.raiz.Position, inimigo.raiz.CFrame.LookVector)
	local direcoes = {}
	for i = 1, quantidade do
		local angulo = (i - (quantidade + 1) / 2) * abertura
		table.insert(direcoes, CFrame.Angles(0, angulo, 0):VectorToWorldSpace(frente))
	end

	parar(inimigo)
	olharPara(inimigo, alvoPos)
	definirAcao(inimigo, "preparar")
	inimigo.ocupadoAte = agora + preparo + passos * entre + 0.5
	for _, direcao in direcoes do
		Vfx.partida(run, "telegrafo", {
			dono = inimigo.modelo,
			forma = "linha",
			pos = centro + direcao * inimigo.raio,
			dir = direcao,
			comprimento = comprimento,
			largura = largura,
			duracao = preparo + passos * entre * 0.5,
			chefe = true,
		})
	end

	task.delay(preparo, function()
		if not podeContinuar(run, inimigo) then
			return
		end
		definirAcao(inimigo, "golpe")
		Vfx.partida(run, "golpeInimigo", { pos = inimigo.raiz.Position, dir = frente, alcance = inimigo.raio + 4, arco = 90, cor = corDoEfeito("alma"), tipo = inimigo.tipo })
		local atingidos = {}
		for passo = 1, passos do
			local distancia = inimigo.raio + passo * (comprimento / passos)
			for _, direcao in direcoes do
				local ponto = limitarNaSala(run, centro + direcao * distancia, 1)
				Vfx.partida(run, "fissura", { pos = ponto, raio = largura / 2 + 0.5, cor = corDoEfeito("alma"), forte = passo == passos })
				for _, info in jogadoresAtingiveis(run) do
					if not atingidos[info.estado] and planar(info.raiz.Position - ponto).Magnitude <= largura / 2 + 1.2 then
						atingidos[info.estado] = true
						local opcoes = opcoesDoEfeito(inimigo, ataque.efeito)
						opcoes.origem = ponto
						Combate.danoAoJogador(run, info.estado, inimigo.dano * (ataque.mult or 1), inimigo, opcoes)
					end
				end
			end
			task.wait(entre)
		end
		if inimigo.vivo then
			definirAcao(inimigo, "")
		end
	end)
	return true
end

------------------------------------------------------------------------
-- Ataques da 2ª fase dos chefes: espiral de projéteis e anéis de perigo
------------------------------------------------------------------------

-- Várias ondas de projéteis em todas as direções, cada onda girada um pouco (espiral)
local function ataqueEspiral(run, inimigo, ataque, agora: number): boolean
	local preparo = ataque.preparo * inimigo.recargaMult
	local ondas = ataque.ondas or 4
	local intervalo = ataque.intervalo or 0.35
	parar(inimigo)
	definirAcao(inimigo, "conjurar")
	inimigo.ocupadoAte = agora + preparo + ondas * intervalo + 0.3
	Vfx.partida(run, "telegrafo", { forma = "circulo", pos = noChao(run, inimigo.raiz.Position), raio = inimigo.raio + 4, duracao = preparo, chefe = true, dono = inimigo.modelo })
	task.delay(preparo, function()
		local giro = math.random() * math.pi
		for _ = 1, ondas do
			if not podeContinuar(run, inimigo) then
				return
			end
			definirAcao(inimigo, "disparo")
			local origem = inimigo.raiz.Position
			local lista = {}
			local quantidade = ataque.quantidade or 10
			for i = 1, quantidade do
				local angulo = giro + i * (math.pi * 2 / quantidade)
				local direcao = Vector3.new(math.sin(angulo), 0, math.cos(angulo))
				table.insert(lista, {
					lado = "inimigo",
					tipo = ataque.projetil,
					pos = origem + direcao * (inimigo.raio + 1),
					dir = direcao,
					velocidade = ataque.velocidade or 32,
					alcance = 80,
					raio = 1.2,
					aoAcertar = function(estado, _, projetil)
						local opcoes = opcoesDoEfeito(inimigo, ataque.efeito)
						opcoes.origem = projetil.pos - projetil.dir * 4
						Combate.danoAoJogador(run, estado, inimigo.dano * (ataque.mult or 1), inimigo, opcoes)
					end,
				})
			end
			Projeteis.disparar(run, lista)
			giro += ataque.giro or 0.25
			task.wait(intervalo)
		end
		if inimigo.vivo then
			definirAcao(inimigo, "")
		end
	end)
	return true
end

-- Anéis de perigo que saem do chefe, um depois do outro: fique entre eles ou pule por cima
local function ataqueAnel(run, inimigo, ataque, agora: number): boolean
	local preparo = ataque.preparo * inimigo.recargaMult
	local aneis = ataque.aneis or 3
	local largura = ataque.largura or 4
	local entre = ataque.entre or 0.7
	local centro = noChao(run, inimigo.raiz.Position)
	local primeiro = inimigo.raio + 3
	local passo = largura * 2.6
	parar(inimigo)
	definirAcao(inimigo, "prepararGiro")
	inimigo.ocupadoAte = agora + preparo + aneis * entre + 0.4
	for i = 1, aneis do
		local raio = primeiro + (i - 1) * passo
		local atraso = preparo + (i - 1) * entre
		Vfx.partida(run, "anelPerigo", { pos = centro, raio = raio, largura = largura, duracao = atraso, cor = corDoEfeito(ataque.efeito), tipo = inimigo.tipo })
		task.delay(atraso, function()
			if not inimigo.vivo or not run.ativa then
				return
			end
			definirAcao(inimigo, "giro")
			Vfx.partida(run, "anelExplode", { pos = centro, raio = raio, largura = largura, cor = corDoEfeito(ataque.efeito), tipo = inimigo.tipo })
			for _, info in jogadoresAtingiveis(run) do
				local distancia = planar(info.raiz.Position - centro).Magnitude
				if math.abs(distancia - raio) <= largura then
					local opcoes = opcoesDoEfeito(inimigo, ataque.efeito)
					opcoes.origem = centro
					Combate.danoAoJogador(run, info.estado, inimigo.dano * (ataque.mult or 1), inimigo, opcoes)
				end
			end
		end)
	end
	task.delay(preparo + aneis * entre + 0.3, function()
		if inimigo.vivo then
			definirAcao(inimigo, "")
		end
	end)
	return true
end

------------------------------------------------------------------------
-- Suporte: cura, escudo e grito de guerra (não precisam de jogador no alcance)
------------------------------------------------------------------------

local function aliadosPerto(run, inimigo, raio: number)
	local lista = {}
	for outro in run.inimigos do
		if outro.vivo and planar(outro.raiz.Position - inimigo.raiz.Position).Magnitude <= raio then
			table.insert(lista, outro)
		end
	end
	return lista
end

local function ataqueCurar(run, inimigo, ataque, agora: number): boolean
	-- o aliado mais ferido (em proporção) que ainda não está quase cheio
	local alvo, menor = nil, 0.8
	for _, outro in aliadosPerto(run, inimigo, ataque.raio) do
		local fracao = outro.vida / outro.vidaMax
		if fracao < menor and (outro ~= inimigo or fracao < 0.5) then
			alvo, menor = outro, fracao
		end
	end
	if not alvo then
		return false
	end
	local preparo = ataque.preparo * inimigo.recargaMult
	parar(inimigo)
	olharPara(inimigo, alvo.raiz.Position)
	definirAcao(inimigo, "conjurar")
	inimigo.ocupadoAte = agora + preparo + 0.3
	Vfx.partida(run, "canalizarCura", { de = inimigo.modelo, para = alvo.modelo, duracao = preparo })
	task.delay(preparo, function()
		if not podeContinuar(run, inimigo) or not alvo.vivo then
			return
		end
		local cura = math.floor(alvo.vidaMax * ataque.cura + 0.5)
		alvo.vida = math.min(alvo.vidaMax, alvo.vida + cura)
		alvo.modelo:SetAttribute("Vida", alvo.vida)
		Vfx.partida(run, "curaInimigo", { pos = alvo.raiz.Position, altura = alvo.alturaBarra, valor = cura, raio = alvo.raio })
		definirAcao(inimigo, "")
	end)
	return true
end

local function ataqueEscudo(run, inimigo, ataque, agora: number): boolean
	local candidatos = {}
	for _, outro in aliadosPerto(run, inimigo, ataque.raio) do
		if (outro.escudo or 0) <= 0 then
			table.insert(candidatos, outro)
		end
	end
	if #candidatos == 0 then
		return false
	end
	-- protege primeiro quem está mais perto dos jogadores (quem vai apanhar)
	local jogadores = jogadoresAtingiveis(run)
	local function perigo(outro): number
		local menor = math.huge
		for _, info in jogadores do
			menor = math.min(menor, planar(info.raiz.Position - outro.raiz.Position).Magnitude)
		end
		return menor
	end
	table.sort(candidatos, function(a, b)
		return perigo(a) < perigo(b)
	end)
	local preparo = ataque.preparo * inimigo.recargaMult
	parar(inimigo)
	definirAcao(inimigo, "conjurar")
	inimigo.ocupadoAte = agora + preparo + 0.3
	Vfx.partida(run, "telegrafoSuporte", { modelo = inimigo.modelo, cor = Color3.fromRGB(110, 190, 255), duracao = preparo })
	task.delay(preparo, function()
		if not podeContinuar(run, inimigo) then
			return
		end
		local alvos = {}
		for i = 1, math.min(ataque.maximo or 4, #candidatos) do
			local outro = candidatos[i]
			if outro.vivo then
				outro.escudo = outro.vidaMax * ataque.escudo
				outro.escudoAte = os.clock() + ataque.duracao
				outro.modelo:SetAttribute("Escudo", outro.escudo)
				outro.modelo:SetAttribute("EscudoMax", outro.escudo)
				table.insert(alvos, outro.modelo)
			end
		end
		Vfx.partida(run, "escudoInimigo", { de = inimigo.modelo, alvos = alvos })
		definirAcao(inimigo, "")
	end)
	return true
end

local function ataqueGrito(run, inimigo, ataque, agora: number): boolean
	local aliados = aliadosPerto(run, inimigo, ataque.raio)
	if #aliados < 2 then
		return false -- sozinho, não adianta gritar
	end
	local preparo = ataque.preparo * inimigo.recargaMult
	parar(inimigo)
	definirAcao(inimigo, "conjurar")
	inimigo.ocupadoAte = agora + preparo + 0.4
	Vfx.partida(run, "telegrafoSuporte", { modelo = inimigo.modelo, cor = Color3.fromRGB(255, 80, 60), duracao = preparo })
	task.delay(preparo, function()
		if not podeContinuar(run, inimigo) then
			return
		end
		local fim = os.clock() + ataque.duracao
		for _, outro in aliadosPerto(run, inimigo, ataque.raio) do
			outro.inspiradoAte = fim
			outro.modelo:SetAttribute("Inspirado", true)
		end
		Vfx.partida(run, "gritoGuerra", { pos = noChao(run, inimigo.raiz.Position), raio = ataque.raio, modelo = inimigo.modelo })
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
	elseif tipo == "puxar" then
		return ataquePuxar(run, inimigo, ataque, agora)
	elseif tipo == "fissura" then
		return ataqueFissura(run, inimigo, ataque, alvoPos, agora)
	elseif tipo == "espiral" then
		return ataqueEspiral(run, inimigo, ataque, agora)
	elseif tipo == "anel" then
		return ataqueAnel(run, inimigo, ataque, agora)
	elseif tipo == "curar" then
		return ataqueCurar(run, inimigo, ataque, agora)
	elseif tipo == "escudo" then
		return ataqueEscudo(run, inimigo, ataque, agora)
	elseif tipo == "grito" then
		return ataqueGrito(run, inimigo, ataque, agora)
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

-- Transformação: o chefe para, fica imune e junta poder por alguns segundos (a sala muda de cor),
-- solta uma onda de choque e volta mais rápido, com ataques novos
local TRANSFORMACAO = 2.8

local function entrarNaFase2(run, inimigo)
	local fase2 = inimigo.def.fase2
	local agora = os.clock()
	local cor = fase2.cor or Color3.fromRGB(255, 70, 50)
	inimigo.fase2 = true
	inimigo.invulneravelAte = agora + TRANSFORMACAO
	inimigo.ocupadoAte = agora + TRANSFORMACAO + 0.3
	parar(inimigo)
	definirAcao(inimigo, "conjurar")
	inimigo.modelo:SetAttribute("Furioso", true)
	inimigo.modelo:SetAttribute("Fase", 2)
	run:anunciar("🔥 " .. (fase2.anuncio or (inimigo.def.nome .. " se enfurece!")), Color3.fromRGB(255, 90, 60))
	local centro = noChao(run, inimigo.raiz.Position)
	local raioOnda = inimigo.raio + 14
	Vfx.partida(run, "fase2", { modelo = inimigo.modelo, pos = centro, cor = cor, duracao = TRANSFORMACAO, raio = raioOnda, tipo = inimigo.tipo })
	Vfx.partida(run, "telegrafo", { forma = "circulo", pos = centro, raio = raioOnda, duracao = TRANSFORMACAO, chefe = true, dono = inimigo.modelo })

	task.delay(TRANSFORMACAO, function()
		if not inimigo.vivo or not run.ativa then
			return
		end
		Vfx.partida(run, "furia", { pos = inimigo.raiz.Position, tipo = inimigo.tipo })
		Vfx.partida(run, "explosao", { pos = inimigo.raiz.Position, raio = raioOnda, cor = cor, forte = true })
		acertarJogadores(run, inimigo, inimigo.raiz.Position, nil, raioOnda, 360, 1.3, nil)
		inimigo.velocidadeMult *= fase2.velocidade or 1
		inimigo.recargaMult *= fase2.recarga or 1
		if fase2.ataques then
			for i, ataque in fase2.ataques do
				table.insert(inimigo.ataques, i, ataque)
				inimigo.prontoEm[ataque] = os.clock() + (ataque.inicial or 1)
			end
		end
		definirAcao(inimigo, "")
	end)
end

-- Golpe que vem logo depois deste num combo (ou nil): cada opção de "seguir" tem uma chance
local function sortearSeguinte(inimigo, ataque)
	if not ataque.seguir then
		return nil
	end
	local mult = if inimigo.fase2 then inimigo.def.fase2.combos or 1 else 1
	for _, opcao in ataque.seguir do
		if math.random() < opcao[2] * mult then
			for _, outro in inimigo.ataques do
				if outro.nome == opcao[1] then
					return outro
				end
			end
		end
	end
	return nil
end

local function decidir(run, inimigo, agora: number)
	local def = inimigo.def

	-- postura: esvazia sozinha depois de 3s sem pressão; o grogue acaba e a barra zera
	if def.posturaMax then
		if inimigo.grogueAte and agora >= inimigo.grogueAte then
			inimigo.grogueAte = nil
			inimigo.fatalPronto = false
			inimigo.postura = 0
			inimigo.modelo:SetAttribute("Grogue", false)
			inimigo.modelo:SetAttribute("Postura", 0)
		elseif (inimigo.postura or 0) > 0 and not inimigo.grogueAte and agora - (inimigo.posturaTocadaEm or 0) > 3 then
			inimigo.postura = math.max(0, inimigo.postura - 1.4)
			inimigo.modelo:SetAttribute("Postura", inimigo.postura / def.posturaMax)
		end
	end

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
	-- escudo de runas e grito de guerra acabam com o tempo
	if (inimigo.escudo or 0) > 0 and agora >= (inimigo.escudoAte or 0) then
		inimigo.escudo = 0
		inimigo.modelo:SetAttribute("Escudo", 0)
	end
	local inspirado = agora < (inimigo.inspiradoAte or 0)
	if not inspirado and inimigo.modelo:GetAttribute("Inspirado") then
		inimigo.modelo:SetAttribute("Inspirado", false)
	end

	if inimigo.chefe and def.fase2 and not inimigo.fase2 and inimigo.vida <= inimigo.vidaMax * 0.5 then
		entrarNaFase2(run, inimigo)
	end

	if agora < inimigo.ocupadoAte or inimigo.investindo then
		return
	end

	local velocidade = def.velocidade * inimigo.velocidadeMult * (if inspirado then 1.35 else 1)
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

	-- combo encadeado: o próximo golpe sai logo que o anterior termina (sem pausa nem recarga)
	if inimigo.encadear then
		local proximo = inimigo.encadear
		inimigo.encadear = nil
		if distancia <= (proximo.alcance or 999) * inimigo.escala * 1.4 then
			olharPara(inimigo, alvoPos)
			if executarAtaque(run, inimigo, proximo, info.estado, alvoPos, agora) then
				inimigo.ultimoAtaque = proximo
				inimigo.encadear = sortearSeguinte(inimigo, proximo)
				return
			end
		end
	end

	-- chefes com "pausa": depois de cada ataque andam um pouco antes do próximo
	local podeAtacar = agora >= (inimigo.ataqueLivreEm or 0)
	if def.aleatorio then
		-- sorteia entre os golpes prontos e no alcance, com peso pela distância
		if podeAtacar then
			local candidatos, total = {}, 0
			for _, ataque in inimigo.ataques do
				if agora >= (inimigo.prontoEm[ataque] or 0) and distancia <= (ataque.alcance or 999) * inimigo.escala and distancia >= (ataque.minimo or 0) then
					local peso = ataque.peso or 1
					if distancia <= 10 and ataque.pesoPerto then
						peso = ataque.pesoPerto
					elseif distancia >= 22 and ataque.pesoLonge then
						peso = ataque.pesoLonge
					end
					if ataque == inimigo.ultimoAtaque then
						peso *= 0.25 -- quase nunca repete o mesmo golpe
					end
					if peso > 0 then
						total += peso
						table.insert(candidatos, { ataque, peso })
					end
				end
			end
			local sorteio = math.random() * total
			for _, item in candidatos do
				sorteio -= item[2]
				if sorteio <= 0 then
					local ataque = item[1]
					if executarAtaque(run, inimigo, ataque, info.estado, alvoPos, agora) then
						inimigo.prontoEm[ataque] = agora + (ataque.recarga or 2) * inimigo.recargaMult
						inimigo.ultimoAtaque = ataque
						inimigo.encadear = sortearSeguinte(inimigo, ataque)
						if def.pausa and not inimigo.encadear then
							local pausa = def.pausa[1] + math.random() * (def.pausa[2] - def.pausa[1])
							inimigo.ataqueLivreEm = inimigo.ocupadoAte + pausa * (if inimigo.fase2 then 0.7 else 1)
						end
						return
					end
					inimigo.prontoEm[ataque] = agora + 2
					break
				end
			end
		end
		podeAtacar = false -- o resto é só movimento
	end
	for _, ataque in inimigo.ataques do
		if podeAtacar and agora >= (inimigo.prontoEm[ataque] or 0) and distancia <= (ataque.alcance or 999) * inimigo.escala and distancia >= (ataque.minimo or 0) then
			if executarAtaque(run, inimigo, ataque, info.estado, alvoPos, agora) then
				local apressado = if inspirado and ataque.tipo ~= "grito" then 0.7 else 1
				inimigo.prontoEm[ataque] = agora + (ataque.recarga or 2) * inimigo.recargaMult * apressado
				if def.pausa then
					local pausa = def.pausa[1] + math.random() * (def.pausa[2] - def.pausa[1])
					inimigo.ataqueLivreEm = inimigo.ocupadoAte + pausa * (if inimigo.fase2 then 0.7 else 1)
				end
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
			if def.pausa then
				olharPara(inimigo, alvoPos)
			end
		elseif def.pausa and not podeAtacar then
			-- esperando o próximo ataque: rodeia o alvo devagar, encarando
			if agora >= inimigo.trocaLadoEm then
				inimigo.lado = -inimigo.lado
				inimigo.trocaLadoEm = agora + 1.5 + math.random() * 1.5
			end
			local pos = inimigo.raiz.Position
			local paraAlvo = unidade(alvoPos - pos, Vector3.new(0, 0, 1))
			inimigo.humanoid.WalkSpeed = velocidade * 0.55
			mover(run, inimigo, pos + Vector3.new(-paraAlvo.Z, 0, paraAlvo.X) * inimigo.lado * 6)
			olharPara(inimigo, alvoPos)
		else
			parar(inimigo)
			olharPara(inimigo, alvoPos)
		end
	elseif comportamento == "suporte" then
		-- fica atrás dos aliados (do lado oposto aos jogadores), sem chegar perto de ninguém
		local pos = inimigo.raiz.Position
		local soma, quantos = Vector3.zero, 0
		for outro in run.inimigos do
			if outro ~= inimigo and outro.vivo and outro.def.comportamento ~= "suporte" then
				soma += outro.raiz.Position
				quantos += 1
			end
		end
		local ideal = def.distancia or 20
		if distancia < ideal - 6 then
			-- jogador perto demais: recua
			mover(run, inimigo, pos + unidade(pos - alvoPos, Vector3.new(1, 0, 0)) * 10)
		elseif quantos > 0 then
			local centro = soma / quantos
			local atras = centro + unidade(centro - alvoPos, Vector3.new(0, 0, 1)) * 7
			if planar(atras - pos).Magnitude > 4 then
				mover(run, inimigo, atras)
			else
				parar(inimigo)
				olharPara(inimigo, alvoPos)
			end
		elseif distancia > ideal + 4 then
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
		Vfx.partida(run, "telegrafo", { forma = "circulo", pos = chao, raio = raio, duracao = 1, dono = inimigo.modelo })
		task.delay(1, function()
			if not run.ativa then
				return
			end
			Vfx.partida(run, "explosao", { pos = chao, raio = raio, cor = Color3.fromRGB(255, 120, 40), forte = true })
			for _, info in jogadoresAtingiveis(run) do
				if planar(info.raiz.Position - chao).Magnitude <= raio + 1 then
					Combate.danoAoJogador(run, info.estado, inimigo.dano * 1.5, nil, { origem = chao })
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
