-- As três classes jogáveis. Os números de cada classe ficam aqui.
-- As cartas de cada classe ficam em Cartas.luau (campo "classe").

local Classes = {}

Classes.ordem = { "cavaleiro", "mago", "arqueiro" }

Classes.dados = {
	cavaleiro = {
		id = "cavaleiro",
		nome = "Cavaleiro",
		titulo = "A Muralha de Aço",
		icone = "🛡️",
		cor = Color3.fromRGB(86, 156, 255),
		descricao = "Luta na linha de frente com espada e escudo. Aguenta muito dano e protege o grupo.",
		notas = { Vida = 5, Dano = 4, Alcance = 1, Velocidade = 2 },

		vida = 150,
		dano = 24,
		velocidade = 17,
		intervalo = 0.42,
		alcance = 9.5,
		armadura = 0.1,

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
			descricao = "Gira a espada por 2 segundos, acertando tudo ao redor.",
		},
		supremo = {
			id = "julgamento",
			nome = "Julgamento",
			icone = "⚡",
			descricao = "Esmaga o chão: dano enorme ao redor e atordoa os inimigos.",
		},
	},

	mago = {
		id = "mago",
		nome = "Mago",
		titulo = "O Arcano",
		icone = "🔮",
		cor = Color3.fromRGB(180, 96, 255),
		descricao = "Ataca de longe com orbes que explodem. Frágil, mas destrói grupos inteiros.",
		notas = { Vida = 2, Dano = 5, Alcance = 4, Velocidade = 2 },

		vida = 90,
		dano = 20,
		velocidade = 17,
		intervalo = 0.5,
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
			descricao = "Um meteoro cai no inimigo mais próximo da mira, com dano enorme em área.",
		},
		supremo = {
			id = "tempestade",
			nome = "Tempestade Arcana",
			icone = "🌩️",
			descricao = "Raios caem sem parar sobre os inimigos por 5 segundos.",
		},
	},

	arqueiro = {
		id = "arqueiro",
		nome = "Arqueiro",
		titulo = "O Olho do Bosque",
		icone = "🏹",
		cor = Color3.fromRGB(96, 214, 120),
		descricao = "Rápido e certeiro. Atira sem parar enquanto foge dos inimigos.",
		notas = { Vida = 3, Dano = 3, Alcance = 5, Velocidade = 5 },

		vida = 100,
		dano = 15,
		velocidade = 20,
		intervalo = 0.32,
		alcance = 60,
		armadura = 0,

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
			recarga = 10,
			descricao = "Flechas caem do céu numa área por 3 segundos.",
		},
		supremo = {
			id = "saraivada",
			nome = "Saraivada",
			icone = "💫",
			descricao = "Dispara flechas em todas as direções sem parar por 4 segundos.",
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
