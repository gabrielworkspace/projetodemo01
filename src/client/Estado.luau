-- Estado compartilhado entre as partes da interface do jogador.
-- Quem muda algo chama Estado.avisar("nome") e quem desenha escuta Estado.Mudou.

local Estado = {
	perfil = { ouro = 0, recorde = 0, melhorias = {}, classe = "cavaleiro", escolheuClasse = false },
	modo = "lobby", -- "lobby" ou "partida"
	stats = nil, -- atributos da partida (vêm do servidor)
	cartas = {},
	aliados = {},
	ouroPartida = 0,
	carga = 0,
	cargaMax = 100,
	habilidadeFim = 0,
	habilidadeTotal = 1,
	esquivaFim = 0,
	esquivaTotal = 1,
	caido = false,
	morto = false,
	sala = nil,
	menusAbertos = 0,
}

local evento = Instance.new("BindableEvent")
Estado.Mudou = evento.Event

function Estado.avisar(chave: string)
	evento:Fire(chave)
end

return Estado
