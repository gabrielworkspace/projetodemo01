-- Combate: atributos, combos, habilidades, supremos, esquiva, dano e jogador caído.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
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
local DURACAO_AURA_SUPREMO = 10 -- segundos do bônus do Julgamento
local DEFESA_SUPREMO = 0.1 -- dano a menos durante o bônus (10%)
local COR_RAIO = Color3.fromRGB(255, 236, 110)
local COR_OURO = Color3.fromRGB(255, 205, 90)

local function planar(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- O jogador tem algum poder de fogo? (Fúria do Dragão ou Redemoinho Flamejante): os golpes e as
-- habilidades do Cavaleiro ficam com efeitos de fogo e queimam
local function temFogo(stats): boolean
	return stats.dragao > 0 or stats.redemoinhoFogo == true or stats.queimadura > 0
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
		-- intervalo entre golpes: o da classe + o tempo a mais de preparação
		intervalo = classe.intervalo / (1 + e("ataqueVelPct")) + Classes.atrasoDoPreparo(classe, 1),
		velAtaque = 1 + e("ataqueVelPct"), -- divide a cadência dos golpes (Classes.cadencia)
		alcance = classe.alcance * (1 + e("alcancePct")) * (1 + 0.2 * e("gigante")),
		critico = math.min((classe.critico or 0) + e("critico"), 0.75),
		multCritico = 3 + e("multCritico"),
		multArea = classe.danoEmArea or 1, -- dano em área (explosões, meteoro, tempestade...)
		rouboVida = e("rouboVida"),
		regen = e("regen"),
		multOuro = (1 + e("ouroPct")) * (if e("ouroMult") > 0 then 2 else 1),
		armadura = math.clamp(classe.armadura + e("armadura"), -0.5, 0.6),
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
		recargaEsquiva = Config.ESQUIVA_RECARGA * (classe.esquivaMult or 1) * (1 - math.min(e("esquivaPct"), 0.6)),
		multCarga = 1 + e("cargaPct"),
		-- Mago
		manaMax = if classe.mana then classe.mana + e("manaPlana") else 0,
		manaRegen = (classe.manaRegen or 0) * (1 + e("manaRegenPct")),
		custoMana = 1 - math.min(e("economiaMana"), 0.5),
		manaAbate = e("manaAbate"),
		-- Assassino
		sangueDps = if classe.sangramento then classe.sangramento.dps * (1 + e("sangrePct")) else 0,
		sangueMax = if classe.sangramento then classe.sangramento.maxPilhas + e("sangrePilhas") else 0,
		sangueDuracao = if classe.sangramento then classe.sangramento.duracao else 0,
		costas = (classe.ataque.costas or 0) + e("costasPct"),
		curaCritico = e("curaCritico"),
		leque = e("leque"),
		contraAtaque = e("contraAtaque") > 0,
		execucao = e("execucao") > 0,
		milCortes = e("milCortes") > 0,
	}
	-- mana: começa cheia e nunca passa do máximo
	estado.mana = math.min(estado.mana or estado.stats.manaMax, estado.stats.manaMax)
	-- todos veem a lâmina pegando fogo quando o jogador tem uma carta de fogo
	estado.player:SetAttribute("PoderFogo", temFogo(estado.stats))
	return estado.stats
end

-- O jogador precisa destes números para mostrar recargas e prever o próprio ataque
function Combate.enviarStats(estado)
	local stats = estado.stats
	local classe = Classes.obter(estado.classe)
	Remotos.enviar(estado.player, "stats", {
		classe = classe.id,
		intervalo = stats.intervalo,
		velAtaque = stats.velAtaque,
		recarga = stats.recarga,
		recargaEsquiva = stats.recargaEsquiva,
		alcance = stats.alcance,
		arco = classe.ataque.arco,
		carga = estado.carga,
		cargaMax = Config.CARGA_MAXIMA,
		mana = estado.mana,
		manaMax = stats.manaMax,
		manaRegen = stats.manaRegen,
		custoMana = stats.custoMana,
		fogo = temFogo(stats),
	})
end

------------------------------------------------------------------------
-- Mana (Mago)
------------------------------------------------------------------------

function Combate.enviarMana(estado, forcar: boolean?)
	if estado.stats.manaMax <= 0 then
		return
	end
	local anterior = estado.manaEnviada or -100
	if forcar or math.abs(estado.mana - anterior) >= 2 or (estado.mana >= estado.stats.manaMax and anterior < estado.stats.manaMax) then
		estado.manaEnviada = estado.mana
		Remotos.enviar(estado.player, "mana", { valor = estado.mana, max = estado.stats.manaMax })
	end
end

-- Gasta mana; sem mana suficiente, avisa o jogador e devolve false
function Combate.gastarMana(estado, custo: number): boolean
	if estado.stats.manaMax <= 0 then
		return true
	end
	custo *= estado.stats.custoMana
	if estado.mana < custo then
		Remotos.enviar(estado.player, "semMana", {})
		return false
	end
	estado.mana -= custo
	Combate.enviarMana(estado, true)
	return true
end

function Combate.ganharMana(estado, quantidade: number)
	if estado.stats.manaMax <= 0 then
		return
	end
	estado.mana = math.min(estado.stats.manaMax, estado.mana + quantidade)
	Combate.enviarMana(estado)
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
	if estado.defendendoDesde then
		fator *= Config.VELOCIDADE_DEFENDENDO
	end
	if os.clock() < (estado.rapidoAte or 0) then
		fator *= 1.3
	end
	local atacando = os.clock() < (estado.atacandoAte or 0)
	if atacando then
		fator *= Config.VELOCIDADE_ATACANDO
	elseif estado.correndo and not estado.carregandoDesde and not estado.defendendoDesde then
		fator *= Config.VELOCIDADE_CORRIDA
	end
	humanoid.WalkSpeed = estado.stats.velocidade * fator
end

-- Corrida leve (Shift): todos veem o personagem correndo pelo atributo "Correndo"
function Combate.correr(estado, ativo: boolean)
	estado.correndo = ativo
	estado.player:SetAttribute("Correndo", ativo)
	Combate.aplicarVelocidade(estado)
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

local COR_SANGUE = Color3.fromRGB(200, 20, 35)

-- Assassino: cada golpe abre mais um corte (pilha); o inimigo perde vida enquanto sangra
local function sangrar(inimigo, estado)
	local stats = estado.stats
	local sangue = inimigo.sangue
	if not sangue or os.clock() > sangue.ate then
		sangue = { pilhas = 0 }
		inimigo.sangue = sangue
	end
	sangue.pilhas = math.min(stats.sangueMax, sangue.pilhas + 1)
	sangue.ate = os.clock() + stats.sangueDuracao
	sangue.dps = stats.dano * stats.sangueDps
	sangue.fonte = estado
	inimigo.modelo:SetAttribute("Sangrando", sangue.pilhas)
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
	-- Carta Execução: golpes acabam com quem está quase morto (chefes só levam o dobro)
	if estado and opcoes.principal and estado.stats.execucao then
		if inimigo.chefe then
			if inimigo.vida <= inimigo.vidaMax * 0.2 then
				dano *= 2
			end
		elseif inimigo.vida - dano <= inimigo.vidaMax * 0.2 then
			dano = math.max(dano, math.ceil(inimigo.vida))
			opcoes.cor = opcoes.cor or Color3.fromRGB(255, 60, 90)
		end
	end
	-- chefe se transformando (troca de fase): não leva dano
	if os.clock() < (inimigo.invulneravelAte or 0) then
		Vfx.partida(run, "dano", {
			pos = inimigo.raiz.Position + Vector3.new(0, inimigo.alturaBarra, 0),
			valor = "IMUNE",
			cor = Color3.fromRGB(200, 200, 210),
		})
		return
	end
	-- chefe com a lâmina presa no chão (Corte Devastador do Skullbane): leva mais dano
	if os.clock() < (inimigo.vulneravelAte or 0) then
		dano = math.floor(dano * 1.35 + 0.5)
		opcoes.cor = opcoes.cor or Color3.fromRGB(255, 225, 90)
	end
	-- escudo de runas (Guardião Rúnico): absorve o dano antes da vida
	if (inimigo.escudo or 0) > 0 then
		local absorvido = math.min(inimigo.escudo, dano)
		inimigo.escudo -= absorvido
		dano -= absorvido
		inimigo.modelo:SetAttribute("Escudo", inimigo.escudo)
		Vfx.partida(run, "dano", {
			pos = inimigo.raiz.Position + Vector3.new(0, inimigo.alturaBarra + 0.8, 0),
			valor = math.floor(absorvido + 0.5),
			cor = Color3.fromRGB(120, 200, 255),
		})
		if inimigo.escudo <= 0 then
			Vfx.partida(run, "escudoQuebrou", { pos = inimigo.raiz.Position, raio = inimigo.raio })
		end
		if dano <= 0 then
			return
		end
	end
	inimigo.vida -= dano
	inimigo.modelo:SetAttribute("Vida", math.max(0, inimigo.vida))

	if estado then
		-- Ameaça: os inimigos preferem atacar quem causa mais dano (o Cavaleiro chama o dobro de atenção)
		inimigo.ameaca[estado] = (inimigo.ameaca[estado] or 0) + dano * (Classes.obter(estado.classe).ameacaMult or 1)
		estado.danoCausado += dano
	end

	Vfx.partida(run, "dano", {
		pos = inimigo.raiz.Position + Vector3.new(0, inimigo.alturaBarra, 0),
		impacto = inimigo.raiz.Position,
		valor = dano,
		critico = opcoes.critico == true,
		cor = opcoes.cor,
		autor = estado and estado.player,
		dot = opcoes.dot, -- dano contínuo (fogo, sangramento): sem som de golpe
		principal = opcoes.principal == true, -- golpe da arma (o Cavaleiro mostra o impacto do corte)
		fogo = opcoes.fogo == true, -- golpe com poder de fogo (impacto de fogo)
		sangue = opcoes.sangue or (estado ~= nil and opcoes.principal == true and estado.stats.sangueMax > 0),
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
		if stats.sangueMax > 0 and opcoes.principal then
			sangrar(inimigo, estado)
		end
		if stats.raios > 0 and opcoes.principal then
			correnteEletrica(run, inimigo, estado, stats.raios, stats.dano * 0.5)
		end
		if opcoes.critico then
			if stats.curaCritico > 0 then
				Combate.curar(run, estado, stats.curaCritico, true)
			end
			if stats.milCortes then
				Combate.reduzirRecarga(estado, 0.5)
			end
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
	-- bônus de dano em área da classe (o Mago causa 15% a mais)
	if estado and estado.stats then
		dano *= estado.stats.multArea or 1
	end
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
	estado.defendendoDesde = nil
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
	-- bônus do supremo do Cavaleiro: 10% menos dano enquanto a aura dura
	if agora < (estado.protecaoSupremoAte or 0) then
		dano *= 1 - DEFESA_SUPREMO
	end
	if agora < (estado.resistenteAte or 0) then
		dano *= 0.6
	end

	-- Escudo erguido (Cavaleiro): golpes vindos da frente perdem quase todo o dano.
	-- Erguido logo antes do golpe, é uma defesa perfeita: bloqueia tudo e atordoa quem atacou.
	if estado.defendendoDesde and not opcoes.ambiente then
		local origem = opcoes.origem or (fonte and fonte.raiz and fonte.raiz.Position)
		if origem then
			local paraFonte = planar(origem - raiz.Position)
			local frente = planar(raiz.CFrame.LookVector)
			local deFrente = paraFonte.Magnitude < 0.5
				or (frente.Magnitude > 0.1 and paraFonte.Unit:Dot(frente.Unit) >= math.cos(math.rad(Config.DEFESA_ANGULO)))
			if deFrente then
				local perfeita = agora - estado.defendendoDesde <= Config.DEFESA_PERFEITA
				local direcaoEscudo = if frente.Magnitude > 0.1 then frente.Unit else Vector3.new(0, 0, -1)
				Vfx.partida(run, "defesa", { jogador = estado.player, perfeita = perfeita, pos = raiz.Position + direcaoEscudo * 1.8, dir = direcaoEscudo })
				animar(run, estado, "bloqueou", { perfeita = perfeita })
				if perfeita then
					if fonte and fonte.vivo then
						Combate.atordoar(fonte, 1.2)
					end
					Combate.adicionarCarga(estado, 6)
					return
				end
				dano *= 1 - Config.DEFESA_REDUCAO
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

local COR_COSTAS = Color3.fromRGB(255, 70, 110)

-- O atacante está atrás do inimigo? (o inimigo olha para o outro lado)
local function pelasCostas(inimigo, origem: Vector3): boolean
	local paraAtacante = planar(origem - inimigo.raiz.Position)
	local olhar = planar(inimigo.raiz.CFrame.LookVector)
	if paraAtacante.Magnitude < 0.1 or olhar.Magnitude < 0.1 then
		return false
	end
	return paraAtacante.Unit:Dot(olhar.Unit) < -0.25
end

local laminasNoturnas
local feiticoDoMago

local function golpeDeEspada(run, estado, classe, raiz: BasePart, direcao: Vector3, mult: number, final: boolean, combo: number)
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
		combo = combo,
		giro = final and classe.id == "cavaleiro",
		cavaleiro = classe.id == "cavaleiro",
		assassino = classe.id == "assassino",
		fogo = temFogo(stats),
	}, estado.player)

	-- o golpe final do Cavaleiro é um giro: acerta tudo em volta
	local giro = final and classe.id == "cavaleiro"
	local limite = if giro then -1 else math.cos(math.rad(arco / 2))
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
	local garantido = estado.criticoGarantido == true
	if #alvos > 0 then
		estado.criticoGarantido = nil
	end
	for _, inimigo in alvos do
		local critico = garantido or math.random() < stats.critico
		local dano = stats.dano * mult * (if critico then stats.multCritico else 1)
		local costas = pelasCostas(inimigo, raiz.Position)
		if costas and stats.costas > 0 then
			dano *= 1 + stats.costas
		end
		local empurrar = direcao
		if giro then
			local fora = planar(inimigo.raiz.Position - raiz.Position)
			empurrar = if fora.Magnitude > 0.1 then fora.Unit else direcao
		end
		Combate.danoAoInimigo(run, inimigo, dano, estado, {
			critico = critico,
			principal = true,
			fogo = temFogo(stats),
			cor = if costas and stats.costas > 0 then COR_COSTAS else nil,
			empurrar = empurrar * (if final then 50 else 25),
		})
	end

	-- Carta Leque de Adagas: o golpe final arremessa adagas
	if final and stats.leque > 0 then
		local lista = {}
		local quantidade = 1 + 2 * stats.leque
		for i = 1, quantidade do
			local angulo = math.rad((i - (quantidade + 1) / 2) * 14)
			table.insert(lista, {
				lado = "jogador",
				tipo = "adaga",
				pos = raiz.Position + direcao * 1.5 + Vector3.new(0, 0.6, 0),
				dir = CFrame.Angles(0, angulo, 0):VectorToWorldSpace(direcao),
				velocidade = 90,
				alcance = 30,
				raio = 1,
				perfuracao = 0,
				aoAcertar = function(inimigo)
					Combate.danoAoInimigo(run, inimigo, stats.dano * 0.9, estado, { semEfeitos = true, cor = classe.cor })
				end,
			})
		end
		Projeteis.disparar(run, lista)
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
	local fogo = classe.id == "arqueiro" and temFogo(stats)
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
			fogo = fogo,
			aoAcertar = function(inimigo, _, projetil)
				local danoAqui = danoFinal
				-- Arqueiro: flecha disparada colada no inimigo perde força
				if classe.id == "arqueiro" then
					local raizAgora = raizDe(estado)
					if raizAgora and planar(raizAgora.Position - inimigo.raiz.Position).Magnitude < inimigo.raio + 6 then
						danoAqui *= 0.6
					end
				end
				Combate.danoAoInimigo(run, inimigo, danoAqui, estado, {
					critico = critico,
					principal = true,
					empurrar = projetil.dir * 18,
					fogo = fogo,
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

-- Mago: cada golpe do combo é uma magia diferente
--   1º Dardo Arcano: rápido e preciso, pequena explosão arcana
--   2º Lança de Gelo: atravessa um inimigo a mais e deixa lento
--   3º Bola de Fogo: lenta e grande, explode e queima
local MAGIAS_DO_COMBO = { "dardoArcano", "lancaGelo", "bolaFogo" }
local COR_ARCANA = Color3.fromRGB(190, 110, 255)
local COR_GELO = Color3.fromRGB(150, 225, 255)

-- Ponto de onde a magia sai: o cristal do cajado, à frente e à direita do corpo
local function pontaDoCajado(raiz: BasePart, direcao: Vector3): Vector3
	local direita = Vector3.new(-direcao.Z, 0, direcao.X)
	return raiz.Position + direcao * 2.5 + Vector3.new(0, 1.4, 0) + direita * 0.5
end

feiticoDoMago = function(run, estado, classe, raiz: BasePart, direcao: Vector3, mult: number, combo: number)
	local stats = estado.stats
	local tipo = MAGIAS_DO_COMBO[combo] or "dardoArcano"
	local origem = pontaDoCajado(raiz, direcao)
	local quantidade = stats.projeteis
	local lista = {}
	for i = 1, quantidade do
		local angulo = math.rad((i - (quantidade + 1) / 2) * 13)
		local dir = CFrame.Angles(0, angulo, 0):VectorToWorldSpace(direcao)
		local critico = math.random() < stats.critico
		local dano = stats.dano * mult * (if critico then stats.multCritico else 1)
		local magia = {
			lado = "jogador",
			tipo = tipo,
			pos = origem,
			dir = dir,
			alcance = stats.alcance,
			tamanho = stats.tamanho,
			ricochete = stats.ricochete,
			perfuracao = stats.perfuracao,
		}
		if tipo == "dardoArcano" then
			magia.velocidade = 80
			magia.raio = 1 * stats.tamanho
			magia.explosao = stats.explosao * 0.7
			magia.aoAcertar = function(inimigo, _, projetil)
				Combate.danoAoInimigo(run, inimigo, dano, estado, { critico = critico, principal = true, empurrar = projetil.dir * 14 })
			end
			magia.aoExplodir = function(pos: Vector3, principal)
				Vfx.partida(run, "explosao", { pos = pos, raio = magia.explosao, cor = COR_ARCANA, leve = true, magia = "dardoArcano" })
				Combate.danoEmArea(run, pos, magia.explosao, dano * 0.5, estado, { semEfeitos = true, exceto = principal, cor = COR_ARCANA })
			end
		elseif tipo == "lancaGelo" then
			magia.velocidade = 72
			magia.raio = 0.9 * stats.tamanho
			magia.perfuracao += 1
			magia.aoAcertar = function(inimigo, _, projetil)
				Combate.danoAoInimigo(run, inimigo, dano, estado, { critico = critico, principal = true, cor = COR_GELO, lento = 0.55, empurrar = projetil.dir * 10 })
			end
		else
			magia.velocidade = 50
			magia.tamanho = stats.tamanho * 1.4
			magia.raio = 1.6 * stats.tamanho
			magia.explosao = math.max(stats.explosao, 4) * 1.8
			magia.aoAcertar = function(inimigo, _, projetil)
				Combate.danoAoInimigo(run, inimigo, dano, estado, { critico = critico, principal = true, queimar = true, cor = COR_FOGO, empurrar = projetil.dir * 30 })
			end
			magia.aoExplodir = function(pos: Vector3, principal)
				Vfx.partida(run, "explosao", { pos = pos, raio = magia.explosao, cor = COR_FOGO, forte = true, magia = "bolaFogo" })
				Combate.danoEmArea(run, pos, magia.explosao, dano * 0.6, estado, { semEfeitos = true, exceto = principal, queimar = true, cor = COR_FOGO, empurrarForca = 30 })
			end
		end
		if not magia.explosao or magia.explosao <= 0 then
			magia.explosao = nil
		end
		table.insert(lista, magia)
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
	if not podeAgir(run, estado) or estado.carregandoDesde or estado.defendendoDesde then
		return
	end
	local stats = estado.stats
	local classe = Classes.obter(estado.classe)
	local agora = os.clock()
	-- cadência: o golpe anterior precisa terminar (com folga para o atraso da internet)
	local espera = Classes.cadencia(classe, if estado.ultimoFoiFinal then 3 else estado.combo, stats.velAtaque)
	if agora - estado.ultimoAtaque < espera * 0.82 then
		return
	end
	if agora - estado.ultimoAtaque > espera + 0.9 then
		estado.combo = 0
	end
	local custos = classe.custos
	if custos and not Combate.gastarMana(estado, if estado.combo % 3 + 1 == 3 then custos.final else custos.ataque) then
		return
	end
	estado.combo = estado.combo % 3 + 1
	local final = estado.combo == 3
	estado.ultimoFoiFinal = final
	estado.ultimoAtaque = agora

	local raiz = raizDe(estado) :: BasePart
	local dir = direcaoValida(direcao, raiz)
	local combo = estado.combo
	local mult = classe.ataque.combo[combo] or 1
	animar(run, estado, "ataque", { combo = combo }, estado.player)

	-- o golpe acontece quando a arma chega no alvo, no meio da animação; enquanto prepara,
	-- o personagem finca o pé (anda bem devagar)
	local impacto = classe.ataque.impacto and classe.ataque.impacto[combo] or 0
	estado.atacandoAte = agora + impacto + 0.1
	Combate.aplicarVelocidade(estado)
	task.delay(impacto + 0.12, function()
		Combate.aplicarVelocidade(estado)
	end)
	task.delay(impacto, function()
		if not podeAgir(run, estado) or estado.defendendoDesde then
			return
		end
		local raizAgora = raizDe(estado) :: BasePart
		if classe.ataque.tipo == "corte" then
			golpeDeEspada(run, estado, classe, raizAgora, dir, mult, final, combo)
		elseif classe.id == "mago" then
			feiticoDoMago(run, estado, classe, raizAgora, dir, mult, combo)
		else
			disparoDeClasse(run, estado, classe, raizAgora, dir, mult, final)
		end
		if stats.dragao > 0 then
			rajadaDoDragao(run, estado, raizAgora, dir)
		end
	end)
end

------------------------------------------------------------------------
-- Ataque carregado: segurar o ataque carrega; soltar dispara um golpe mais forte
------------------------------------------------------------------------

function Combate.carregar(run, estado)
	if not podeAgir(run, estado) or estado.carregandoDesde or estado.defendendoDesde then
		return
	end
	local custos = Classes.obter(estado.classe).custos
	if custos and estado.mana < custos.carregado * estado.stats.custoMana then
		Remotos.enviar(estado.player, "semMana", {})
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

-- Cavaleiro: a espada girando acima da cabeça vira um tornado. Ao soltar, o corte para baixo
-- acerta quem está na frente e lança o tornado, que anda reto puxando e ferindo os inimigos
-- (para na parede). Com a carga cheia, ele explode no fim e atordoa.
local pontoLivre
local function tornadoDoCavaleiro(run, estado, classe, raiz: BasePart, direcao: Vector3, fracao: number, mult: number)
	local stats = estado.stats
	local perfeito = fracao >= 0.99
	local raio = (5 + 3 * fracao) * (stats.alcance / 9.5)
	local velocidade = 15 + 7 * fracao
	local duracao = 1.4 + 1.0 * fracao
	local inicio = noChao(run, raiz.Position + direcao * 3)
	local fim = noChao(run, pontoLivre(estado.player.Character, inicio + Vector3.new(0, 3, 0), inicio + Vector3.new(0, 3, 0) + direcao * velocidade * duracao))
	duracao = math.max(0.5, (fim - inicio).Magnitude / velocidade)
	local saida = 0.14 -- a espada chega no chão na animação "soltar"
	Vfx.partida(run, "tornado", {
		jogador = estado.player,
		de = inicio,
		ate = fim,
		duracao = duracao,
		saida = saida,
		raio = raio,
		cor = classe.cor,
		perfeito = perfeito,
		fogo = temFogo(stats),
	})

	task.delay(saida, function()
		if not run.ativa then
			return
		end
		-- o corte que lança o tornado: acerta quem está na frente
		local origem = raiz.Position
		for _, inimigo in inimigosVivos(run) do
			local delta = planar(inimigo.raiz.Position - origem)
			if delta.Magnitude <= stats.alcance * 1.1 + inimigo.raio and (delta.Magnitude < 2 or delta.Unit:Dot(direcao) > 0.35) then
				local critico = math.random() < stats.critico
				Combate.danoAoInimigo(run, inimigo, stats.dano * mult * 0.6 * (if critico then stats.multCritico else 1), estado, {
					critico = critico,
					principal = true,
					empurrar = direcao * 30,
				})
			end
		end
		if stats.dragao > 0 then
			rajadaDoDragao(run, estado, raiz, direcao)
		end

		-- o tornado anda, puxa para o centro e fere a cada 0,25s
		local comeco = os.clock()
		local proximoDano = 0
		local danoTique = stats.dano * (0.35 + 0.25 * fracao)
		while run.ativa do
			local agora = os.clock()
			local k = math.min(1, (agora - comeco) / duracao)
			local centro = inicio:Lerp(fim, k)
			local ferir = agora >= proximoDano
			if ferir then
				proximoDano = agora + 0.25
			end
			for _, inimigo in inimigosVivos(run) do
				local delta = planar(centro - inimigo.raiz.Position)
				local distancia = delta.Magnitude
				if distancia <= raio + inimigo.raio then
					if not inimigo.pesado then
						-- gira em volta e é sugado para o meio, flutuando um pouco
						local lado = Vector3.new(-delta.Z, 0, delta.X)
						local puxao = if distancia > 0.5 then delta.Unit * 22 + lado.Unit * 14 else Vector3.zero
						inimigo.raiz.AssemblyLinearVelocity = puxao + direcao * velocidade + Vector3.new(0, 7, 0)
					end
					if ferir then
						local fogo = temFogo(stats)
						Combate.danoAoInimigo(run, inimigo, danoTique, estado, { semEfeitos = true, queimar = fogo, cor = if fogo then COR_FOGO else classe.cor })
					end
				end
			end
			if k >= 1 then
				break
			end
			task.wait(0.05)
		end
		if perfeito and run.ativa then
			Vfx.partida(run, "explosao", { pos = fim, raio = raio * 1.6, cor = classe.cor, forte = true })
			for _, inimigo in inimigosVivos(run) do
				if planar(inimigo.raiz.Position - fim).Magnitude <= raio * 1.6 + inimigo.raio then
					Combate.atordoar(inimigo, 1.2)
				end
			end
			Combate.danoEmArea(run, fim, raio * 1.6, stats.dano * 1.5, estado, { semEfeitos = true, cor = classe.cor, empurrarForca = 55 })
		end
	end)
end

local function golpeCarregado(run, estado, classe, raiz: BasePart, direcao: Vector3, fracao: number)
	local stats = estado.stats
	local mult = Config.DANO_CARGA_MIN + (Config.DANO_CARGA_MAX - Config.DANO_CARGA_MIN) * fracao
	local perfeito = fracao >= 0.99

	if classe.id == "cavaleiro" then
		tornadoDoCavaleiro(run, estado, classe, raiz, direcao, fracao, mult)
	elseif classe.id == "mago" then
		-- Orbe do Vazio: lento, puxa os inimigos em volta enquanto voa e explode forte
		-- (atravessa tudo com a carga cheia)
		local custos = classe.custos
		if custos then
			estado.mana = math.max(0, estado.mana - custos.carregado * stats.custoMana)
			Combate.enviarMana(estado, true)
		end
		local tamanho = (1.8 + 1.4 * fracao) * stats.tamanho
		local explosao = math.max(stats.explosao, 4) * (1.6 + 1.4 * fracao)
		local dano = stats.dano * mult
		local raioPuxao = 9 + 5 * fracao
		local proximoPuxao = 0
		Projeteis.disparar(run, {
			{
				lado = "jogador",
				tipo = "orbeCarregado",
				pos = pontaDoCajado(raiz, direcao),
				aoMover = function(projetil)
					local agora = os.clock()
					if agora < proximoPuxao then
						return
					end
					proximoPuxao = agora + 0.1
					for _, inimigo in inimigosVivos(run) do
						local delta = planar(projetil.pos - inimigo.raiz.Position)
						if not inimigo.pesado and delta.Magnitude > 1 and delta.Magnitude <= raioPuxao then
							inimigo.raiz.AssemblyLinearVelocity = delta.Unit * 24 + Vector3.new(0, 2, 0)
						end
					end
				end,
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
					Vfx.partida(run, "vazio", { pos = pos, raio = explosao })
					Combate.danoEmArea(run, pos, explosao, dano * 0.7, estado, { semEfeitos = true, exceto = principal, cor = classe.cor, empurrarForca = 35 })
				end,
			},
		})
	elseif classe.id == "assassino" then
		-- Investida Letal: avança cortando tudo numa linha (o movimento é feito no computador
		-- de quem ataca). Com a carga cheia, todo corte é crítico.
		local inicio = raiz.Position
		local fim = inicio + direcao * (12 + 6 * fracao)
		Vfx.partida(run, "investidaLetal", { jogador = estado.player, de = inicio, ate = fim, cor = classe.cor, perfeito = perfeito }, estado.player)
		estado.invulneravelAte = math.max(estado.invulneravelAte or 0, os.clock() + 0.3)
		task.delay(0.12, function()
			if not run.ativa then
				return
			end
			for _, inimigo in inimigosVivos(run) do
				if Projeteis.distanciaAoSegmento(inimigo.raiz.Position, inicio, fim) <= inimigo.raio + 3 then
					local critico = perfeito or math.random() < stats.critico
					Combate.danoAoInimigo(run, inimigo, stats.dano * mult * (if critico then stats.multCritico else 1), estado, {
						critico = critico,
						principal = true,
						empurrar = direcao * 20,
					})
				end
			end
		end)
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
				fogo = temFogo(stats),
				aoAcertar = function(inimigo, _, projetil)
					Combate.danoAoInimigo(run, inimigo, dano, estado, { critico = critico, principal = true, empurrar = projetil.dir * 35, fogo = temFogo(stats) })
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
-- Defesa com escudo (Cavaleiro): segurar ergue o escudo, soltar abaixa
------------------------------------------------------------------------

function Combate.defender(run, estado, ativo: boolean)
	if estado.classe ~= "cavaleiro" then
		return
	end
	if ativo then
		if not podeAgir(run, estado) or estado.defendendoDesde then
			return
		end
		if estado.carregandoDesde then
			Combate.cancelarCarga(run, estado)
		end
		estado.defendendoDesde = os.clock()
		Combate.aplicarVelocidade(estado)
		animar(run, estado, "defender", nil, estado.player)
	elseif estado.defendendoDesde then
		estado.defendendoDesde = nil
		Combate.aplicarVelocidade(estado)
		animar(run, estado, "pararDefesa", nil, estado.player)
	end
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
	Vfx.partida(run, "redemoinho", { jogador = estado.player, duracao = duracao, raio = raio, cor = classe.cor, fogo = temFogo(stats) })
	animar(run, estado, "habilidade", { duracao = duracao })
	estado.resistenteAte = os.clock() + duracao
	task.spawn(function()
		local fim = os.clock() + duracao
		while os.clock() < fim and run.ativa and estado.vivo and not estado.caido do
			local raiz = raizDe(estado)
			if not raiz then
				break
			end
			-- empurrar negativo puxa os inimigos para o centro do giro
			Combate.danoEmArea(run, raiz.Position, raio, stats.dano * 0.55, estado, { queimar = temFogo(stats), empurrarForca = -18 })
			task.wait(0.22)
		end
		estado.resistenteAte = nil
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
			Vfx.partida(run, "meteoro", { pos = ponto, duracao = 0.75, raio = 11, amigo = true, arcano = true })
			task.delay(0.75, function()
				if not run.ativa then
					return
				end
				Vfx.partida(run, "explosao", { pos = ponto, raio = 11, cor = COR_FOGO, forte = true })
				Combate.danoEmArea(run, ponto, 11, stats.dano * 3.5, estado, { semEfeitos = true, queimar = true, cor = COR_FOGO, empurrarForca = 40 })
				-- o chão fica em chamas por 3 segundos
				Vfx.partida(run, "zonaFogo", { pos = ponto, raio = 8, duracao = 3 })
				task.spawn(function()
					local fimZona = os.clock() + 3
					while os.clock() < fimZona and run.ativa do
						task.wait(0.5)
						Combate.danoEmArea(run, ponto, 8, stats.dano * 0.35, estado, { semEfeitos = true, cor = COR_FOGO })
					end
				end)
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
	Vfx.partida(run, "chuvaFlechas", { pos = centro, raio = raio, duracao = duracao, cor = classe.cor, fogo = temFogo(stats) })
	task.spawn(function()
		local fim = os.clock() + duracao
		task.wait(0.35)
		while os.clock() < fim and run.ativa do
			Combate.danoEmArea(run, centro, raio, stats.dano * 0.45, estado, { semEfeitos = true, lento = 0.75 })
			task.wait(0.25)
		end
	end)
end

-- Ponto livre entre "de" e "ate" (não atravessa paredes)
function pontoLivre(personagem: Model?, de: Vector3, ate: Vector3): Vector3
	local parametros = RaycastParams.new()
	parametros.FilterType = Enum.RaycastFilterType.Exclude
	local ignorar = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignorar, player.Character)
		end
	end
	if personagem then
		table.insert(ignorar, personagem)
	end
	for _, inimigo in CollectionService:GetTagged("Inimigo") do
		table.insert(ignorar, inimigo)
	end
	parametros.FilterDescendantsInstances = ignorar
	parametros.RespectCanCollide = true
	local delta = ate - de
	local resultado = workspace:Raycast(de, delta, parametros)
	if resultado then
		local recuo = math.max(0, (resultado.Position - de).Magnitude - 2)
		return de + delta.Unit * recuo
	end
	return ate
end

-- Coloca o jogador atrás do inimigo, olhando para ele
local function teleportarAtras(estado, inimigo, raiz: BasePart): Vector3
	local alvo = inimigo.raiz.Position
	local olhar = planar(inimigo.raiz.CFrame.LookVector)
	if olhar.Magnitude < 0.1 then
		olhar = planar(alvo - raiz.Position)
	end
	olhar = if olhar.Magnitude > 0.1 then olhar.Unit else Vector3.new(0, 0, -1)
	local altura = Vector3.new(0, raiz.Position.Y - alvo.Y, 0)
	local desejado = alvo + altura - olhar * (inimigo.raio + 2.5)
	local destino = pontoLivre(estado.player.Character, alvo + altura, desejado)
	local personagem = estado.player.Character
	if personagem then
		personagem:PivotTo(CFrame.lookAt(destino, Vector3.new(alvo.X, destino.Y, alvo.Z)))
	end
	return destino
end

local function passoSombrio(run, estado, classe, raiz: BasePart, direcao: Vector3)
	local stats = estado.stats
	local inicio = raiz.Position
	local alvo = alvoNaMira(inicio, direcao, run, 35)
	estado.invulneravelAte = math.max(estado.invulneravelAte or 0, os.clock() + 0.5)
	if not alvo then
		-- sem alvo: só avança na direção da mira
		local destino = pontoLivre(estado.player.Character, inicio, inicio + direcao * 14)
		local personagem = estado.player.Character
		if personagem then
			personagem:PivotTo(CFrame.lookAt(destino, destino + direcao))
		end
		Vfx.partida(run, "passoSombrio", { jogador = estado.player, de = inicio, ate = destino, cor = classe.cor })
		return
	end
	local destino = teleportarAtras(estado, alvo, raiz)
	Vfx.partida(run, "passoSombrio", { jogador = estado.player, de = inicio, ate = destino, cor = classe.cor })
	task.delay(0.1, function()
		if not run.ativa or not alvo.vivo then
			return
		end
		local dano = stats.dano * 2.2 * stats.multCritico * (1 + stats.costas)
		Combate.danoAoInimigo(run, alvo, dano, estado, { critico = true, principal = true, cor = COR_COSTAS, empurrar = planar(alvo.raiz.Position - destino).Unit * 20 })
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
	local custos = Classes.obter(estado.classe).custos
	if custos and not Combate.gastarMana(estado, custos.habilidade) then
		return
	end
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
	elseif id == "passoSombrio" then
		animar(run, estado, "habilidade", { duracao = 0.4 })
		passoSombrio(run, estado, classe, raiz, dir)
	else
		-- o salto para trás é feito no computador do arqueiro; aqui só fica intocável no salto
		estado.invulneravelAte = math.max(estado.invulneravelAte or 0, agora + 0.3)
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

-- Assassino: salta de inimigo em inimigo, intocável, cortando cada um pelas costas
laminasNoturnas = function(run, estado, classe)
	local stats = estado.stats
	local golpes = 10
	local duracao = golpes * 0.28 + 0.3
	estado.invulneravelAte = math.max(estado.invulneravelAte or 0, os.clock() + duracao)
	animar(run, estado, "supremo", { duracao = duracao })
	task.spawn(function()
		local ultimo = nil
		for _ = 1, golpes do
			if not run.ativa or not estado.vivo or estado.caido then
				break
			end
			local raiz = raizDe(estado)
			if not raiz then
				break
			end
			-- o mais perto, evitando repetir o último (a não ser que só reste ele)
			local melhor, melhorDistancia = nil, math.huge
			for _, inimigo in inimigosVivos(run) do
				local distancia = (inimigo.raiz.Position - raiz.Position).Magnitude
				if inimigo == ultimo then
					distancia += 1000
				end
				if distancia < melhorDistancia then
					melhor, melhorDistancia = inimigo, distancia
				end
			end
			if not melhor then
				break
			end
			ultimo = melhor
			local inicio = raiz.Position
			local destino = teleportarAtras(estado, melhor, raiz)
			Vfx.partida(run, "passoSombrio", { jogador = estado.player, de = inicio, ate = destino, cor = classe.cor, leve = true })
			local critico = math.random() < stats.critico + 0.25
			local dano = stats.dano * 2.4 * (1 + stats.costas) * (if critico then stats.multCritico else 1)
			Combate.danoAoInimigo(run, melhor, dano, estado, { critico = critico, principal = true, cor = COR_COSTAS })
			task.wait(0.28)
		end
	end)
end

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
		-- aura do supremo: por 10s o Cavaleiro recebe 10% menos dano
		estado.protecaoSupremoAte = os.clock() + DURACAO_AURA_SUPREMO
		Vfx.partida(run, "auraSupremo", { jogador = estado.player, duracao = DURACAO_AURA_SUPREMO, cor = classe.cor })
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
			-- o Cavaleiro e os aliados por perto ganham um escudo que bloqueia o próximo golpe
			for _, outro in run.jogadores do
				local raizOutro = raizDe(outro)
				if outro.vivo and not outro.caido and raizOutro and planar(raizOutro.Position - centro).Magnitude <= 25 then
					outro.escudoAtivo = true
					Vfx.partida(run, "escudoGanho", { jogador = outro.player, cor = classe.cor })
				end
			end
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
					Combate.danoEmArea(run, ponto, 4.5, stats.dano * 1.6, estado, { semEfeitos = true, cor = COR_RAIO, lento = 0.6 })
				end
				task.wait(0.2)
			end
		end)
	elseif classe.supremo.id == "laminasNoturnas" then
		laminasNoturnas(run, estado, classe)
	else
		animar(run, estado, "supremo", { duracao = 4 })
		estado.rapidoAte = os.clock() + 4
		Combate.aplicarVelocidade(estado)
		task.delay(4.05, function()
			Combate.aplicarVelocidade(estado)
		end)
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
						fogo = temFogo(stats),
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
	local dash = Classes.obter(estado.classe).esquiva
	local duracaoDash = if dash then dash.duracao else Config.ESQUIVA_DURACAO
	estado.invulneravelAte = math.max(estado.invulneravelAte or 0, agora + math.max(Config.ESQUIVA_INVULNERAVEL, duracaoDash + 0.05))
	animar(run, estado, "esquiva", nil, estado.player)
	if estado.stats.contraAtaque then
		estado.criticoGarantido = true
	end

	-- Carta Investida Brutal: atropela quem estiver no caminho
	local stats = estado.stats
	if stats.investida > 0 then
		local raiz = raizDe(estado) :: BasePart
		local inicio = raiz.Position
		task.delay(duracaoDash + 0.05, function()
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
		local sangue = inimigo.sangue
		if sangue then
			if agora < sangue.ate then
				Combate.danoAoInimigo(run, inimigo, sangue.dps * sangue.pilhas * dt, sangue.fonte, { semEfeitos = true, cor = COR_SANGUE, sangue = "gota", dot = true })
			else
				inimigo.sangue = nil
				inimigo.modelo:SetAttribute("Sangrando", 0)
			end
		end
		if inimigo.vivo and inimigo.queimaAte then
			if agora < inimigo.queimaAte then
				Combate.danoAoInimigo(run, inimigo, inimigo.queimaDps * dt, inimigo.queimaFonte, { semEfeitos = true, cor = COR_FOGO, dot = true })
			else
				inimigo.queimaAte = nil
				inimigo.queimaDps = 0
				inimigo.modelo:SetAttribute("Queimando", false)
			end
		end
	end

	for _, estado in run.jogadores do
		-- barreira ativa (Barreira Arcana / Escudo Abençoado): todos veem a bolha em volta do jogador
		local barreira = estado.vivo and not estado.caido and estado.escudoAtivo == true
		if estado.player:GetAttribute("BarreiraArcana") ~= barreira then
			estado.player:SetAttribute("BarreiraArcana", barreira)
		end
		if estado.vivo then
			if estado.caido then
				processarCaido(run, estado, dt, agora)
			else
				if estado.stats.regen > 0 then
					Combate.curar(run, estado, estado.stats.regen * dt, true)
				end
				if estado.stats.manaMax > 0 and estado.mana < estado.stats.manaMax then
					Combate.ganharMana(estado, estado.stats.manaRegen * dt)
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
	estado.mana = estado.stats.manaMax
	Combate.enviarMana(estado, true)
	estado.carregandoDesde = nil
	estado.defendendoDesde = nil
	estado.escudoAtivo = estado.stats.escudo
	estado.invulneravelAte = os.clock() + 1.5
	estado.lentoAte = nil
	estado.queimaAte = nil
end

return Combate
