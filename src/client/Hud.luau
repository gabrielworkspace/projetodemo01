-- HUD: tudo o que fica na tela durante o jogo (lobby e masmorra).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Classes = require(Shared:WaitForChild("Classes"))
local Cartas = require(Shared:WaitForChild("Cartas"))
local Teclas = require(Shared:WaitForChild("Teclas"))

local modulos = script.Parent
local UI = require(modulos.UI)
local Estado = require(modulos.Estado)
local Vfx = require(modulos.Vfx)
local Atalhos = require(modulos.Atalhos)
local Sons = require(modulos.Sons)

local Hud = {}
Hud.aoAbrir = nil :: ((string) -> ())?
Hud.botoesToque = {}

local jogador = Players.LocalPlayer
local criar, animar, cores, fontes = UI.criar, UI.animar, UI.cores, UI.fontes
local celular = UI.ehCelular()

local gui = criar("ScreenGui", {
	Name = "Hud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 1,
	Parent = jogador:WaitForChild("PlayerGui"),
})
local topo = criar("ScreenGui", {
	Name = "HudTopo",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 30,
	Parent = jogador:WaitForChild("PlayerGui"),
})

local function camada(nome: string, pai: Instance): Frame
	return criar("Frame", { Name = nome, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = pai })
end

local telaLobby = camada("Lobby", gui)
local telaPartida = camada("Partida", gui)
telaPartida.Visible = false

------------------------------------------------------------------------
-- Componentes pequenos
------------------------------------------------------------------------

-- "Ficha": painel pequeno com ícone e um número (ouro, recorde)
local function ficha(pai: Instance, icone: string, posicao: UDim2, largura: number)
	local painel = UI.painel({
		AnchorPoint = Vector2.new(1, 0),
		Position = posicao,
		Size = UDim2.fromOffset(largura, 44),
		Parent = pai,
		SemCantos = true,
		Transparencia = 0.12,
	})
	UI.escalavel(painel)
	UI.medalhao({ Parent = painel, Icone = icone, Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(40, 40), Cor = cores.painelClaro })
	local texto = UI.texto({
		Position = UDim2.fromOffset(52, 7),
		Size = UDim2.new(1, -60, 0, 30),
		FontFace = fontes.numero,
		Text = "0",
		TextColor3 = cores.ouroClaro,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = painel,
	})
	UI.contorno(texto, 1.5)
	return painel, texto
end

local function formatarNumero(n: number): string
	local texto = tostring(math.floor(n))
	local resultado = texto:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if resultado:sub(1, 1) == "." then
		resultado = resultado:sub(2)
	end
	return resultado
end

------------------------------------------------------------------------
-- Lobby
------------------------------------------------------------------------

local perfilCard = UI.painel({ Position = UDim2.fromOffset(16, 64), Size = UDim2.fromOffset(310, 98), Parent = telaLobby })
UI.escalavel(perfilCard)
local foto = criar("ImageLabel", {
	Position = UDim2.fromOffset(14, 15),
	Size = UDim2.fromOffset(68, 68),
	BackgroundColor3 = cores.fundo,
	Image = UI.fotoJogador(jogador.UserId),
	Parent = perfilCard,
})
UI.redondo(foto)
local aroFoto = UI.borda(foto, cores.ouro, 3)
local nomeJogador = UI.texto({
	Position = UDim2.fromOffset(94, 12),
	Size = UDim2.fromOffset(204, 28),
	FontFace = fontes.cabecalho,
	Text = jogador.DisplayName,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = perfilCard,
})
UI.contorno(nomeJogador, 1.5)
local classeJogador = UI.texto({
	Position = UDim2.fromOffset(94, 44),
	Size = UDim2.fromOffset(204, 24),
	FontFace = fontes.numero,
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = perfilCard,
})
UI.contorno(classeJogador, 1.5)
local tituloClasse = UI.texto({
	Position = UDim2.fromOffset(94, 70),
	Size = UDim2.fromOffset(204, 18),
	FontFace = fontes.texto,
	Text = "",
	TextColor3 = cores.textoSuave,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = perfilCard,
})

local _, textoOuroLobby = ficha(telaLobby, "💰", UDim2.new(1, -16, 0, 64), 190)
local _, textoRecorde = ficha(telaLobby, "🏆", UDim2.new(1, -16, 0, 114), 190)

local doca = criar("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -22),
	Size = UDim2.fromOffset(760, 62),
	BackgroundTransparency = 1,
	Parent = telaLobby,
})
UI.escalavel(doca)
criar("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 14),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = doca,
})
for ordem, info in { { "classe", "⚔️ CLASSE", "ouro" }, { "loja", "🛒 LOJA", "escuro" }, { "ajuda", "📜 COMO JOGAR", "escuro" }, { "teclas", "⚙️ TECLAS", "escuro" } } do
	local botao = UI.botao({ Parent = doca, Texto = info[2], Estilo = info[3], Size = UDim2.fromOffset(170, 58), LayoutOrder = ordem, TamanhoTexto = 24 })
	botao.Activated:Connect(function()
		if Hud.aoAbrir then
			Hud.aoAbrir(info[1])
		end
	end)
end

-- Fila do portal
local painelFila = UI.painel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 64),
	Size = UDim2.fromOffset(440, 158),
	Visible = false,
	Parent = telaLobby,
})
UI.escalavel(painelFila)
UI.titulo(painelFila, "A MASMORRA AGUARDA", 10, 380, 36)
local contagemFila = UI.texto({
	Position = UDim2.fromOffset(20, 64),
	Size = UDim2.fromOffset(90, 70),
	FontFace = fontes.numero,
	Text = "10",
	TextColor3 = Color3.fromRGB(210, 170, 255),
	Parent = painelFila,
})
UI.contorno(contagemFila, 2)
local vagas = {}
for i = 1, Config.MAX_JOGADORES_POR_PARTIDA do
	local vaga = criar("ImageLabel", {
		Position = UDim2.fromOffset(120 + (i - 1) * 74, 70),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = cores.fundo,
		BackgroundTransparency = 0.2,
		Image = "",
		Parent = painelFila,
	})
	UI.redondo(vaga)
	local aro = UI.borda(vaga, cores.bronze, 2)
	local icone = UI.texto({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 6, 1, 6),
		Size = UDim2.fromOffset(24, 24),
		Text = "",
		Parent = vaga,
	})
	vagas[i] = { imagem = vaga, aro = aro, icone = icone }
end
local dicaFila = UI.texto({
	Position = UDim2.fromOffset(20, 134),
	Size = UDim2.new(1, -40, 0, 18),
	FontFace = fontes.texto,
	Text = "Saia do círculo para cancelar",
	TextColor3 = cores.textoSuave,
	Parent = painelFila,
})

------------------------------------------------------------------------
-- Partida
------------------------------------------------------------------------

-- Placa da sala, com o progresso até o chefe
local placaSala = criar("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(380, 84),
	BackgroundTransparency = 1,
	Parent = telaPartida,
})
UI.escalavel(placaSala)
local textoSala = UI.texto({ Size = UDim2.new(1, 0, 0, 38), FontFace = fontes.titulo, Text = "SALA 1", TextColor3 = cores.ouroClaro, Parent = placaSala })
UI.contorno(textoSala, 2)
local textoTema = UI.texto({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 20), FontFace = fontes.cabecalho, Text = "", TextColor3 = cores.texto, Parent = placaSala })
UI.contorno(textoTema, 1.5)
local pips = {}
for i = 1, Config.SALAS_POR_ANDAR do
	local x = 0.5 + (i - (Config.SALAS_POR_ANDAR + 1) / 2) * 0.075
	local pip = UI.losango(placaSala, UDim2.new(x, 0, 0, 72), if i == Config.SALAS_POR_ANDAR then 14 else 11, cores.bronze)
	pips[i] = pip
end

-- Barra do chefe
local painelChefe = criar("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 96),
	Size = UDim2.fromOffset(660, 70),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = telaPartida,
})
UI.escalavel(painelChefe)
local nomeChefe = UI.texto({ Size = UDim2.new(1, 0, 0, 30), FontFace = fontes.titulo, Text = "", TextColor3 = Color3.fromRGB(255, 120, 100), Parent = painelChefe })
UI.contorno(nomeChefe, 2)
local barraChefe = UI.barra({
	Parent = painelChefe,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 34),
	Size = UDim2.fromOffset(620, 22),
	Cor = Color3.fromRGB(196, 30, 44),
	Raio = 5,
})
local marcaFase = UI.losango(barraChefe.quadro, UDim2.fromScale(0.5, 0.5), 12, cores.ouro)
marcaFase.ZIndex = 5
local tituloChefe = UI.texto({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 16), FontFace = fontes.cabecalho, Text = "", TextColor3 = cores.textoSuave, Parent = painelChefe })

-- Ouro e cartas da partida
local _, textoOuroPartida = ficha(telaPartida, "💰", UDim2.new(1, -16, 0, 64), 170)

local faixaCartas = criar("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 116),
	Size = UDim2.fromOffset(250, 140),
	BackgroundTransparency = 1,
	Parent = telaPartida,
})
UI.escalavel(faixaCartas)
criar("UIGridLayout", {
	CellSize = UDim2.fromOffset(40, 40),
	CellPadding = UDim2.fromOffset(6, 6),
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	StartCorner = Enum.StartCorner.TopRight,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = faixaCartas,
})

-- Quadros dos aliados
local listaAliados = criar("Frame", {
	Position = UDim2.fromOffset(16, 64),
	Size = UDim2.fromOffset(240, 260),
	BackgroundTransparency = 1,
	Parent = telaPartida,
})
UI.escalavel(listaAliados)
criar("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = listaAliados })
local quadrosAliados = {}

-- Barra de ações (computador)
local barraAcoes = UI.painel({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(560, 132),
	Transparencia = 0.12,
	Parent = telaPartida,
})
UI.escalavel(barraAcoes)
-- engrenagem ao lado da barra: abre o menu de teclas no meio da partida
local botaoTeclasPartida = UI.botao({
	Parent = barraAcoes,
	Texto = "⚙️",
	Estilo = "escuro",
	Position = UDim2.new(1, 10, 0, 4),
	Size = UDim2.fromOffset(46, 46),
})
botaoTeclasPartida.Activated:Connect(function()
	if Hud.aoAbrir then
		Hud.aoAbrir("teclas")
	end
end)
local medalhaoClasse = UI.medalhao({ Parent = barraAcoes, Icone = "🛡️", Position = UDim2.fromOffset(14, 24), Size = UDim2.fromOffset(80, 80), EspessuraBorda = 3 })
local barraVida = UI.barra({ Parent = barraAcoes, Position = UDim2.fromOffset(106, 14), Size = UDim2.fromOffset(440, 26) })
local barraCarga = UI.barra({
	Parent = barraAcoes,
	Position = UDim2.fromOffset(106, 46),
	Size = UDim2.fromOffset(440, 10),
	Cor = Color3.fromRGB(230, 170, 40),
	CorClara = Color3.fromRGB(255, 236, 150),
	Fundo = Color3.fromRGB(30, 24, 12),
	Raio = 4,
})
barraCarga.rotulo.Visible = false
barraCarga.definir(0)
-- Mana (só aparece para o Mago), logo acima do painel
local barraMana = UI.barra({
	Parent = barraAcoes,
	Position = UDim2.fromOffset(106, -20),
	Size = UDim2.fromOffset(440, 16),
	Cor = Color3.fromRGB(70, 140, 255),
	CorClara = Color3.fromRGB(160, 210, 255),
	Fundo = Color3.fromRGB(12, 18, 36),
	Raio = 5,
})
barraMana.quadro.Visible = false

local linhaSlots = criar("Frame", {
	Position = UDim2.fromOffset(106, 64),
	Size = UDim2.fromOffset(440, 58),
	BackgroundTransparency = 1,
	Parent = barraAcoes,
})
criar("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 14),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = linhaSlots,
})

local function criarSlot(ordem: number, tecla: string)
	local slot = criar("Frame", {
		Size = UDim2.fromOffset(98, 56),
		BackgroundColor3 = cores.branco,
		LayoutOrder = ordem,
		Parent = linhaSlots,
	})
	UI.cantos(slot, 8)
	UI.gradiente(slot, cores.painelClaro, cores.fundo)
	local aro = UI.borda(slot, cores.bronze, 2)
	local icone = UI.texto({ Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(44, 44), Text = "", Parent = slot })
	local nome = UI.texto({
		Position = UDim2.fromOffset(52, 8),
		Size = UDim2.fromOffset(42, 24),
		FontFace = fontes.numero,
		Text = tecla,
		TextColor3 = cores.ouroClaro,
		Parent = slot,
	})
	UI.contorno(nome, 1.5)
	local rotulo = UI.texto({
		Position = UDim2.fromOffset(50, 32),
		Size = UDim2.fromOffset(46, 16),
		FontFace = fontes.texto,
		Text = "",
		TextColor3 = cores.textoSuave,
		Parent = slot,
	})
	local sombra = criar("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = cores.preto,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = slot,
	})
	UI.cantos(sombra, 8)
	local segundos = UI.texto({ Size = UDim2.fromScale(1, 1), FontFace = fontes.numero, Text = "", ZIndex = 4, Parent = slot })
	UI.contorno(segundos, 2)
	return { quadro = slot, icone = icone, rotulo = rotulo, sombra = sombra, segundos = segundos, aro = aro, tecla = nome }
end

-- mostra nos quadradinhos a tecla que o jogador escolheu para cada ação
local slotsPorAcao = {}
local function atualizarTeclasNosSlots()
	for id, slot in slotsPorAcao do
		slot.tecla.Text = Teclas.curto(Atalhos.principal(id))
	end
end

local slots = {
	ataque = criarSlot(1, "🖱️"),
	habilidade = criarSlot(2, "E"),
	esquiva = criarSlot(3, "Q"),
	supremo = criarSlot(4, "R"),
}
slots.ataque.rotulo.Text = "Ataque"
slots.habilidade.rotulo.Text = "Habilid."
slots.esquiva.rotulo.Text = "Esquiva"
slots.esquiva.icone.Text = "💨"
slots.supremo.rotulo.Text = "Supremo"
slotsPorAcao = { ataque = slots.ataque, habilidade = slots.habilidade, esquiva = slots.esquiva, supremo = slots.supremo }
atualizarTeclasNosSlots()

-- Versão celular: vida no topo e botões grandes à direita
local vidaCelular = UI.painel({
	Position = UDim2.fromOffset(16, 64),
	Size = UDim2.fromOffset(280, 82),
	Transparencia = 0.15,
	SemCantos = true,
	Visible = false,
	Parent = telaPartida,
})
UI.escalavel(vidaCelular)
local barraVidaCelular = UI.barra({ Parent = vidaCelular, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(256, 24) })
local barraCargaCelular = UI.barra({
	Parent = vidaCelular,
	Position = UDim2.fromOffset(12, 42),
	Size = UDim2.fromOffset(256, 10),
	Cor = Color3.fromRGB(230, 170, 40),
	Fundo = Color3.fromRGB(30, 24, 12),
	Raio = 4,
})
barraCargaCelular.rotulo.Visible = false
local barraManaCelular = UI.barra({
	Parent = vidaCelular,
	Position = UDim2.fromOffset(12, 58),
	Size = UDim2.fromOffset(256, 12),
	Cor = Color3.fromRGB(70, 140, 255),
	Fundo = Color3.fromRGB(12, 18, 36),
	Raio = 4,
})
barraManaCelular.rotulo.Visible = false
barraManaCelular.quadro.Visible = false
barraCargaCelular.definir(0)

local areaToque = criar("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -150, 1, -16),
	Size = UDim2.fromOffset(250, 240),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
UI.escalavel(areaToque)

local function botaoRedondo(nome: string, tamanho: number, posicao: UDim2, icone: string)
	local b = criar("TextButton", {
		Name = nome,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = posicao,
		Size = UDim2.fromOffset(tamanho, tamanho),
		BackgroundColor3 = cores.branco,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Text = "",
		Parent = areaToque,
	})
	UI.redondo(b)
	UI.gradiente(b, cores.painelClaro, cores.fundo)
	local aro = UI.borda(b, cores.ouro, 3)
	local rotulo = UI.texto({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.55, 0.55), Text = icone, Parent = b })
	local sombra = criar("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = cores.preto, BackgroundTransparency = 0.4, Visible = false, ZIndex = 3, Parent = b })
	UI.redondo(sombra)
	local segundos = UI.texto({ Size = UDim2.fromScale(1, 1), FontFace = fontes.numero, Text = "", ZIndex = 4, Parent = b })
	UI.contorno(segundos, 2)
	Hud.botoesToque[nome] = b
	return { botao = b, aro = aro, rotulo = rotulo, sombra = sombra, segundos = segundos }
end

local toque = {
	ataque = botaoRedondo("ataque", 118, UDim2.new(1, -60, 1, -60), "⚔️"),
	habilidade = botaoRedondo("habilidade", 78, UDim2.new(1, -150, 1, -128), "🌀"),
	esquiva = botaoRedondo("esquiva", 70, UDim2.new(1, -168, 1, -40), "💨"),
	supremo = botaoRedondo("supremo", 74, UDim2.new(1, -66, 1, -178), "⚡"),
	-- só aparece para o Cavaleiro (segurar ergue o escudo)
	defesa = botaoRedondo("defesa", 66, UDim2.new(1, -226, 1, -112), "🛡️"),
}

-- Caído / espectador
local painelCaido = UI.painel({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.72),
	Size = UDim2.fromOffset(460, 118),
	Visible = false,
	Parent = telaPartida,
})
UI.escalavel(painelCaido)
local tituloCaido = UI.texto({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 40), FontFace = fontes.titulo, Text = "VOCÊ CAIU", TextColor3 = Color3.fromRGB(255, 110, 100), Parent = painelCaido })
UI.contorno(tituloCaido, 2)
local barraCaido = UI.barra({ Parent = painelCaido, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(400, 14), Cor = Color3.fromRGB(150, 150, 160), Raio = 4 })
barraCaido.rotulo.Visible = false
local dicaCaido = UI.texto({ Position = UDim2.fromOffset(20, 78), Size = UDim2.new(1, -40, 0, 30), FontFace = fontes.forte, Text = "", TextColor3 = cores.texto, Parent = painelCaido })

local textoEspectador = UI.texto({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -170),
	Size = UDim2.fromOffset(760, 30),
	FontFace = fontes.forte,
	Text = "",
	TextColor3 = Color3.fromRGB(205, 200, 255),
	Visible = false,
	Parent = telaPartida,
})
UI.escalavel(textoEspectador)
UI.contorno(textoEspectador, 2)

------------------------------------------------------------------------
-- Camada do topo: escurecer, faixas de cinema, títulos, avisos e bordas vermelhas
------------------------------------------------------------------------

local function bordaVermelha(posicao: UDim2, tamanho: UDim2, rotacao: number)
	local f = criar("Frame", {
		Position = posicao,
		Size = tamanho,
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		BorderSizePixel = 0,
		BackgroundTransparency = 0,
		Parent = topo,
	})
	criar("UIGradient", { Rotation = rotacao, Transparency = NumberSequence.new(0, 1), Parent = f })
	return f
end
local function criarVinheta(): CanvasGroup
	local grupo = criar("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Parent = topo })
	for _, info in {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), 90 },
		{ UDim2.fromScale(0, 0.78), UDim2.fromScale(1, 0.22), -90 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), 0 },
		{ UDim2.fromScale(0.84, 0), UDim2.fromScale(0.16, 1), 180 },
	} do
		bordaVermelha(info[1], info[2], info[3]).Parent = grupo
	end
	return grupo
end
local vinheta = criarVinheta() -- pisca ao levar dano
local vinhetaVida = criarVinheta() -- pulsa com a vida baixa

local faixaCima = criar("Frame", { Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.fromScale(0, -0.12), BackgroundColor3 = cores.preto, BorderSizePixel = 0, Parent = topo })
local faixaBaixo = criar("Frame", { Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.fromScale(0, 1), BackgroundColor3 = cores.preto, BorderSizePixel = 0, Parent = topo })

local cartaoTitulo = criar("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.34),
	Size = UDim2.fromOffset(900, 170),
	BackgroundTransparency = 1,
	GroupTransparency = 1,
	Parent = topo,
})
UI.escalavel(cartaoTitulo)
local tituloGrande = UI.texto({ Size = UDim2.new(1, 0, 0, 96), FontFace = fontes.titulo, Text = "", TextColor3 = cores.ouroClaro, Parent = cartaoTitulo })
UI.contorno(tituloGrande, 3, 0)
UI.separador(cartaoTitulo, UDim2.new(0.5, 0, 0, 104), 420)
local subtitulo = UI.texto({ Position = UDim2.fromOffset(0, 116), Size = UDim2.new(1, 0, 0, 36), FontFace = fontes.cabecalho, Text = "", TextColor3 = cores.texto, Parent = cartaoTitulo })
UI.contorno(subtitulo, 2, 0)

local banner = criar("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.22),
	Size = UDim2.fromOffset(900, 70),
	BackgroundTransparency = 1,
	GroupTransparency = 1,
	Parent = topo,
})
UI.escalavel(banner)
local textoBanner = UI.texto({ Size = UDim2.new(1, 0, 0, 48), FontFace = fontes.cabecalho, Text = "", Parent = banner })
UI.contorno(textoBanner, 2.5, 0)
UI.separador(banner, UDim2.new(0.5, 0, 0, 58), 300)

local pilhaAvisos = criar("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 270),
	Size = UDim2.fromOffset(330, 320),
	BackgroundTransparency = 1,
	Parent = topo,
})
UI.escalavel(pilhaAvisos)
criar("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pilhaAvisos })

local escuro = criar("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = cores.preto, BackgroundTransparency = 1, ZIndex = 50, Parent = topo })

------------------------------------------------------------------------
-- Atualizações
------------------------------------------------------------------------

local function atualizarPerfil()
	local perfil = Estado.perfil
	local classe = Classes.obter(perfil.classe)
	textoOuroLobby.Text = formatarNumero(perfil.ouro or 0)
	textoRecorde.Text = "Sala " .. (perfil.recorde or 0)
	classeJogador.Text = classe.icone .. " " .. classe.nome
	classeJogador.TextColor3 = classe.cor:Lerp(cores.branco, 0.25)
	tituloClasse.Text = classe.titulo
	aroFoto.Color = classe.cor
end

local function atualizarClasseNaBarra()
	local id = if Estado.stats then Estado.stats.classe else Estado.perfil.classe
	local classe = Classes.obter(id)
	local icone = medalhaoClasse:FindFirstChild("Icone") :: TextLabel?
	if icone then
		icone.Text = classe.icone
	end
	slots.ataque.icone.Text = classe.ataque.icone
	slots.habilidade.icone.Text = classe.habilidade.icone
	slots.supremo.icone.Text = classe.supremo.icone
	toque.ataque.rotulo.Text = classe.ataque.icone
	toque.habilidade.rotulo.Text = classe.habilidade.icone
	toque.supremo.rotulo.Text = classe.supremo.icone
	toque.defesa.botao.Visible = classe.id == "cavaleiro"
	barraVida.cor(classe.cor:Lerp(cores.vida, 0.65))
end

local function atualizarCartas()
	for _, filho in faixaCartas:GetChildren() do
		if filho:IsA("Frame") then
			filho:Destroy()
		end
	end
	for ordem, carta in Cartas.lista do
		local quantidade = Estado.cartas[carta.id] or 0
		if quantidade > 0 then
			local m = UI.medalhao({
				Parent = faixaCartas,
				Icone = carta.icone,
				Cor = cores.painelClaro,
				Borda = Config.RARIDADES[carta.raridade].cor,
				LayoutOrder = ordem,
			})
			if quantidade > 1 then
				local n = UI.texto({
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, 4, 1, 4),
					Size = UDim2.fromOffset(24, 16),
					FontFace = fontes.numero,
					Text = "x" .. quantidade,
					TextColor3 = cores.ouroClaro,
					ZIndex = 4,
					Parent = m,
				})
				UI.contorno(n, 1.5, 0)
			end
		end
	end
end

local function montarAliados()
	for _, filho in listaAliados:GetChildren() do
		if filho:IsA("Frame") then
			filho:Destroy()
		end
	end
	table.clear(quadrosAliados)
	for ordem, aliado in Estado.aliados do
		if aliado.userId ~= jogador.UserId then
			local classe = Classes.obter(aliado.classe)
			local quadro = UI.painel({ Size = UDim2.fromOffset(240, 58), LayoutOrder = ordem, Parent = listaAliados, SemCantos = true, Transparencia = 0.15 })
			local retrato = criar("ImageLabel", {
				Position = UDim2.fromOffset(8, 7),
				Size = UDim2.fromOffset(44, 44),
				BackgroundColor3 = cores.fundo,
				Image = UI.fotoJogador(aliado.userId),
				Parent = quadro,
			})
			UI.redondo(retrato)
			UI.borda(retrato, classe.cor, 2)
			local nome = UI.texto({
				Position = UDim2.fromOffset(60, 6),
				Size = UDim2.fromOffset(170, 20),
				FontFace = fontes.forte,
				Text = classe.icone .. " " .. aliado.nome,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = quadro,
			})
			UI.contorno(nome, 1.5)
			local barra = UI.barra({ Parent = quadro, Position = UDim2.fromOffset(60, 32), Size = UDim2.fromOffset(170, 14), Raio = 4 })
			barra.rotulo.Visible = false
			quadrosAliados[aliado.userId] = { quadro = quadro, barra = barra, nome = nome, retrato = retrato, texto = classe.icone .. " " .. aliado.nome }
		end
	end
end

------------------------------------------------------------------------
-- API chamada pelo Main
------------------------------------------------------------------------

function Hud.modo(modo: string)
	telaLobby.Visible = modo == "lobby"
	telaPartida.Visible = modo == "partida"
	areaToque.Visible = modo == "partida" and celular
	barraAcoes.Visible = not celular
	vidaCelular.Visible = celular
	painelChefe.Visible = false
	painelCaido.Visible = false
	textoEspectador.Visible = false
	if modo == "partida" then
		montarAliados()
		atualizarCartas()
		atualizarClasseNaBarra()
	else
		painelFila.Visible = false
	end
	animar(escuro, 0.3, { BackgroundTransparency = 1 })
end

function Hud.fila(dados)
	if dados.esconder or Estado.modo ~= "lobby" then
		painelFila.Visible = false
		return
	end
	painelFila.Visible = true
	if dados.cheio then
		contagemFila.Text = "—"
		dicaFila.Text = "Grupo cheio! Espere a próxima partida."
		return
	end
	contagemFila.Text = tostring(dados.segundos)
	dicaFila.Text = "Saia do círculo para cancelar"
	for i, vaga in vagas do
		local membro = dados.membros and dados.membros[i]
		if membro then
			local classe = Classes.obter(membro.classe)
			vaga.imagem.Image = UI.fotoJogador(membro.userId)
			vaga.aro.Color = classe.cor
			vaga.icone.Text = classe.icone
		else
			vaga.imagem.Image = ""
			vaga.aro.Color = cores.bronze
			vaga.icone.Text = ""
		end
	end
end

local idBanner = 0
function Hud.banner(texto: string, cor: Color3?)
	idBanner += 1
	local meu = idBanner
	textoBanner.Text = texto
	textoBanner.TextColor3 = cor or cores.texto
	banner.Position = UDim2.fromScale(0.5, 0.25)
	banner.GroupTransparency = 1
	animar(banner, 0.3, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.22) }, Enum.EasingStyle.Back)
	task.delay(2.4, function()
		if idBanner == meu then
			animar(banner, 0.4, { GroupTransparency = 1 })
		end
	end)
end

function Hud.aviso(texto: string)
	local quadro = UI.painel({ Size = UDim2.fromOffset(330, 46), Parent = pilhaAvisos, SemCantos = true, Transparencia = 0.1 })
	local grupo = criar("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = quadro })
	local rotulo = UI.texto({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 1, -16),
		FontFace = fontes.forte,
		Text = texto,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = grupo,
	})
	UI.limiteTexto(rotulo, 20)
	local deslize = criar("UIScale", { Scale = 0.6, Parent = quadro })
	animar(deslize, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	local avisos = {}
	for _, filho in pilhaAvisos:GetChildren() do
		if filho:IsA("Frame") then
			table.insert(avisos, filho)
		end
	end
	if #avisos > 4 then
		avisos[1]:Destroy()
	end
	task.delay(3.5, function()
		if quadro.Parent then
			animar(grupo, 0.3, { GroupTransparency = 1 })
			animar(quadro, 0.3, { BackgroundTransparency = 1 })
			task.wait(0.3)
			quadro:Destroy()
		end
	end)
end

local function mostrarTitulo(titulo: string, sub: string, cor: Color3, duracao: number)
	tituloGrande.Text = titulo
	tituloGrande.TextColor3 = cor
	subtitulo.Text = sub
	local escala = cartaoTitulo:FindFirstChildOfClass("UIScale")
	cartaoTitulo.GroupTransparency = 1
	if escala then
		escala.Scale = UI.escalaAtual * 1.25
		animar(escala, 0.5, { Scale = UI.escalaAtual }, Enum.EasingStyle.Quint)
	end
	animar(cartaoTitulo, 0.4, { GroupTransparency = 0 })
	task.delay(duracao, function()
		animar(cartaoTitulo, 0.6, { GroupTransparency = 1 })
	end)
end

function Hud.sala(dados)
	textoSala.Text = (if dados.tipo == "chefe" then "☠ " elseif dados.tipo == "tesouro" then "💰 " else "") .. "SALA " .. dados.numero
	textoTema.Text = dados.tema.nome
	for i, pip in pips do
		local cor = cores.bronze
		if i < dados.posicaoNoAndar then
			cor = cores.ouro
		elseif i == dados.posicaoNoAndar then
			cor = if dados.tipo == "chefe" then Color3.fromRGB(255, 60, 60) else cores.ouroClaro
		elseif i == #pips then
			cor = Color3.fromRGB(140, 40, 40)
		end
		pip.BackgroundColor3 = cor
	end
	if dados.tipo ~= "chefe" then
		mostrarTitulo("Sala " .. dados.numero, dados.tema.nome, cores.ouroClaro, 1.6)
	end
end

function Hud.introChefe(dados)
	animar(faixaCima, 0.4, { Position = UDim2.fromScale(0, 0) })
	animar(faixaBaixo, 0.4, { Position = UDim2.fromScale(0, 0.88) })
	mostrarTitulo(dados.nome, dados.titulo, Color3.fromRGB(255, 96, 80), 2.2)
	Vfx.tremer(1.5, 0.8)
	task.delay(2.6, function()
		animar(faixaCima, 0.5, { Position = UDim2.fromScale(0, -0.12) })
		animar(faixaBaixo, 0.5, { Position = UDim2.fromScale(0, 1) })
	end)
end

function Hud.transicao(escurecer: boolean)
	if escurecer then
		animar(escuro, 0.35, { BackgroundTransparency = 0 })
	else
		task.delay(0.2, function()
			animar(escuro, 0.5, { BackgroundTransparency = 1 })
		end)
	end
end

function Hud.danoLocal(_valor: number)
	vinheta.GroupTransparency = 0.25
	animar(vinheta, 0.5, { GroupTransparency = 1 })
end

function Hud.ganhouOuro(_valor: number)
	local escala = textoOuroPartida:FindFirstChildOfClass("UIScale") or criar("UIScale", { Parent = textoOuroPartida })
	escala.Scale = 1.25
	animar(escala, 0.25, { Scale = 1 })
end

function Hud.caiu()
	painelCaido.Visible = true
	tituloCaido.Text = "VOCÊ CAIU"
	dicaCaido.Text = "Um aliado precisa ficar perto de você para te levantar!"
end

function Hud.levantou()
	painelCaido.Visible = false
end

function Hud.morreu()
	painelCaido.Visible = false
	textoEspectador.Text = "💀 Você caiu. Você volta quando seus amigos limparem a sala."
	textoEspectador.Visible = true
end

function Hud.reviveu()
	textoEspectador.Visible = false
	painelCaido.Visible = false
end

------------------------------------------------------------------------
-- Loop: barras, recargas, aliados, chefe, espectador
------------------------------------------------------------------------

local function recarga(fim: number, total: number, sombra: Frame, segundos: TextLabel, redondo: boolean)
	local restante = fim - os.clock()
	if restante > 0 then
		if redondo then
			sombra.Visible = true
		else
			sombra.Size = UDim2.fromScale(1, math.clamp(restante / math.max(total, 0.01), 0, 1))
		end
		segundos.Text = if restante >= 1 then tostring(math.ceil(restante)) else string.format("%.1f", restante)
	else
		if redondo then
			sombra.Visible = false
		else
			sombra.Size = UDim2.fromScale(1, 0)
		end
		segundos.Text = ""
	end
end

-- Barrinha do ataque, embaixo do próprio personagem: enche enquanto o golpe termina (cadência)
-- e pisca quando o próximo ataque fica pronto
local barraAtaque = criar("BillboardGui", {
	Name = "BarraDoAtaque",
	ResetOnSpawn = false,
	Size = UDim2.fromOffset(62, 7),
	StudsOffset = Vector3.new(0, -3.3, 0),
	AlwaysOnTop = true,
	LightInfluence = 0,
	Enabled = false,
	Parent = jogador:WaitForChild("PlayerGui"), -- (BillboardGui dentro de ScreenGui não aparece)
})
local fundoAtaque = criar("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(16, 14, 22),
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	Parent = barraAtaque,
})
UI.redondo(fundoAtaque)
UI.borda(fundoAtaque, cores.preto, 1.5)
local cheioAtaque = criar("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = cores.ouroClaro,
	BorderSizePixel = 0,
	Parent = fundoAtaque,
})
UI.redondo(cheioAtaque)
local ataqueEstavaPronto = true

local function atualizarBarraAtaque(corClasse: Color3)
	local personagem = jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local agora = os.clock()
	local restante = Estado.ataqueFim - agora
	local pronto = restante <= 0
	if not raiz or Estado.caido or Estado.morto then
		barraAtaque.Enabled = false
		return
	end
	barraAtaque.Adornee = raiz
	if not pronto then
		ataqueEstavaPronto = false
		barraAtaque.Enabled = true
		local fracao = 1 - math.clamp(restante / math.max(Estado.ataqueTotal, 0.01), 0, 1)
		cheioAtaque.Size = UDim2.fromScale(fracao, 1)
		cheioAtaque.BackgroundColor3 = corClasse:Lerp(cores.branco, 0.15)
		cheioAtaque.BackgroundTransparency = 0
		fundoAtaque.BackgroundTransparency = 0.3
	else
		-- pronto: pisca branco e some em 0,25s
		if not ataqueEstavaPronto then
			ataqueEstavaPronto = true
			slots.ataque.aro.Color = cores.branco
			task.delay(0.15, function()
				slots.ataque.aro.Color = cores.bronze
			end)
		end
		local desde = -restante
		if desde < 0.25 then
			barraAtaque.Enabled = true
			cheioAtaque.Size = UDim2.fromScale(1, 1)
			cheioAtaque.BackgroundColor3 = cores.branco
			cheioAtaque.BackgroundTransparency = desde / 0.25
			fundoAtaque.BackgroundTransparency = 0.3 + 0.7 * desde / 0.25
		else
			barraAtaque.Enabled = false
		end
	end
end

local placasCaidos = {} -- [Model] = { placa, barra }

-- Placa sobre aliados caídos, com o progresso de reviver
local function atualizarCaidos()
	for _, aliado in Estado.aliados do
		local outro = Players:GetPlayerByUserId(aliado.userId)
		local personagem = outro and outro.Character
		if personagem and outro ~= jogador then
			local caido = personagem:GetAttribute("Caido") == true
			local info = placasCaidos[personagem]
			if caido and not info then
				local cabeca = personagem:FindFirstChild("Head") or personagem:FindFirstChild("HumanoidRootPart")
				if cabeca then
					local placa = criar("BillboardGui", {
						Adornee = cabeca,
						Size = UDim2.fromOffset(150, 52),
						StudsOffset = Vector3.new(0, 3, 0),
						AlwaysOnTop = true,
						LightInfluence = 0,
						Parent = gui,
					})
					local rotulo = UI.texto({ Size = UDim2.new(1, 0, 0, 22), FontFace = fontes.numero, Text = "💀 CAÍDO", TextColor3 = Color3.fromRGB(255, 120, 110), Parent = placa })
					UI.contorno(rotulo, 2, 0)
					local barra = UI.barra({ Parent = placa, Position = UDim2.fromOffset(10, 28), Size = UDim2.fromOffset(130, 14), Cor = cores.sucesso, Raio = 4 })
					barra.rotulo.Visible = false
					barra.definir(0)
					info = { placa = placa, barra = barra }
					placasCaidos[personagem] = info
				end
			elseif not caido and info then
				info.placa:Destroy()
				placasCaidos[personagem] = nil
				info = nil
			end
			if info then
				info.barra.definir(personagem:GetAttribute("Reviver") or 0)
			end
		end
	end
	for personagem, info in placasCaidos do
		if not personagem.Parent then
			info.placa:Destroy()
			placasCaidos[personagem] = nil
		end
	end
end

local proximoEspectador = 0
local function atualizarEspectador()
	if not Estado.morto or os.clock() < proximoEspectador then
		return
	end
	proximoEspectador = os.clock() + 0.5
	local camera = workspace.CurrentCamera
	local atual = camera.CameraSubject
	local valido = atual ~= nil and atual:IsA("Humanoid") and atual.Health > 0 and atual.Parent ~= jogador.Character
	if valido then
		return
	end
	for _, aliado in Estado.aliados do
		local outro = Players:GetPlayerByUserId(aliado.userId)
		local personagem = outro and outro ~= jogador and outro.Character
		local humanoid = personagem and personagem:FindFirstChildOfClass("Humanoid")
		if outro and humanoid and humanoid.Health > 0 then
			camera.CameraSubject = humanoid
			textoEspectador.Text = "👻 Assistindo " .. outro.DisplayName .. ". Você volta quando a sala for limpa."
			return
		end
	end
end

local function atualizarChefe()
	local chefe = nil
	for _, modelo in CollectionService:GetTagged("Inimigo") do
		if modelo:GetAttribute("Chefe") then
			chefe = modelo
			break
		end
	end
	painelChefe.Visible = chefe ~= nil and Estado.modo == "partida"
	if chefe then
		nomeChefe.Text = (if chefe:GetAttribute("Furioso") then "🔥 " else "") .. (chefe:GetAttribute("Nome") or "")
		tituloChefe.Text = chefe:GetAttribute("Titulo") or ""
		local vida = chefe:GetAttribute("Vida") or 0
		local maxima = chefe:GetAttribute("VidaMax") or 1
		barraChefe.definir(vida / math.max(maxima, 1), formatarNumero(math.max(0, vida)) .. " / " .. formatarNumero(maxima))
	end
end

function Hud.iniciar()
	Estado.Mudou:Connect(function(chave)
		if chave == "perfil" then
			atualizarPerfil()
			if Estado.modo == "lobby" then
				atualizarClasseNaBarra()
			end
		elseif chave == "stats" then
			atualizarClasseNaBarra()
		elseif chave == "cartas" then
			atualizarCartas()
		elseif chave == "ouro" then
			textoOuroPartida.Text = formatarNumero(Estado.ouroPartida)
		elseif chave == "teclas" then
			atualizarTeclasNosSlots()
		end
	end)
	atualizarPerfil()

	local pulsoVida = 0
	local manaExibida = 0
	local semManaAte = 0
	Estado.Mudou:Connect(function(chave)
		if chave == "semMana" then
			Sons.tocar("semMana")
			semManaAte = os.clock() + 0.4
			Hud.aviso("💧 Sem mana!")
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local personagem = jogador.Character
		local humanoid = personagem and personagem:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MaxHealth > 0 then
			local fracao = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
			local texto = math.ceil(math.max(0, humanoid.Health)) .. " / " .. math.floor(humanoid.MaxHealth)
			barraVida.definir(fracao, texto)
			barraVidaCelular.definir(fracao, texto)
			-- vida baixa: bordas vermelhas pulsando
			if Estado.modo == "partida" and fracao < 0.3 and fracao > 0 and not Estado.caido then
				pulsoVida += dt * 5
				vinhetaVida.GroupTransparency = 0.6 + 0.25 * math.sin(pulsoVida)
			else
				vinhetaVida.GroupTransparency = 1
			end
		end
		if Estado.modo ~= "partida" then
			return
		end

		-- mana: a barra corre suave até o valor do servidor; pisca vermelha quando falta
		local temMana = Estado.manaMax > 0
		barraMana.quadro.Visible = temMana
		barraManaCelular.quadro.Visible = temMana
		if temMana then
			manaExibida += (Estado.mana - manaExibida) * math.min(1, dt * 12)
			local fracaoMana = math.clamp(manaExibida / Estado.manaMax, 0, 1)
			local textoMana = "💧 " .. math.floor(manaExibida) .. " / " .. math.floor(Estado.manaMax)
			barraMana.definir(fracaoMana, textoMana)
			barraManaCelular.definir(fracaoMana)
			local alerta = math.max(0, semManaAte - os.clock()) / 0.4
			local corFundo = Color3.fromRGB(12, 18, 36):Lerp(Color3.fromRGB(150, 20, 30), alerta)
			barraMana.quadro.BackgroundColor3 = corFundo
			barraManaCelular.quadro.BackgroundColor3 = corFundo
		end

		local carga = math.clamp(Estado.carga / math.max(Estado.cargaMax, 1), 0, 1)
		barraCarga.definir(carga)
		barraCargaCelular.definir(carga)
		local pronto = carga >= 1
		slots.supremo.aro.Color = if pronto then cores.ouroClaro else cores.bronze
		slots.supremo.aro.Thickness = if pronto then 3 + math.sin(os.clock() * 6) else 2
		toque.supremo.sombra.Visible = not pronto
		toque.supremo.aro.Color = if pronto then cores.ouroClaro else cores.bronze

		recarga(Estado.habilidadeFim, Estado.habilidadeTotal, slots.habilidade.sombra, slots.habilidade.segundos, false)
		recarga(Estado.esquivaFim, Estado.esquivaTotal, slots.esquiva.sombra, slots.esquiva.segundos, false)
		recarga(Estado.habilidadeFim, Estado.habilidadeTotal, toque.habilidade.sombra, toque.habilidade.segundos, true)
		recarga(Estado.esquivaFim, Estado.esquivaTotal, toque.esquiva.sombra, toque.esquiva.segundos, true)
		-- ataque: sombra no quadradinho e no botão de toque, sem números (é rápido)
		recarga(Estado.ataqueFim, Estado.ataqueTotal, slots.ataque.sombra, slots.ataque.segundos, false)
		recarga(Estado.ataqueFim, Estado.ataqueTotal, toque.ataque.sombra, toque.ataque.segundos, true)
		slots.ataque.segundos.Text = ""
		toque.ataque.segundos.Text = ""
		local classeBarra = Estado.stats and Classes.obter(Estado.stats.classe)
		atualizarBarraAtaque(if classeBarra then classeBarra.cor else cores.ouroClaro)

		for userId, info in quadrosAliados do
			local outro = Players:GetPlayerByUserId(userId)
			local p = outro and outro.Character
			local h = p and p:FindFirstChildOfClass("Humanoid")
			if not outro then
				info.nome.Text = info.texto .. " (saiu)"
				info.barra.definir(0)
			elseif h and h.MaxHealth > 0 then
				info.barra.definir(h.Health / h.MaxHealth)
				if p:GetAttribute("Caido") then
					info.nome.Text = "💀 " .. info.texto
				elseif h.Health <= 0 then
					info.nome.Text = "☠ " .. info.texto
				else
					info.nome.Text = info.texto
				end
			end
		end

		if Estado.caido and personagem then
			local restante = personagem:GetAttribute("CaidoRestante") or 0
			local reviver = personagem:GetAttribute("Reviver") or 0
			barraCaido.definir(restante / Config.TEMPO_CAIDO)
			if reviver > 0 then
				tituloCaido.Text = "LEVANTANDO... " .. math.floor(reviver * 100) .. "%"
			else
				tituloCaido.Text = "VOCÊ CAIU  •  " .. math.ceil(restante) .. "s"
			end
		end

		atualizarCaidos()
		atualizarEspectador()
		atualizarChefe()
	end)
end

return Hud
