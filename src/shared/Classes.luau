-- As quatro classes jogáveis. Os números de cada classe ficam aqui.
-- As cartas de cada classe ficam em Cartas.luau (campo "classe").
--
-- Cada classe tem pontos fortes e fracos claros:
--   Cavaleiro: aguenta muito e protege o grupo, mas é lento e só bate de perto
--   Mago:      destrói grupos de longe, mas é frágil e ataca devagar
--   Arqueiro:  dano constante de longe e muito ágil, mas fraco contra quem chega perto
--   Assassino: mata um alvo de cada vez muito rápido, mas tem pouca vida e quase nenhuma área
--
-- Campos opcionais: critico (chance base), esquivaMult (recarga da esquiva),
-- ameacaMult (o quanto chama a atenção dos inimigos)

local Classes = {}

Classes.ordem = { "cavaleiro", "mago", "arqueiro", "assassino" }

Classes.dados = {
	cavaleiro = {
		id = "cavaleiro",
		nome = "Cavaleiro",
		titulo = "A Muralha de Aço",
		icone = "🛡️",
		cor = Color3.fromRGB(86, 156, 255),
		descricao = "Luta na linha de frente com espada e escudo e atrai os inimigos para si.",
		forte = "Muita vida e armadura, protege os aliados",
		fraco = "Lento, esquiva demora mais e só bate de perto",
		notas = { Vida = 5, Dano = 3, Alcance = 1, Velocidade = 1 },

		vida = 160,
		dano = 22,
		velocidade = 16,
		intervalo = 0.44,
		alcance = 9.5,
		armadura = 0.15,
		esquivaMult = 1.25,
		ameacaMult = 2.5,

		ataque = {
			tipo = "corte",
			arco = 140,
			combo = { 1, 1.1, 1.9 }, -- o terceiro golpe é o finalizador
			nome = "Combo de Espada",
			icone = "⚔️",
		},
		habilidade = {
			id = "redemoinho",
			nome = "Redemoinho",
			icone = "🌀",
			recarga = 8,
			descricao = "Gira por 2s puxando os inimigos para perto. Recebe 40% menos dano enquanto gira.",
		},
		supremo = {
			id = "julgamento",
			nome = "Julgamento",
			icone = "⚡",
			descricao = "Esmaga o chão: atordoa todos ao redor e dá um escudo aos aliados próximos.",
		},
	},

	mago = {
		id = "mago",
		nome = "Mago",
		titulo = "O Arcano",
		icone = "🔮",
		cor = Color3.fromRGB(180, 96, 255),
		descricao = "Ataca de longe com orbes que explodem e controla o campo com fogo e raios.",
		forte = "Enorme dano em área e controle de grupos",
		fraco = "Pouquíssima vida e ataque lento",
		notas = { Vida = 1, Dano = 5, Alcance = 4, Velocidade = 2 },

		vida = 80,
		dano = 21,
		velocidade = 17,
		intervalo = 0.52,
		alcance = 50,
		armadura = 0,

		ataque = {
			tipo = "projetil",
			projetil = "orbe",
			velocidade = 62,
			raio = 1.3,
			explosao = 4,
			combo = { 1, 1, 1.7 },
			nome = "Orbe Arcano",
			icone = "✨",
		},
		habilidade = {
			id = "meteoro",
			nome = "Meteoro",
			icone = "☄️",
			recarga = 9,
			descricao = "Um meteoro cai na mira e deixa o chão em chamas por 3 segundos.",
		},
		supremo = {
			id = "tempestade",
			nome = "Tempestade Arcana",
			icone = "🌩️",
			descricao = "Raios caem sem parar por 5s e deixam os inimigos atingidos lentos.",
		},
	},

	arqueiro = {
		id = "arqueiro",
		nome = "Arqueiro",
		titulo = "O Olho do Bosque",
		icone = "🏹",
		cor = Color3.fromRGB(96, 214, 120),
		descricao = "Rápido e certeiro. Atira sem parar enquanto mantém os inimigos longe.",
		forte = "Maior alcance, muito ágil, dano constante",
		fraco = "Flechas perdem força em inimigos colados",
		notas = { Vida = 3, Dano = 3, Alcance = 5, Velocidade = 4 },

		vida = 100,
		dano = 15,
		velocidade = 20,
		intervalo = 0.32,
		alcance = 60,
		armadura = 0,
		critico = 0.05,

		ataque = {
			tipo = "projetil",
			projetil = "flecha",
			velocidade = 115,
			raio = 0.9,
			explosao = 0,
			combo = { 1, 1, 2 },
			nome = "Flechada",
			icone = "🎯",
		},
		habilidade = {
			id = "chuva",
			nome = "Chuva de Flechas",
			icone = "🌧️",
			recarga = 9,
			descricao = "Salta para trás e faz chover flechas na mira por 3s, deixando os inimigos lentos.",
		},
		supremo = {
			id = "saraivada",
			nome = "Saraivada",
			icone = "💫",
			descricao = "Dispara flechas em todas as direções por 4s, correndo 30% mais rápido.",
		},
	},

	assassino = {
		id = "assassino",
		nome = "Assassino",
		titulo = "A Lâmina na Sombra",
		icone = "🗡️",
		cor = Color3.fromRGB(235, 60, 90),
		descricao = "Duas adagas, muitos críticos e golpes pelas costas. Some e reaparece atrás do alvo.",
		forte = "Mata um alvo de cada vez, críticos e esquiva rápida",
		fraco = "Pouca vida, alcance curtíssimo, quase nada de área",
		notas = { Vida = 2, Dano = 5, Alcance = 1, Velocidade = 5 },

		vida = 85,
		dano = 15,
		velocidade = 21,
		intervalo = 0.26,
		alcance = 7.5,
		armadura = 0,
		critico = 0.15,
		esquivaMult = 0.7,
		ameacaMult = 0.6,

		ataque = {
			tipo = "corte",
			arco = 95,
			combo = { 1, 1, 2.4 },
			costas = 0.5, -- +50% de dano acertando o inimigo pelas costas
			nome = "Dança das Adagas",
			icone = "🗡️",
		},
		habilidade = {
			id = "passoSombrio",
			nome = "Passo Sombrio",
			icone = "🌑",
			recarga = 6,
			descricao = "Some e aparece atrás do inimigo na mira, com um golpe crítico garantido.",
		},
		supremo = {
			id = "laminasNoturnas",
			nome = "Lâminas da Noite",
			icone = "🌙",
			descricao = "Fica intocável e salta de inimigo em inimigo, cortando até 10 vezes.",
		},
	},
}

function Classes.obter(id: string?)
	return Classes.dados[id or ""] or Classes.dados.cavaleiro
end

function Classes.existe(id: any): boolean
	return type(id) == "string" and Classes.dados[id] ~= nil
end

return Classes
