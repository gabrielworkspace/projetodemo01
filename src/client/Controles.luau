-- Controles: segurar para atacar (mira no mouse; no celular mira sozinha no inimigo mais próximo),
-- habilidade (E), esquiva (Q), supremo (R) e os botões de toque no celular.

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

local Controles = {}

local jogador = Players.LocalPlayer
local Acao = ReplicatedStorage:WaitForChild("Remotos"):WaitForChild("Acao") :: RemoteEvent

local segurandoAtaque = false
local ultimoAtaque = 0
local comboLocal = 0
local ultimoFoiFinal = false
local mirandoAte = 0
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

local function podeLutar(): boolean
	return not Estado.caido and not Estado.morto and Estado.menusAbertos == 0
end

local function tentarAtacar()
	if not podeLutar() then
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
	comboLocal = comboLocal % 3 + 1
	ultimoFoiFinal = comboLocal == 3
	ultimoAtaque = agora

	local direcao = direcaoDaMira()
	mirar(direcao)
	Acao:FireServer("atacar", direcao)

	-- O próprio corte aparece na hora, sem esperar o servidor
	if naPartida then
		local classe = Classes.obter(stats.classe)
		if classe.ataque.tipo == "corte" then
			local final = comboLocal == 3
			Vfx.corte({
				jogador = jogador,
				pos = raiz.Position,
				dir = direcao,
				alcance = stats.alcance * (if final then 1.15 else 1),
				arco = stats.arco * (if final then 1.25 else 1),
				cor = classe.cor,
				combo = comboLocal,
			})
		end
	end
end

local function usarHabilidade()
	if Estado.modo ~= "partida" or not podeLutar() then
		return
	end
	if os.clock() < Estado.habilidadeFim - 0.1 then
		return
	end
	local direcao = direcaoDaMira()
	mirar(direcao)
	Acao:FireServer("habilidade", direcao)
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

	Vfx.esquiva({ jogador = jogador })
	Acao:FireServer("esquiva", direcao)
end

Controles.atacar = tentarAtacar
Controles.habilidade = usarHabilidade
Controles.supremo = usarSupremo
Controles.esquivar = esquivar

function Controles.segurarAtaque(segurando: boolean)
	segurandoAtaque = segurando
	if segurando then
		tentarAtacar()
	end
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
		end
	end)
	UserInputService.InputEnded:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.MouseButton1 or entrada.KeyCode == Enum.KeyCode.ButtonR2 then
			Controles.segurarAtaque(false)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if segurandoAtaque then
			tentarAtacar()
		end
		local raiz, humanoid = personagem()
		if not raiz or not humanoid then
			return
		end
		if os.clock() < mirandoAte and humanoid.Health > 0 and not Estado.caido then
			humanoid.AutoRotate = false
			raiz.CFrame = CFrame.lookAt(raiz.Position, raiz.Position + direcaoAtual)
			if segurandoAtaque then
				direcaoAtual = direcaoDaMira()
			end
		elseif not humanoid.AutoRotate then
			humanoid.AutoRotate = true
		end
	end)
end

return Controles
