-- Cartas de poder (11 universais e 11 de cada classe). "classe = nil" aparece para todos; as outras só para aquela classe.
-- "efeitos" soma valores aos atributos do jogador (veja Combate.calcularStats no servidor).

local Cartas = {}

local function carta(id, nome, icone, raridade, classe, maxPilha, descricao, efeitos)
	return {
		id = id,
		nome = nome,
		icone = icone,
		raridade = raridade,
		classe = classe,
		maxPilha = maxPilha,
		descricao = descricao,
		efeitos = efeitos,
	}
end

Cartas.lista = {
	-- Universais ------------------------------------------------------------
	carta("coracao", "Coração Forte", "❤️", "Comum", nil, 8, "+25 de vida máxima e cura total", { vidaPlana = 25 }),
	carta("forca", "Força Bruta", "💪", "Comum", nil, 8, "+15% de dano", { danoPct = 0.15 }),
	carta("botas", "Botas Ligeiras", "👟", "Comum", nil, 4, "+10% de velocidade", { velocidadePct = 0.1 }),
	carta("regen", "Regeneração", "🌿", "Comum", nil, 5, "Recupera 1,5 de vida por segundo", { regen = 1.5 }),
	carta("vampiro", "Vampirismo", "🦇", "Rara", nil, 4, "Cada acerto cura 2 de vida", { rouboVida = 2 }),
	carta("critico", "Olhar Mortal", "🎯", "Rara", nil, 4, "+12% de chance de crítico (dano triplo)", { critico = 0.12 }),
	carta("ampulheta", "Ampulheta", "⏳", "Rara", nil, 3, "A habilidade recarrega 15% mais rápido", { recargaPct = 0.15 }),
	carta("brasa", "Coração em Brasa", "🔥", "Rara", nil, 3, "O Supremo carrega 30% mais rápido", { cargaPct = 0.3 }),
	carta("ganancia", "Ganância", "💰", "Rara", nil, 3, "+50% de ouro, mas -15 de vida máxima", { ouroPct = 0.5, vidaPlana = -15 }),
	carta("segunda", "Segunda Chance", "👼", "Lendaria", nil, 1, "Ao cair, levanta na hora com metade da vida (uma vez)", { segundaChance = 1 }),
	carta("midas", "Rei Midas", "👑", "Lendaria", nil, 1, "Dobra todo o ouro que você ganha", { ouroMult = 1 }),

	-- Cavaleiro ------------------------------------------------------------
	carta("laminaLarga", "Lâmina Larga", "🗡️", "Comum", "cavaleiro", 4, "+25% de alcance dos cortes", { alcancePct = 0.25 }),
	carta("ritmo", "Ritmo de Batalha", "🥁", "Comum", "cavaleiro", 5, "Ataca 15% mais rápido", { ataqueVelPct = 0.15 }),
	carta("armadura", "Armadura Pesada", "🧱", "Comum", "cavaleiro", 4, "Recebe 10% menos dano", { armadura = 0.1 }),
	carta("espinhos", "Espinhos", "🌵", "Rara", "cavaleiro", 3, "Quem te acerta leva o mesmo dano de volta", { espinhos = 1 }),
	carta("investida", "Investida Brutal", "🐗", "Rara", "cavaleiro", 2, "Sua esquiva atropela os inimigos no caminho", { investida = 1 }),
	carta("escudo", "Escudo Abençoado", "🛡️", "Epica", "cavaleiro", 1, "Bloqueia o primeiro golpe que você leva em cada sala", { escudo = 1 }),
	carta("ondaCorte", "Onda de Corte", "🌊", "Epica", "cavaleiro", 2, "O golpe final do combo solta uma onda de energia", { ondaCorte = 1 }),
	carta("redemoinhoFogo", "Redemoinho Flamejante", "🌪️", "Epica", "cavaleiro", 1, "O Redemoinho dura 50% a mais e queima os inimigos", { redemoinhoFogo = 1 }),
	carta("gigante", "Gigante", "🗿", "Epica", "cavaleiro", 2, "Fica 30% maior: +50 de vida e +20% de alcance, mas 8% mais lento", { gigante = 1 }),
	carta("dragao", "Fúria do Dragão", "🐉", "Lendaria", "cavaleiro", 1, "Todo golpe solta uma rajada de fogo à frente", { dragao = 1 }),
	carta("protetor", "Aura do Protetor", "✨", "Lendaria", "cavaleiro", 1, "Aliados perto de você recebem 30% menos dano", { protetor = 1 }),

	-- Mago -----------------------------------------------------------------
	carta("orbeMaior", "Orbe Maior", "🔮", "Comum", "mago", 4, "+20% de dano e orbes maiores", { danoPct = 0.2, tamanhoPct = 0.2 }),
	carta("canalizacao", "Canalização", "🌀", "Comum", "mago", 5, "Lança orbes 15% mais rápido", { ataqueVelPct = 0.15 }),
	carta("explosaoArcana", "Explosão Arcana", "💠", "Comum", "mago", 3, "A explosão dos orbes fica 40% maior", { explosaoPct = 0.4 }),
	carta("missil", "Míssil Duplo", "🎆", "Rara", "mago", 2, "+1 orbe por ataque", { projeteisExtra = 1 }),
	carta("gelo", "Toque Gélido", "❄️", "Rara", "mago", 2, "Orbes deixam os inimigos 35% mais lentos", { lentidao = 1 }),
	carta("barreira", "Barreira Arcana", "🌐", "Epica", "mago", 1, "Bloqueia o primeiro golpe que você leva em cada sala", { escudo = 1 }),
	carta("raio", "Corrente Elétrica", "⚡", "Epica", "mago", 3, "Cada acerto solta raios em 2 inimigos próximos", { raios = 2 }),
	carta("chuvaMeteoros", "Chuva de Meteoros", "☄️", "Epica", "mago", 2, "O Meteoro cai mais 2 vezes", { meteoros = 2 }),
	carta("perfurante", "Orbe Perfurante", "📌", "Epica", "mago", 2, "Orbes atravessam mais 2 inimigos", { perfuracao = 2 }),
	carta("combustao", "Combustão", "💥", "Lendaria", "mago", 1, "Inimigos explodem ao morrer e ferem os vizinhos", { explosaoMorte = 1 }),
	carta("arquimago", "Arquimago", "🧙", "Lendaria", "mago", 1, "Cada inimigo derrotado reduz 1s da recarga da habilidade", { arquimago = 1 }),

	-- Arqueiro ---------------------------------------------------------------
	carta("pontaAfiada", "Ponta Afiada", "📍", "Comum", "arqueiro", 5, "+15% de dano", { danoPct = 0.15 }),
	carta("maoRapida", "Mão Rápida", "🤚", "Comum", "arqueiro", 5, "Atira 15% mais rápido", { ataqueVelPct = 0.15 }),
	carta("passosLeves", "Passos Leves", "🍃", "Comum", "arqueiro", 3, "+10% de velocidade e esquiva 25% mais rápida", { velocidadePct = 0.1, esquivaPct = 0.25 }),
	carta("multiplo", "Tiro Múltiplo", "🎇", "Rara", "arqueiro", 3, "+2 flechas em leque", { projeteisExtra = 2 }),
	carta("perfurantes", "Flechas Perfurantes", "➡️", "Rara", "arqueiro", 3, "Flechas atravessam mais 1 inimigo", { perfuracao = 1 }),
	carta("flechasFogo", "Flechas de Fogo", "🔥", "Rara", "arqueiro", 3, "Flechas queimam o inimigo por 3 segundos", { queimadura = 0.3 }),
	carta("aguia", "Olho de Águia", "🦅", "Rara", "arqueiro", 3, "+10% de crítico e flechas mais velozes", { critico = 0.1, velProjPct = 0.25 }),
	carta("ricochete", "Ricochete", "↪️", "Epica", "arqueiro", 2, "Flechas quicam em mais 2 inimigos", { ricochete = 2 }),
	carta("torrencial", "Chuva Torrencial", "🌧️", "Epica", "arqueiro", 2, "A Chuva de Flechas fica 40% maior e dura mais", { chuvaPct = 0.4 }),
	carta("fantasma", "Tiro Fantasma", "👻", "Lendaria", "arqueiro", 1, "O golpe final do combo dispara uma flecha gigante que atravessa tudo", { fantasma = 1 }),
	carta("cacador", "Caçador", "🏹", "Lendaria", "arqueiro", 1, "Críticos causam 5x de dano em vez de 3x", { multCritico = 2 }),

	-- Assassino --------------------------------------------------------------
	carta("laminasAfiadas", "Lâminas Afiadas", "🔪", "Comum", "assassino", 5, "+15% de dano", { danoPct = 0.15 }),
	carta("reflexos", "Reflexos", "⚡", "Comum", "assassino", 5, "Ataca 15% mais rápido", { ataqueVelPct = 0.15 }),
	carta("sombraAgil", "Sombra Ágil", "💨", "Comum", "assassino", 3, "+10% de velocidade e esquiva 20% mais rápida", { velocidadePct = 0.1, esquivaPct = 0.2 }),
	carta("venenoAdagas", "Lâminas Envenenadas", "🧪", "Rara", "assassino", 3, "Cada golpe envenena o inimigo por 3 segundos", { queimadura = 0.35 }),
	carta("pontoFraco", "Ponto Fraco", "🎯", "Rara", "assassino", 3, "Golpes pelas costas causam +40% de dano", { costasPct = 0.4 }),
	carta("sangria", "Sangria", "🩸", "Rara", "assassino", 3, "Críticos curam 4 de vida", { curaCritico = 4 }),
	carta("sombraPersistente", "Sombra Persistente", "🌑", "Epica", "assassino", 2, "O Passo Sombrio recarga 30% mais rápido", { recargaPct = 0.3 }),
	carta("lequeAdagas", "Leque de Adagas", "🎴", "Epica", "assassino", 2, "O golpe final do combo arremessa 3 adagas em leque", { leque = 1 }),
	carta("contraAtaque", "Contra-Ataque", "🔄", "Epica", "assassino", 1, "Depois de esquivar, o próximo golpe é crítico garantido", { contraAtaque = 1 }),
	carta("execucao", "Execução", "☠️", "Lendaria", "assassino", 1, "Golpes acabam na hora com inimigos abaixo de 20% de vida (chefes levam dano dobrado)", { execucao = 1 }),
	carta("milCortes", "Mil Cortes", "🌸", "Lendaria", "assassino", 1, "Cada crítico tira 0,5s da recarga do Passo Sombrio", { milCortes = 1 }),
}

Cartas.porId = {}
for _, c in Cartas.lista do
	Cartas.porId[c.id] = c
end

return Cartas
