-- Efeitos sonoros. Todos os sons ficam num arquivo só (sons/MasmorraSons.ogg, gerado por
-- ferramentas/gerar_sons.py); cada som é um trecho dele (SonsMapa.luau diz onde começa e
-- quanto dura). Depois de enviar o arquivo para o Roblox, cole o ID em Config.SONS_ID.
-- Também dá para usar um ID por som em Config.SONS_IDS (tem preferência).
--
-- Sons.tocar("espada", { pos = Vector3 })   -> som no mundo (mais baixo de longe)
-- Sons.tocar("clique")                      -> som da interface (sem posição)

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Mapa = require(script.Parent.SonsMapa)

local Sons = {}

-- volume base e quanto o tom varia a cada vez (para não soar repetido)
local AJUSTES = {
	espada = { 0.6, 0.08 },
	espadaPesada = { 0.75, 0.06 },
	adaga = { 0.5, 0.1 },
	impacto = { 0.5, 0.12 },
	critico = { 0.7, 0.05 },
	sangue = { 0.45, 0.12 },
	escudo = { 0.7, 0.05 },
	escudoPerfeito = { 0.85, 0 },
	giro = { 0.55, 0.03 },
	julgamento = { 0.95, 0 },
	arcoPuxar = { 0.35, 0.05 },
	arcoSoltar = { 0.85, 0.06 },
	flechaImpacto = { 0.5, 0.1 },
	chuvaFlechas = { 0.5, 0 },
	dardoArcano = { 0.5, 0.08 },
	lancaGelo = { 0.55, 0.06 },
	geloQuebra = { 0.5, 0.1 },
	bolaFogo = { 0.6, 0.06 },
	explosao = { 0.75, 0.08 },
	vazioExplode = { 0.85, 0 },
	meteoro = { 0.7, 0 },
	raio = { 0.55, 0.12 },
	tempestade = { 0.6, 0 },
	semMana = { 0.5, 0 },
	passoSombrio = { 0.65, 0.05 },
	investida = { 0.7, 0.05 },
	carregar = { 0.45, 0 },
	cargaCheia = { 0.6, 0 },
	esquiva = { 0.5, 0.1 },
	supremo = { 0.75, 0 },
	inimigoMorre = { 0.5, 0.12 },
	danoJogador = { 0.6, 0.08 },
	moeda = { 0.35, 0.1 },
	carta = { 0.5, 0.05 },
	clique = { 0.3, 0.03 },
	reviver = { 0.6, 0 },
	caiu = { 0.6, 0 },
	portal = { 0.55, 0 },
	pouso = { 0.7, 0.08 },
	vento = { 0.6, 0.05 },
	trovao = { 0.9, 0.04 },
	golpeEspada = { 0.75, 0.08 },
}

-- Sons que já vêm com o Roblox: tocam mesmo antes de enviar o arquivo de sons
local SEM_ARQUIVO = {
	explosao = "rbxasset://sounds/impact_explosion_03.mp3",
	vazioExplode = "rbxasset://sounds/impact_explosion_03.mp3",
	julgamento = "rbxasset://sounds/impact_explosion_03.mp3",
	pouso = "rbxasset://sounds/action_jump_land.mp3", -- fim do rolamento do Cavaleiro
	vento = "rbxasset://sounds/action_falling.ogg", -- vento do tornado
	trovao = "rbxassetid://4299587602", -- estrondo de raio (veio no pacote de VFX): supremo do Cavaleiro
}

local grupo = Instance.new("SoundGroup")
grupo.Name = "Efeitos"
grupo.Volume = 1
grupo.Parent = SoundService

local terreno = workspace.Terrain
local ultimaVez = {} -- [nome] = quando tocou (evita o mesmo som 20 vezes no mesmo quadro)
local tocando = 0
local MAXIMO_JUNTOS = 28

local function idValido(id: any): boolean
	return type(id) == "string" and string.match(id, "%d+") ~= nil and not string.match(id, "^rbxassetid://0+$")
end

-- ID e trecho (início, duração) de um som; nil se não houver como tocar
local function origem(nome: string): (string?, { number }?)
	local individual = Config.SONS_IDS and Config.SONS_IDS[nome]
	if idValido(individual) then
		return individual, nil
	end
	if idValido(Config.SONS_ID) and Mapa[nome] then
		return Config.SONS_ID, Mapa[nome]
	end
	return SEM_ARQUIVO[nome], nil
end

--[[ opcoes: pos (Vector3: som no mundo), pai (Instance: segue a peça), volume (multiplica),
	tom (multiplica a velocidade/altura), alcance (distância em que some, padrão 140),
	duracao (repete o som por esse tempo e some devagar no fim)
	Devolve o Sound (para parar antes, se precisar). ]]
function Sons.tocar(nome: string, opcoes): Sound?
	opcoes = opcoes or {}
	local id, trecho = origem(nome)
	if not id then
		return nil
	end
	local agora = os.clock()
	if agora - (ultimaVez[nome] or 0) < 0.04 or tocando >= MAXIMO_JUNTOS then
		return nil
	end
	ultimaVez[nome] = agora

	local ajuste = AJUSTES[nome] or { 0.5, 0 }
	local som = Instance.new("Sound")
	som.Name = nome
	som.SoundId = id
	som.Volume = ajuste[1] * (opcoes.volume or 1)
	som.PlaybackSpeed = (opcoes.tom or 1) * (1 + (math.random() * 2 - 1) * ajuste[2])
	som.SoundGroup = grupo
	if trecho then
		som.PlaybackRegionsEnabled = true
		som.PlaybackRegion = NumberRange.new(trecho[1], trecho[1] + trecho[2])
	end

	local remover: Instance = som
	if opcoes.pos then
		local ponto = Instance.new("Attachment")
		ponto.WorldPosition = opcoes.pos
		ponto.Parent = terreno
		som.Parent = ponto
		remover = ponto
	elseif opcoes.pai then
		som.Parent = opcoes.pai
	else
		som.Parent = SoundService
	end
	if opcoes.pos or opcoes.pai then
		som.RollOffMode = Enum.RollOffMode.InverseTapered
		som.RollOffMinDistance = 14
		som.RollOffMaxDistance = opcoes.alcance or 140
	end

	local duracao = (if trecho then trecho[2] else 5) / som.PlaybackSpeed + 0.3
	if opcoes.duracao then
		-- som contínuo (vento): repete e some devagar no fim
		som.Looped = true
		duracao = opcoes.duracao + 0.4
		task.delay(opcoes.duracao, function()
			if som.Parent then
				game:GetService("TweenService"):Create(som, TweenInfo.new(0.35), { Volume = 0 }):Play()
			end
		end)
	end
	som:Play()
	tocando += 1
	task.delay(duracao, function()
		tocando -= 1
	end)
	Debris:AddItem(remover, duracao)
	return som
end

-- Para um som antes do fim (ex.: o som de carregar quando o jogador solta)
function Sons.parar(som: Sound?)
	if som and som.Parent then
		som:Stop()
	end
end

function Sons.iniciar()
	if not idValido(Config.SONS_ID) and next(Config.SONS_IDS or {}) == nil then
		warn("[Sons] Os efeitos sonoros ainda não foram enviados para o Roblox. Envie sons/MasmorraSons.ogg e cole o ID em Config.SONS_ID (veja COMO_USAR.md).")
		return
	end
	-- carrega o arquivo antes de precisar dele (o primeiro golpe já sai com som)
	task.spawn(function()
		local previa = Instance.new("Sound")
		previa.SoundId = Config.SONS_ID
		pcall(function()
			ContentProvider:PreloadAsync({ previa })
		end)
		previa:Destroy()
	end)
end

return Sons
