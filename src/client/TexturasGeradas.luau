-- Texturas de efeitos desenhadas pelo próprio jogo (sem enviar imagens para o Roblox):
-- lua de corte, onda de choque, brilho, faísca em rastro, estrela de crítico, fumaça com
-- ruído, chama, círculo mágico com runas, raio e faixa de rastro.
--
-- O desenho é feito pixel a pixel (funções "puras", testáveis fora do Roblox) e vira um
-- EditableImage. Se o Roblox não deixar criar imagens (recurso desligado no jogo), os
-- efeitos usam as texturas padrão do Roblox — nada quebra.
-- Para garantir no jogo publicado: Game Settings > Security > "Allow Mesh / Image APIs".

local TexturasGeradas = {}

------------------------------------------------------------------------
-- Matemática de desenho (u, v de 0 a 1; devolve brilho e opacidade de 0 a 1)
------------------------------------------------------------------------

local function suave(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function ruido(x: number, y: number, oitavas: number): number
	local total, amplitude, frequencia, soma = 0, 1, 1, 0
	for _ = 1, oitavas do
		total += math.noise(x * frequencia, y * frequencia, 7.3) * amplitude
		soma += amplitude
		amplitude *= 0.5
		frequencia *= 2
	end
	return total / soma -- mais ou menos de -0,5 a 0,5
end

local function centro(u: number, v: number): (number, number, number)
	local x, y = u * 2 - 1, v * 2 - 1
	return x, y, math.sqrt(x * x + y * y)
end

-- distância de um ponto a um segmento
local function distSegmento(px: number, py: number, ax: number, ay: number, bx: number, by: number): number
	local dx, dy = bx - ax, by - ay
	local t = math.clamp(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0, 1)
	local qx, qy = ax + dx * t - px, ay + dy * t - py
	return math.sqrt(qx * qx + qy * qy)
end

local DESENHOS = {}

-- Brilho redondo com núcleo quente
DESENHOS.brilho = function(u, v)
	local _, _, r = centro(u, v)
	local a = math.clamp(1 - r, 0, 1) ^ 2.2 + math.exp(-r * r * 40) * 0.6
	return 1, math.min(a, 1)
end

-- Onda de choque: anel fino de borda viva, com um leve rastro para dentro
DESENHOS.onda = function(u, v)
	local _, _, r = centro(u, v)
	local anel = math.exp(-((r - 0.82) / 0.05) ^ 2)
	local dentro = suave(0.3, 0.8, r) * (1 - suave(0.8, 0.86, r)) * 0.35
	return 1, math.clamp(anel + dentro, 0, 1)
end

-- Faísca em rastro (vertical: o Roblox estica na direção do movimento)
DESENHOS.faisca = function(u, v)
	local x, y = u * 2 - 1, v * 2 - 1
	local a = math.exp(-(x * x) / 0.012) * math.exp(-(y * y) / 0.35)
	local nucleo = math.exp(-(x * x) / 0.002) * math.exp(-(y * y) / 0.12)
	return 1, math.clamp(a + nucleo, 0, 1)
end

-- Estrela de 4 pontas (crítico, brilho de impacto)
DESENHOS.estrela = function(u, v)
	local x, y, r = centro(u, v)
	local raios = math.exp(-math.abs(x) * 28) * math.exp(-y * y * 3) + math.exp(-math.abs(y) * 28) * math.exp(-x * x * 3)
	local diagonal = (math.exp(-math.abs(x - y) * 40) + math.exp(-math.abs(x + y) * 40)) * math.exp(-r * r * 9) * 0.5
	local nucleo = math.exp(-r * r * 30)
	return 1, math.clamp(raios + diagonal + nucleo, 0, 1)
end

-- Lua de corte: crescente grosso no meio e fino nas pontas; a ponta da frente (direita) é
-- a mais forte e a de trás vai sumindo, como um rastro
DESENHOS.corte = function(u, v)
	local x, y = u * 2 - 1, v * 2 - 1
	local fora = math.sqrt(x * x + (y - 0.15) ^ 2)
	local dentro = math.sqrt(x * x + (y + 0.12) ^ 2)
	local forma = (1 - suave(0.86, 0.92, fora)) * suave(0.78, 0.86, dentro)
	local rastroDeTras = suave(-1, 0.7, x)
	local fio = math.exp(-((fora - 0.89) / 0.025) ^ 2) -- fio da lâmina mais claro
	return 0.7 + 0.3 * fio, math.clamp(forma * rastroDeTras * (0.55 + fio), 0, 1)
end

-- Fumaça: nuvem com ruído e bordas macias
DESENHOS.fumaca = function(u, v)
	local x, y, r = centro(u, v)
	local n = ruido(u * 3, v * 3, 4)
	local forma = 1 - suave(0.45, 1, r + n * 0.5)
	local tom = 0.75 + n * 0.5
	return math.clamp(tom, 0.4, 1), math.clamp(forma * (0.8 + n), 0, 1)
end

-- Chama: gota que afina para cima, distorcida por ruído, núcleo branco
DESENHOS.chama = function(u, v)
	local x = u * 2 - 1
	local y = 1 - v -- 0 embaixo, 1 em cima
	local distorcao = ruido(u * 4, v * 3 - 1, 3) * 0.35 * y
	local largura = 0.85 * (1 - y) ^ 0.6 * (0.55 + 0.45 * math.sin(math.min(y, 1) * math.pi))
	local d = math.abs(x + distorcao) / math.max(largura, 0.001)
	local forma = (1 - suave(0.55, 1, d)) * suave(0, 0.15, y) * (1 - suave(0.85, 1, y))
	local nucleo = (1 - suave(0, 0.5, d)) * (1 - suave(0.2, 0.7, y))
	return math.clamp(0.75 + nucleo * 0.4, 0, 1), math.clamp(forma, 0, 1)
end

-- Círculo mágico: anéis, marcas em volta, hexagrama e pontinhos (runas)
DESENHOS.circulo = function(u, v)
	local x, y, r = centro(u, v)
	local a = 0
	local function anel(raio, largura)
		a += math.exp(-((r - raio) / largura) ^ 2)
	end
	anel(0.93, 0.012)
	anel(0.86, 0.008)
	anel(0.58, 0.01)
	anel(0.2, 0.012)
	local angulo = math.atan2(y, x)
	-- marcas entre os dois anéis de fora
	if r > 0.865 and r < 0.925 then
		local marca = math.abs(((angulo / (2 * math.pi) * 48) % 1) - 0.5)
		a += (1 - suave(0.04, 0.12, marca)) * 0.9
	end
	-- "runas": pontos e traços na faixa do meio
	if r > 0.62 and r < 0.82 then
		local setor = math.floor((angulo + math.pi) / (2 * math.pi) * 16)
		local fase = ((angulo / (2 * math.pi) * 16) % 1)
		local altura = (r - 0.62) / 0.2
		local padrao = (setor % 3 == 0 and math.abs(fase - 0.5) < 0.08)
			or (setor % 3 == 1 and math.abs(altura - 0.5) < 0.1 and math.abs(fase - 0.5) < 0.3)
			or (setor % 3 == 2 and math.abs(fase - 0.3) < 0.07 and altura > 0.25 and altura < 0.75)
		if padrao then
			a += 0.85
		end
	end
	-- hexagrama (dois triângulos) dentro do anel do meio
	local pontos = {}
	for i = 0, 5 do
		local ang = math.pi / 2 + i * math.pi / 3
		pontos[i] = { math.cos(ang) * 0.58, math.sin(ang) * 0.58 }
	end
	for _, tri in { { 0, 2, 4 }, { 1, 3, 5 } } do
		for k = 1, 3 do
			local p1, p2 = pontos[tri[k]], pontos[tri[k % 3 + 1]]
			a += math.exp(-(distSegmento(x, y, p1[1], p1[2], p2[1], p2[2]) / 0.01) ^ 2)
		end
	end
	a += math.exp(-r * r * 60) * 0.6
	return 1, math.clamp(a, 0, 1)
end

-- Raio: linha em zigue-zague ao longo do comprimento (para Beams)
DESENHOS.raio = function(u, v)
	local desvio = ruido(u * 6, 0.5, 3) * 0.6 + ruido(u * 20, 3.1, 2) * 0.15
	local d = math.abs(v - 0.5 - desvio)
	local nucleo = math.exp(-(d / 0.02) ^ 2)
	local aura = math.exp(-(d / 0.09) ^ 2) * 0.5
	return 1, math.clamp(nucleo + aura, 0, 1)
end

-- Faixa de rastro (para Beams/Trails): centro forte, bordas macias
DESENHOS.rastro = function(_u, v)
	local d = math.abs(v - 0.5)
	return 1, math.clamp(math.exp(-(d / 0.07) ^ 2) + math.exp(-(d / 0.25) ^ 2) * 0.45, 0, 1)
end

-- Tamanho de cada textura (largura, altura)
local TAMANHOS = {
	brilho = { 64, 64 },
	onda = { 128, 128 },
	faisca = { 32, 64 },
	estrela = { 128, 128 },
	corte = { 128, 128 },
	fumaca = { 128, 128 },
	chama = { 64, 128 },
	circulo = { 256, 256 },
	raio = { 256, 64 },
	rastro = { 16, 64 },
}
TexturasGeradas.TAMANHOS = TAMANHOS
TexturasGeradas.DESENHOS = DESENHOS

-- Desenha uma textura num buffer RGBA (4 bytes por pixel)
function TexturasGeradas.desenhar(nome: string): (buffer, number, number)
	local tamanho = TAMANHOS[nome]
	local largura, altura = tamanho[1], tamanho[2]
	local desenho = DESENHOS[nome]
	local dados = buffer.create(largura * altura * 4)
	for py = 0, altura - 1 do
		for px = 0, largura - 1 do
			local brilho, alfa = desenho((px + 0.5) / largura, (py + 0.5) / altura)
			local i = (py * largura + px) * 4
			local valor = math.floor(math.clamp(brilho, 0, 1) * 255 + 0.5)
			buffer.writeu8(dados, i, valor)
			buffer.writeu8(dados, i + 1, valor)
			buffer.writeu8(dados, i + 2, valor)
			buffer.writeu8(dados, i + 3, math.floor(math.clamp(alfa, 0, 1) * 255 + 0.5))
		end
	end
	return dados, largura, altura
end

------------------------------------------------------------------------
-- No Roblox: cria os EditableImage (aos poucos, para não travar o jogo)
------------------------------------------------------------------------

local prontas = {} -- [nome] = Content

-- Content da textura gerada, ou nil se ainda não existe / não foi possível criar
function TexturasGeradas.obter(nome: string): any
	return prontas[nome]
end

function TexturasGeradas.iniciar()
	local AssetService = game:GetService("AssetService")
	task.spawn(function()
		for nome in TAMANHOS do
			local ok, erro = pcall(function()
				local dados, largura, altura = TexturasGeradas.desenhar(nome)
				local imagem = AssetService:CreateEditableImage({ Size = Vector2.new(largura, altura) })
				imagem:WritePixelsBuffer(Vector2.zero, Vector2.new(largura, altura), dados)
				prontas[nome] = Content.fromObject(imagem)
			end)
			if not ok then
				warn("[Texturas] Não deu para criar as texturas próprias (usando as padrão do Roblox): " .. tostring(erro))
				return
			end
			task.wait() -- uma por quadro
		end
	end)
end

return TexturasGeradas
