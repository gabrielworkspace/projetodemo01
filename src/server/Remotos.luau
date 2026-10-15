-- Canais de comunicação entre servidor e jogadores.
-- Evento: servidor -> jogador (tipo, dados). Acao: jogador -> servidor (tipo, dados).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotos = {}

local pasta = Instance.new("Folder")
pasta.Name = "Remotos"

local evento = Instance.new("RemoteEvent")
evento.Name = "Evento"
evento.Parent = pasta

local acao = Instance.new("RemoteEvent")
acao.Name = "Acao"
acao.Parent = pasta

pasta.Parent = ReplicatedStorage

Remotos.Evento = evento
Remotos.Acao = acao

function Remotos.enviar(player: Player, tipo: string, dados: any?)
	if player.Parent then
		evento:FireClient(player, tipo, dados or {})
	end
end

function Remotos.enviarParaTodos(tipo: string, dados: any?)
	evento:FireAllClients(tipo, dados or {})
end

return Remotos
