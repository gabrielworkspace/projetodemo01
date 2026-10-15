-- Menus: escolha de classe, cartas, elevador, loja do mercador, resumo da partida e ajuda.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Classes = require(Shared:WaitForChild("Classes"))
local Cartas = require(Shared:WaitForChild("Cartas"))

local modulos = script.Parent
local UI = require(modulos.UI)
local Estado = require(modulos.Estado)

local Menus = {}

local jogador = Players.LocalPlayer
local Acao = ReplicatedStorage:WaitForChild("Remotos"):WaitForChild("Acao") :: RemoteEvent
local criar, animar, cores, fontes = UI.criar, UI.animar, UI.cores, UI.fontes

local gui = criar("ScreenGui", {
	Name = "Menus",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 10,
	Parent = jogador:WaitForChild("PlayerGui"),
})

local gradientesGirando = {} -- bordas brilhantes das cartas épicas e lendárias

------------------------------------------------------------------------
-- Abrir e fechar
------------------------------------------------------------------------

local abertos = {}

local function novoMenu(nome: string, largura: number, altura: number)
	local fundo = criar("Frame", {
		Name = nome,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = cores.preto,
		BackgroundTransparency = 0.35,
		Visible = false,
		Parent = gui,
	})
	local conteudo = criar("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(largura, altura),
		BackgroundTransparency = 1,
		Parent = fundo,
	})
	local escala = UI.escalavel(conteudo)
	return { fundo = fundo, conteudo = conteudo, escala = escala }
end

local function abrir(menu)
	if abertos[menu] then
		return
	end
	abertos[menu] = true
	Estado.menusAbertos += 1
	UI.desfocar(true)
	menu.fundo.Visible = true
	menu.fundo.BackgroundTransparency = 1
	animar(menu.fundo, 0.25, { BackgroundTransparency = 0.35 })
	menu.escala.Scale = UI.escalaAtual * 0.9
	animar(menu.escala, 0.3, { Scale = UI.escalaAtual }, Enum.EasingStyle.Back)
end

local function fechar(menu)
	if not abertos[menu] then
		return
	end
	abertos[menu] = nil
	Estado.menusAbertos = math.max(0, Estado.menusAbertos - 1)
	UI.desfocar(false)
	menu.fundo.Visible = false
end

local function botaoFechar(menu)
	local b = UI.botao({
		Parent = menu.conteudo,
		Texto = "✕",
		Estilo = "perigo",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(48, 48),
	})
	b.ZIndex = 10
	b.Activated:Connect(function()
		fechar(menu)
	end)
end

-- Pontinhos de 1 a 5 (força de um atributo)
local function pontos(pai: Instance, posicao: UDim2, valor: number, cor: Color3)
	local linha = criar("Frame", { Position = posicao, Size = UDim2.fromOffset(120, 14), BackgroundTransparency = 1, Parent = pai })
	criar("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = linha })
	for i = 1, 5 do
		local p = criar("Frame", {
			Size = UDim2.fromOffset(20, 12),
			BackgroundColor3 = if i <= valor then cor else Color3.fromRGB(46, 40, 58),
			BorderSizePixel = 0,
			Parent = linha,
		})
		UI.cantos(p, 3)
		UI.borda(p, cores.preto, 1, 0.4)
	end
end

------------------------------------------------------------------------
-- Escolha de classe
------------------------------------------------------------------------

local menuClasses = novoMenu("Classes", 1220, 690)
botaoFechar(menuClasses)
UI.titulo(menuClasses.conteudo, "ESCOLHA SUA CLASSE", 0, 620, 58)
UI.texto({
	Position = UDim2.fromOffset(0, 72),
	Size = UDim2.new(1, 0, 0, 22),
	FontFace = fontes.texto,
	Text = "Você pode trocar quando quiser nos altares do acampamento",
	TextColor3 = cores.textoSuave,
	Parent = menuClasses.conteudo,
})
local linhaClasses = criar("Frame", { Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 0, 570), BackgroundTransparency = 1, Parent = menuClasses.conteudo })
criar("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 14),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = linhaClasses,
})

local botoesClasse = {}
for ordem, id in Classes.ordem do
	local classe = Classes.dados[id]
	local cartao = UI.painel({ Size = UDim2.fromOffset(286, 566), LayoutOrder = ordem, Parent = linhaClasses })
	local zoom = criar("UIScale", { Parent = cartao })
	local cabecalho = criar("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 130),
		BackgroundColor3 = cores.branco,
		Parent = cartao,
	})
	UI.cantos(cabecalho, 8)
	UI.gradiente(cabecalho, classe.cor, classe.cor:Lerp(cores.fundo, 0.75))
	UI.medalhao({ Parent = cabecalho, Icone = classe.icone, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(96, 96), Cor = classe.cor, EspessuraBorda = 3 })
	local nome = UI.texto({ Position = UDim2.fromOffset(0, 144), Size = UDim2.new(1, 0, 0, 32), FontFace = fontes.cabecalho, Text = classe.nome, TextColor3 = classe.cor:Lerp(cores.branco, 0.35), Parent = cartao })
	UI.contorno(nome, 2)
	UI.texto({ Position = UDim2.fromOffset(0, 176), Size = UDim2.new(1, 0, 0, 18), FontFace = fontes.texto, Text = classe.titulo, TextColor3 = cores.ouro, Parent = cartao })
	local descricao = UI.texto({
		Position = UDim2.fromOffset(16, 198),
		Size = UDim2.new(1, -32, 0, 44),
		FontFace = fontes.texto,
		Text = classe.descricao,
		TextColor3 = cores.texto,
		TextWrapped = true,
		Parent = cartao,
	})
	UI.limiteTexto(descricao, 15)
	-- pontos fortes e fracos
	for i, info in { { "✔ " .. (classe.forte or ""), Color3.fromRGB(130, 230, 140) }, { "✘ " .. (classe.fraco or ""), Color3.fromRGB(255, 120, 120) } } do
		local linha = UI.texto({
			Position = UDim2.fromOffset(16, 244 + (i - 1) * 32),
			Size = UDim2.new(1, -32, 0, 30),
			FontFace = fontes.forte,
			Text = info[1],
			TextColor3 = info[2],
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = cartao,
		})
		UI.limiteTexto(linha, 13)
	end
	local y = 314
	for _, atributo in { "Vida", "Dano", "Alcance", "Velocidade" } do
		UI.texto({
			Position = UDim2.fromOffset(20, y),
			Size = UDim2.fromOffset(120, 18),
			FontFace = fontes.forte,
			Text = atributo,
			TextColor3 = cores.textoSuave,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = cartao,
		})
		pontos(cartao, UDim2.fromOffset(146, y + 3), classe.notas[atributo], classe.cor)
		y += 22
	end
	for i, info in { { classe.habilidade, "E" }, { classe.supremo, "R" } } do
		local linhaY = 408 + (i - 1) * 52
		UI.medalhao({ Parent = cartao, Icone = info[1].icone, Position = UDim2.fromOffset(14, linhaY), Size = UDim2.fromOffset(40, 40), Cor = classe.cor })
		UI.texto({
			Position = UDim2.fromOffset(60, linhaY),
			Size = UDim2.new(1, -70, 0, 18),
			FontFace = fontes.forte,
			Text = info[1].nome .. "  [" .. info[2] .. "]",
			TextColor3 = cores.ouroClaro,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = cartao,
		})
		local d = UI.texto({
			Position = UDim2.fromOffset(60, linhaY + 18),
			Size = UDim2.new(1, -70, 0, 30),
			FontFace = fontes.texto,
			Text = info[1].descricao,
			TextColor3 = cores.textoSuave,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = cartao,
		})
		UI.limiteTexto(d, 12)
	end
	local botao = UI.botao({
		Parent = cartao,
		Texto = "ESCOLHER",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(230, 42),
	})
	botao.Activated:Connect(function()
		if Estado.perfil.classe ~= id or not Estado.perfil.escolheuClasse then
			Acao:FireServer("escolherClasse", id)
		end
		fechar(menuClasses)
	end)
	cartao.MouseEnter:Connect(function()
		animar(zoom, 0.15, { Scale = 1.03 })
	end)
	cartao.MouseLeave:Connect(function()
		animar(zoom, 0.15, { Scale = 1 })
	end)
	botoesClasse[id] = botao
end

local function atualizarClasses()
	for id, botao in botoesClasse do
		local selecionada = Estado.perfil.classe == id and Estado.perfil.escolheuClasse
		UI.textoBotao(botao, if selecionada then "SELECIONADA ✓" else "ESCOLHER")
		UI.estiloBotao(botao, if selecionada then "verde" else "ouro")
	end
end

function Menus.abrirClasses()
	if Estado.modo ~= "lobby" then
		return
	end
	atualizarClasses()
	abrir(menuClasses)
end

------------------------------------------------------------------------
-- Cartas
------------------------------------------------------------------------

local menuCartas = novoMenu("Cartas", 1040, 560)
UI.titulo(menuCartas.conteudo, "ESCOLHA UMA CARTA", 0, 600, 56)
local tempoCartas = UI.texto({
	Position = UDim2.fromOffset(0, 72),
	Size = UDim2.new(1, 0, 0, 24),
	FontFace = fontes.forte,
	Text = "",
	TextColor3 = cores.textoSuave,
	Parent = menuCartas.conteudo,
})
local linhaCartas = criar("Frame", { Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 420), BackgroundTransparency = 1, Parent = menuCartas.conteudo })
criar("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 30),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = linhaCartas,
})

local escolhaFeita = false
local idCartas = 0

local function criarCarta(id: string, indice: number)
	local carta = Cartas.porId[id]
	if not carta then
		return
	end
	local raridade = Config.RARIDADES[carta.raridade]
	local classe = carta.classe and Classes.dados[carta.classe]
	local botao = criar("TextButton", {
		Size = UDim2.fromOffset(280, 410),
		BackgroundColor3 = cores.branco,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = indice,
		Parent = linhaCartas,
	})
	UI.cantos(botao, 14)
	UI.gradiente(botao, raridade.cor:Lerp(cores.fundo, 0.55), cores.fundo)
	local contorno = UI.borda(botao, raridade.cor, 3)
	if carta.raridade == "Epica" or carta.raridade == "Lendaria" then
		local brilho = criar("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, raridade.cor),
				ColorSequenceKeypoint.new(0.5, cores.branco),
				ColorSequenceKeypoint.new(1, raridade.cor),
			}),
			Parent = contorno,
		})
		contorno.Thickness = 4
		table.insert(gradientesGirando, brilho)
	end
	local zoom = criar("UIScale", { Scale = 0, Parent = botao })

	-- Etiqueta da classe
	local etiqueta = criar("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(150, 26),
		BackgroundColor3 = if classe then classe.cor:Lerp(cores.fundo, 0.3) else cores.bronze,
		ZIndex = 3,
		Parent = botao,
	})
	UI.cantos(etiqueta, 13)
	UI.borda(etiqueta, cores.preto, 1.5, 0.2)
	local textoEtiqueta = UI.texto({
		Size = UDim2.fromScale(1, 1),
		FontFace = fontes.numero,
		Text = if classe then string.upper(classe.nome) else "UNIVERSAL",
		ZIndex = 4,
		Parent = etiqueta,
	})
	UI.limiteTexto(textoEtiqueta, 15)

	local rotuloRaridade = UI.texto({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 22), FontFace = fontes.cabecalho, Text = raridade.nome, TextColor3 = raridade.cor, Parent = botao })
	UI.contorno(rotuloRaridade, 1.5)
	UI.medalhao({
		Parent = botao,
		Icone = carta.icone,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(124, 124),
		Cor = raridade.cor,
		Borda = raridade.cor:Lerp(cores.branco, 0.3),
		EspessuraBorda = 3,
	})
	local nome = UI.texto({ Position = UDim2.fromOffset(12, 196), Size = UDim2.new(1, -24, 0, 34), FontFace = fontes.cabecalho, Text = carta.nome, Parent = botao })
	UI.contorno(nome, 2)
	UI.separador(botao, UDim2.new(0.5, 0, 0, 240), 200, raridade.cor)
	local descricao = UI.texto({
		Position = UDim2.fromOffset(18, 254),
		Size = UDim2.new(1, -36, 0, 96),
		FontFace = fontes.forte,
		Text = carta.descricao,
		TextColor3 = cores.texto,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = botao,
	})
	UI.limiteTexto(descricao, 21)
	local tenho = Estado.cartas[id] or 0
	if tenho > 0 then
		UI.texto({
			Position = UDim2.new(0, 12, 1, -38),
			Size = UDim2.new(1, -24, 0, 22),
			FontFace = fontes.forte,
			Text = "Você já tem: " .. tenho .. " de " .. carta.maxPilha,
			TextColor3 = cores.ouro,
			Parent = botao,
		})
	end

	-- entrada em sequência
	task.delay((indice - 1) * 0.09, function()
		animar(zoom, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	botao.MouseEnter:Connect(function()
		if not escolhaFeita then
			animar(zoom, 0.12, { Scale = 1.06 })
		end
	end)
	botao.MouseLeave:Connect(function()
		if not escolhaFeita then
			animar(zoom, 0.12, { Scale = 1 })
		end
	end)
	botao.Activated:Connect(function()
		if escolhaFeita then
			return
		end
		escolhaFeita = true
		UI.tocar(UI.SONS.clique, 0.5)
		Acao:FireServer("escolherCarta", indice)
		for _, outro in linhaCartas:GetChildren() do
			if outro:IsA("TextButton") and outro ~= botao then
				local escala = outro:FindFirstChildOfClass("UIScale")
				if escala then
					animar(escala, 0.2, { Scale = 0 })
				end
			end
		end
		animar(zoom, 0.2, { Scale = 1.12 }, Enum.EasingStyle.Back)
		tempoCartas.Text = "Esperando os outros jogadores..."
	end)
end

function Menus.cartas(dados)
	idCartas += 1
	local meu = idCartas
	escolhaFeita = false
	table.clear(gradientesGirando)
	for _, filho in linhaCartas:GetChildren() do
		if filho:IsA("TextButton") then
			filho:Destroy()
		end
	end
	for indice, id in dados.opcoes do
		criarCarta(id, indice)
	end
	abrir(menuCartas)
	local fim = os.clock() + (dados.tempo or 20)
	task.spawn(function()
		while idCartas == meu and abertos[menuCartas] do
			if not escolhaFeita then
				tempoCartas.Text = "⏳ " .. math.max(0, math.ceil(fim - os.clock())) .. "s para escolher"
			end
			task.wait(0.2)
		end
	end)
end

function Menus.fecharCartas()
	fechar(menuCartas)
end

-- O servidor confirmou a carta: fecha logo para o jogador voltar a se mexer
function Menus.cartaEscolhida()
	if escolhaFeita then
		task.delay(0.35, function()
			fechar(menuCartas)
		end)
	end
end

------------------------------------------------------------------------
-- Elevador
------------------------------------------------------------------------

local menuElevador = novoMenu("Elevador", 920, 460)
local painelElevador = UI.painel({ Size = UDim2.fromScale(1, 1), Parent = menuElevador.conteudo })
UI.titulo(painelElevador, "O CHEFE CAIU", 18, 500, 52)
UI.texto({ Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 26), FontFace = fontes.cabecalho, Text = "Para onde agora?", TextColor3 = cores.texto, Parent = painelElevador })

local function opcaoElevador(estilo: string, x: number, icone: string, titulo: string)
	local botao = UI.botao({ Parent = painelElevador, Estilo = estilo, Position = UDim2.fromOffset(x, 130), Size = UDim2.fromOffset(400, 230) })
	local rotulo = botao:FindFirstChild("Rotulo") :: TextLabel
	rotulo.Visible = false
	UI.texto({ Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 70), Text = icone, Parent = botao })
	local t = UI.texto({ Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, 44), FontFace = fontes.titulo, Text = titulo, TextColor3 = if estilo == "ouro" then Color3.fromRGB(46, 28, 8) else cores.texto, Parent = botao })
	if estilo ~= "ouro" then
		UI.contorno(t, 2)
	end
	local detalhe = UI.texto({
		Position = UDim2.fromOffset(20, 142),
		Size = UDim2.new(1, -40, 0, 70),
		FontFace = fontes.forte,
		Text = "",
		TextColor3 = if estilo == "ouro" then Color3.fromRGB(60, 36, 10) else cores.texto,
		TextWrapped = true,
		Parent = botao,
	})
	UI.limiteTexto(detalhe, 22)
	return botao, detalhe
end

local botaoSubir, detalheSubir = opcaoElevador("ouro", 40, "⬆️", "SUBIR")
local botaoDescer, detalheDescer = opcaoElevador("perigo", 480, "⬇️", "DESCER")
local barraTempo = UI.barra({
	Parent = painelElevador,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 384),
	Size = UDim2.fromOffset(840, 16),
	Cor = cores.ouro,
	Raio = 5,
})
local avisoElevador = UI.texto({
	Position = UDim2.fromOffset(0, 408),
	Size = UDim2.new(1, 0, 0, 22),
	FontFace = fontes.texto,
	Text = "",
	TextColor3 = Color3.fromRGB(255, 170, 160),
	Parent = painelElevador,
})

local function responderElevador(escolha: string)
	if abertos[menuElevador] then
		fechar(menuElevador)
		Acao:FireServer("elevador", escolha)
	end
end
botaoSubir.Activated:Connect(function()
	responderElevador("sair")
end)
botaoDescer.Activated:Connect(function()
	responderElevador("continuar")
end)

local idElevador = 0
function Menus.elevador(dados)
	idElevador += 1
	local meu = idElevador
	fechar(menuCartas)
	detalheSubir.Text = "Volte ao acampamento e guarde 💰 " .. dados.ouro
	detalheDescer.Text = "Siga para a sala " .. dados.proximaSala .. ": inimigos mais fortes e mais ouro"
	avisoElevador.Text = "Se cair lá embaixo, você fica com só " .. math.floor(Config.OURO_MANTIDO_AO_MORRER * 100) .. "% do ouro. Sem resposta, você sobe."
	abrir(menuElevador)
	local total = dados.tempo or 25
	local fim = os.clock() + total
	task.spawn(function()
		while idElevador == meu and abertos[menuElevador] do
			local restante = math.max(0, fim - os.clock())
			barraTempo.definir(restante / total, math.ceil(restante) .. "s")
			task.wait(0.1)
		end
	end)
end

------------------------------------------------------------------------
-- Loja do mercador
------------------------------------------------------------------------

local menuLoja = novoMenu("Loja", 680, 560)
local painelLoja = UI.painel({ Size = UDim2.fromScale(1, 1), Parent = menuLoja.conteudo })
botaoFechar(menuLoja)
UI.titulo(painelLoja, "MERCADOR", 16, 400, 52)
local ouroLoja = UI.texto({ Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 28), FontFace = fontes.numero, Text = "", TextColor3 = cores.ouroClaro, Parent = painelLoja })
UI.contorno(ouroLoja, 1.5)

local linhasLoja = {}
for i, melhoria in Config.MELHORIAS do
	local linha = criar("Frame", {
		Position = UDim2.fromOffset(28, 128 + (i - 1) * 132),
		Size = UDim2.new(1, -56, 0, 118),
		BackgroundColor3 = cores.branco,
		Parent = painelLoja,
	})
	UI.cantos(linha, 10)
	UI.gradiente(linha, cores.painelClaro, cores.fundo)
	UI.borda(linha, cores.bronze, 1.5)
	UI.medalhao({ Parent = linha, Icone = melhoria.icone, Position = UDim2.fromOffset(14, 20), Size = UDim2.fromOffset(78, 78), Cor = cores.painelClaro })
	local nome = UI.texto({
		Position = UDim2.fromOffset(106, 14),
		Size = UDim2.fromOffset(300, 30),
		FontFace = fontes.cabecalho,
		Text = melhoria.nome,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = linha,
	})
	UI.contorno(nome, 1.5)
	UI.texto({
		Position = UDim2.fromOffset(106, 46),
		Size = UDim2.fromOffset(300, 22),
		FontFace = fontes.texto,
		Text = melhoria.descricao,
		TextColor3 = cores.textoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = linha,
	})
	local niveis = criar("Frame", { Position = UDim2.fromOffset(110, 80), Size = UDim2.fromOffset(300, 16), BackgroundTransparency = 1, Parent = linha })
	criar("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = niveis })
	local marcas = {}
	for n = 1, melhoria.nivelMax do
		local marca = criar("Frame", { Size = UDim2.fromOffset(12, 12), Rotation = 45, BackgroundColor3 = cores.bronze, BorderSizePixel = 0, LayoutOrder = n, Parent = niveis })
		UI.borda(marca, cores.preto, 1, 0.3)
		marcas[n] = marca
	end
	local comprar = UI.botao({ Parent = linha, Position = UDim2.new(1, -172, 0.5, -28), Size = UDim2.fromOffset(156, 56) })
	comprar.Activated:Connect(function()
		Acao:FireServer("comprarMelhoria", melhoria.id)
	end)
	linhasLoja[melhoria.id] = { melhoria = melhoria, botao = comprar, marcas = marcas }
end

local function atualizarLoja()
	local perfil = Estado.perfil
	ouroLoja.Text = "Seu ouro: 💰 " .. (perfil.ouro or 0)
	for id, linha in linhasLoja do
		local nivel = (perfil.melhorias and perfil.melhorias[id]) or 0
		for n, marca in linha.marcas do
			marca.BackgroundColor3 = if n <= nivel then cores.ouro else Color3.fromRGB(56, 48, 66)
		end
		if nivel >= linha.melhoria.nivelMax then
			UI.textoBotao(linha.botao, "MÁXIMO")
			UI.estiloBotao(linha.botao, "cinza")
		else
			local preco = Config.precoMelhoria(linha.melhoria, nivel)
			UI.textoBotao(linha.botao, "💰 " .. preco)
			UI.estiloBotao(linha.botao, if (perfil.ouro or 0) >= preco then "ouro" else "cinza")
		end
	end
end

function Menus.abrirLoja()
	if Estado.modo ~= "lobby" then
		return
	end
	atualizarLoja()
	abrir(menuLoja)
end

------------------------------------------------------------------------
-- Resumo da partida
------------------------------------------------------------------------

local menuFim = novoMenu("Fim", 780, 560)
local painelFim = UI.painel({ Size = UDim2.fromScale(1, 1), Parent = menuFim.conteudo })
local tituloFim = UI.titulo(painelFim, "", 18, 640, 56)
local fitaRecorde = criar("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 92),
	Size = UDim2.fromOffset(300, 34),
	BackgroundColor3 = cores.sucesso,
	Visible = false,
	Parent = painelFim,
})
UI.cantos(fitaRecorde, 17)
UI.borda(fitaRecorde, cores.preto, 2, 0.2)
local textoFita = UI.texto({ Size = UDim2.fromScale(1, 1), FontFace = fontes.numero, Text = "🏆 NOVO RECORDE!", Parent = fitaRecorde })
UI.contorno(textoFita, 1.5)

local quadrosFim = {}
for i, rotulo in { "Sala alcançada", "Inimigos derrotados", "Dano causado", "Ouro guardado" } do
	local coluna = (i - 1) % 2
	local linha = (i - 1) // 2
	local quadro = criar("Frame", {
		Position = UDim2.fromOffset(40 + coluna * 360, 140 + linha * 100),
		Size = UDim2.fromOffset(340, 88),
		BackgroundColor3 = cores.branco,
		Parent = painelFim,
	})
	UI.cantos(quadro, 10)
	UI.gradiente(quadro, cores.painelClaro, cores.fundo)
	UI.borda(quadro, cores.bronze, 1.5)
	UI.texto({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 20), FontFace = fontes.forte, Text = rotulo, TextColor3 = cores.textoSuave, TextXAlignment = Enum.TextXAlignment.Left, Parent = quadro })
	local valor = UI.texto({
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -32, 0, 44),
		FontFace = fontes.numero,
		Text = "",
		TextColor3 = if i == 4 then cores.ouroClaro else cores.texto,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = quadro,
	})
	UI.contorno(valor, 1.5)
	quadrosFim[i] = valor
end
local cartasFim = criar("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 350),
	Size = UDim2.fromOffset(700, 100),
	BackgroundTransparency = 1,
	Parent = painelFim,
})
criar("UIGridLayout", {
	CellSize = UDim2.fromOffset(44, 44),
	CellPadding = UDim2.fromOffset(8, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = cartasFim,
})
local botaoVoltar = UI.botao({
	Parent = painelFim,
	Texto = "VOLTAR AO ACAMPAMENTO",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -22),
	Size = UDim2.fromOffset(360, 56),
})
botaoVoltar.Activated:Connect(function()
	fechar(menuFim)
end)

local function formatarNumero(n: number): string
	local texto = tostring(math.floor(n))
	local resultado = texto:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if resultado:sub(1, 1) == "." then
		resultado = resultado:sub(2)
	end
	return resultado
end

function Menus.fim(dados)
	fechar(menuCartas)
	fechar(menuElevador)
	local escapou = dados.motivo == "saiu"
	tituloFim.Text = if escapou then "VOCÊ ESCAPOU COM VIDA" else "VOCÊ CAIU NA MASMORRA"
	tituloFim.TextColor3 = if escapou then cores.ouroClaro else Color3.fromRGB(255, 110, 100)
	fitaRecorde.Visible = dados.novoRecorde == true
	quadrosFim[1].Text = "Sala " .. dados.sala
	quadrosFim[2].Text = tostring(dados.abates or 0)
	quadrosFim[3].Text = formatarNumero(dados.dano or 0)
	quadrosFim[4].Text = "💰 " .. dados.ganho .. (if escapou then "" else "  (de " .. dados.ouroPartida .. ")")
	for _, filho in cartasFim:GetChildren() do
		if filho:IsA("Frame") then
			filho:Destroy()
		end
	end
	for ordem, carta in Cartas.lista do
		if (dados.cartas and dados.cartas[carta.id] or 0) > 0 then
			UI.medalhao({ Parent = cartasFim, Icone = carta.icone, Cor = cores.painelClaro, Borda = Config.RARIDADES[carta.raridade].cor, LayoutOrder = ordem })
		end
	end
	abrir(menuFim)
end

------------------------------------------------------------------------
-- Como jogar
------------------------------------------------------------------------

local menuAjuda = novoMenu("Ajuda", 820, 580)
local painelAjuda = UI.painel({ Size = UDim2.fromScale(1, 1), Parent = menuAjuda.conteudo })
botaoFechar(menuAjuda)
UI.titulo(painelAjuda, "COMO JOGAR", 16, 420, 52)
local secoes = {
	{ "🎮", "Controles", "Clique (segure) para atacar  •  E: habilidade  •  Q: esquiva  •  R: supremo\nNo celular, use os botões redondos à direita." },
	{ "⚔️", "Combo", "Todo terceiro ataque é um golpe final mais forte. A barra dourada enche lutando: com ela cheia, use o supremo!" },
	{ "💨", "Esquiva", "Durante a esquiva você não leva dano e atravessa projéteis. Fuja das áreas vermelhas no chão!" },
	{ "🃏", "Cartas", "Depois de cada sala, escolha 1 de 3 cartas. Cada classe tem cartas próprias, e algumas combinam muito bem." },
	{ "❤️", "Reviver", "Aliado caído? Fique perto dele por alguns segundos para levantá-lo." },
	{ "👑", "Chefes", "A cada 5 salas vem um chefe. Depois dele: suba com todo o ouro, ou desça para ganhar mais." },
}
for i, secao in secoes do
	local y = 96 + (i - 1) * 76
	UI.medalhao({ Parent = painelAjuda, Icone = secao[1], Position = UDim2.fromOffset(32, y), Size = UDim2.fromOffset(56, 56), Cor = cores.painelClaro })
	UI.texto({
		Position = UDim2.fromOffset(104, y),
		Size = UDim2.fromOffset(680, 22),
		FontFace = fontes.cabecalho,
		Text = secao[2],
		TextColor3 = cores.ouroClaro,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = painelAjuda,
	})
	local texto = UI.texto({
		Position = UDim2.fromOffset(104, y + 24),
		Size = UDim2.fromOffset(680, 40),
		FontFace = fontes.texto,
		Text = secao[3],
		TextColor3 = cores.texto,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = painelAjuda,
	})
	UI.limiteTexto(texto, 17)
end

function Menus.abrirAjuda()
	abrir(menuAjuda)
end

------------------------------------------------------------------------
-- Troca de modo
------------------------------------------------------------------------

function Menus.fecharPartida()
	fechar(menuCartas)
	fechar(menuElevador)
end

function Menus.fecharLobby()
	fechar(menuClasses)
	fechar(menuLoja)
	fechar(menuAjuda)
	fechar(menuFim)
end

function Menus.iniciar()
	Estado.Mudou:Connect(function(chave)
		if chave == "perfil" then
			atualizarLoja()
			atualizarClasses()
		end
	end)
	RunService.RenderStepped:Connect(function()
		local giro = (os.clock() * 120) % 360
		for _, gradiente in gradientesGirando do
			gradiente.Rotation = giro
		end
	end)
end

return Menus
