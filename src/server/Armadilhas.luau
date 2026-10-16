-- Armadilhas da sala de exploração (montadas em Masmorra.luau): espinhos que sobem do chão e
-- respiradouros que soltam um jato de fogo. Elas avisam antes (a placa esquenta e as pontas
-- aparecem; a grade solta fagulhas) e só machucam os jogadores. Quem pula por cima, dá a
-- esquiva na hora ou tem relíquias contra armadilhas (resistArmadilha) se livra.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local servidor = script.Parent
local Vfx = require(servidor.Vfx)
local Combate = require(servidor.Combate)

local Armadilhas = {}

local COR_QUENTE = Color3.fromRGB(226, 104, 70)

-- Jogadores de pé em cima da armadilha (e perto do chão: quem pulou alto escapa)
local function jogadoresEmCima(run, armadilha, alturaMaxima: number)
	local lista = {}
	local chao = run.sala.origem.Y
	for _, estado in run.jogadores do
		if estado.vivo and not estado.caido then
			local personagem = estado.player.Character
			local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
			if raiz and raiz:IsA("BasePart") then
				local d = raiz.Position - armadilha.centro
				if math.abs(d.X) < armadilha.meio.X + 0.8 and math.abs(d.Z) < armadilha.meio.Z + 0.8 and raiz.Position.Y - chao < alturaMaxima then
					table.insert(lista, estado)
				end
			end
		end
	end
	return lista
end

local function ferir(run, estado, armadilha, base: number, opcoes)
	local resistencia = estado.stats.resistArmadilha or 0
	if resistencia >= 1 then
		return
	end
	local dano = base * (run.mult and run.mult.dano or 1) * (1 - resistencia)
	opcoes.ambiente = true
	opcoes.origem = armadilha.centro
	Combate.danoAoJogador(run, estado, dano, nil, opcoes)
end

local function ativa(run, sala): boolean
	return run.ativa and run.sala == sala and sala.modelo.Parent ~= nil
end

local function moverEspinhos(armadilha, altura: number, tempo: number, estilo: Enum.EasingStyle)
	for _, info in armadilha.pecas do
		local peca, repouso = info[1], info[2]
		if peca.Parent then
			TweenService:Create(peca, TweenInfo.new(tempo, estilo, Enum.EasingDirection.Out), { CFrame = repouso + Vector3.new(0, altura, 0) }):Play()
		end
	end
end

local function cicloEspinhos(run, sala, armadilha)
	local info = Config.EXPLORACAO
	while ativa(run, sala) do
		task.wait(2.4)
		if not ativa(run, sala) then
			return
		end
		-- aviso: a placa esquenta e as pontas aparecem
		TweenService:Create(armadilha.placa, TweenInfo.new(0.6), { Color = COR_QUENTE }):Play()
		moverEspinhos(armadilha, 1.1, 0.25, Enum.EasingStyle.Quad)
		Vfx.partida(run, "armadilha", { tipo = "espinhosAviso", pos = armadilha.centro })
		task.wait(0.7)
		if not ativa(run, sala) then
			return
		end
		-- os espinhos sobem de uma vez
		moverEspinhos(armadilha, 2.9, 0.08, Enum.EasingStyle.Linear)
		Vfx.partida(run, "armadilha", { tipo = "espinhos", pos = armadilha.centro })
		local feridos = {}
		local fim = os.clock() + 0.9
		while os.clock() < fim and ativa(run, sala) do
			for _, estado in jogadoresEmCima(run, armadilha, 4.5) do
				if not feridos[estado] then
					feridos[estado] = true
					ferir(run, estado, armadilha, info.danoEspinhos, { lento = { duracao = 1.2, fator = 0.6 } })
				end
			end
			task.wait(0.1)
		end
		moverEspinhos(armadilha, 0, 0.45, Enum.EasingStyle.Quad)
		TweenService:Create(armadilha.placa, TweenInfo.new(0.6), { Color = armadilha.corPlaca }):Play()
	end
end

local function cicloFogo(run, sala, armadilha)
	local info = Config.EXPLORACAO
	local function ligar(emissores: Instance?, ligado: boolean)
		if emissores then
			for _, e in emissores:GetChildren() do
				if e:IsA("ParticleEmitter") then
					e.Enabled = ligado
				end
			end
		end
	end
	while ativa(run, sala) do
		task.wait(3.4)
		if not ativa(run, sala) then
			return
		end
		-- aviso: a grade solta mais fagulhas e começa a brilhar
		if armadilha.brasas then
			for _, e in armadilha.brasas:GetChildren() do
				if e:IsA("ParticleEmitter") then
					e.Rate *= 4
				end
			end
		end
		TweenService:Create(armadilha.luz, TweenInfo.new(0.9), { Brightness = 1.2 }):Play()
		Vfx.partida(run, "armadilha", { tipo = "fogoAviso", pos = armadilha.centro })
		task.wait(0.9)
		if not ativa(run, sala) then
			return
		end
		-- jato de fogo
		ligar(armadilha.jato, true)
		armadilha.luz.Brightness = 3.5
		Vfx.partida(run, "armadilha", { tipo = "fogo", pos = armadilha.centro })
		local feridos = {}
		local fim = os.clock() + 1.4
		while os.clock() < fim and ativa(run, sala) do
			for _, estado in jogadoresEmCima(run, armadilha, 9) do
				if not feridos[estado] then
					feridos[estado] = true
					ferir(run, estado, armadilha, info.danoFogo, { queimar = info.queimaFogo })
				end
			end
			task.wait(0.1)
		end
		ligar(armadilha.jato, false)
		if armadilha.brasas then
			for _, e in armadilha.brasas:GetChildren() do
				if e:IsA("ParticleEmitter") then
					e.Rate /= 4
				end
			end
		end
		TweenService:Create(armadilha.luz, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	end
end

-- Liga todas as armadilhas da sala (cada uma num ritmo, para não dispararem juntas)
function Armadilhas.iniciar(run, sala)
	for indice, armadilha in sala.armadilhas do
		task.spawn(function()
			task.wait((indice * 0.97) % 3)
			if armadilha.tipo == "espinhos" then
				cicloEspinhos(run, sala, armadilha)
			else
				cicloFogo(run, sala, armadilha)
			end
		end)
	end
end

return Armadilhas
