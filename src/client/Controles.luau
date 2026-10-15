-- Controles: tocar para atacar (mira no mouse; no celular mira sozinha no inimigo mais próximo),
-- segurar para carregar e soltar para um golpe forte, habilidade (E), esquiva (Q), supremo (R),
-- defesa com escudo do Cavaleiro (F / botão direito / L2) e os botões de toque no celular.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Classes = require(Shared:WaitForChild("Classes"))

local modulos = script.Parent
local Estado = require(modulos.Estado)
local Vfx = require(modulos.Vfx)
local UI = require(modulos.UI)
local Animacoes = require(modulos.Animacoes)

local Controles = {}

local jogador = Players.LocalPlayer
local Acao = ReplicatedStorage:WaitForChild("Remotos"):WaitForChild("Acao") :: RemoteEvent

local segurandoAtaque = false
local segurouEm = 0
local carregando = false
local cargaComecou = 0
local defendendo = false
local ultimoAtaque = 0
local comboLocal = 0
local ultimoFoiFinal = false
local mirandoAte = 0
local esquivandoAte = 0
local direcaoAtual = Vector3.new(0, 0, -1)

local function planar(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function personagem()
	local p = jogador.Character
	local raiz = p and p:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = p and p:FindFirstChildOfClass("Humanoid")
	return raiz, humanoid
end

local function inimigoMaisProximo(origem: Vector3, alcance: number): Vector3?
	local melhor, melhorDistancia = nil, alcance
	for _, modelo in CollectionService:GetTagged("Inimigo") do
		local raiz = modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz then
			local distancia = planar(raiz.Position - origem).Magnitude
			if distancia < melhorDistancia then
				melhor, melhorDistancia = raiz.Position, distancia
			end
		end
	end
	return melhor
end

-- Para onde o ataque vai: o ponto do chão sob o mouse, ou o inimigo mais próximo
local function direcaoDaMira(): Vector3
	local raiz = personagem()
	if not raiz then
		return direcaoAtual
	end
	if UserInputService.MouseEnabled and not UI.ehCelular() and UserInputService:GetLastInputType() ~= Enum.UserInputType.Gamepad1 then
		local camera = workspace.CurrentCamera
		local mouse = UserInputService:GetMouseLocation()
		local raio = camera:ViewportPointToRay(mouse.X, mouse.Y)
		if math.abs(raio.Direction.Y) > 1e-3 then
			local t = (raiz.Position.Y - 2 - raio.Origin.Y) / raio.Direction.Y
			if t > 0 then
				local ponto = raio.Origin + raio.Direction * t
				local direcao = planar(ponto - raiz.Position)
				if direcao.Magnitude > 0.5 then
					return direcao.Unit
				end
			end
		end
	end
	local alvo = inimigoMaisProximo(raiz.Position, 60)
	if alvo then
		local direcao = planar(alvo - raiz.Position)
		if direcao.Magnitude > 0.1 then
			return direcao.Unit
		end
	end
	local olhar = planar(raiz.CFrame.LookVector)
	return if olhar.Magnitude > 0.1 then olhar.Unit else direcaoAtual
end

-- Vira o personagem para a mira por um instante (dá para andar e atirar para outro lado)
local function mirar(direcao: Vector3)
	direcaoAtual = direcao
	mirandoAte = os.clock() + 0.35
end

-- Empurra o próprio personagem (o movimento do personagem é feito neste computador)
local function impulso(direcao: Vector3, velocidade: number, duracao: number)
	local raiz = personagem()
	if not raiz then
		return
	end
	local anexo = Instance.new("Attachment")
	anexo.Parent = raiz
	local forca = Instance.new("LinearVelocity")
	forca.Attachment0 = anexo
	forca.MaxForce = 1e7
	forca.RelativeTo = Enum.ActuatorRelativeTo.World
	forca.VectorVelocity = direcao * velocidade
	forca.Parent = raiz
	Debris:AddItem(forca, duracao)
	Debris:AddItem(anexo, duracao)
end

-- Mago: tem mana para esta magia? (o servidor confere de novo; aqui é só para não animar à toa)
local function temMana(tipoCusto: string): boolean
	local stats = Estado.stats
	if Estado.modo ~= "partida" or not stats or (stats.manaMax or 0) <= 0 then
		return true
	end
	local custos = Classes.obter(stats.classe).custos
	local custo = if custos then (custos[tipoCusto] or 0) * (stats.custoMana or 1) else 0
	if Estado.mana < custo then
		Estado.avisar("semMana")
		return false
	end
	Estado.mana -= custo
	return true
end

local function podeLutar(): boolean
	return not Estado.caido and not Estado.morto and Estado.menusAbertos == 0
end

local function tentarAtacar()
	if not podeLutar() or defendendo then
		return
	end
	local raiz = personagem()
	if not raiz then
		return
	end
	local agora = os.clock()
	local stats = Estado.stats
	local naPartida = Estado.modo == "partida" and stats ~= nil
	local intervalo = if naPartida then stats.intervalo else 0.5
	local espera = intervalo * (if ultimoFoiFinal then 1.35 else 1)
	if agora - ultimoAtaque < espera then
		return
	end
	if agora - ultimoAtaque > intervalo * 2.6 + 0.3 then
		comboLocal = 0
	end
	if not temMana(if comboLocal % 3 + 1 == 3 then "final" else "ataque") then
		ultimoAtaque = agora - intervalo * 0.5 -- não fica repetindo o aviso a cada quadro
		return
	end
	comboLocal = comboLocal % 3 + 1
	ultimoFoiFinal = comboLocal == 3
	ultimoAtaque = agora

	local direcao = direcaoDaMira()
	mirar(direcao)
	Acao:FireServer("atacar", direcao, comboLocal)
	if jogador.Character then
		Animacoes.tocar(jogador.Character, "ataque", { combo = comboLocal })
	end

	-- O próprio corte aparece na hora, sem esperar o servidor
	if naPartida then
		local classe = Classes.obter(stats.classe)
		if classe.ataque.tipo == "corte" then
			-- o rastro do corte aparece quando a lâmina passa na frente (não no clique)
			local combo = comboLocal
			local final = combo == 3
			task.delay(classe.ataque.impacto and classe.ataque.impacto[combo] or 0, function()
				local raizAgora = personagem()
				if not raizAgora then
					return
				end
				Vfx.corte({
					jogador = jogador,
					pos = raizAgora.Position,
					dir = direcao,
					alcance = stats.alcance * (if final then 1.15 else 1),
					arco = stats.arco * (if final then 1.25 else 1),
					cor = classe.cor,
					combo = combo,
				})
			end)
		end
	end
end

------------------------------------------------------------------------
-- Ataque carregado: segurando o ataque, começa a carregar; ao soltar, sai o golpe forte
------------------------------------------------------------------------

local function comecarCarga()
	local stats = Estado.stats
	local custos = stats and Classes.obter(stats.classe).custos
	if custos and Estado.modo == "partida" and Estado.mana < custos.carregado * (stats.custoMana or 1) then
		Estado.avisar("semMana")
		segurouEm = os.clock() + 999 -- só tenta de novo ao segurar outra vez
		return
	end
	carregando = true
	cargaComecou = os.clock()
	Acao:FireServer("carregar")
	if jogador.Character then
		Animacoes.tocar(jogador.Character, "carregar", nil)
	end
end

local function cancelarCarga()
	if not carregando then
		return
	end
	carregando = false
	Acao:FireServer("cancelar")
	if jogador.Character then
		Animacoes.tocar(jogador.Character, "cancelar", nil)
	end
end

local function soltarCarga()
	if not carregando then
		return
	end
	local raiz = personagem()
	local duracao = os.clock() - cargaComecou
	if not raiz or not podeLutar() or duracao < Config.CARGA_ATAQUE_MIN then
		cancelarCarga()
		return
	end
	carregando = false
	local fracao = math.clamp((duracao - Config.CARGA_ATAQUE_MIN) / (Config.CARGA_ATAQUE_MAX - Config.CARGA_ATAQUE_MIN), 0, 1)
	local direcao = direcaoDaMira()
	mirar(direcao)
	Acao:FireServer("soltar", direcao)
	-- o golpe carregado encerra o combo (o próximo clique recomeça do primeiro golpe)
	comboLocal = 0
	ultimoAtaque = os.clock()
	ultimoFoiFinal = true
	if jogador.Character then
		Animacoes.tocar(jogador.Character, "soltar", { fracao = fracao })
	end

	local stats = Estado.stats
	if Estado.modo == "partida" and stats then
		local classe = Classes.obter(stats.classe)
		if classe.id == "cavaleiro" then
			Vfx.giroCarregado({
				jogador = jogador,
				raio = stats.alcance * (1.25 + 0.3 * fracao),
				cor = classe.cor,
				perfeito = fracao >= 0.99,
			})
		elseif classe.id == "assassino" then
			-- Investida Letal: dispara para frente (mesma distância que o servidor usa)
			local distancia = 12 + 6 * fracao
			Vfx.investidaLetal({ jogador = jogador, de = raiz.Position, ate = raiz.Position + direcao * distancia, cor = classe.cor, perfeito = fracao >= 0.99 })
			impulso(direcao, distancia / 0.2, 0.2)
			mirandoAte = os.clock() + 0.3
		else
			Vfx.tremer(0.4 + 0.6 * fracao, 0.15)
		end
	end
end

------------------------------------------------------------------------
-- Defesa com escudo (só o Cavaleiro)
------------------------------------------------------------------------

local function minhaClasse(): string
	return if Estado.stats then Estado.stats.classe else Estado.perfil.classe
end

local function defender(ativo: boolean)
	if ativo == defendendo then
		return
	end
	if ativo then
		if minhaClasse() ~= "cavaleiro" or not podeLutar() then
			return
		end
		cancelarCarga()
		defendendo = true
		Acao:FireServer("defender", true)
		if jogador.Character then
			Animacoes.tocar(jogador.Character, "defender", nil)
		end
	else
		defendendo = false
		Acao:FireServer("defender", false)
		if jogador.Character then
			Animacoes.tocar(jogador.Character, "pararDefesa", nil)
		end
	end
end
Controles.defender = defender

local function usarHabilidade()
	if Estado.modo ~= "partida" or not podeLutar() then
		return
	end
	if os.clock() < Estado.habilidadeFim - 0.1 then
		return
	end
	if not temMana("habilidade") then
		return
	end
	defender(false)
	local direcao = direcaoDaMira()
	mirar(direcao)
	Acao:FireServer("habilidade", direcao)
	-- Arqueiro: salta para trás antes da chuva de flechas
	local stats = Estado.stats
	if stats and stats.classe == "arqueiro" then
		impulso(-direcao, 70, 0.18)
	end
end

local function usarSupremo()
	if Estado.modo ~= "partida" or not podeLutar() or Estado.carga < Estado.cargaMax then
		return
	end
	Acao:FireServer("supremo")
end

local function esquivar()
	if Estado.caido or Estado.morto or Estado.menusAbertos > 0 then
		return
	end
	local raiz, humanoid = personagem()
	if not raiz or not humanoid or humanoid.Health <= 0 then
		return
	end
	local agora = os.clock()
	if agora < Estado.esquivaFim then
		return
	end
	-- esquivar cancela a carga e abaixa o escudo (segure de novo para recomeçar)
	cancelarCarga()
	defender(false)
	segurouEm = agora
	local recarga = if Estado.stats then Estado.stats.recargaEsquiva else Config.ESQUIVA_RECARGA
	Estado.esquivaFim = agora + recarga
	Estado.esquivaTotal = recarga
	Estado.avisar("recargas")

	local direcao = planar(humanoid.MoveDirection)
	if direcao.Magnitude < 0.1 then
		direcao = planar(raiz.CFrame.LookVector)
	end
	direcao = if direcao.Magnitude > 0.01 then direcao.Unit else Vector3.new(0, 0, -1)

	local anexo = Instance.new("Attachment")
	anexo.Parent = raiz
	local impulso = Instance.new("LinearVelocity")
	impulso.Attachment0 = anexo
	impulso.MaxForce = 1e7
	impulso.RelativeTo = Enum.ActuatorRelativeTo.World
	impulso.VectorVelocity = direcao * Config.ESQUIVA_VELOCIDADE
	impulso.Parent = raiz
	Debris:AddItem(impulso, Config.ESQUIVA_DURACAO)
	Debris:AddItem(anexo, Config.ESQUIVA_DURACAO)

	-- o corpo vira para onde vai, para a animação da esquiva fazer sentido
	direcaoAtual = direcao
	mirandoAte = agora + Config.ESQUIVA_DURACAO + 0.1
	esquivandoAte = mirandoAte
	if jogador.Character then
		Animacoes.tocar(jogador.Character, "esquiva", nil)
	end
	Acao:FireServer("esquiva", direcao)
end

Controles.atacar = tentarAtacar
Controles.habilidade = usarHabilidade
Controles.supremo = usarSupremo
Controles.esquivar = esquivar

function Controles.segurarAtaque(segurando: boolean)
	if segurando == segurandoAtaque then
		return
	end
	segurandoAtaque = segurando
	if segurando then
		segurouEm = os.clock()
		tentarAtacar()
	elseif carregando then
		soltarCarga()
	end
end

-- Para tudo sem disparar o golpe (ao cair, morrer, abrir menus...)
function Controles.pararAtaque()
	segurandoAtaque = false
	cancelarCarga()
	defender(false)
end

-- Liga os botões de toque criados pelo HUD
function Controles.ligarBotoes(botoes)
	local function aoTocar(botao: GuiButton, comecar: () -> (), terminar: (() -> ())?)
		botao.InputBegan:Connect(function(entrada)
			if entrada.UserInputType == Enum.UserInputType.Touch or entrada.UserInputType == Enum.UserInputType.MouseButton1 then
				comecar()
			end
		end)
		if terminar then
			botao.InputEnded:Connect(function(entrada)
				if entrada.UserInputType == Enum.UserInputType.Touch or entrada.UserInputType == Enum.UserInputType.MouseButton1 then
					terminar()
				end
			end)
		end
	end
	aoTocar(botoes.ataque, function()
		Controles.segurarAtaque(true)
	end, function()
		Controles.segurarAtaque(false)
	end)
	aoTocar(botoes.habilidade, usarHabilidade)
	aoTocar(botoes.esquiva, esquivar)
	aoTocar(botoes.supremo, usarSupremo)
	if botoes.defesa then
		aoTocar(botoes.defesa, function()
			defender(true)
		end, function()
			defender(false)
		end)
	end
end

function Controles.iniciar()
	UserInputService.InputBegan:Connect(function(entrada, processado)
		if processado then
			return
		end
		local tipo, tecla = entrada.UserInputType, entrada.KeyCode
		if tipo == Enum.UserInputType.MouseButton1 or tecla == Enum.KeyCode.ButtonR2 then
			Controles.segurarAtaque(true)
		elseif tecla == Enum.KeyCode.E or tecla == Enum.KeyCode.ButtonX then
			usarHabilidade()
		elseif tecla == Enum.KeyCode.Q or tecla == Enum.KeyCode.ButtonB then
			esquivar()
		elseif tecla == Enum.KeyCode.R or tecla == Enum.KeyCode.ButtonY then
			usarSupremo()
		elseif tecla == Enum.KeyCode.F or tecla == Enum.KeyCode.ButtonL2 or tipo == Enum.UserInputType.MouseButton2 then
			defender(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.MouseButton1 or entrada.KeyCode == Enum.KeyCode.ButtonR2 then
			Controles.segurarAtaque(false)
		elseif entrada.KeyCode == Enum.KeyCode.F or entrada.KeyCode == Enum.KeyCode.ButtonL2 or entrada.UserInputType == Enum.UserInputType.MouseButton2 then
			defender(false)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local agora = os.clock()
		if defendendo then
			-- o escudo acompanha a mira (protege o lado para onde você aponta)
			if not podeLutar() or minhaClasse() ~= "cavaleiro" then
				defender(false)
			else
				direcaoAtual = direcaoDaMira()
				mirandoAte = math.max(mirandoAte, agora + 0.1)
			end
		end
		if carregando then
			local _, humanoidAtual = personagem()
			if not podeLutar() or not humanoidAtual or humanoidAtual.Health <= 0 then
				cancelarCarga()
			else
				-- enquanto carrega, o corpo acompanha a mira
				mirandoAte = math.max(mirandoAte, agora + 0.1)
			end
		elseif segurandoAtaque and not defendendo and agora - segurouEm >= Config.CARGA_ATAQUE_COMECA and podeLutar() and personagem() then
			comecarCarga()
		end
		local raiz, humanoid = personagem()
		if not raiz or not humanoid then
			return
		end
		if agora < mirandoAte and humanoid.Health > 0 and not Estado.caido then
			humanoid.AutoRotate = false
			raiz.CFrame = CFrame.lookAt(raiz.Position, raiz.Position + direcaoAtual)
			if segurandoAtaque and agora >= esquivandoAte then
				direcaoAtual = direcaoDaMira()
			end
		elseif not humanoid.AutoRotate then
			humanoid.AutoRotate = true
		end
	end)
end

return Controles
