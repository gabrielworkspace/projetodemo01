-- Braço que se mexe num modelo 3D de uma peça só (sem esqueleto), como o Skullbane.
-- Usa EditableMesh: os vértices do braço e da lâmina giram pelo ombro e pelo cotovelo.
--
-- As medidas vêm do arquivo original (.glb), num espaço em que o modelo olha para +Z e o braço
-- da lâmina fica do lado -X. A malha do Roblox é ligada a esse espaço pela caixa em volta
-- (mínimo e máximo de cada eixo), então não importa se o Roblox centralizou ou espelhou.
--
-- Pose do braço (radianos):
--   lev = levanta para a frente/cima (0 = caído, 1,57 = para a frente, 2,7 = acima da cabeça)
--   abr = abre para o lado de fora     gir = gira na horizontal (+ = cruza na frente do corpo)
--   cot = dobra o cotovelo para a frente
--
-- Precisa de Game Settings > Security > "Allow Mesh / Image APIs". Sem isso (ou se der erro),
-- BracoMalha.criar devolve nil e o modelo fica com o braço parado.

local AssetService = game:GetService("AssetService")

local BracoMalha = {}

local function suave(a: number, b: number, x: number): number
	local k = math.clamp((x - a) / (b - a), 0, 1)
	return k * k * (3 - 2 * k)
end

-- Pesos de um ponto (espaço do .glb): w = o quanto gira com o ombro, wE = com o cotovelo
local function pesos(def, p: Vector3): (number, number)
	local cadeia, raios = def.cadeia, def.raios
	local melhor, sMelhor, rMelhor = math.huge, 0, 0
	local acumulado = 0
	local inicioCotovelo = 0
	for i = 1, #cadeia - 1 do
		local a, b = cadeia[i], cadeia[i + 1]
		local ab = b - a
		local comprimento = ab.Magnitude
		local t = math.clamp((p - a):Dot(ab) / (comprimento * comprimento), 0, 1)
		local d = (p - (a + ab * t)).Magnitude
		if d < melhor then
			melhor, sMelhor, rMelhor = d, acumulado + t * comprimento, raios[i]
		end
		if i == 1 then
			inicioCotovelo = comprimento
		end
		acumulado += comprimento
	end
	-- transições largas: na malha do Roblox (com triângulos maiores que os do .glb) um
	-- triângulo nunca fica com um canto girando e outro parado
	local w = (1 - suave(rMelhor - 0.05, rMelhor, melhor)) * suave(0.02, 0.18, sMelhor)
	local wE = suave(inicioCotovelo - 0.08, inicioCotovelo + 0.08, sMelhor)
	local regras = def.regras
	-- pernas nunca mexem (nem um espinho do pé que fique do lado da arma)
	if regras.pernasY and p.Y < regras.pernasY then
		return 0, 0
	end
	-- lâmina e manopla: tudo à esquerda da capa abaixo do pulso vai inteiro com o braço
	if p.Y < regras.pulsoY and p.X < regras.laminaX then
		return 1, 1
	end
	-- capa e corpo: nunca mexem
	if (p.Y < regras.pulsoY and p.X > regras.capaX) or p.X > regras.corpoX then
		return 0, 0
	end
	return w, wE
end

-- Rotações do ombro e do cotovelo (espaço do .glb) para uma pose
local function rotacoes(lev: number, abr: number, gir: number, cot: number): (CFrame, CFrame)
	local ombro = CFrame.Angles(0, gir, 0) * CFrame.Angles(0, 0, -abr) * CFrame.Angles(-lev, 0, 0)
	local cotovelo = CFrame.Angles(-cot, 0, 0)
	return ombro, cotovelo
end
BracoMalha.rotacoes = rotacoes

-- Transformação da lâmina (pontos com peso total) no espaço do .glb
function BracoMalha.transformacao(def, lev: number, abr: number, gir: number, cot: number): CFrame
	local ombro, cotovelo = rotacoes(lev, abr, gir, cot)
	local s, e = def.cadeia[1], def.cadeia[2]
	return CFrame.new(s) * ombro * CFrame.new(-s) * CFrame.new(e) * cotovelo * CFrame.new(-e)
end

--[[ Cria a malha editável a partir da peça original. Devolve { parte = MeshPart nova (já com
	a mesma aparência e tamanho), aplicar = function(lev, abr, gir, cot) } ou nil.
	Demora um pouco (carrega a malha); chame dentro de task.spawn. ]]
function BracoMalha.criar(original: MeshPart, def)
	local ok, resultado = pcall(function()
		local conteudo = Content.fromUri(original.MeshId)
		local malha = AssetService:CreateEditableMeshAsync(conteudo, { FixedSize = false })
		local vertices = malha:GetVertices()
		if #vertices == 0 then
			error("malha sem vértices")
		end
		-- caixa da malha do Roblox
		local minimo = Vector3.one * math.huge
		local maximo = -Vector3.one * math.huge
		local posicoes = {}
		local menorX, maiorX = nil, nil
		for _, id in vertices do
			local p = malha:GetPosition(id)
			posicoes[id] = p
			minimo = minimo:Min(p)
			maximo = maximo:Max(p)
			if not menorX or p.X < posicoes[menorX].X then
				menorX = id
			end
			if not maiorX or p.X > posicoes[maiorX].X then
				maiorX = id
			end
		end
		local extensao = maximo - minimo
		-- espelhado? Compara os pontos mais à esquerda e mais à direita com os mesmos pontos
		-- medidos no .glb (altura e profundidade de 0 a 1 dentro da caixa)
		local function relativo(p: Vector3): Vector2
			local u = (p - minimo) / extensao
			return Vector2.new(u.Y, u.Z)
		end
		local a, b = relativo(posicoes[menorX]), relativo(posicoes[maiorX])
		local refMin, refMax = def.referencia.minX, def.referencia.maxX
		local espelhoX = math.abs(a.X - refMin.X) + math.abs(b.X - refMax.X) > math.abs(a.X - refMax.X) + math.abs(b.X - refMin.X)
		local ponta = if espelhoX then b else a -- o ponto que no .glb é o mais à esquerda
		local espelhoZ = math.abs(ponta.Y - refMin.Y) > math.abs((1 - ponta.Y) - refMin.Y)
		local gMin, gMax = def.caixa.min, def.caixa.max
		local gExt = gMax - gMin
		local function paraGlb(p: Vector3): Vector3
			local u = (p - minimo) / extensao
			if espelhoX then
				u = Vector3.new(1 - u.X, u.Y, u.Z)
			end
			if espelhoZ then
				u = Vector3.new(u.X, u.Y, 1 - u.Z)
			end
			return gMin + u * gExt
		end
		local function daGlb(g: Vector3): Vector3
			local u = (g - gMin) / gExt
			if espelhoX then
				u = Vector3.new(1 - u.X, u.Y, u.Z)
			end
			if espelhoZ then
				u = Vector3.new(u.X, u.Y, 1 - u.Z)
			end
			return minimo + u * extensao
		end
		local sinal = Vector3.new(if espelhoX then -1 else 1, 1, if espelhoZ then -1 else 1)

		-- vértices que se mexem, com os pesos e as normais
		local braco = {}
		for _, id in vertices do
			local g = paraGlb(posicoes[id])
			local w, wE = pesos(def, g)
			if w > 0.001 then
				table.insert(braco, { id, g, w, wE, {} })
			end
		end
		if #braco == 0 then
			error("nenhum vértice no braço (o modelo é outro?)")
		end

		-- Triângulos que ligam a parte que gira à parte parada (a malha da IA é uma casca só:
		-- a lâmina pode estar "colada" na coxa ou na capa) esticariam em fios compridos com a
		-- textura da lâmina. Eles são apagados; se forem muitos, o braço fica parado.
		local pesoDe = {}
		for _, v in braco do
			pesoDe[v[1]] = v
		end
		local remover, facesDoBraco = {}, 0
		for _, face in malha:GetFaces() do
			local menorW, maiorW, menorE, maiorE = 1, 0, 1, 0
			for _, id in malha:GetFaceVertices(face) do
				local v = pesoDe[id]
				local w = if v then v[3] else 0
				local we = if v then v[3] * v[4] else 0
				menorW, maiorW = math.min(menorW, w), math.max(maiorW, w)
				menorE, maiorE = math.min(menorE, we), math.max(maiorE, we)
			end
			if maiorW > 0.001 then
				facesDoBraco += 1
				if maiorW - menorW > 0.45 or maiorE - menorE > 0.6 then
					table.insert(remover, face)
				end
			end
		end
		if facesDoBraco == 0 or #remover / facesDoBraco > 0.15 then
			error(string.format("%d de %d triângulos do braço esticariam (a malha não combina com as medidas)", #remover, facesDoBraco))
		end
		for _, face in remover do
			malha:RemoveFace(face)
		end
		-- normais de cada vértice (lidas depois de apagar os triângulos, só as que sobraram)
		for _, v in braco do
			local okNormais, ids = pcall(function()
				return malha:GetVertexNormals(v[1])
			end)
			if okNormais and ids then
				for _, idNormal in ids do
					local n = malha:GetNormal(idNormal)
					if n then
						table.insert(v[5], { idNormal, n * sinal })
					end
				end
			end
		end

		local parte = AssetService:CreateMeshPartAsync(Content.fromObject(malha))
		parte.Size = original.Size
		for _, filho in original:GetChildren() do
			if filho:IsA("SurfaceAppearance") then
				filho:Clone().Parent = parte
			end
		end
		parte.Anchored = true
		parte.CanCollide = false
		parte.CanQuery = false
		parte.CanTouch = false
		parte.CastShadow = original.CastShadow
		parte.Massless = true

		local s, e = def.cadeia[1], def.cadeia[2]
		local function aplicar(lev: number, abr: number, gir: number, cot: number)
			local ombro, cotovelo = rotacoes(lev, abr, gir, cot)
			local tudo = ombro * cotovelo
			for _, v in braco do
				local g, w, wE = v[2], v[3], v[4]
				local p1 = g
				if wE > 0.001 then
					p1 = g:Lerp(e + cotovelo:VectorToWorldSpace(g - e), w * wE)
				end
				local p2 = p1:Lerp(s + ombro:VectorToWorldSpace(p1 - s), w)
				malha:SetPosition(v[1], daGlb(p2))
				-- normais: giram junto (a luz bate certo no braço erguido)
				if w > 0.5 then
					local rot = if wE > 0.5 then tudo else ombro
					for _, n in v[5] do
						malha:SetNormal(n[1], rot:VectorToWorldSpace(n[2]) * sinal)
					end
				end
			end
		end
		return { parte = parte, aplicar = aplicar, vertices = #braco }
	end)
	if not ok then
		warn("[BracoMalha] O braço do chefe vai ficar parado (" .. tostring(resultado) .. "). Ligue Game Settings > Security > Allow Mesh / Image APIs.")
		return nil
	end
	return resultado
end

return BracoMalha
