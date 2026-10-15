-- Projéteis (flechas, orbes, bolas de fogo...). O servidor calcula o trajeto e os acertos;
-- os jogadores só desenham. Funciona para projéteis de jogadores e de inimigos.

local Vfx = require(script.Parent.Vfx)

local Projeteis = {}

local proximoId = 0

local function planar(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Distância (no plano) de um ponto até o segmento a-b, e a posição relativa no segmento (0 a 1)
local function distanciaAoSegmento(ponto: Vector3, a: Vector3, b: Vector3): (number, number)
	local p, ia, ib = planar(ponto), planar(a), planar(b)
	local ab = ib - ia
	local comprimento2 = ab:Dot(ab)
	local t = 0
	if comprimento2 > 0 then
		t = math.clamp((p - ia):Dot(ab) / comprimento2, 0, 1)
	end
	return (ia + ab * t - p).Magnitude, t
end
Projeteis.distanciaAoSegmento = distanciaAoSegmento

--[[ Cada item da lista aceita:
	lado = "jogador" ou "inimigo"   tipo = nome do visual (orbe, flecha, fogo...)
	pos, dir, velocidade, alcance, raio, tamanho
	perfuracao, ricochete           (quantos inimigos atravessa / quica)
	explosao                        (raio da explosão ao terminar, opcional)
	aoAcertar(alvo, pos, projetil)  alvo = inimigo (lado jogador) ou estado do jogador (lado inimigo)
	aoExplodir(pos, alvoPrincipal)
	aoMover(projetil, dt)           (chamado a cada passo, opcional)  ]]
function Projeteis.disparar(run, lista)
	local visuais = {}
	for _, dados in lista do
		local direcao = planar(dados.dir)
		direcao = if direcao.Magnitude > 0.01 then direcao.Unit else Vector3.new(0, 0, -1)
		proximoId += 1
		local projetil = {
			id = proximoId,
			lado = dados.lado,
			pos = dados.pos,
			dir = direcao,
			velocidade = dados.velocidade,
			alcance = dados.alcance,
			percorrido = 0,
			raio = dados.raio or 1,
			perfuracao = dados.perfuracao or 0,
			ricochete = dados.ricochete or 0,
			explosao = dados.explosao,
			aoAcertar = dados.aoAcertar,
			aoExplodir = dados.aoExplodir,
			aoMover = dados.aoMover,
			atingidos = {},
		}
		run.projeteis[projetil] = true
		table.insert(visuais, {
			id = projetil.id,
			tipo = dados.tipo,
			pos = dados.pos,
			dir = direcao,
			vel = dados.velocidade,
			alcance = dados.alcance,
			tamanho = dados.tamanho or 1,
		})
	end
	if #visuais > 0 then
		Vfx.partida(run, "projeteis", { lista = visuais })
	end
end

local function terminar(run, projetil, impacto: boolean, alvoPrincipal)
	run.projeteis[projetil] = nil
	if projetil.explosao and projetil.aoExplodir then
		projetil.aoExplodir(projetil.pos, alvoPrincipal)
	end
	Vfx.partida(run, "projetilFim", { id = projetil.id, pos = projetil.pos, impacto = impacto })
end

local function alvosDoInimigo(run)
	local lista = {}
	local agora = os.clock()
	for _, estado in run.jogadores do
		-- quem está esquivando atravessa os projéteis
		if estado.vivo and not estado.caido and agora >= (estado.invulneravelAte or 0) then
			local personagem = estado.player.Character
			local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
			if raiz then
				table.insert(lista, { alvo = estado, pos = raiz.Position, raio = 1.6 })
			end
		end
	end
	return lista
end

local function alvosDoJogador(run)
	local lista = {}
	for inimigo in run.inimigos do
		if inimigo.vivo then
			table.insert(lista, { alvo = inimigo, pos = inimigo.raiz.Position, raio = inimigo.raio })
		end
	end
	return lista
end

local function procurarRicochete(run, projetil)
	local melhor, melhorDistancia = nil, 24
	for inimigo in run.inimigos do
		if inimigo.vivo and not projetil.atingidos[inimigo] then
			local distancia = planar(inimigo.raiz.Position - projetil.pos).Magnitude
			if distancia < melhorDistancia then
				melhor, melhorDistancia = inimigo, distancia
			end
		end
	end
	return melhor
end

local function bateuNaSala(run, pos: Vector3): boolean
	local sala = run.sala
	if not sala then
		return false
	end
	local local_ = pos - sala.origem
	if math.abs(local_.X) > sala.largura / 2 or math.abs(local_.Z) > sala.comprimento / 2 then
		return true
	end
	for _, pilar in sala.pilares do
		if planar(pos - pilar.pos).Magnitude < pilar.raio then
			return true
		end
	end
	return false
end

function Projeteis.atualizar(run, dt: number)
	local lista = {}
	for projetil in run.projeteis do
		table.insert(lista, projetil)
	end

	for _, projetil in lista do
		local passo = projetil.velocidade * dt
		local inicio = projetil.pos
		local fim = inicio + projetil.dir * passo
		projetil.pos = fim
		projetil.percorrido += passo
		if projetil.aoMover then
			projetil.aoMover(projetil, dt)
		end

		-- Quem está no caminho deste passo, em ordem
		local candidatos = {}
		local alvos = if projetil.lado == "jogador" then alvosDoJogador(run) else alvosDoInimigo(run)
		for _, info in alvos do
			if not projetil.atingidos[info.alvo] then
				local distancia, t = distanciaAoSegmento(info.pos, inicio, fim)
				if distancia <= projetil.raio + info.raio then
					table.insert(candidatos, { info = info, t = t })
				end
			end
		end
		table.sort(candidatos, function(a, b)
			return a.t < b.t
		end)

		local acabou = false
		for _, candidato in candidatos do
			local alvo = candidato.info.alvo
			projetil.atingidos[alvo] = true
			projetil.pos = inicio:Lerp(fim, candidato.t)
			if projetil.aoAcertar then
				projetil.aoAcertar(alvo, projetil.pos, projetil)
			end
			if projetil.perfuracao > 0 then
				projetil.perfuracao -= 1
			elseif projetil.ricochete > 0 and projetil.lado == "jogador" then
				projetil.ricochete -= 1
				local proximo = procurarRicochete(run, projetil)
				if proximo then
					projetil.dir = planar(proximo.raiz.Position - projetil.pos).Unit
					projetil.percorrido = math.max(0, projetil.alcance - 30)
					Vfx.partida(run, "projetilDir", { id = projetil.id, pos = projetil.pos, dir = projetil.dir })
				else
					terminar(run, projetil, true, alvo)
					acabou = true
				end
				break
			else
				terminar(run, projetil, true, alvo)
				acabou = true
				break
			end
		end

		if not acabou then
			if bateuNaSala(run, projetil.pos) then
				terminar(run, projetil, true, nil)
			elseif projetil.percorrido >= projetil.alcance then
				terminar(run, projetil, false, nil)
			end
		end
	end
end

function Projeteis.limpar(run)
	table.clear(run.projeteis)
end

return Projeteis
