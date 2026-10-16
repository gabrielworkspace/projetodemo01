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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

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
		-- a esquiva é um rolamento: mais lenta e mais longa, mas cobre a mesma distância
		esquiva = { velocidade = 44, duracao = 0.3 },

		ataque = {
			tipo = "corte",
			arco = 140,
			combo = { 1, 1.1, 1.9 }, -- o terceiro golpe é o finalizador: um giro que acerta em volta
			impacto = { 0.13, 0.13, 0.24 }, -- quando a lâmina chega no alvo em cada golpe (segundos)
			preparo = 1.8, -- golpes pesados: preparação 80% mais longa (veja Config.PREPARO_GOLPE)
			nome = "Combo de Espada",
			icone = "⚔️",
		},
		habilidade = {
			id = "redemoinho",
			nome = "Redemoinho",
			icone = "🌀",
			recarga = 8,
			descricao = "Uma tempestade de cortes em volta dele por 2s, puxando os inimigos. Recebe 40% menos dano enquanto gira.",
		},
		supremo = {
			id = "julgamento",
			nome = "Julgamento",
			icone = "⚡",
			descricao = "Um raio cai do céu: atordoa todos ao redor, dá um escudo aos aliados próximos e, por 10s, brilha e recebe 10% menos dano.",
		},
	},

	mago = {
		id = "mago",
		nome = "Mago",
		titulo = "O Arcano",
		icone = "🔮",
		cor = Color3.fromRGB(180, 96, 255),
		descricao = "Ataca de longe com orbes que explodem e controla o campo com fogo e raios.",
		forte = "Enorme dano em área, magias de fogo, gelo e arcano",
		fraco = "Pouca vida, defesa baixa (leva 10% a mais de dano) e depende de mana",
		notas = { Vida = 1, Dano = 5, Alcance = 4, Velocidade = 2 },

		vida = 70,
		dano = 25,
		velocidade = 17,
		intervalo = 0.52,
		alcance = 50,
		armadura = -0.1, -- defesa baixa: leva 10% a mais de dano
		-- Mana: toda magia gasta mana, que volta sozinha com o tempo
		mana = 100,
		manaRegen = 9, -- por segundo (mais devagar: precisa escolher bem as magias)
		danoEmArea = 1.15, -- explosões, meteoro e tempestade causam 15% a mais
		custos = { ataque = 7, final = 14, carregado = 22, habilidade = 30 },

		ataque = {
			tipo = "projetil",
			projetil = "orbe",
			velocidade = 62,
			raio = 1.3,
			explosao = 4,
			combo = { 1, 1, 1.7 },
			impacto = { 0.15, 0.15, 0.28 },
			preparo = 1.5,
			nome = "Dardo, Gelo e Fogo",
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
		dano = 22, -- cada tiro tira a flecha da aljava: mais lento, mas mais forte
		velocidade = 20,
		intervalo = 0.5,
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
			impacto = { 0.26, 0.26, 0.34 },
			preparo = 1.25, -- já tem o ciclo de pegar a flecha na aljava
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
		descricao = "Duas adagas que fazem sangrar, muitos críticos e golpes pelas costas.",
		forte = "Sangramento, críticos, o mais rápido de todos",
		fraco = "Defesa baixa: leva 15% a mais de dano; pouca vida",
		notas = { Vida = 1, Dano = 5, Alcance = 1, Velocidade = 5 },

		vida = 85,
		dano = 15,
		velocidade = 23,
		intervalo = 0.26,
		alcance = 7.5,
		armadura = -0.15, -- defesa baixa: leva mais dano
		-- cada golpe abre um corte: o inimigo sangra (acumula até maxPilhas vezes)
		sangramento = { dps = 0.14, duracao = 4, maxPilhas = 5 },
		critico = 0.15,
		esquivaMult = 0.7,
		ameacaMult = 0.6,

		ataque = {
			tipo = "corte",
			arco = 95,
			combo = { 1, 1, 2.4 },
			impacto = { 0.09, 0.09, 0.2 },
			preparo = 1.6,
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

-- Preparação dos golpes: "impacto" passa a ser o momento real (mais tarde); o original fica em
-- "impactoBase" (é nele que estão os quadros da animação, que Animacoes estica só na preparação)
for _, classe in Classes.dados do
	local ataque = classe.ataque
	local fator = ataque.preparo or Config.PREPARO_GOLPE or 1
	ataque.preparoFator = fator
	ataque.impactoBase = ataque.impacto
	if ataque.impacto then
		local atrasado = {}
		for i, momento in ataque.impacto do
			atrasado[i] = momento * fator
		end
		ataque.impacto = atrasado
	end
end

-- Tempo a mais que cada golpe leva por causa da preparação mais longa
function Classes.atrasoDoPreparo(classe, combo: number): number
	local base = classe.ataque.impactoBase
	return if base then (base[combo] or 0) * ((classe.ataque.preparoFator or 1) - 1) else 0
end

function Classes.obter(id: string?)
	return Classes.dados[id or ""] or Classes.dados.cavaleiro
end

function Classes.existe(id: any): boolean
	return type(id) == "string" and Classes.dados[id] ~= nil
end

return Classes
