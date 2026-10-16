-- Configurações do jogo. Quase todo o balanceamento fica aqui: mude os números e teste.

local Config = {}

Config.NOME_DO_JOGO = "Masmorra das Cartas"

-- Efeitos sonoros: envie sons/MasmorraSons.ogg para o Roblox e cole o ID aqui
-- (ex.: "rbxassetid://1234567890"). Veja "Efeitos sonoros" em COMO_USAR.md.
Config.SONS_ID = ""
-- Opcional: um ID por som (tem preferência sobre o arquivo único). Ex.: espada = "rbxassetid://..."
Config.SONS_IDS = {
	-- som de espada que você salvou no jogo (sword-swing-whoosh): golpes do Cavaleiro
	espada = "rbxassetid://135315310485417",
	espadaPesada = "rbxassetid://135315310485417",
	golpeEspada = "rbxassetid://135315310485417", -- espada acertando o inimigo
}
-- Música do acampamento (o som "Ambient Trust" que você colocou no jogo): toca em loop no lobby
-- e some ao entrar na masmorra. Deixe "" para desligar.
Config.MUSICA_LOBBY = "rbxassetid://91000345218760"
Config.VOLUME_MUSICA_LOBBY = 0.4

-- Partida
Config.MAX_JOGADORES_POR_PARTIDA = 4
Config.CONTAGEM_PORTAL = 10 -- segundos em cima do portal até a partida começar
Config.CONTAGEM_PORTAL_CHEIO = 3 -- contagem quando o grupo já está completo
Config.SALAS_POR_ANDAR = 5 -- a cada 5 salas vem um chefe e o elevador

-- Salas de exploração (temas com "exploracao = true", hoje o Calabouço): salas bem maiores em
-- três áreas. Os inimigos de cada área aparecem quando alguém chega perto dela. Sacadas (escada
-- de mão ou de pedra), uma torre com pedras flutuantes e baús guardam relíquias
-- (shared/Reliquias.luau); armadilhas protegem o caminho.
Config.EXPLORACAO = {
	largura = { 150, 160 },
	comprimento = { 200, 220 },
	altura = 32, -- paredes mais altas (a torre chega a 22)
	inimigosMult = 1.2, -- mais inimigos que numa sala comum (a sala é maior)
	distanciaArea = 14, -- a área acorda quando alguém passa a menos disto do começo dela
	miniChefeNasSalas = { 2, 4 }, -- posição no andar (1 a 4) com mini-chefe guardando o relicário
	-- chance de cada baú dar relíquia (senão dá ouro e cura); veja Reliquias.BAUS
	chanceReliquia = { chao = 0.15, alto = 0.45, torre = 1, relicario = 1, chefe = 1 },
	danoEspinhos = 14, -- armadilhas: multiplicado pelo dano dos inimigos da sala
	danoFogo = 10,
	queimaFogo = 4, -- dano por segundo do fogo por 3 s
}
Config.CHANCE_SALA_TESOURO = 0.15
Config.TEMPO_ESCOLHER_CARTA = 20
Config.TEMPO_ELEVADOR = 25
Config.TEMPO_PORTA_AUTOMATICA = 60

-- Esquiva (todas as classes)
Config.ESQUIVA_RECARGA = 2.2
Config.ESQUIVA_INVULNERAVEL = 0.35
Config.ESQUIVA_VELOCIDADE = 78
Config.ESQUIVA_DURACAO = 0.17

-- Ataque carregado: segure o ataque para carregar e solte para um golpe mais forte
Config.CARGA_ATAQUE_COMECA = 0.3 -- segurando por este tempo, começa a carregar
Config.CARGA_ATAQUE_MIN = 0.3 -- carga mínima para o golpe carregado sair
Config.CARGA_ATAQUE_MAX = 1.2 -- carga cheia (dano máximo e efeito especial)
Config.DANO_CARGA_MIN = 1.6 -- multiplicador de dano com carga mínima
Config.DANO_CARGA_MAX = 3.2 -- multiplicador de dano com carga cheia
Config.VELOCIDADE_CARREGANDO = 0.5 -- anda mais devagar enquanto carrega

-- Peso dos golpes: a preparação (do clique até a arma chegar no alvo) fica mais longa.
-- 1 = como antes; 1.8 = 80% mais tempo preparando. Cada classe pode ter o seu (ataque.preparo).
Config.PREPARO_GOLPE = 1.7
-- Braço da espada animado nos modelos 3D (Skullbane, Ceifador): deforma a malha com
-- EditableMesh. Se der problema no seu jogo, troque para false (o braço fica parado).
Config.BRACO_ANIMADO = true
Config.VELOCIDADE_CORRIDA = 1.35 -- segurando Shift: corrida leve (não vale atacando, carregando ou defendendo)
Config.VELOCIDADE_ATACANDO = 0.45 -- o personagem quase para enquanto prepara o golpe

-- Defesa com escudo (Cavaleiro): segure F, o botão direito do mouse ou L2
Config.DEFESA_REDUCAO = 0.75 -- golpes de frente perdem 75% do dano
Config.DEFESA_ANGULO = 65 -- protege golpes vindos até 65° para cada lado da frente
Config.DEFESA_PERFEITA = 0.3 -- erguer o escudo até 0,3s antes do golpe: bloqueia tudo e atordoa
Config.VELOCIDADE_DEFENDENDO = 0.45

-- Supremo: a barra enche causando dano e derrotando inimigos
Config.CARGA_MAXIMA = 100
Config.CARGA_POR_ACERTO = 2.5
Config.CARGA_POR_ABATE = 4

-- Jogador caído: aliados reviram ficando perto
Config.TEMPO_CAIDO = 15
Config.TEMPO_PARA_REVIVER = 3
Config.RAIO_REVIVER = 8
Config.VIDA_AO_REVIVER = 0.4

-- Ouro: quem morre fica só com esta parte. Quem sobe no elevador fica com tudo.
Config.OURO_MANTIDO_AO_MORRER = 0.25

-- Versão do jogo: aparece no canto da tela junto com a data e a hora do build (o build.py
-- grava ReplicatedStorage > Versao). Suba o número quando publicar uma atualização grande.
Config.VERSAO = "0.15"

-- Inimigos ficam mais fortes a cada sala
Config.VIDA_INIMIGO_POR_SALA = 0.14
Config.DANO_INIMIGO_POR_SALA = 0.06

-- Dificuldade do grupo: cada jogador a mais na partida deixa a masmorra mais difícil.
-- Com 4 jogadores: inimigos com +225% de vida e +60% de dano; chefes com +390% de vida,
-- +90% de dano, golpes 30% mais frequentes e postura +180% (mais difícil de quebrar).
Config.VIDA_INIMIGO_POR_JOGADOR_EXTRA = 0.75
Config.DANO_INIMIGO_POR_JOGADOR_EXTRA = 0.2
-- o grupo inteiro bate no chefe ao mesmo tempo e o dano dele se divide entre todos
Config.VIDA_CHEFE_POR_JOGADOR_EXTRA = 1.3
Config.DANO_CHEFE_POR_JOGADOR_EXTRA = 0.3
Config.RECARGA_CHEFE_POR_JOGADOR_EXTRA = 0.1 -- recarga dos golpes 10% menor por jogador a mais (mínimo 60%)
Config.POSTURA_CHEFE_POR_JOGADOR_EXTRA = 0.6 -- mais parries no grupo: a postura aguenta mais
Config.INIMIGOS_POR_JOGADOR_EXTRA = 4 -- inimigos a mais em cada sala de combate
Config.VIVOS_POR_JOGADOR_EXTRA = 2 -- inimigos a mais ao mesmo tempo na sala
Config.ELITE_POR_JOGADOR_EXTRA = 0.04 -- chance de elite a mais (o máximo também sobe)

-- Inimigos de apoio (Acólito cura, Guardião dá escudo, Porta-Estandarte grita) aparecem
-- mais nas salas grandes: o peso deles em Config.TEMAS é multiplicado por isto (1 = normal).
-- Com 2, eles passam de ~1 em 5 para ~1 em 3 inimigos.
Config.PESO_INIMIGOS_DE_APOIO = 2

-- Maldição do Alto (só o Skullbane, 1º chefe): a cada MALDICAO_INTERVALO segundos uma alma cai
-- do alto num jogador do grupo. O círculo verde avisa; quem sai dele, esquiva ou defende com o
-- escudo escapa. Quem é atingido fica sem esquiva (dash), corrida, habilidade (E) e supremo (R),
-- com a tela verde. A cada MALDICAO_FORTE_A_CADA quedas vem a maldição forte (maior e mais longa).
Config.MALDICAO_INTERVALO = 5
Config.MALDICAO_DURACAO = 1.2
Config.MALDICAO_RAIO = 5
Config.MALDICAO_AVISO = 1.4 -- tempo do selo no chão até a alma cair
-- o selo segue a pessoa e só trava no lugar este tempo antes de a alma cair: sair andando não
-- adianta; escapa quem dá a esquiva (dash) bem na hora ou quem defende com o escudo
Config.MALDICAO_TRAVA = 0.35
Config.MALDICAO_FORTE_A_CADA = 2 -- uma queda sim, outra não: a forte vem a cada 10s
Config.MALDICAO_FORTE_DURACAO = 2.5
Config.MALDICAO_FORTE_RAIO = 7

-- Caveiras (só o Skullbane): a cada CAVEIRAS_INTERVALO segundos ele solta caveiras em chamas
-- verdes que perseguem os jogadores (uma por jogador, no mínimo CAVEIRAS_MINIMO). Elas viram
-- devagar (CAVEIRAS_GIRO, em radianos por segundo): dá para fugir ou desviar de lado na hora certa.
Config.CAVEIRAS_INTERVALO = 7
Config.CAVEIRAS_MINIMO = 2
Config.CAVEIRAS_VELOCIDADE = 17
Config.CAVEIRAS_GIRO = 2.2
Config.CAVEIRAS_DURACAO = 5 -- segundos até a caveira se desfazer
Config.CAVEIRAS_DANO = 0.45 -- parte do dano do chefe

-- Chefes começam a atacar logo depois de despertar: o tempo até o primeiro uso de cada
-- golpe ("inicial" em Inimigos.luau) é multiplicado por isto
Config.INICIO_ATAQUES_CHEFE = 0.35

-- Inimigos de elite (mais fortes, com um poder especial, dão mais ouro)
Config.CHANCE_ELITE_BASE = 0.05
Config.CHANCE_ELITE_POR_SALA = 0.012
Config.CHANCE_ELITE_MAXIMA = 0.3

Config.RARIDADES = {
	Comum = { nome = "Comum", cor = Color3.fromRGB(196, 202, 214), peso = 60 },
	Rara = { nome = "Rara", cor = Color3.fromRGB(72, 165, 255), peso = 28 },
	Epica = { nome = "Épica", cor = Color3.fromRGB(190, 100, 255), peso = 10 },
	Lendaria = { nome = "Lendária", cor = Color3.fromRGB(255, 186, 48), peso = 2.5 },
}
Config.ORDEM_RARIDADES = { "Comum", "Rara", "Epica", "Lendaria" }
Config.SORTE_POR_NIVEL = { Comum = -3, Rara = 1.5, Epica = 1, Lendaria = 0.5 }
Config.PESO_EXTRA_CARTA_DE_CLASSE = 1.5 -- cartas da sua classe aparecem mais

Config.MELHORIAS = {
	{ id = "Vida", nome = "Vida Extra", icone = "❤️", descricao = "+15 de vida máxima por nível", precoBase = 40, nivelMax = 10 },
	{ id = "Forca", nome = "Força", icone = "💪", descricao = "+8% de dano por nível", precoBase = 50, nivelMax = 10 },
	{ id = "Sorte", nome = "Sorte", icone = "🍀", descricao = "Cartas raras aparecem mais", precoBase = 75, nivelMax = 5 },
}

function Config.precoMelhoria(melhoria, nivelAtual: number): number
	return math.floor(melhoria.precoBase * (nivelAtual + 1) ^ 1.6)
end

function Config.buscarMelhoria(id)
	for _, melhoria in Config.MELHORIAS do
		if melhoria.id == id then
			return melhoria
		end
	end
	return nil
end

-- Cada andar (5 salas) tem um tema: visual, inimigos e chefe próprios.
-- Depois do último tema, o ciclo recomeça com inimigos mais fortes.
Config.TEMAS = {
	{
		id = "calabouco",
		nome = "Calabouço",
		inimigos = { gosma = 4, esqueleto = 4, esqueletoArqueiro = 2.5, rato = 2, acolito = 1.3, guardiao = 0.9, portaEstandarte = 0.8 },
		chefe = "skullbane", -- (o Rei Esqueleto continua no jogo: troque aqui para voltar a ele)
		-- mesmo estilo do lobby: peças lisas com cores vivas de fantasia, fogo do pacote de VFX
		estilo = "fantasia",
		-- salas de combate viram salas de exploração: grandes, com sacadas, torre, baús de
		-- relíquias, armadilhas e mini-chefe (Masmorra.luau e Config.EXPLORACAO)
		exploracao = true,
		chao = { material = Enum.Material.SmoothPlastic, cor = Color3.fromRGB(206, 186, 156) },
		parede = { material = Enum.Material.SmoothPlastic, cor = Color3.fromRGB(136, 120, 172) },
		detalhe = { material = Enum.Material.SmoothPlastic, cor = Color3.fromRGB(214, 204, 232) },
		luz = Color3.fromRGB(255, 172, 96),
		ambiente = Color3.fromRGB(104, 92, 128),
		nevoa = Color3.fromRGB(70, 56, 96),
		tinta = Color3.fromRGB(255, 244, 236),
		brilho = 1.1, -- Lighting.Brightness (padrão 0,6): o estilo claro pede mais luz
		densidade = 0.28, -- névoa (padrão 0,4): dá para ver a sala grande de ponta a ponta
		particulas = "poeira",
		lava = false,
	},
	{
		id = "caverna",
		nome = "Caverna Musgosa",
		inimigos = { kobold = 4, aranha = 3, cogumelo = 2, xama = 2, gosma = 1.5, portaEstandarte = 1.4, acolito = 0.9, guardiao = 0.8 },
		chefe = "rainhaAranha",
		chao = { material = Enum.Material.Ground, cor = Color3.fromRGB(74, 84, 58) },
		parede = { material = Enum.Material.Rock, cor = Color3.fromRGB(70, 78, 64) },
		detalhe = { material = Enum.Material.Slate, cor = Color3.fromRGB(50, 60, 48) },
		luz = Color3.fromRGB(170, 255, 140),
		ambiente = Color3.fromRGB(44, 66, 50),
		nevoa = Color3.fromRGB(18, 34, 24),
		tinta = Color3.fromRGB(225, 255, 230),
		particulas = "esporos",
		lava = false,
	},
	{
		id = "cripta",
		nome = "Cripta Congelada",
		inimigos = { carnical = 4, espectro = 3, cavaleiroMorto = 1.5, esqueleto = 1.5, acolito = 1.4, guardiao = 1.3, portaEstandarte = 0.8 },
		chefe = "lich",
		chao = { material = Enum.Material.Slate, cor = Color3.fromRGB(120, 140, 165) },
		parede = { material = Enum.Material.Glacier, cor = Color3.fromRGB(130, 160, 200) },
		detalhe = { material = Enum.Material.Ice, cor = Color3.fromRGB(165, 205, 240) },
		luz = Color3.fromRGB(140, 205, 255),
		ambiente = Color3.fromRGB(70, 86, 118),
		nevoa = Color3.fromRGB(30, 42, 66),
		tinta = Color3.fromRGB(220, 235, 255),
		particulas = "neve",
		lava = false,
	},
	{
		id = "fornalha",
		nome = "Fornalha",
		inimigos = { diabrete = 3.5, elementalFogo = 3, ogro = 1.5, carnical = 1, guardiao = 1.3, portaEstandarte = 1.3, acolito = 1 },
		chefe = "senhorChamas",
		chao = { material = Enum.Material.Basalt, cor = Color3.fromRGB(46, 38, 38) },
		parede = { material = Enum.Material.CrackedLava, cor = Color3.fromRGB(96, 46, 34) },
		detalhe = { material = Enum.Material.Basalt, cor = Color3.fromRGB(30, 24, 24) },
		luz = Color3.fromRGB(255, 120, 60),
		ambiente = Color3.fromRGB(86, 44, 34),
		nevoa = Color3.fromRGB(52, 16, 8),
		tinta = Color3.fromRGB(255, 220, 200),
		particulas = "brasas",
		lava = true,
	},
}

function Config.indiceTema(numeroSala: number): number
	return ((numeroSala - 1) // Config.SALAS_POR_ANDAR) % #Config.TEMAS + 1
end

function Config.temaDaSala(numeroSala: number)
	return Config.TEMAS[Config.indiceTema(numeroSala)]
end

return Config
