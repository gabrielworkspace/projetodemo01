-- Progresso permanente dos jogadores (ouro, recorde e melhorias), salvo no DataStore.
-- No Studio, o salvamento só funciona com o jogo publicado e com
-- "Game Settings > Security > Enable Studio Access to API Services" ligado.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Classes = require(Shared:WaitForChild("Classes"))
local Remotos = require(script.Parent.Remotos)

local Dados = {}

local NOME_DO_BANCO = "MasmorraDasCartas_v1"

local banco: DataStore? = nil
do
	local ok, resultado = pcall(function()
		return DataStoreService:GetDataStore(NOME_DO_BANCO)
	end)
	if ok then
		banco = resultado
	else
		warn("[Dados] DataStore indisponível, o progresso não será salvo: " .. tostring(resultado))
	end
end

local perfis = {} -- [Player] = perfil
local podeSalvar = {} -- [Player] = true só se o carregamento deu certo (evita apagar progresso)

local function perfilPadrao()
	local melhorias = {}
	for _, melhoria in Config.MELHORIAS do
		melhorias[melhoria.id] = 0
	end
	return { Ouro = 0, Recorde = 0, Melhorias = melhorias, Classe = "cavaleiro", EscolheuClasse = false }
end

local function corrigirPerfil(salvo)
	local perfil = perfilPadrao()
	if type(salvo) ~= "table" then
		return perfil
	end
	if type(salvo.Ouro) == "number" then
		perfil.Ouro = math.max(0, math.floor(salvo.Ouro))
	end
	if type(salvo.Recorde) == "number" then
		perfil.Recorde = math.max(0, math.floor(salvo.Recorde))
	end
	if type(salvo.Melhorias) == "table" then
		for id, nivel in salvo.Melhorias do
			if perfil.Melhorias[id] ~= nil and type(nivel) == "number" then
				perfil.Melhorias[id] = math.max(0, math.floor(nivel))
			end
		end
	end
	if Classes.existe(salvo.Classe) then
		perfil.Classe = salvo.Classe
		perfil.EscolheuClasse = salvo.EscolheuClasse == true
	end
	return perfil
end

local function chave(player: Player): string
	return "jogador_" .. player.UserId
end

local function criarLeaderstats(player: Player, perfil)
	local pasta = Instance.new("Folder")
	pasta.Name = "leaderstats"

	local ouro = Instance.new("IntValue")
	ouro.Name = "Ouro"
	ouro.Value = perfil.Ouro
	ouro.Parent = pasta

	local recorde = Instance.new("IntValue")
	recorde.Name = "Recorde"
	recorde.Value = perfil.Recorde
	recorde.Parent = pasta

	pasta.Parent = player
end

local function atualizarLeaderstats(player: Player)
	local perfil = perfis[player]
	local pasta = player:FindFirstChild("leaderstats")
	if not perfil or not pasta then
		return
	end
	local ouro = pasta:FindFirstChild("Ouro") :: IntValue?
	local recorde = pasta:FindFirstChild("Recorde") :: IntValue?
	if ouro then
		ouro.Value = perfil.Ouro
	end
	if recorde then
		recorde.Value = perfil.Recorde
	end
end

function Dados.carregar(player: Player)
	local perfil = perfilPadrao()
	if banco then
		local ok, salvo = pcall(function()
			return banco:GetAsync(chave(player))
		end)
		if ok then
			perfil = corrigirPerfil(salvo)
			podeSalvar[player] = true
		else
			warn("[Dados] Não consegui carregar o progresso de " .. player.Name .. ": " .. tostring(salvo))
		end
	end
	if not player.Parent then
		return nil
	end
	perfis[player] = perfil
	criarLeaderstats(player, perfil)
	player:SetAttribute("Classe", perfil.Classe)
	return perfil
end

function Dados.obter(player: Player)
	return perfis[player]
end

function Dados.salvar(player: Player)
	local perfil = perfis[player]
	if not perfil or not podeSalvar[player] or not banco then
		return
	end
	local copia = {
		Ouro = perfil.Ouro,
		Recorde = perfil.Recorde,
		Melhorias = table.clone(perfil.Melhorias),
		Classe = perfil.Classe,
		EscolheuClasse = perfil.EscolheuClasse,
	}
	local ok, erro = pcall(function()
		banco:SetAsync(chave(player), copia)
	end)
	if not ok then
		warn("[Dados] Erro ao salvar " .. player.Name .. ": " .. tostring(erro))
	end
end

function Dados.salvarERemover(player: Player)
	Dados.salvar(player)
	perfis[player] = nil
	podeSalvar[player] = nil
end

function Dados.salvarTodos()
	for player in perfis do
		Dados.salvar(player)
	end
end

function Dados.enviarPerfil(player: Player)
	local perfil = perfis[player]
	if perfil then
		Remotos.enviar(player, "perfil", {
			ouro = perfil.Ouro,
			recorde = perfil.Recorde,
			melhorias = perfil.Melhorias,
			classe = perfil.Classe,
			escolheuClasse = perfil.EscolheuClasse,
		})
	end
end

function Dados.definirClasse(player: Player, classe: any): boolean
	local perfil = perfis[player]
	if not perfil or not Classes.existe(classe) then
		return false
	end
	perfil.Classe = classe
	perfil.EscolheuClasse = true
	player:SetAttribute("Classe", classe)
	return true
end

function Dados.adicionarOuro(player: Player, quantidade: number)
	local perfil = perfis[player]
	if perfil and quantidade > 0 then
		perfil.Ouro += math.floor(quantidade)
		atualizarLeaderstats(player)
	end
end

-- Retorna true se for um recorde novo
function Dados.registrarRecorde(player: Player, sala: number): boolean
	local perfil = perfis[player]
	if perfil and sala > perfil.Recorde then
		perfil.Recorde = sala
		atualizarLeaderstats(player)
		return true
	end
	return false
end

function Dados.comprarMelhoria(player: Player, id: any): (boolean, string)
	local perfil = perfis[player]
	local melhoria = Config.buscarMelhoria(id)
	if not perfil or not melhoria then
		return false, "Melhoria inválida"
	end
	local nivel = perfil.Melhorias[melhoria.id] or 0
	if nivel >= melhoria.nivelMax then
		return false, "Essa melhoria já está no máximo!"
	end
	local preco = Config.precoMelhoria(melhoria, nivel)
	if perfil.Ouro < preco then
		return false, "Ouro insuficiente: faltam " .. (preco - perfil.Ouro)
	end
	perfil.Ouro -= preco
	perfil.Melhorias[melhoria.id] = nivel + 1
	atualizarLeaderstats(player)
	return true, melhoria.icone .. " " .. melhoria.nome .. " agora está no nível " .. (nivel + 1) .. "!"
end

-- Salvamento automático a cada 2 minutos
task.spawn(function()
	while true do
		task.wait(120)
		Dados.salvarTodos()
	end
end)

return Dados
