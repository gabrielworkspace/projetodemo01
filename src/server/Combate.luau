-- Combate: atributos, combos, habilidades, supremos, esquiva, dano e jogador caído.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Classes = require(Shared:WaitForChild("Classes"))
local Cartas = require(Shared:WaitForChild("Cartas"))

local servidor = script.Parent
local Remotos = require(servidor.Remotos)
local Vfx = require(servidor.Vfx)
local Projeteis = require(servidor.Projeteis)
local Masmorra = require(servidor.Masmorra)
local Armas = require(servidor.Armas)

local Combate = {}

local COR_FOGO = Color3.fromRGB(255, 130, 40)
local COR_RAIO = Color3.fromRGB(255, 236, 110)
local COR_OURO = Color3.fromRGB(255, 205, 90)

local function planar(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function humanoidDe(estado): Humanoid?
	local personagem = estado.player.Character
	return personagem and personagem:FindFirstChildOfClass("Humanoid")
end
Combate.humanoidDe = humanoidDe

local function raizDe(estado): BasePart?
	local personagem = estado.player.Character
	return personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
end
Combate.raizDe = raizDe

local function noChao(run, pos: Vector3): Vector3
	local y = if run.sala then run.sala.origem.Y else pos.Y
	return Vector3.new(pos.X, y, pos.Z)
end

local function inimigosVivos(run)
	local lista = {}
	for inimigo in run.inimigos do
		if inimigo.vivo then
			table.insert(lista, inimigo)
		end
	end
	return lista
end
Combate.inimigosVivos = inimigosVivos

------------------------------------------------------------------------
-- Atributos
------------------------------------------------------------------------

local function somarEfeitos(cartas)
	local soma = {}
	for id, quantidade in cartas do
		local carta = Cartas.porId[id]
		if carta and quantidade > 0 then
			for efeito, valor in carta.efeitos do
				soma[efeito] = (soma[efeito] or 0) + valor * quantidade
			end
		end
	end
	return soma
end

function Combate.calcularStats(estado)
	local classe = Classes.obter(estado.classe)
	local soma = somarEfeitos(estado.cartas)
	local function e(nome: string): number
		return soma[nome] or 0
	end
	local melhorias = estado.perfil.Melhorias

	estado.stats = {
		vidaMax = math.max(25, classe.vida + (melhorias.Vida or 0) * 15 + e("vidaPlana") + e("gigante") * 50),
		dano = classe.dano * (1 + (melhorias.Forca or 0) * 0.08) * (1 + e("danoPct")),
		velocidade = classe.velocidade * (1 + e("velocidadePct")) * (0.92 ^ e("gigante")),
		intervalo = classe.intervalo / (1 + e("ataqueVelPct")),
		alcance = classe.alcance * (1 + e("alcancePct")) * (1 + 0.2 * e("gigante")),
		critico = math.min(e("critico"), 0.75),
		multCritico = 3 + e("multCritico"),
		rouboVida = e("rouboVida"),
		regen = e("regen"),
		multOuro = (1 + e("ouroPct")) * (if e("ouroMult") > 0 then 2 else 1),
		armadura = math.min(classe.armadura + e("armadura"), 0.6),
		espinhos = e("espinhos"),
		escudo = e("escudo") > 0,
		investida = e("investida"),
		ondaCorte = e("ondaCorte"),
		redemoinhoFogo = e("redemoinhoFogo") > 0,
		escala = 1 + 0.3 * e("gigante"),
		dragao = e("dragao"),
		protetor = e("protetor") > 0,
		tamanho = 1 + e("tamanhoPct"),
		explosao = (classe.ataque.explosao or 0) * (1 + e("explosaoPct")),
		projeteis = 1 + e("projeteisExtra"),
		lentidao = if e("lentidao") > 0 then math.min(0.35 + 0.1 * (e("lentidao") - 1), 0.6) else 0,
		raios = e("raios"),
		meteoros = 1 + e("meteoros"),
		perfuracao = e("perfuracao"),
		explosaoMorte = e("explosaoMorte"),
		arquimago = e("arquimago") > 0,
		queimadura = e("queimadura"),
		velProjetil = (classe.ataque.velocidade or 0) * (1 + e("velProjPct")),
		ricochete = e("ricochete"),
		chuva = 1 + e("chuvaPct"),
		fantasma = e("fantasma") > 0,
		recarga = classe.habilidade.recarga * (1 - math.min(e("recargaPct"), 0.6)),
		recargaEsquiva = Config.ESQUIVA_RECARGA * (1 - math.min(e("esquivaPct"), 0.6)),
		multCarga = 1 + e("cargaPct"),
	}
	return estado.stats
end

-- O jogador precisa destes números para mostrar recargas e prever o próprio ataque
function Combate.enviarStats(estado)
	local stats = estado.stats
	local classe = Classes.obter(estado.classe)
	Remotos.enviar(estado.player, "stats", {
		classe = classe.id,
		intervalo = stats.intervalo,
		recarga = stats.recarga,
		recargaEsquiva = stats.recargaEsquiva,
		alcance = stats.alcance,
		arco = classe.ataque.arco,
		carga = estado.carga,
		cargaMax = Config.CARGA_MAXIMA,
	})
end

function Combate.aplicarVelocidade(estado)
	local humanoid = humanoidDe(estado)
	if not humanoid then
		return
	end
	if estado.caido then
		humanoid.WalkSpeed = 0
		return
	end
	local fator = if os.clock() < (estado.lentoAte or 0) then estado.lentoFator or 1 else 1
	if estado.carregandoDesde then
		fator *= Config.VELOCIDADE_CARREGANDO
	end
	humanoid.WalkSpeed = estado.stats.velocidade * fator
end

function Combate.aplicarStats(estado, curarTudo: boolean?)
	local personagem = estado.player.Character
	local humanoid = humanoidDe(estado)
	if not personagem or not humanoid or humanoid.Health <= 0 then
		return
	end
	local stats = estado.stats
	local maximoAntigo = humanoid.MaxHealth
	humanoid.MaxHealth = stats.vidaMax
	if curarTudo then
		humanoid.Health = stats.vidaMax
	elseif stats.vidaMax > maximoAntigo then
		humanoid.Health = math.min(humanoid.Health + (stats.vidaMax - maximoAntigo), stats.vidaMax)
	end
	Combate.aplicarVelocidade(estado)
	if math.abs(personagem:GetScale() - stats.escala) > 0.01 then
		pcall(function()
			personagem:ScaleTo(stats.escala)
		end)
	end
end

function Combate.equipar(estado)
	local personagem = estado.player.Character
	if personagem then
		Armas.vestir(personagem, estado.classe)
	end
end

-- Avisa os jogadores para tocarem uma animação no personagem (feita em Client/Animacoes).
-- "exceto" é quem já tocou a animação no próprio computador, na hora do clique.
local function animar(run, estado, acao: string, dados, exceto: Player?)
	dados = dados or {}
	dados.jogador = estado.player
	dados.acao = acao
	dados.classe = estado.classe
	Vfx.partida(run, "anim", dados, exceto)
end

local function podeAgir(run, estado): boolean
	return run.ativa and estado.vivo and not estado.caido and raizDe(estado) ~= nil
end

local function direcaoValida(direcao: any, raiz: BasePart): Vector3
	if typeof(direcao) == "Vector3" then
		local plano = planar(direcao)
		local tamanho = plano.Magnitude
		if tamanho > 0.01 and tamanho < 1e6 then
			return plano / tamanho
		end
	end
	return planar(raiz.CFrame.LookVector).Unit
end

------------------------------------------------------------------------
-- Supremo (barra de carga)
------------------------------------------------------------------------

function Combate.adicionarCarga(estado, valor: number)
	if estado.carga >= Config.CARGA_MAXIMA then
		return
	end
	estado.carga = math.min(Config.CARGA_MAXIMA, estado.carga + valor * estado.stats.multCarga)
	if estado.carga >= Config.CARGA_MAXIMA or estado.carga - (estado.cargaEnviada or 0) >= 3 then
		estado.cargaEnviada = estado.carga
		Remotos.enviar(estado.player, "carga", { valor = estado.carga, max = Config.CARGA_MAXIMA })
	end
end

------------------------------------------------------------------------
-- Dano em inimigos
------------------------------------------------------------------------

local function queimar(inimigo, danoPorSegundo: number, estado)
	inimigo.queimaAte = os.clock() + 3
	inimigo.queimaDps = math.max(inimigo.queimaDps or 0, danoPorSegundo)
	inimigo.queimaFonte = estado
	inimigo.modelo:SetAttribute("Queimando", true)
end

local function desacelerar(inimigo, fator: number, duracao: number)
	inimigo.lentoAte = os.clock() + duracao
	inimigo.lentoFator = math.min(inimigo.lentoFator or 1, fator)
	inimigo.modelo:SetAttribute("Lento", true)
end

function Combate.atordoar(inimigo, duracao: number)
	if inimigo.chefe then
		duracao *= 0.35
	end
	inimigo.atordoadoAte = math.max(inimigo.atordoadoAte or 0, os.clock() + duracao)
	inimigo.modelo:SetAttribute("Atordoado", true)
end

local function correnteEletrica(run, origem, estado, quantidade: number, dano: number)
	local candidatos = {}
	for _, outro in inimigosVivos(run) do
		if outro ~= origem then
			local distancia = (outro.raiz.Position - origem.raiz.Position).Magnitude
			if distancia <= 18 then
				table.insert(candidatos, { inimigo = outro, distancia = distancia })
			end
		end
	end
	table.sort(candidatos, function(a, b)
		return a.distancia < b.distancia
	end)
	for i = 1, math.min(quantidade, #candidatos) do
		local alvo = candidatos[i].inimigo
		Vfx.partida(run, "raio", { de = origem.raiz.Position, ate = alvo.raiz.Position })
		Combate.danoAoInimigo(run, alvo, dano, estado, { semEfeitos = true, cor = COR_RAIO })
	end
end

--[[ opcoes: critico, principal (ataque básico), empurrar (Vector3), semEfeitos,
	queimar, lento (fator), cor, exceto ]]
function Combate.danoAoInimigo(run, inimigo, dano: number, estado, opcoes)
	if not inimigo.vivo then
		return
	end
	opcoes = opcoes or {}
	dano = math.max(1, math.floor(dano * (1 - (inimigo.armadura or 0)) + 0.5))
	inimigo.vida -= dano
	inimigo.modelo:SetAttribute("Vida", math.max(0, inimigo.vida))

	if estado then
		-- Ameaça: os inimigos preferem atacar quem causa mais dano (o Cavaleiro chama o dobro de atenção)
		inimigo.ameaca[estado] = (inimigo.ameaca[estado] or 0) + dano * (if estado.classe == "cavaleiro" then 2 else 1)
		estado.danoCausado += dano
	end

	Vfx.partida(run, "dano", {
		pos = inimigo.raiz.Position + Vector3.new(0, inimigo.alturaBarra, 0),
		impacto = inimigo.raiz.Position,
		valor = dano,
		critico = opcoes.critico == true,
		cor = opcoes.cor,
		autor = estado and estado.player,
	})

	if opcoes.empurrar and not inimigo.pesado and inimigo.vida > 0 then
		inimigo.raiz.AssemblyLinearVelocity = opcoes.empurrar + Vector3.new(0, 10, 0)
	end

	if estado and not opcoes.semEfeitos then
		local stats = estado.stats
		if stats.rouboVida > 0 then
			Combate.curar(run, estado, stats.rouboVida, true)
		end
		if stats.lentidao > 0 then
			desacelerar(inimigo, 1 - stats.lentidao, 2)
		end
		if stats.queimadura > 0 then
			queimar(inimigo, stats.dano * stats.queimadura, estado)
		end
		if stats.raios > 0 and opcoes.principal then
			correnteEletrica(run, inimigo, estado, stats.raios, stats.dano * 0.5)
		end
		Combate.adicionarCarga(estado, Config.CARGA_POR_ACERTO)
	end
	if opcoes.queimar and estado then
		queimar(inimigo, estado.stats.dano * 0.3, estado)
	end
	if opcoes.lento then
		desacelerar(inimigo, opcoes.lento, 2)
	end

	if inimigo.vida <= 0 then
		run:aoMorrerInimigo(inimigo, estado)
	end
end

function Combate.danoEmArea(run, centro: Vector3, raio: number, dano: number, estado, opcoes)
	opcoes = opcoes or {}
	for _, inimigo in inimigosVivos(run) do
		if inimigo ~= opcoes.exceto and planar(inimigo.raiz.Position - centro).Magnitude <= raio + inimigo.raio then
			local opcoesDeste = table.clone(opcoes)
			if opcoes.empurrarForca then
				local fora = planar(inimigo.raiz.Position - centro)
				if fora.Magnitude > 0.1 then
					opcoesDeste.empurrar = fora.Unit * opcoes.empurrarForca
				end
			end
			Combate.danoAoInimigo(run, inimigo, dano, estado, opcoesDeste)
		end
	end
end

------------------------------------------------------------------------
-- Cura, dano em jogadores, caído e reviver
------------------------------------------------------------------------

function Combate.curar(run, estado, quantidade: number, silencioso: boolean?)
	local humanoid = humanoidDe(estado)
	if not humanoid or humanoid.Health <= 0 or estado.caido then
		return
	end
	local antes = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + quantidade)
	local curado = humanoid.Health - antes
	if not silencioso and curado >= 1 then
		Vfx.partida(run, "cura", { jogador = estado.player, valor = math.floor(curado + 0.5) })
	end
end

local function definirCaidoNoPersonagem(estado, caido: boolean)
	local personagem = estado.player.Character
	if personagem then
		personagem:SetAttribute("Caido", caido)
		personagem:SetAttribute("Reviver", 0)
		personagem:SetAttribute("CaidoRestante", if caido then Config.TEMPO_CAIDO else 0)
	end
end

-- Termina de morrer (o tempo de caído acabou ou não há ninguém para reviver)
function Combate.morrerDeVez(run, estado)
	estado.caido = false
	definirCaidoNoPersonagem(estado, false)
	local humanoid = humanoidDe(estado)
	if humanoid then
		humanoid.Sit = false
		humanoid.Health = 0
	end
end

local function contarAtivos(run, exceto)
	local total = 0
	for _, outro in run.jogadores do
		if outro ~= exceto and outro.vivo and not outro.caido then
			total += 1
		end
	end
	return total
end

function Combate.derrubar(run, estado)
	local humanoid = humanoidDe(estado)
	if not humanoid then
		return
	end
	-- Sozinho (ou sem ninguém de pé) não há quem reviva: cai de vez
	if contarAtivos(run, estado) == 0 then
		Combate.morrerDeVez(run, estado)
		return
	end
	estado.caido = true
	estado.caidoAte = os.clock() + Config.TEMPO_CAIDO
	estado.progressoReviver = 0
	humanoid.Health = 1
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	estado.carregandoDesde = nil
	humanoid.Sit = true
	Combate.aplicarVelocidade(estado)
	definirCaidoNoPersonagem(estado, true)
	Vfx.partida(run, "caiu", { jogador = estado.player })
	Remotos.enviar(estado.player, "caiu", { tempo = Config.TEMPO_CAIDO })
	run:anunciar("💀 " .. estado.player.DisplayName .. " caiu! Fique perto para reviver.", Color3.fromRGB(255, 110, 110))
end

function Combate.levantar(run, estado, fracaoVida: number)
	local humanoid = humanoidDe(estado)
	estado.caido = false
	definirCaidoNoPersonagem(estado, false)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid.Sit = false
	humanoid.JumpPower = 50
	humanoid.Health = math.max(1, humanoid.MaxHealth * fracaoVida)
	estado.invulneravelAte = os.clock() + 1.5
	Combate.aplicarVelocidade(estado)
	Vfx.partida(run, "reviver", { jogador = estado.player })
	Remotos.enviar(estado.player, "levantou", {})
end

--[[ opcoes: ambiente (lava: ignora escudo e espinhos), lento = {fator, duracao}, queimar (dano/s) ]]
function Combate.danoAoJogador(run, estado, dano: number, fonte, opcoes)
	if not estado.vivo or estado.caido then
		return
	end
	local humanoid = humanoidDe(estado)
	local raiz = raizDe(estado)
	if not humanoid or not raiz or humanoid.Health <= 0 then
		return
	end
	opcoes = opcoes or {}
	local agora = os.clock()
	if agora < (estado.invulneravelAte or 0) then
		return
	end

	-- Aura do Protetor de um aliado próximo
	for _, outro in run.jogadores do
		if outro ~= estado and outro.vivo and not outro.caido and outro.stats.protetor then
			local raizOutro = raizDe(outro)
			if raizOutro and planar(raizOutro.Position - raiz.Position).Magnitude <= 18 then
				dano *= 0.7
				break
			end
		end
	end
	dano = math.max(1, math.floor(dano * (1 - estado.stats.armadura) + 0.5))

	if estado.escudoAtivo and not opcoes.ambiente then
		estado.escudoAtivo = false
		Vfx.partida(run, "bloqueio", { jogador = estado.player })
		return
	end

	if fonte and fonte.vivo and estado.stats.espinhos > 0 and not opcoes.ambiente then
		Combate.danoAoInimigo(run, fonte, dano * estado.stats.espinhos, estado, { semEfeitos = true, cor = Color3.fromRGB(140, 255, 120) })
	end

	if dano >= humanoid.Health then
		if (estado.cartas.segunda or 0) > 0 then
			estado.cartas.segunda -= 1
			humanoid.Health = humanoid.MaxHealth * 0.5
			estado.invulneravelAte = agora + 2
			Vfx.partida(run, "segundaChance", { jogador = estado.player })
			run:anunciar("👼 " .. estado.player.DisplayName .. " usou a Segunda Chance!", COR_OURO)
			Remotos.enviar(estado.player, "minhasCartas", { cartas = estado.cartas })
			return
		end
		Combate.derrubar(run, estado)
		return
	end

	humanoid:TakeDamage(dano)
	Vfx.partida(run, "danoJogador", { jogador = estado.player, valor = dano })

	if opcoes.lento then
		estado.lentoAte = agora + (opcoes.lento.duracao or 2)
		estado.lentoFator = opcoes.lento.fator or 0.6
		Combate.aplicarVelocidade(estado)
	end
	if opcoes.queimar then
		estado.queimaAte = agora + 3
		estado.queimaDps = opcoes.queimar
	end
end

------------------------------------------------------------------------
-- Ataque básico (combo de 3)
------------------------------------------------------------------------

local function golpeDeEspada(run, estado, classe, raiz: BasePart, direcao: Vector3, mult: number, final: boolean)
	local stats = estado.stats
	local arco = classe.ataque.arco * (if final then 1.25 else 1)
	local alcance = stats.alcance * (if final then 1.15 else 1)
	-- quem atacou já desenhou o próprio corte; os outros recebem aqui
	Vfx.partida(run, "corte", {
		jogador = estado.player,
		pos = raiz.Position,
		dir = direcao,
		alcance = alcance,
		arco = arco,
		cor = classe.cor,
		combo = estado.combo,
	}, estado.player)

	local limite = math.cos(math.rad(arco / 2))
	local alvos = {}
	for _, inimigo in inimigosVivos(run) do
		local delta = planar(inimigo.raiz.Position - raiz.Position)
		local distancia = delta.Magnitude
		if distancia <= alcance + inimigo.raio then
			if distancia < inimigo.raio + 1.5 or delta.Unit:Dot(direcao) >= limite then
				table.insert(alvos, inimigo)
			end
		end
	end
	for _, inimigo in alvos do
		local critico = math.random() < stats.critico
		local dano = stats.dano * mult * (if critico then stats.multCritico else 1)
		Combate.danoAoInimigo(run, inimigo, dano, estado, {
			critico = critico,
			principal = true,
			empurrar = direcao * (if final then 50 else 25),
		})
	end

	if final and stats.ondaCorte > 0 then
		Projeteis.disparar(run, {
			{
				lado = "jogador",
				tipo = "onda",
				pos = raiz.Position + direcao * 2,
				dir = direcao,
				velocidade = 55,
				alcance = 32,
				raio = 3.2,
				perfuracao = 99,
				aoAcertar = function(inimigo)
					Combate.danoAoInimigo(run, inimigo, stats.dano * 0.8 * stats.ondaCorte, estado, { semEfeitos = true, cor = classe.cor })
				end,
			},
		})
	end
end

local function disparoDeClasse(run, estado, classe, raiz: BasePart, direcao: Vector3, mult: number, final: boolean)
	local stats = estado.stats
	local tipo = classe.ataque.projetil
	local tamanho = stats.tamanho
	local perfuracao = stats.perfuracao
	local explosao = stats.explosao
	local dano = stats.dano * mult

	if final then
		if classe.id == "mago" then
			tipo = "orbeGrande"
			tamanho *= 1.7
			explosao = math.max(explosao, 4) * 1.8
		elseif stats.fantasma then
			tipo = "fantasma"
			perfuracao = 999
			tamanho *= 2.4
			dano *= 1.6
		else
			tipo = "flechaGrande"
			perfuracao += 2
			tamanho *= 1.4
		end
	end

	local quantidade = stats.projeteis
	local abertura = if classe.id == "arqueiro" then 9 else 13
	local origem = raiz.Position + direcao * 1.5 + Vector3.new(0, 0.6, 0)
	local lista = {}
	for i = 1, quantidade do
		local angulo = math.rad((i - (quantidade + 1) / 2) * abertura)
		local critico = math.random() < stats.critico
		local danoFinal = dano * (if critico then stats.multCritico else 1)
		table.insert(lista, {
			lado = "jogador",
			tipo = tipo,
			pos = origem,
			dir = CFrame.Angles(0, angulo, 0):VectorToWorldSpace(direcao),
			velocidade = stats.velProjetil,
			alcance = stats.alcance,
			raio = classe.ataque.raio * tamanho,
			tamanho = tamanho,
			perfuracao = perfuracao,
			ricochete = stats.ricochete,
			explosao = if explosao > 0 then explosao else nil,
			aoAcertar = function(inimigo, _, projetil)
				Combate.danoAoInimigo(run, inimigo, danoFinal, estado, {
					critico = critico,
					principal = true,
					empurrar = projetil.dir * 18,
				})
			end,
			aoExplodir = function(pos: Vector3, principal)
				Vfx.partida(run, "explosao", { pos = pos, raio = explosao, cor = classe.cor, leve = true })
				Combate.danoEmArea(run, pos, explosao, dano * 0.6, estado, { semEfeitos = true, exceto = principal, cor = classe.cor })
			end,
		})
	end
	Projeteis.disparar(run, lista)
end

local function rajadaDoDragao(run, estado, raiz: BasePart, direcao: Vector3)
	local stats = estado.stats
	local alcance = stats.alcance * 2.2
	Vfx.partida(run, "rajada", { pos = raiz.Position, dir = direcao, alcance = alcance })
	local atingidos = {}
	for _, inimigo in inimigosVivos(run) do
		local delta = planar(inimigo.raiz.Position - raiz.Position)
		if delta.Magnitude > 0.1 and delta.Magnitude <= alcance + inimigo.raio and delta.Unit:Dot(direcao) >= 0.5 then
			table.insert(atingidos, inimigo)
		end
	end
	for _, inimigo in atingidos do
		Combate.danoAoInimigo(run, inimigo, stats.dano * 0.6 * stats.dragao, estado, { semEfeitos = true, queimar = true, cor = COR_FOGO })
	end
end

function Combate.atacar(run, estado, direcao: any)
	if not podeAgir(run, estado) or estado.carregandoDesde then
		return
	end
	local stats = estado.stats
	local classe = Classes.obter(estado.classe)
	local agora = os.clock()
	local espera = stats.intervalo * (if estado.ultimoFoiFinal then 1.35 else 1)
	if agora - estado.ultimoAtaque < espera * 0.8 then
		return
	end
	if agora - estado.ultimoAtaque > stats.intervalo * 2.6 + 0.3 then
		estado.combo = 0
	end
	estado.combo = estado.combo % 3 + 1
	local final = estado.combo == 3
	estado.ultimoFoiFinal = final
	estado.ultimoAtaque = agora

	local raiz = raizDe(estado) :: BasePart
	local dir = direcaoValida(direcao, raiz)
	local mult = classe.ataque.combo[estado.combo] or 1
	animar(run, estado, "ataque", { combo = estado.combo }, estado.player)

	if classe.ataque.tipo == "corte" then
		golpeDeEspada(run, estado, classe, raiz, dir, mult, final)
	else
		disparoDeClasse(run, estado, classe, raiz, dir, mult, final)
	end
	if stats.dragao > 0 then
		rajadaDoDragao(run, estado, raiz, dir)
	end
end

------------------------------------------------------------------------
-- Ataque carregado: segurar o ataque carrega; soltar dispara um golpe mais forte
------------------------------------------------------------------------

function Combate.carregar(run, estado)
	if not podeAgir(run, estado) or estado.carregandoDesde then
		return
	end
	estado.carregandoDesde = os.clock()
	Combate.aplicarVelocidade(estado)
	animar(run, estado, "carregar", nil, estado.player)
end

function Combate.cancelarCarga(run, estado)
	if not estado.carregandoDesde then
		return
	end
	estado.carregandoDesde = nil
	Combate.aplicarVelocidade(estado)
	animar(run, estado, "cancelar", nil, estado.player)
end

local function golpeCarregado(run, estado, classe, raiz: BasePart, direcao: Vector3, fracao: number)
	local stats = estado.stats
	local mult = Config.DANO_CARGA_MIN + (Config.DANO_CARGA_MAX - Config.DANO_CARGA_MIN) * fracao
	local perfeito = fracao >= 0.99

	if classe.id == "cavaleiro" then
		-- Giro completo com a espada, empurrando todos para longe
		local raio = stats.alcance * (1.25 + 0.3 * fracao)
		Vfx.partida(run, "giroCarregado", { jogador = estado.player, raio = raio, cor = classe.cor, perfeito = perfeito }, estado.player)
		local alvos = {}
		for _, inimigo in inimigosVivos(run) do
			if planar(inimigo.raiz.Position - raiz.Position).Magnitude <= raio + inimigo.raio then
				table.insert(alvos, inimigo)
			end
		end
		for _, inimigo in alvos do
			local critico = math.random() < stats.critico
			local fora = planar(inimigo.raiz.Position - raiz.Position)
			fora = if fora.Magnitude > 0.1 then fora.Unit else direcao
			Combate.danoAoInimigo(run, inimigo, stats.dano * mult * (if critico then stats.multCritico else 1), estado, {
				critico = critico,
				principal = true,
				empurrar = fora * (40 + 40 * fracao),
			})
			if perfeito and inimigo.vivo then
				Combate.atordoar(inimigo, 1.2)
			end
		end
		if perfeito then
			local centro = raiz.Position
			task.delay(0.15, function()
				if not run.ativa then
					return
				end
				Vfx.partida(run, "explosao", { pos = centro, raio = raio * 1.8, cor = classe.cor, forte = true })
				Combate.danoEmArea(run, centro, raio * 1.8, stats.dano * 1.2, estado, { semEfeitos = true, cor = classe.cor, empurrarForca = 50 })
			end)
		end
		if stats.dragao > 0 then
			rajadaDoDragao(run, estado, raiz, direcao)
		end
	elseif classe.id == "mago" then
		-- Orbe enorme e lento que explode forte (atravessa tudo com a carga cheia)
		local tamanho = (1.8 + 1.4 * fracao) * stats.tamanho
		local explosao = math.max(stats.explosao, 4) * (1.6 + 1.4 * fracao)
		local dano = stats.dano * mult
		Projeteis.disparar(run, {
			{
				lado = "jogador",
				tipo = "orbeCarregado",
				pos = raiz.Position + direcao * 2 + Vector3.new(0, 1, 0),
				dir = direcao,
				velocidade = 42,
				alcance = stats.alcance * 1.1,
				raio = 1.2 * tamanho,
				tamanho = tamanho,
				perfuracao = if perfeito then 999 else 2,
				explosao = explosao,
				aoAcertar = function(inimigo, _, projetil)
					Combate.danoAoInimigo(run, inimigo, dano, estado, { principal = true, empurrar = projetil.dir * 30 })
				end,
				aoExplodir = function(pos: Vector3, principal)
					Vfx.partida(run, "explosao", { pos = pos, raio = explosao, cor = classe.cor, forte = true })
					Combate.danoEmArea(run, pos, explosao, dano * 0.7, estado, { semEfeitos = true, exceto = principal, cor = classe.cor, empurrarForca = 35 })
				end,
			},
		})
	else
		-- Flecha perfurante e veloz (crítico garantido com a carga cheia)
		local critico = perfeito or math.random() < stats.critico
		local dano = stats.dano * mult * (if critico then stats.multCritico else 1)
		Projeteis.disparar(run, {
			{
				lado = "jogador",
				tipo = "flechaCarregada",
				pos = raiz.Position + direcao * 1.5 + Vector3.new(0, 0.6, 0),
				dir = direcao,
				velocidade = stats.velProjetil * 1.5,
				alcance = stats.alcance * 1.4,
				raio = 1.5,
				tamanho = 1.5 + 0.8 * fracao,
				perfuracao = 999,
				aoAcertar = function(inimigo, _, projetil)
					Combate.danoAoInimigo(run, inimigo, dano, estado, { critico = critico, principal = true, empurrar = projetil.dir * 35 })
				end,
			},
		})
	end
end

function Combate.soltar(run, estado, direcao: any)
	local inicio = estado.carregandoDesde
	if not inicio then
		return
	end
	estado.carregandoDesde = nil
	Combate.aplicarVelocidade(estado)
	if not podeAgir(run, estado) then
		return
	end
	local duracao = os.clock() - inicio
	if duracao < Config.CARGA_ATAQUE_MIN * 0.75 then
		animar(run, estado, "cancelar", nil, estado.player)
		return
	end
	local fracao = math.clamp((duracao - Config.CARGA_ATAQUE_MIN) / (Config.CARGA_ATAQUE_MAX - Config.CARGA_ATAQUE_MIN), 0, 1)
	estado.combo = 0
	estado.ultimoAtaque = os.clock()
	estado.ultimoFoiFinal = true
	local raiz = raizDe(estado) :: BasePart
	local dir = direcaoValida(direcao, raiz)
	local classe = Classes.obter(estado.classe)
	animar(run, estado, "soltar", { fracao = fracao }, estado.player)
	golpeCarregado(run, estado, classe, raiz, dir, fracao)
end

------------------------------------------------------------------------
-- Habilidades (tecla E)
------------------------------------------------------------------------

-- Inimigo mais perto da linha de mira
local function alvoNaMira(origem: Vector3, direcao: Vector3, run, alcanceMax: number)
	local melhor, melhorNota = nil, math.huge
	for _, inimigo in inimigosVivos(run) do
		local delta = planar(inimigo.raiz.Position - origem)
		local distancia = delta.Magnitude
		if distancia > 0.1 and distancia <= alcanceMax then
			local alinhamento = delta.Unit:Dot(direcao)
			if alinhamento > 0.4 then
				local nota = distancia * (2 - alinhamento)
				if nota < melhorNota then
					melhor, melhorNota = inimigo, nota
				end
			end
		end
	end
	return melhor
end

local function redemoinho(run, estado, classe)
	local stats = estado.stats
	local duracao = 2 * (if stats.redemoinhoFogo then 1.5 else 1)
	local raio = stats.alcance * 1.1
	Vfx.partida(run, "redemoinho", { jogador = estado.player, duracao = duracao, raio = raio, cor = classe.cor, fogo = stats.redemoinhoFogo })
	animar(run, estado, "habilidade", { duracao = duracao })
	task.spawn(function()
		local fim = os.clock() + duracao
		while os.clock() < fim and run.ativa and estado.vivo and not estado.caido do
			local raiz = raizDe(estado)
			if not raiz then
				break
			end
			Combate.danoEmArea(run, raiz.Position, raio, stats.dano * 0.55, estado, { queimar = stats.redemoinhoFogo })
			task.wait(0.22)
		end
	end)
end

local function meteoro(run, estado, raiz: BasePart, direcao: Vector3)
	local stats = estado.stats
	local primeiro = alvoNaMira(raiz.Position, direcao, run, 60)
	local base = noChao(run, if primeiro then primeiro.raiz.Position else raiz.Position + direcao * 18)

	-- Meteoros extras caem nos inimigos mais próximos do primeiro ponto
	local vizinhos = {}
	for _, inimigo in inimigosVivos(run) do
		if inimigo ~= primeiro then
			table.insert(vizinhos, inimigo)
		end
	end
	table.sort(vizinhos, function(a, b)
		return (a.raiz.Position - base).Magnitude < (b.raiz.Position - base).Magnitude
	end)

	for i = 1, stats.meteoros do
		local ponto = base
		if i > 1 then
			local vizinho = vizinhos[i - 1]
			ponto = if vizinho
				then noChao(run, vizinho.raiz.Position)
				else base + Vector3.new(math.random(-9, 9), 0, math.random(-9, 9))
		end
		task.delay((i - 1) * 0.35, function()
			if not run.ativa then
				return
			end
			Vfx.partida(run, "meteoro", { pos = ponto, duracao = 0.75, raio = 11, amigo = true })
			task.delay(0.75, function()
				if not run.ativa then
					return
				end
				Vfx.partida(run, "explosao", { pos = ponto, raio = 11, cor = COR_FOGO, forte = true })
				Combate.danoEmArea(run, ponto, 11, stats.dano * 4, estado, { semEfeitos = true, queimar = true, cor = COR_FOGO, empurrarForca = 40 })
			end)
		end)
	end
end

local function chuvaDeFlechas(run, estado, classe, raiz: BasePart, direcao: Vector3)
	local stats = estado.stats
	local raio = 10 * math.sqrt(stats.chuva)
	local duracao = 3 * stats.chuva
	local alvo = alvoNaMira(raiz.Position, direcao, run, 60)
	local centro = noChao(run, if alvo then alvo.raiz.Position else raiz.Position + direcao * 20)
	Vfx.partida(run, "chuvaFlechas", { pos = centro, raio = raio, duracao = duracao, cor = classe.cor })
	task.spawn(function()
		local fim = os.clock() + duracao
		task.wait(0.35)
		while os.clock() < fim and run.ativa do
			Combate.danoEmArea(run, centro, raio, stats.dano * 0.45, estado, { semEfeitos = true, lento = 0.75 })
			task.wait(0.25)
		end
	end)
end

function Combate.habilidade(run, estado, direcao: any)
	if not podeAgir(run, estado) then
		return
	end
	local agora = os.clock()
	if agora < estado.habilidadeProntaEm - 0.15 then
		return
	end
	local stats = estado.stats
	estado.habilidadeProntaEm = agora + stats.recarga
	Remotos.enviar(estado.player, "recarga", { tipo = "habilidade", restante = stats.recarga, total = stats.recarga })

	local raiz = raizDe(estado) :: BasePart
	local dir = direcaoValida(direcao, raiz)
	local classe = Classes.obter(estado.classe)
	local id = classe.habilidade.id
	if id == "redemoinho" then
		redemoinho(run, estado, classe)
	elseif id == "meteoro" then
		animar(run, estado, "habilidade", { duracao = 0.5 })
		meteoro(run, estado, raiz, dir)
	else
		animar(run, estado, "habilidade", { duracao = 0.45 })
		chuvaDeFlechas(run, estado, classe, raiz, dir)
	end
end

-- Carta Arquimago: abates aceleram a habilidade
function Combate.reduzirRecarga(estado, segundos: number)
	estado.habilidadeProntaEm -= segundos
	local restante = math.max(0, estado.habilidadeProntaEm - os.clock())
	Remotos.enviar(estado.player, "recarga", { tipo = "habilidade", restante = restante, total = estado.stats.recarga })
end

------------------------------------------------------------------------
-- Supremos (tecla R)
------------------------------------------------------------------------

function Combate.supremo(run, estado)
	if not podeAgir(run, estado) or estado.carga < Config.CARGA_MAXIMA then
		return
	end
	estado.carga = 0
	estado.cargaEnviada = 0
	Remotos.enviar(estado.player, "carga", { valor = 0, max = Config.CARGA_MAXIMA })

	local stats = estado.stats
	local classe = Classes.obter(estado.classe)
	local raiz = raizDe(estado) :: BasePart
	Vfx.partida(run, "supremo", { jogador = estado.player, nome = classe.supremo.nome, cor = classe.cor })

	if classe.supremo.id == "julgamento" then
		animar(run, estado, "supremo", { duracao = 0.75 })
		local centro = noChao(run, raiz.Position)
		Vfx.partida(run, "julgamento", { pos = centro, raio = 18, cor = classe.cor })
		task.delay(0.35, function()
			if not run.ativa then
				return
			end
			for _, inimigo in inimigosVivos(run) do
				if planar(inimigo.raiz.Position - centro).Magnitude <= 18 + inimigo.raio then
					Combate.atordoar(inimigo, 2.5)
				end
			end
			Combate.danoEmArea(run, centro, 18, stats.dano * 5, estado, { semEfeitos = true, cor = COR_OURO, empurrarForca = 60 })
		end)
	elseif classe.supremo.id == "tempestade" then
		animar(run, estado, "supremo", { duracao = 5 })
		task.spawn(function()
			local fim = os.clock() + 5
			while os.clock() < fim and run.ativa do
				local vivos = inimigosVivos(run)
				if #vivos > 0 then
					local ponto = noChao(run, vivos[math.random(#vivos)].raiz.Position)
					Vfx.partida(run, "raioCeu", { pos = ponto, cor = classe.cor })
					Combate.danoEmArea(run, ponto, 4.5, stats.dano * 1.6, estado, { semEfeitos = true, cor = COR_RAIO })
				end
				task.wait(0.2)
			end
		end)
	else
		animar(run, estado, "supremo", { duracao = 4 })
		task.spawn(function()
			local fim = os.clock() + 4
			local giro = 0
			while os.clock() < fim and run.ativa and estado.vivo and not estado.caido do
				local raizAtual = raizDe(estado)
				if not raizAtual then
					break
				end
				local lista = {}
				for i = 1, 12 do
					local angulo = giro + i * (math.pi * 2 / 12)
					local dir = Vector3.new(math.sin(angulo), 0, math.cos(angulo))
					table.insert(lista, {
						lado = "jogador",
						tipo = "flecha",
						pos = raizAtual.Position + Vector3.new(0, 0.6, 0) + dir * 1.5,
						dir = dir,
						velocidade = stats.velProjetil,
						alcance = 45,
						raio = 1,
						perfuracao = 1,
						aoAcertar = function(inimigo)
							Combate.danoAoInimigo(run, inimigo, stats.dano * 0.7, estado, { semEfeitos = true })
						end,
					})
				end
				Projeteis.disparar(run, lista)
				giro += 0.13
				task.wait(0.3)
			end
		end)
	end
end

------------------------------------------------------------------------
-- Esquiva (tecla Q). O movimento é feito no computador do jogador; aqui só a invulnerabilidade.
------------------------------------------------------------------------

function Combate.esquiva(run, estado, direcao: any)
	if not podeAgir(run, estado) then
		return
	end
	local agora = os.clock()
	if agora < estado.esquivaProntaEm - 0.25 then
		return
	end
	estado.esquivaProntaEm = agora + estado.stats.recargaEsquiva
	estado.invulneravelAte = math.max(estado.invulneravelAte or 0, agora + Config.ESQUIVA_INVULNERAVEL)
	animar(run, estado, "esquiva", nil, estado.player)

	-- Carta Investida Brutal: atropela quem estiver no caminho
	local stats = estado.stats
	if stats.investida > 0 then
		local raiz = raizDe(estado) :: BasePart
		local inicio = raiz.Position
		task.delay(Config.ESQUIVA_DURACAO + 0.05, function()
			local raizAgora = raizDe(estado)
			if not raizAgora or not run.ativa then
				return
			end
			local fim = raizAgora.Position
			local dir = direcaoValida(fim - inicio, raizAgora)
			for _, inimigo in inimigosVivos(run) do
				local distancia = Projeteis.distanciaAoSegmento(inimigo.raiz.Position, inicio, fim)
				if distancia <= inimigo.raio + 2.5 then
					Combate.danoAoInimigo(run, inimigo, stats.dano * 1.2 * stats.investida, estado, { semEfeitos = true, empurrar = dir * 45 })
				end
			end
		end)
	end
end

------------------------------------------------------------------------
-- Ciclo: queimaduras, regeneração, lava, lentidão e jogadores caídos (a cada 0,25s)
------------------------------------------------------------------------

local function processarCaido(run, estado, dt: number, agora: number)
	if agora >= estado.caidoAte then
		Combate.morrerDeVez(run, estado)
		return
	end
	local raiz = raizDe(estado)
	if not raiz then
		return
	end
	local ajudantes = 0
	for _, outro in run.jogadores do
		if outro ~= estado and outro.vivo and not outro.caido then
			local raizOutro = raizDe(outro)
			if raizOutro and planar(raizOutro.Position - raiz.Position).Magnitude <= Config.RAIO_REVIVER then
				ajudantes += 1
			end
		end
	end
	if ajudantes > 0 then
		estado.progressoReviver += dt * (1 + 0.5 * (ajudantes - 1)) / Config.TEMPO_PARA_REVIVER
	else
		estado.progressoReviver = math.max(0, estado.progressoReviver - dt * 0.25)
	end
	local personagem = estado.player.Character
	if personagem then
		personagem:SetAttribute("Reviver", math.min(1, estado.progressoReviver))
		personagem:SetAttribute("CaidoRestante", math.max(0, estado.caidoAte - agora))
	end
	if estado.progressoReviver >= 1 then
		Combate.levantar(run, estado, Config.VIDA_AO_REVIVER)
		return
	end
	local humanoid = humanoidDe(estado)
	if humanoid and not humanoid.Sit then
		humanoid.Sit = true
	end
end

function Combate.tick(run, dt: number)
	local agora = os.clock()
	for _, inimigo in inimigosVivos(run) do
		if inimigo.queimaAte then
			if agora < inimigo.queimaAte then
				Combate.danoAoInimigo(run, inimigo, inimigo.queimaDps * dt, inimigo.queimaFonte, { semEfeitos = true, cor = COR_FOGO })
			else
				inimigo.queimaAte = nil
				inimigo.queimaDps = 0
				inimigo.modelo:SetAttribute("Queimando", false)
			end
		end
	end

	for _, estado in run.jogadores do
		if estado.vivo then
			if estado.caido then
				processarCaido(run, estado, dt, agora)
			else
				if estado.stats.regen > 0 then
					Combate.curar(run, estado, estado.stats.regen * dt, true)
				end
				local raiz = raizDe(estado)
				if raiz and run.sala and Masmorra.naLava(run.sala, raiz.Position) then
					Combate.danoAoJogador(run, estado, 30 * dt, nil, { ambiente = true })
				end
				if estado.queimaAte then
					if agora < estado.queimaAte then
						Combate.danoAoJogador(run, estado, estado.queimaDps * dt, nil, { ambiente = true })
					else
						estado.queimaAte = nil
					end
				end
				if estado.lentoAte and agora >= estado.lentoAte then
					estado.lentoAte = nil
					Combate.aplicarVelocidade(estado)
				end
			end
		end
	end
end

-- Ao começar cada sala
function Combate.novaSala(estado)
	estado.carregandoDesde = nil
	estado.escudoAtivo = estado.stats.escudo
	estado.invulneravelAte = os.clock() + 1.5
	estado.lentoAte = nil
	estado.queimaAte = nil
end

return Combate
