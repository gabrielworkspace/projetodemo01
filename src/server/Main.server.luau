-- Script principal do servidor: monta o lobby e cuida da entrada e saída dos jogadores.

local Players = game:GetService("Players")

-- Os personagens são criados pelo nosso código (para controlar mortes e renascimentos)
Players.CharacterAutoLoads = false

local servidor = script.Parent
local Remotos = require(servidor.Remotos)
local Dados = require(servidor.Dados)
local Partida = require(servidor.Partida)
local Lobby = require(servidor.Lobby)

Lobby.construir()
task.spawn(Lobby.iniciarFila)

local function aoEntrar(player: Player)
	local perfil = Dados.carregar(player)
	if not perfil or not player.Parent then
		return
	end

	player.CharacterAdded:Connect(function(personagem)
		local humanoid = personagem:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		if not Partida.emPartida(player) then
			task.defer(Lobby.vestirClasse, player)
		end
		-- Mortes no lobby: renasce em 3 segundos. Mortes na masmorra são tratadas pela Partida.
		humanoid.Died:Connect(function()
			if Partida.emPartida(player) then
				return
			end
			task.delay(3, function()
				if player.Parent and player.Character == personagem and not Partida.emPartida(player) then
					player:LoadCharacterAsync()
				end
			end)
		end)
	end)

	player:LoadCharacterAsync()
	Dados.enviarPerfil(player)
	Remotos.enviar(player, "lobby", {})
end

Players.PlayerAdded:Connect(aoEntrar)
for _, player in Players:GetPlayers() do
	task.spawn(aoEntrar, player)
end

Players.PlayerRemoving:Connect(function(player)
	Partida.removerJogador(player)
	Dados.salvarERemover(player)
end)

game:BindToClose(function()
	Dados.salvarTodos()
end)

local ACOES_DE_COMBATE = { atacar = true, carregar = true, soltar = true, cancelar = true, defender = true, habilidade = true, esquiva = true, supremo = true }

Remotos.Acao.OnServerEvent:Connect(function(player, tipo, dados, extra)
	if type(tipo) ~= "string" then
		return
	end
	if ACOES_DE_COMBATE[tipo] then
		Partida.acaoDeCombate(player, tipo, dados, extra)
	elseif tipo == "pronto" then
		Dados.enviarPerfil(player)
		if not Partida.emPartida(player) then
			Remotos.enviar(player, "lobby", {})
		end
	elseif tipo == "escolherClasse" then
		Lobby.escolherClasse(player, dados)
	elseif tipo == "escolherCarta" then
		Partida.escolherCarta(player, dados)
	elseif tipo == "elevador" then
		Partida.escolherElevador(player, dados)
	elseif tipo == "comprarMelhoria" then
		if Partida.emPartida(player) then
			return
		end
		local _, mensagem = Dados.comprarMelhoria(player, dados)
		Remotos.enviar(player, "aviso", { texto = mensagem })
		Dados.enviarPerfil(player)
	end
end)
