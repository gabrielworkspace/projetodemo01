-- Configurações do jogo. Quase todo o balanceamento fica aqui: mude os números e teste.

local Config = {}

Config.NOME_DO_JOGO = "Masmorra das Cartas"

-- Partida
Config.MAX_JOGADORES_POR_PARTIDA = 4
Config.CONTAGEM_PORTAL = 10 -- segundos em cima do portal até a partida começar
Config.CONTAGEM_PORTAL_CHEIO = 3 -- contagem quando o grupo já está completo
Config.SALAS_POR_ANDAR = 5 -- a cada 5 salas vem um chefe e o elevador
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

-- Inimigos ficam mais fortes a cada sala e quando há mais jogadores
Config.VIDA_INIMIGO_POR_SALA = 0.14
Config.DANO_INIMIGO_POR_SALA = 0.06
Config.VIDA_INIMIGO_POR_JOGADOR_EXTRA = 0.4

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
		inimigos = { gosma = 4, esqueleto = 4, esqueletoArqueiro = 2.5, rato = 2 },
		chefe = "reiEsqueleto",
		chao = { material = Enum.Material.Cobblestone, cor = Color3.fromRGB(98, 94, 100) },
		parede = { material = Enum.Material.Brick, cor = Color3.fromRGB(84, 74, 76) },
		detalhe = { material = Enum.Material.Slate, cor = Color3.fromRGB(58, 52, 58) },
		luz = Color3.fromRGB(255, 165, 85),
		ambiente = Color3.fromRGB(62, 52, 62),
		nevoa = Color3.fromRGB(34, 24, 30),
		tinta = Color3.fromRGB(255, 236, 220),
		particulas = "poeira",
		lava = false,
	},
	{
		id = "caverna",
		nome = "Caverna Musgosa",
		inimigos = { kobold = 4, aranha = 3, cogumelo = 2, xama = 2, gosma = 1.5 },
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
		inimigos = { carnical = 4, espectro = 3, cavaleiroMorto = 1.5, esqueleto = 1.5 },
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
		inimigos = { diabrete = 3.5, elementalFogo = 3, ogro = 1.5, carnical = 1 },
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
