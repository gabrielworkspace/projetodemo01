-- Teclas de cada ação (o jogador pode trocar no menu ⚙️ Teclas). Usado pelo servidor
-- para validar o que é salvo e pelo jogador para ler os comandos.
--
-- Cada ação tem até 2 teclas (principal e alternativa). Uma tecla é guardada pelo nome:
-- o nome de um Enum.KeyCode ("E", "LeftShift"...) ou "MouseButton1", "MouseButton2",
-- "MouseButton3". O controle (gamepad) tem botões fixos.

local Teclas = {}

Teclas.ACOES = {
	{ id = "ataque", nome = "Atacar", detalhe = "Segure e solte para o golpe carregado", icone = "⚔️" },
	{ id = "habilidade", nome = "Habilidade", detalhe = "Habilidade especial da classe", icone = "✨" },
	{ id = "esquiva", nome = "Esquiva", detalhe = "Fica intocável por um instante", icone = "💨" },
	{ id = "supremo", nome = "Supremo", detalhe = "Com a barra dourada cheia", icone = "⚡" },
	{ id = "defender", nome = "Defender", detalhe = "Cavaleiro: segure para erguer o escudo", icone = "🛡️" },
}

Teclas.PADRAO = {
	ataque = { "MouseButton1" },
	habilidade = { "E" },
	esquiva = { "Q" },
	supremo = { "R" },
	defender = { "F", "MouseButton2" },
}

-- Botões do controle (não mudam)
Teclas.CONTROLE = {
	ataque = Enum.KeyCode.ButtonR2,
	habilidade = Enum.KeyCode.ButtonX,
	esquiva = Enum.KeyCode.ButtonB,
	supremo = Enum.KeyCode.ButtonY,
	defender = Enum.KeyCode.ButtonL2,
}

-- Teclas que já fazem outra coisa no Roblox (andar, pular, chat, menu)
Teclas.RESERVADAS = {
	W = true,
	A = true,
	S = true,
	D = true,
	Up = true,
	Down = true,
	Left = true,
	Right = true,
	Space = true,
	Escape = true,
	Slash = true,
	Tab = true,
	Backquote = true,
	Unknown = true,
}

local MOUSE = { MouseButton1 = true, MouseButton2 = true, MouseButton3 = true }

local acoesPorId = {}
for _, acao in Teclas.ACOES do
	acoesPorId[acao.id] = acao
end
Teclas.acoesPorId = acoesPorId

-- A tecla existe e pode ser usada?
function Teclas.valida(nome: any): boolean
	if type(nome) ~= "string" or #nome > 32 then
		return false
	end
	if MOUSE[nome] then
		return true
	end
	if Teclas.RESERVADAS[nome] then
		return false
	end
	local ok, tecla = pcall(function()
		return (Enum.KeyCode :: any)[nome]
	end)
	return ok and tecla ~= nil
end

-- Limpa uma tabela vinda de fora: só ações conhecidas, no máximo 2 teclas válidas cada,
-- e a mesma tecla nunca em duas ações. Ações que ficarem de fora usam o padrão.
function Teclas.normalizar(tabela: any)
	local resultado = {}
	local usadas = {}
	for _, acao in Teclas.ACOES do
		local lista = if type(tabela) == "table" then tabela[acao.id] else nil
		if type(lista) ~= "table" then
			lista = Teclas.PADRAO[acao.id]
		end
		local limpa = {}
		for slot = 1, 2 do
			local nome = lista[slot]
			if Teclas.valida(nome) and not usadas[nome] then
				usadas[nome] = true
				limpa[slot] = nome
			else
				limpa[slot] = false -- vazio (false para não abrir buraco na lista)
			end
		end
		resultado[acao.id] = limpa
	end
	return resultado
end

-- Nome curto para mostrar na tela
local NOMES = {
	MouseButton1 = "Clique Esq.",
	MouseButton2 = "Clique Dir.",
	MouseButton3 = "Clique Meio",
	LeftShift = "Shift Esq.",
	RightShift = "Shift Dir.",
	LeftControl = "Ctrl Esq.",
	RightControl = "Ctrl Dir.",
	LeftAlt = "Alt Esq.",
	RightAlt = "Alt Dir.",
	Return = "Enter",
	Backspace = "Apagar",
	CapsLock = "Caps Lock",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
	Zero = "0",
	Minus = "-",
	Equals = "=",
	LeftBracket = "[",
	RightBracket = "]",
	Semicolon = ";",
	Quote = "'",
	Comma = ",",
	Period = ".",
	BackSlash = "\\",
}

function Teclas.texto(nome: any): string
	if type(nome) ~= "string" then
		return "—"
	end
	return NOMES[nome] or nome
end

-- Texto bem curto para os quadradinhos do HUD
function Teclas.curto(nome: any): string
	if nome == "MouseButton1" then
		return "🖱️E"
	elseif nome == "MouseButton2" then
		return "🖱️D"
	elseif nome == "MouseButton3" then
		return "🖱️M"
	end
	local texto = Teclas.texto(nome)
	return if #texto > 5 then string.sub(texto, 1, 5) else texto
end

return Teclas
