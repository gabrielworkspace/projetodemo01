-- Relíquias: tesouros achados explorando a masmorra (baús no chão, nas sacadas, nas torres e
-- o relicário que o mini-chefe guarda). Cada jogador sorteia a própria e fica com ela até o fim
-- da partida. Não acumulam: cada relíquia só uma vez por jogador.
-- "efeitos" usa as mesmas chaves das cartas (Combate.calcularStats) e mais três próprias:
--   resistMaldicao  = fração a menos no tempo das maldições (soma, até 90%)
--   imuneMaldicao   = maldições não pegam mais
--   resistArmadilha = fração a menos no dano das armadilhas (soma, até 80%)

local Reliquias = {}

local function reliquia(id, nome, icone, raridade, descricao, efeitos)
	return { id = id, nome = nome, icone = icone, raridade = raridade, descricao = descricao, efeitos = efeitos }
end

Reliquias.lista = {
	-- Comuns
	reliquia("amuletoOsso", "Amuleto de Osso", "🦴", "Comum", "Maldições duram 25% menos", { resistMaldicao = 0.25 }),
	reliquia("anelPedra", "Anel de Pedra", "💍", "Comum", "+15 de vida máxima e 4% menos dano recebido", { vidaPlana = 15, armadura = 0.04 }),
	reliquia("botasCouro", "Botas de Couro Velho", "🥾", "Comum", "+6% de velocidade e 30% menos dano de armadilhas", { velocidadePct = 0.06, resistArmadilha = 0.3 }),
	reliquia("frascoErvas", "Frasco de Ervas", "🧪", "Comum", "Recupera 1 de vida por segundo", { regen = 1 }),
	-- Raras
	reliquia("seloEsmeralda", "Selo Esmeralda", "💚", "Rara", "Maldições duram 50% menos e +5% de dano", { resistMaldicao = 0.5, danoPct = 0.05 }),
	reliquia("lanternaAlmas", "Lanterna das Almas", "🏮", "Rara", "+8% de crítico e maldições duram 20% menos", { critico = 0.08, resistMaldicao = 0.2 }),
	reliquia("manoplaCarcereiro", "Manopla do Carcereiro", "🧤", "Rara", "+12% de dano", { danoPct = 0.12 }),
	reliquia("capaSombra", "Capa da Sombra", "🧥", "Rara", "Esquiva recarrega 20% mais rápido e 50% menos dano de armadilhas", { esquivaPct = 0.2, resistArmadilha = 0.5 }),
	-- Épicas
	reliquia("coracaoPurificado", "Coração Purificado", "💠", "Epica", "Maldições duram 75% menos e +30 de vida máxima", { resistMaldicao = 0.75, vidaPlana = 30 }),
	reliquia("olhoCeifador", "Olho do Ceifador", "👁️", "Epica", "Cada acerto cura 2 de vida e +10% de crítico", { rouboVida = 2, critico = 0.1 }),
	reliquia("tomoProibido", "Tomo Proibido", "📕", "Epica", "Habilidade recarrega 20% mais rápido e o Supremo carrega 25% mais rápido", { recargaPct = 0.2, cargaPct = 0.25 }),
	-- Lendárias
	reliquia("coroaReiCaido", "Coroa do Rei Caído", "👑", "Lendaria", "IMUNE às maldições e +15% de dano", { imuneMaldicao = 1, danoPct = 0.15 }),
	reliquia("caliceEterno", "Cálice Eterno", "🏆", "Lendaria", "+60 de vida máxima, recupera 2,5 de vida por segundo e imune a armadilhas", { vidaPlana = 60, regen = 2.5, resistArmadilha = 1 }),
}

Reliquias.porId = {}
for _, r in Reliquias.lista do
	Reliquias.porId[r.id] = r
end

-- Chance de cada raridade por tipo de baú (somam 100)
Reliquias.BAUS = {
	chao = { nome = "Baú Antigo", Comum = 70, Rara = 27, Epica = 3, Lendaria = 0 },
	alto = { nome = "Baú Esquecido", Comum = 20, Rara = 55, Epica = 22, Lendaria = 3 },
	torre = { nome = "Baú da Atalaia", Comum = 0, Rara = 45, Epica = 45, Lendaria = 10 },
	relicario = { nome = "Relicário do Carcereiro", Comum = 0, Rara = 15, Epica = 60, Lendaria = 25 },
	chefe = { nome = "Tesouro do Senhor da Guerra", Comum = 0, Rara = 0, Epica = 65, Lendaria = 35 },
}

return Reliquias
