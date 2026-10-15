-- Script principal do jogador: liga a interface, os efeitos, os controles e recebe as
-- mensagens do servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local modulos = script.Parent
local Estado = require(modulos.Estado)
local UI = require(modulos.UI)
local Vfx = require(modulos.Vfx)
local Ambiente = require(modulos.Ambiente)
local VisualInimigos = require(modulos.VisualInimigos)
local Controles = require(modulos.Controles)
local Hud = require(modulos.Hud)
local Menus = require(modulos.Menus)

local jogador = Players.LocalPlayer
local Remotos = ReplicatedStorage:WaitForChild("Remotos")
local Evento = Remotos:WaitForChild("Evento") :: RemoteEvent
local Acao = Remotos:WaitForChild("Acao") :: RemoteEvent

-- Esconde a barra de vida e a mochila padrão do Roblox (usamos as nossas)
for _, tipo in { Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(tipo, false)
	end)
end

-- Escala da interface acompanha o tamanho da tela
local function acompanharCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(UI.atualizarEscala)
	end
	UI.atualizarEscala()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(acompanharCamera)
acompanharCamera()

Ambiente.iniciar()
VisualInimigos.iniciar()
Hud.iniciar()
Menus.iniciar()
Controles.iniciar()
Controles.ligarBotoes(Hud.botoesToque)

Vfx.extras.salto = VisualInimigos.salto
Vfx.aoDanoLocal = Hud.danoLocal

Hud.aoAbrir = function(nome: string)
	if nome == "classe" then
		Menus.abrirClasses()
	elseif nome == "loja" then
		Menus.abrirLoja()
	else
		Menus.abrirAjuda()
	end
end

local mostrouClasses = false

local function voltarAoLobby()
	Estado.modo = "lobby"
	Estado.stats = nil
	Estado.cartas = {}
	Estado.aliados = {}
	Estado.caido = false
	Estado.morto = false
	Estado.carga = 0
	Estado.habilidadeFim = 0
	Ambiente.lobby()
	Ambiente.caido(false)
	Menus.fecharPartida()
	Hud.modo("lobby")
end

local manipuladores = {
	perfil = function(dados)
		Estado.perfil = dados
		Estado.avisar("perfil")
		if not dados.escolheuClasse and not mostrouClasses and Estado.modo == "lobby" then
			mostrouClasses = true
			task.delay(1, Menus.abrirClasses)
		end
	end,
	lobby = voltarAoLobby,
	fila = Hud.fila,
	inicioPartida = function(dados)
		Estado.modo = "partida"
		Estado.aliados = dados.aliados or {}
		Estado.cartas = {}
		Estado.ouroPartida = 0
		Estado.carga = 0
		Estado.caido = false
		Estado.morto = false
		Menus.fecharLobby()
		Hud.modo("partida")
		Estado.avisar("ouro")
		Estado.avisar("cartas")
	end,
	transicao = function()
		Hud.transicao(true)
	end,
	sala = function(dados)
		Estado.sala = dados
		Ambiente.masmorra(dados.tema)
		Hud.sala(dados)
		Hud.transicao(false)
	end,
	stats = function(dados)
		Estado.stats = dados
		Estado.carga = dados.carga or Estado.carga
		Estado.cargaMax = dados.cargaMax or Estado.cargaMax
		Estado.avisar("stats")
	end,
	carga = function(dados)
		Estado.carga = dados.valor
		Estado.cargaMax = dados.max
		Estado.avisar("carga")
	end,
	recarga = function(dados)
		if dados.tipo == "habilidade" then
			Estado.habilidadeFim = os.clock() + dados.restante
			Estado.habilidadeTotal = dados.total
		end
	end,
	ouro = function(dados)
		Estado.ouroPartida = dados.total
		Estado.avisar("ouro")
		Hud.ganhouOuro(dados.ganho)
	end,
	banner = function(dados)
		Hud.banner(dados.texto, dados.cor)
	end,
	aviso = function(dados)
		Hud.aviso(dados.texto)
	end,
	introChefe = Hud.introChefe,
	cartas = Menus.cartas,
	cartasFechar = Menus.fecharCartas,
	minhasCartas = function(dados)
		Estado.cartas = dados.cartas or {}
		Estado.avisar("cartas")
		Menus.cartaEscolhida()
	end,
	elevador = Menus.elevador,
	caiu = function()
		Estado.caido = true
		Controles.segurarAtaque(false)
		Hud.caiu()
		Ambiente.caido(true)
	end,
	levantou = function()
		Estado.caido = false
		Hud.levantou()
		Ambiente.caido(false)
	end,
	morreu = function()
		Estado.morto = true
		Estado.caido = false
		Controles.segurarAtaque(false)
		Ambiente.caido(false)
		Hud.morreu()
	end,
	reviveu = function()
		Estado.morto = false
		Estado.caido = false
		Ambiente.caido(false)
		Hud.reviveu()
	end,
	fimPartida = Menus.fim,
	abrirLoja = Menus.abrirLoja,
	vfx = Vfx.receber,
}

Evento.OnClientEvent:Connect(function(tipo: string, dados)
	local manipulador = manipuladores[tipo]
	if manipulador then
		manipulador(dados or {})
	end
end)

-- Ao renascer, a câmera volta para o próprio personagem
jogador.CharacterAdded:Connect(function(personagem)
	local humanoid = personagem:WaitForChild("Humanoid", 10)
	if humanoid then
		workspace.CurrentCamera.CameraSubject = humanoid
	end
end)

Hud.modo("lobby")
Acao:FireServer("pronto")
