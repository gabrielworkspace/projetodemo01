-- Teclas escolhidas pelo jogador: diz qual ação uma tecla aperta e salva as mudanças
-- no perfil (servidor). A lista de ações e as teclas padrão ficam em Shared/Teclas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Teclas = require(Shared:WaitForChild("Teclas"))

local Estado = require(script.Parent.Estado)

local Atalhos = {}

local Acao = ReplicatedStorage:WaitForChild("Remotos"):WaitForChild("Acao") :: RemoteEvent

Atalhos.atual = Teclas.normalizar(nil)

-- Nome da tecla (ou botão do mouse) de uma entrada; nil se não for teclado/mouse
function Atalhos.nomeDe(entrada: InputObject): string?
	local tipo = entrada.UserInputType
	if tipo == Enum.UserInputType.MouseButton1 or tipo == Enum.UserInputType.MouseButton2 or tipo == Enum.UserInputType.MouseButton3 then
		return tipo.Name
	elseif tipo == Enum.UserInputType.Keyboard then
		return entrada.KeyCode.Name
	end
	return nil
end

-- Qual ação esta entrada aciona (teclado, mouse ou controle)
function Atalhos.acaoDe(entrada: InputObject): string?
	local nome = Atalhos.nomeDe(entrada)
	if nome then
		for id, lista in Atalhos.atual do
			if lista[1] == nome or lista[2] == nome then
				return id
			end
		end
		return nil
	end
	for id, botao in Teclas.CONTROLE do
		if entrada.KeyCode == botao then
			return id
		end
	end
	return nil
end

-- Tecla principal de uma ação (para mostrar no HUD); usa a alternativa se não houver
function Atalhos.principal(id: string): string?
	local lista = Atalhos.atual[id]
	if not lista then
		return nil
	end
	return (lista[1] or lista[2]) or nil
end

local function avisarMudanca()
	Estado.avisar("teclas")
end

-- Teclas vindas do perfil salvo
function Atalhos.carregar(tabela: any)
	Atalhos.atual = Teclas.normalizar(tabela)
	avisarMudanca()
end

local salvarAgendado = false
local function salvar()
	avisarMudanca()
	-- junta várias mudanças seguidas num só envio
	if salvarAgendado then
		return
	end
	salvarAgendado = true
	task.delay(1, function()
		salvarAgendado = false
		Acao:FireServer("salvarTeclas", Atalhos.atual)
	end)
end

--[[ Coloca uma tecla numa ação (slot 1 = principal, 2 = alternativa).
	Se a tecla já era de outra ação, sai de lá. Retorna (ok, mensagem). ]]
function Atalhos.definir(id: string, slot: number, nome: string): (boolean, string?)
	if not Atalhos.atual[id] or (slot ~= 1 and slot ~= 2) then
		return false, nil
	end
	if Teclas.RESERVADAS[nome] then
		return false, "Essa tecla já é usada para andar, pular ou abrir o chat."
	end
	if not Teclas.valida(nome) then
		return false, "Essa tecla não pode ser usada."
	end
	local mensagem = nil
	for outroId, lista in Atalhos.atual do
		for outroSlot = 1, 2 do
			if lista[outroSlot] == nome and not (outroId == id and outroSlot == slot) then
				lista[outroSlot] = false
				mensagem = Teclas.texto(nome) .. " saiu de " .. Teclas.acoesPorId[outroId].nome .. "."
			end
		end
	end
	Atalhos.atual[id][slot] = nome
	salvar()
	return true, mensagem
end

function Atalhos.limpar(id: string, slot: number)
	if Atalhos.atual[id] then
		Atalhos.atual[id][slot] = false
		salvar()
	end
end

function Atalhos.restaurarPadrao()
	Atalhos.atual = Teclas.normalizar(nil)
	salvar()
end

return Atalhos
