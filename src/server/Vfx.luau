-- Efeitos visuais: o servidor só avisa o que aconteceu e cada jogador desenha o efeito
-- no próprio computador (fica suave e não pesa na rede). Os desenhos ficam em Client/Vfx.

local Remotos = require(script.Parent.Remotos)

local Vfx = {}

-- Envia um efeito para todos os jogadores de uma partida (menos "exceto", se informado)
function Vfx.partida(run, tipo: string, dados, exceto: Player?)
	dados.t = tipo
	for player in run.jogadores do
		if player ~= exceto then
			Remotos.enviar(player, "vfx", dados)
		end
	end
end

-- Envia um efeito para todo mundo no servidor (usado no lobby)
function Vfx.todos(tipo: string, dados)
	dados.t = tipo
	Remotos.enviarParaTodos("vfx", dados)
end

return Vfx
