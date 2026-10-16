-- Kit visual da interface: cores, fontes e componentes (painéis, botões, barras, medalhões).
-- Estilo "fantasia sombria": painéis escuros, bordas douradas duplas e losangos nos cantos.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Sons = require(script.Parent.Sons)
local TweenService = game:GetService("TweenService")

local UI = {}

UI.cores = {
	fundo = Color3.fromRGB(12, 10, 18),
	painel = Color3.fromRGB(24, 20, 34),
	painelClaro = Color3.fromRGB(44, 37, 60),
	bronze = Color3.fromRGB(128, 100, 62),
	ouro = Color3.fromRGB(236, 192, 96),
	ouroClaro = Color3.fromRGB(255, 228, 160),
	texto = Color3.fromRGB(246, 238, 222),
	textoSuave = Color3.fromRGB(184, 174, 160),
	vida = Color3.fromRGB(206, 40, 52),
	vidaClara = Color3.fromRGB(255, 108, 98),
	perigo = Color3.fromRGB(224, 64, 64),
	sucesso = Color3.fromRGB(86, 204, 112),
	mana = Color3.fromRGB(86, 156, 255),
	preto = Color3.new(0, 0, 0),
	branco = Color3.new(1, 1, 1),
}

local function fonte(nome: Enum.Font, peso: Enum.FontWeight): Font
	return Font.new(Font.fromEnum(nome).Family, peso)
end

UI.fontes = {
	titulo = fonte(Enum.Font.GrenzeGotisch, Enum.FontWeight.Bold),
	cabecalho = fonte(Enum.Font.Merriweather, Enum.FontWeight.Bold),
	texto = fonte(Enum.Font.BuilderSans, Enum.FontWeight.Medium),
	forte = fonte(Enum.Font.BuilderSans, Enum.FontWeight.Bold),
	numero = fonte(Enum.Font.BuilderSans, Enum.FontWeight.ExtraBold),
}

------------------------------------------------------------------------
-- Básico
------------------------------------------------------------------------

function UI.criar(classe: string, propriedades): any
	local objeto = Instance.new(classe)
	for chave, valor in propriedades do
		if chave ~= "Parent" then
			(objeto :: any)[chave] = valor
		end
	end
	objeto.Parent = propriedades.Parent
	return objeto
end
local criar = UI.criar

function UI.animar(objeto: Instance, duracao: number, propriedades, estilo: Enum.EasingStyle?, direcao: Enum.EasingDirection?)
	local tween = TweenService:Create(objeto, TweenInfo.new(duracao, estilo or Enum.EasingStyle.Quad, direcao or Enum.EasingDirection.Out), propriedades)
	tween:Play()
	return tween
end
local animar = UI.animar

function UI.cantos(objeto: Instance, raio: number?)
	return criar("UICorner", { CornerRadius = UDim.new(0, raio or 10), Parent = objeto })
end

function UI.redondo(objeto: Instance)
	return criar("UICorner", { CornerRadius = UDim.new(1, 0), Parent = objeto })
end

function UI.borda(objeto: Instance, cor: Color3, espessura: number?, transparencia: number?): UIStroke
	return criar("UIStroke", {
		Color = cor,
		Thickness = espessura or 2,
		Transparency = transparencia or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = objeto,
	})
end

-- Contorno escuro no texto (fica legível em qualquer fundo)
function UI.contorno(objeto: Instance, espessura: number?, transparencia: number?): UIStroke
	return criar("UIStroke", {
		Color = UI.cores.preto,
		Thickness = espessura or 2,
		Transparency = transparencia or 0.25,
		Parent = objeto,
	})
end

function UI.gradiente(objeto: Instance, topo: Color3, base: Color3, rotacao: number?)
	return criar("UIGradient", { Color = ColorSequence.new(topo, base), Rotation = rotacao or 90, Parent = objeto })
end

function UI.texto(propriedades): TextLabel
	local final = {
		BackgroundTransparency = 1,
		FontFace = UI.fontes.forte,
		TextColor3 = UI.cores.texto,
		TextScaled = true,
	}
	for chave, valor in propriedades do
		final[chave] = valor
	end
	return criar("TextLabel", final)
end

function UI.limiteTexto(objeto: Instance, maximo: number)
	criar("UITextSizeConstraint", { MaxTextSize = maximo, Parent = objeto })
end

------------------------------------------------------------------------
-- Escala para caber em qualquer tela (o desenho é feito para ~1280x720)
------------------------------------------------------------------------

local escalas = {}
UI.escalaAtual = 1

function UI.atualizarEscala()
	local camera = workspace.CurrentCamera
	local tela = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	UI.escalaAtual = math.clamp(math.min(tela.X / 1280, tela.Y / 720), 0.55, 1.3)
	for objeto, base in escalas do
		if objeto.Parent then
			objeto.Scale = UI.escalaAtual * base
		else
			escalas[objeto] = nil
		end
	end
end

function UI.escalavel(objeto: Instance, fator: number?): UIScale
	local escala = criar("UIScale", { Scale = UI.escalaAtual * (fator or 1), Parent = objeto })
	escalas[escala] = fator or 1
	return escala
end

function UI.ehCelular(): boolean
	local UserInputService = game:GetService("UserInputService")
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

------------------------------------------------------------------------
-- Sons da interface (os sons em si ficam em Sons.luau)
------------------------------------------------------------------------

UI.SONS = {
	clique = "clique",
	carta = "carta",
}

-- volume relativo: 0.4 é o normal
function UI.tocar(nome: string, volume: number?)
	Sons.tocar(nome, { volume = (volume or 0.4) / 0.4 })
end

------------------------------------------------------------------------
-- Componentes
------------------------------------------------------------------------

-- Losango dourado (usado nos cantos e nos separadores)
function UI.losango(pai: Instance, posicao: UDim2, tamanho: number, cor: Color3?)
	local l = criar("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = posicao,
		Size = UDim2.fromOffset(tamanho, tamanho),
		Rotation = 45,
		BackgroundColor3 = cor or UI.cores.ouro,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = pai,
	})
	UI.borda(l, UI.cores.preto, 1, 0.3)
	return l
end

-- Painel com borda dupla e losangos nos cantos
function UI.painel(propriedades): Frame
	local final = {
		BackgroundColor3 = UI.cores.branco,
		BorderSizePixel = 0,
	}
	for chave, valor in propriedades do
		if chave ~= "Transparencia" and chave ~= "SemCantos" and chave ~= "Cor" then
			final[chave] = valor
		end
	end
	final.BackgroundTransparency = propriedades.Transparencia or 0.04
	local painel = criar("Frame", final)
	UI.cantos(painel, 10)
	local corBase = propriedades.Cor or UI.cores.painel
	UI.gradiente(painel, corBase:Lerp(UI.cores.painelClaro, 0.55), corBase:Lerp(UI.cores.fundo, 0.4))
	UI.borda(painel, UI.cores.bronze, 2)
	local interna = criar("Frame", {
		Name = "BordaInterna",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
		Parent = painel,
	})
	UI.cantos(interna, 7)
	UI.borda(interna, UI.cores.ouro, 1, 0.65)
	if not propriedades.SemCantos then
		for _, canto in { UDim2.fromScale(0, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), UDim2.fromScale(1, 1) } do
			UI.losango(painel, canto, 10)
		end
	end
	return painel
end

-- Linha ornamental com losango no meio
function UI.separador(pai: Instance, posicao: UDim2, largura: number, cor: Color3?)
	local caixa = criar("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = posicao,
		Size = UDim2.fromOffset(largura, 12),
		BackgroundTransparency = 1,
		Parent = pai,
	})
	local corLinha = cor or UI.cores.ouro
	for _, lado in { 0, 1 } do
		local linha = criar("Frame", {
			AnchorPoint = Vector2.new(lado, 0.5),
			Position = UDim2.fromScale(lado, 0.5),
			Size = UDim2.new(0.5, -10, 0, 2),
			BackgroundColor3 = corLinha,
			BorderSizePixel = 0,
			Parent = caixa,
		})
		criar("UIGradient", {
			Transparency = NumberSequence.new(if lado == 0 then 1 else 0, if lado == 0 then 0 else 1),
			Parent = linha,
		})
	end
	UI.losango(caixa, UDim2.fromScale(0.5, 0.5), 8, corLinha)
	return caixa
end

-- Título grande com separador embaixo
function UI.titulo(pai: Instance, texto: string, y: number, largura: number, altura: number?, fonteTitulo: Font?)
	local rotulo = UI.texto({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(largura, altura or 44),
		FontFace = fonteTitulo or UI.fontes.titulo,
		Text = texto,
		TextColor3 = UI.cores.ouroClaro,
		Parent = pai,
	})
	UI.contorno(rotulo, 2)
	UI.separador(pai, UDim2.new(0.5, 0, 0, y + (altura or 44) + 6), math.min(largura, 360))
	return rotulo
end

local CORES_BOTAO = {
	ouro = { Color3.fromRGB(255, 220, 130), Color3.fromRGB(196, 136, 46), Color3.fromRGB(46, 28, 8) },
	escuro = { Color3.fromRGB(70, 60, 92), Color3.fromRGB(34, 28, 46), UI.cores.texto },
	perigo = { Color3.fromRGB(236, 96, 90), Color3.fromRGB(150, 32, 40), UI.cores.texto },
	verde = { Color3.fromRGB(130, 230, 140), Color3.fromRGB(44, 140, 70), UI.cores.texto },
	cinza = { Color3.fromRGB(110, 108, 116), Color3.fromRGB(64, 62, 70), Color3.fromRGB(200, 196, 190) },
}

--[[ Botão. propriedades: Texto, Estilo (ouro/escuro/perigo/verde), Position, Size, AnchorPoint, Parent, TamanhoTexto
	Devolve o TextButton; use botao.Activated. Para trocar o estilo: UI.estiloBotao(botao, "cinza") ]]
function UI.botao(propriedades): TextButton
	local b = criar("TextButton", {
		AnchorPoint = propriedades.AnchorPoint or Vector2.zero,
		Position = propriedades.Position or UDim2.new(),
		Size = propriedades.Size or UDim2.fromOffset(200, 50),
		BackgroundColor3 = UI.cores.branco,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = propriedades.LayoutOrder or 0,
		Parent = propriedades.Parent,
	})
	UI.cantos(b, 9)
	local gradiente = criar("UIGradient", { Rotation = 90, Parent = b })
	local contorno = UI.borda(b, UI.cores.preto, 2, 0.1)
	criar("Frame", {
		Name = "Brilho",
		BackgroundColor3 = UI.cores.branco,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 0, 3),
		Size = UDim2.new(1, -12, 0, 2),
		Parent = b,
	})
	local rotulo = UI.texto({
		Name = "Rotulo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(1, -16, 0.62, 0),
		FontFace = UI.fontes.numero,
		Text = propriedades.Texto or "",
		Parent = b,
	})
	if propriedades.TamanhoTexto then
		UI.limiteTexto(rotulo, propriedades.TamanhoTexto)
	end
	local escala = criar("UIScale", { Parent = b })

	b:SetAttribute("Estilo", propriedades.Estilo or "ouro")
	local function aplicarEstilo()
		local cores = CORES_BOTAO[b:GetAttribute("Estilo")] or CORES_BOTAO.ouro
		gradiente.Color = ColorSequence.new(cores[1], cores[2])
		rotulo.TextColor3 = cores[3]
		contorno.Color = cores[2]:Lerp(UI.cores.preto, 0.6)
	end
	aplicarEstilo()
	b:GetAttributeChangedSignal("Estilo"):Connect(aplicarEstilo)

	b.MouseEnter:Connect(function()
		animar(escala, 0.12, { Scale = 1.05 })
	end)
	b.MouseLeave:Connect(function()
		animar(escala, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		animar(escala, 0.06, { Scale = 0.95 })
	end)
	b.MouseButton1Up:Connect(function()
		animar(escala, 0.1, { Scale = 1.03 })
	end)
	b.Activated:Connect(function()
		UI.tocar(UI.SONS.clique, 0.25)
	end)
	return b
end

function UI.estiloBotao(botao: TextButton, estilo: string)
	botao:SetAttribute("Estilo", estilo)
end

function UI.textoBotao(botao: TextButton, texto: string)
	local rotulo = botao:FindFirstChild("Rotulo") :: TextLabel?
	if rotulo then
		rotulo.Text = texto
	end
end

-- Medalhão redondo com um ícone (emoji) no meio
function UI.medalhao(propriedades): Frame
	local cor = propriedades.Cor or UI.cores.ouro
	local m = criar("Frame", {
		AnchorPoint = propriedades.AnchorPoint or Vector2.zero,
		Position = propriedades.Position or UDim2.new(),
		Size = propriedades.Size or UDim2.fromOffset(56, 56),
		BackgroundColor3 = UI.cores.branco,
		LayoutOrder = propriedades.LayoutOrder or 0,
		Parent = propriedades.Parent,
	})
	UI.redondo(m)
	UI.gradiente(m, cor:Lerp(UI.cores.branco, 0.15), cor:Lerp(UI.cores.fundo, 0.65))
	UI.borda(m, propriedades.Borda or UI.cores.ouro, propriedades.EspessuraBorda or 2)
	UI.texto({
		Name = "Icone",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Text = propriedades.Icone or "",
		Parent = m,
	})
	return m
end

--[[ Barra com rastro: o pedaço perdido some devagar (como nos jogos de luta).
	propriedades: Position, Size, Cor, CorClara, Fundo, Raio, Borda e EspessuraBorda (contorno)
	Devolve { quadro, definir(fracao, texto), cor(nova) } ]]
function UI.barra(propriedades)
	local quadro = criar("Frame", {
		AnchorPoint = propriedades.AnchorPoint or Vector2.zero,
		Position = propriedades.Position or UDim2.new(),
		Size = propriedades.Size or UDim2.fromOffset(300, 22),
		BackgroundColor3 = propriedades.Fundo or Color3.fromRGB(26, 14, 18),
		BorderSizePixel = 0,
		Parent = propriedades.Parent,
	})
	UI.cantos(quadro, propriedades.Raio or 6)
	UI.borda(quadro, propriedades.Borda or UI.cores.preto, propriedades.EspessuraBorda or 2, if propriedades.Borda then 0 else 0.1)
	local rastro = criar("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = propriedades.CorRastro or Color3.fromRGB(255, 236, 200),
		BorderSizePixel = 0,
		Parent = quadro,
	})
	UI.cantos(rastro, propriedades.Raio or 6)
	local preenchimento = criar("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.cores.branco,
		BorderSizePixel = 0,
		Parent = quadro,
	})
	UI.cantos(preenchimento, propriedades.Raio or 6)
	local cor = propriedades.Cor or UI.cores.vida
	local gradiente = UI.gradiente(preenchimento, (propriedades.CorClara or cor:Lerp(UI.cores.branco, 0.35)), cor)
	criar("Frame", {
		BackgroundColor3 = UI.cores.branco,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 3, 0, 2),
		Size = UDim2.new(1, -6, 0.22, 0),
		Parent = preenchimento,
	})
	local rotulo = UI.texto({
		Size = UDim2.fromScale(1, 1),
		FontFace = UI.fontes.numero,
		Text = "",
		ZIndex = 3,
		Parent = quadro,
	})
	UI.contorno(rotulo, 1.5)

	local atual = 1
	local objeto = { quadro = quadro, rotulo = rotulo, preenchimento = preenchimento }
	function objeto.definir(fracao: number, texto: string?)
		fracao = math.clamp(fracao, 0, 1)
		if math.abs(fracao - atual) > 0.0005 then
			animar(preenchimento, 0.12, { Size = UDim2.fromScale(fracao, 1) })
			if fracao < atual then
				task.delay(0.3, function()
					animar(rastro, 0.45, { Size = UDim2.fromScale(fracao, 1) })
				end)
			else
				rastro.Size = UDim2.fromScale(fracao, 1)
			end
			atual = fracao
		end
		if texto then
			rotulo.Text = texto
		end
	end
	function objeto.cor(nova: Color3)
		gradiente.Color = ColorSequence.new(nova:Lerp(UI.cores.branco, 0.35), nova)
	end
	return objeto
end

------------------------------------------------------------------------
-- Desfoque do fundo quando um menu está aberto
------------------------------------------------------------------------

local desfoque = Lighting:FindFirstChild("DesfoqueMenu") or criar("BlurEffect", { Name = "DesfoqueMenu", Size = 0, Parent = Lighting })
local menusAbertos = 0

function UI.desfocar(ligar: boolean)
	menusAbertos = math.max(0, menusAbertos + (if ligar then 1 else -1))
	animar(desfoque, 0.25, { Size = if menusAbertos > 0 then 14 else 0 })
end

-- Foto do jogador (rosto do avatar)
function UI.fotoJogador(userId: number): string
	return "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
end

function UI.jogadorLocal(): Player
	return Players.LocalPlayer
end

return UI
