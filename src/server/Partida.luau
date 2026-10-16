-- Controla cada partida: salas, ondas de inimigos, cartas, elevador e fim de jogo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cartas = require(Shared:WaitForChild("Cartas"))
local Reliquias = require(Shared:WaitForChild("Reliquias"))

local servidor = script.Parent
local Remotos = require(servidor.Remotos)
local Dados = require(servidor.Dados)
local Vfx = require(servidor.Vfx)
local Masmorra = require(servidor.Masmorra)
local Combate = require(servidor.Combate)
local Projeteis = require(servidor.Projeteis)
local Inimigos = require(servidor.Inimigos)
local Armadilhas = require(servidor.Armadilhas)

local Partida = {}

local partidasAtivas = {} -- [run] = true
local partidaDoJogador = {} -- [Player] = run
local contadorPartidas = 0

local COR_OURO = Color3.fromRGB(255, 205, 60)
local COR_VERDE = Color3.fromRGB(120, 255, 150)
local COR_VERMELHO = Color3.fromRGB(255, 80, 80)

------------------------------------------------------------------------
-- Objeto da partida
------------------------------------------------------------------------
local Run = {}
Run.__index = Run

function Run:enviar(player: Player, tipo: string, dados)
	Remotos.enviar(player, tipo, dados)
end

function Run:enviarTodos(tipo: string, dados)
	for player in self.jogadores do
		Remotos.enviar(player, tipo, dados)
	end
end

function Run:anunciar(texto: string, cor: Color3?)
	self:enviarTodos("banner", { texto = texto, cor = cor })
end

-- Jogadores de pé (vivos e não caídos)
function Run:jogadoresAtivos(): number
	local total = 0
	for _, estado in self.jogadores do
		if estado.vivo and not estado.caido then
			total += 1
		end
	end
	return total
end

function Run:quantidadeJogadores(): number
	local total = 0
	for _ in self.jogadores do
		total += 1
	end
	return total
end

function Run:quantidadeInimigos(): number
	local total = 0
	for _ in self.inimigos do
		total += 1
	end
	return total
end

local function darOuro(run, estado, base: number)
	local valor = math.max(1, math.floor(base * estado.stats.multOuro + 0.5))
	estado.ouro += valor
	run:enviar(estado.player, "ouro", { total = estado.ouro, ganho = valor })
end

-- Cria um inimigo. Sem "imediato", ele sai de um portal no chão (o jogador vê de onde vem).
function Run:invocar(tipo: string, posicao: Vector3, elite: string?, imediato: boolean?)
	local sala = self.sala
	if imediato then
		return Inimigos.criar(self, tipo, posicao, self.mult, elite)
	end
	self.inimigosPendentes += 1
	Vfx.partida(self, "portal", { pos = posicao, duracao = 0.9, elite = elite ~= nil })
	task.delay(0.9, function()
		self.inimigosPendentes -= 1
		if self.ativa and self.sala == sala then
			Inimigos.criar(self, tipo, posicao, self.mult, elite)
		end
	end)
	return nil
end

function Run:aoMorrerInimigo(inimigo, estadoMatador)
	if not inimigo.vivo then
		return
	end
	local posicao = inimigo.raiz.Position
	local eraChefe = inimigo.chefe
	Inimigos.morrer(self, inimigo)

	if estadoMatador then
		local ouroBase = inimigo.ouro * (1 + self.numeroSala * 0.08)
		for _, estado in self.jogadores do
			darOuro(self, estado, ouroBase)
		end
		Vfx.partida(self, "moedas", { pos = posicao, quantidade = math.clamp(math.floor(ouroBase / 2), 2, 14) })
		estadoMatador.abates += 1
		Combate.adicionarCarga(estadoMatador, Config.CARGA_POR_ABATE)

		local stats = estadoMatador.stats
		if stats.arquimago then
			Combate.reduzirRecarga(estadoMatador, 1)
		end
		if stats.manaAbate > 0 then
			Combate.ganharMana(estadoMatador, stats.manaAbate)
		end
		-- Carta Combustão: explosões em cadeia
		if stats.explosaoMorte > 0 then
			task.delay(0.12, function()
				if not self.ativa then
					return
				end
				Vfx.partida(self, "explosao", { pos = posicao, raio = 10, cor = Color3.fromRGB(255, 140, 40), magia = "bolaFogo" })
				Combate.danoEmArea(self, posicao, 10, stats.dano * 0.6 * stats.explosaoMorte, estadoMatador, {
					semEfeitos = true,
					cor = Color3.fromRGB(255, 140, 40),
				})
			end)
		end
	end

	if eraChefe then
		self:enviarTodos("chefe", { fim = true })
	end
end

------------------------------------------------------------------------
-- Personagens
------------------------------------------------------------------------

local function personagemVivo(player: Player): boolean
	local personagem = player.Character
	local humanoid = personagem and personagem:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function configurarPersonagem(run, estado)
	local player = estado.player
	local personagem = player.Character
	local humanoid = personagem and personagem:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end
	for _, conexao in estado.conexoes do
		conexao:Disconnect()
	end
	estado.conexoes = {}

	Combate.aplicarStats(estado, true)
	Combate.equipar(estado)
	Combate.enviarStats(estado)

	table.insert(estado.conexoes, humanoid.Died:Connect(function()
		if run.jogadores[player] ~= estado or not estado.vivo then
			return
		end
		estado.vivo = false
		estado.caido = false
		run:enviar(player, "morreu", {})
	end))
end

local function reviver(run, estado, cframe: CFrame)
	local player = estado.player
	if not player.Parent then
		return
	end
	player:LoadCharacterAsync()
	if not player.Parent or run.jogadores[player] ~= estado then
		return
	end
	local personagem = player.Character
	if not personagem then
		return
	end
	personagem:PivotTo(cframe)
	estado.vivo = true
	estado.caido = false
	configurarPersonagem(run, estado)
	run:enviar(player, "reviveu", {})
end

------------------------------------------------------------------------
-- Fim da partida para um jogador
------------------------------------------------------------------------

-- motivo: "saiu" (elevador), "morreu" ou "desconectou"
local function finalizarJogador(run, estado, motivo: string)
	local player = estado.player
	if run.jogadores[player] ~= estado then
		return
	end
	run.jogadores[player] = nil
	partidaDoJogador[player] = nil
	for _, conexao in estado.conexoes do
		conexao:Disconnect()
	end

	local ganho = if motivo == "saiu" then estado.ouro else math.floor(estado.ouro * Config.OURO_MANTIDO_AO_MORRER)
	Dados.adicionarOuro(player, ganho)
	local novoRecorde = Dados.registrarRecorde(player, run.numeroSala)

	if motivo == "desconectou" then
		return
	end
	task.spawn(Dados.salvar, player)

	Remotos.enviar(player, "fimPartida", {
		motivo = motivo,
		sala = run.numeroSala,
		ouroPartida = estado.ouro,
		ganho = ganho,
		novoRecorde = novoRecorde,
		abates = estado.abates,
		dano = estado.danoCausado,
		cartas = estado.cartas,
		classe = estado.classe,
	})
	task.spawn(function()
		if player.Parent and not partidaDoJogador[player] then
			player:SetAttribute("PoderFogo", false) -- as cartas ficam na partida
			player:SetAttribute("BarreiraArcana", false)
			player:SetAttribute("AuraProtetor", false)
			player:SetAttribute("InvestidaBrutal", false)
			player:LoadCharacterAsync()
			Remotos.enviar(player, "lobby", {})
			Dados.enviarPerfil(player)
		end
	end)
end

------------------------------------------------------------------------
-- Salas
------------------------------------------------------------------------

local function escolherTipoSala(run, numero: number): string
	if numero % Config.SALAS_POR_ANDAR == 0 then
		return "chefe"
	end
	local depoisDoChefe = numero % Config.SALAS_POR_ANDAR == 1
	if numero > 1 and not depoisDoChefe and run.ultimoTesouro ~= numero - 1 and run.rng:NextNumber() < Config.CHANCE_SALA_TESOURO then
		run.ultimoTesouro = numero
		return "tesouro"
	end
	return "combate"
end

local function multiplicadores(run, numero: number)
	local extras = math.max(0, run:quantidadeJogadores() - 1)
	local ciclo = (numero - 1) // (Config.SALAS_POR_ANDAR * #Config.TEMAS)
	local vidaSala = (1 + (numero - 1) * Config.VIDA_INIMIGO_POR_SALA) * (1 + ciclo * 0.5)
	local danoSala = (1 + (numero - 1) * Config.DANO_INIMIGO_POR_SALA) * (1 + ciclo * 0.25)
	return {
		vida = vidaSala * (1 + extras * Config.VIDA_INIMIGO_POR_JOGADOR_EXTRA),
		dano = danoSala * (1 + extras * Config.DANO_INIMIGO_POR_JOGADOR_EXTRA),
		-- chefes: vida, dano, recarga dos golpes e postura próprios do grupo
		vidaChefe = vidaSala * (1 + extras * Config.VIDA_CHEFE_POR_JOGADOR_EXTRA),
		danoChefe = danoSala * (1 + extras * Config.DANO_CHEFE_POR_JOGADOR_EXTRA),
		recargaChefe = math.max(0.6, 1 - extras * Config.RECARGA_CHEFE_POR_JOGADOR_EXTRA),
		posturaChefe = 1 + extras * Config.POSTURA_CHEFE_POR_JOGADOR_EXTRA,
	}
end

-- Avisa o grupo quando a dificuldade muda porque alguém entrou ou saiu
local function avisarDificuldade(run)
	local jogadores = run:quantidadeJogadores()
	if jogadores == (run.tamanhoAvisado or 1) then
		return
	end
	run.tamanhoAvisado = jogadores
	if jogadores <= 1 then
		return
	end
	local extras = jogadores - 1
	local function pct(valor: number): number
		return math.floor(extras * valor * 100 + 0.5)
	end
	run:anunciar(string.format("👥 Grupo de %d: inimigos +%d%% vida e +%d%% dano · chefes +%d%% vida e +%d%% dano",
		jogadores,
		pct(Config.VIDA_INIMIGO_POR_JOGADOR_EXTRA),
		pct(Config.DANO_INIMIGO_POR_JOGADOR_EXTRA),
		pct(Config.VIDA_CHEFE_POR_JOGADOR_EXTRA),
		pct(Config.DANO_CHEFE_POR_JOGADOR_EXTRA)), Color3.fromRGB(255, 170, 80))
end

local function prepararSala(run, numero: number, tipo: string)
	run:enviarTodos("transicao", {})
	task.wait(0.45)
	if not run.ativa then
		return
	end

	Inimigos.limparTodos(run)
	Projeteis.limpar(run)
	local salaAntiga = run.sala
	run.usarSegundoEspaco = not run.usarSegundoEspaco
	local origem = run.origemBase + (if run.usarSegundoEspaco then Vector3.new(0, 0, 400) else Vector3.zero)

	-- mini-chefe guardando o relicário em algumas salas de exploração do andar
	local posicaoNoAndar = (numero - 1) % Config.SALAS_POR_ANDAR + 1
	local miniChefe = table.find(Config.EXPLORACAO.miniChefeNasSalas, posicaoNoAndar) ~= nil
	local sala = Masmorra.construir(origem, numero, tipo, run.rng, { miniChefe = miniChefe })
	sala.modelo.Parent = run.pasta
	run.sala = sala
	run.numeroSala = numero
	run.mult = multiplicadores(run, numero)
	avisarDificuldade(run)

	local jogadores = {}
	for _, estado in run.jogadores do
		table.insert(jogadores, estado)
	end
	for indice, estado in jogadores do
		local cframe = sala.spawn * CFrame.new((indice - 1) * 4 - 6, 0, 0)
		if not estado.vivo or estado.caido or not personagemVivo(estado.player) then
			reviver(run, estado, cframe)
		else
			local personagem = estado.player.Character
			if personagem then
				personagem:PivotTo(cframe)
			end
		end
		Combate.novaSala(estado)
	end

	if salaAntiga then
		salaAntiga.modelo:Destroy()
	end

	local tema = sala.tema
	run:enviarTodos("sala", {
		numero = numero,
		tipo = tipo,
		posicaoNoAndar = (numero - 1) % Config.SALAS_POR_ANDAR + 1,
		tema = {
			id = tema.id,
			nome = tema.nome,
			ambiente = tema.ambiente,
			nevoa = tema.nevoa,
			luz = tema.luz,
			tinta = tema.tinta,
			brilho = tema.brilho,
			densidade = tema.densidade,
		},
	})
end

local function sortearDaTabela(rng: Random, pesos): string
	local total = 0
	for _, peso in pesos do
		total += peso
	end
	local sorteio = rng:NextNumber() * total
	local ultimo = nil
	for tipo, peso in pesos do
		ultimo = tipo
		sorteio -= peso
		if sorteio <= 0 then
			return tipo
		end
	end
	return ultimo
end

-- Só os inimigos que já podem aparecer nesta sala (alguns esperam a 2ª sala). Os de apoio
-- (curam, dão escudo, gritam) aparecem mais vezes: Config.PESO_INIMIGOS_DE_APOIO
local function tabelaDaSala(pesos, numero: number)
	local filtrada = {}
	for tipo, peso in pesos do
		local def = Inimigos.TIPOS[tipo]
		if def and numero >= (def.salaMinima or 1) then
			filtrada[tipo] = if def.comportamento == "suporte" then peso * Config.PESO_INIMIGOS_DE_APOIO else peso
		end
	end
	return filtrada
end

local function sortearElite(run, numero: number): string?
	local extras = math.max(0, run:quantidadeJogadores() - 1)
	local chance = math.min(
		Config.CHANCE_ELITE_BASE + numero * Config.CHANCE_ELITE_POR_SALA + extras * Config.ELITE_POR_JOGADOR_EXTRA,
		Config.CHANCE_ELITE_MAXIMA + extras * Config.ELITE_POR_JOGADOR_EXTRA
	)
	if numero >= 2 and run.rng:NextNumber() < chance then
		return Inimigos.LISTA_ELITES[run.rng:NextInteger(1, #Inimigos.LISTA_ELITES)]
	end
	return nil
end

------------------------------------------------------------------------
-- Relíquias e baús
------------------------------------------------------------------------

local function listaDeReliquias(estado)
	local lista = {}
	for id in estado.reliquias do
		table.insert(lista, id)
	end
	return lista
end

-- Sorteia uma relíquia que o jogador ainda não tem; a raridade depende do tipo do baú
-- (Reliquias.BAUS). Sem nenhuma da raridade sorteada sobrando, tenta as de cima e depois as de baixo.
local function sortearReliquia(run, estado, tipoBau: string): string?
	local chances = Reliquias.BAUS[tipoBau] or Reliquias.BAUS.chao
	local ordem = Config.ORDEM_RARIDADES
	local total = 0
	for _, raridade in ordem do
		total += chances[raridade] or 0
	end
	local sorteio = run.rng:NextNumber() * total
	local escolhida = ordem[1]
	for _, raridade in ordem do
		sorteio -= chances[raridade] or 0
		if sorteio <= 0 then
			escolhida = raridade
			break
		end
	end
	local inicio = table.find(ordem, escolhida) or 1
	local tentativas = {}
	for i = inicio, #ordem do
		table.insert(tentativas, ordem[i])
	end
	for i = inicio - 1, 1, -1 do
		table.insert(tentativas, ordem[i])
	end
	for _, raridade in tentativas do
		local opcoes = {}
		for _, reliquia in Reliquias.lista do
			if reliquia.raridade == raridade and not estado.reliquias[reliquia.id] then
				table.insert(opcoes, reliquia.id)
			end
		end
		if #opcoes > 0 then
			return opcoes[run.rng:NextInteger(1, #opcoes)]
		end
	end
	return nil
end

local function darReliquia(run, estado, id: string)
	local reliquia = Reliquias.porId[id]
	estado.reliquias[id] = true
	Combate.calcularStats(estado)
	Combate.aplicarStats(estado, false)
	Combate.enviarStats(estado)
	local cor = Config.RARIDADES[reliquia.raridade].cor
	run:enviar(estado.player, "reliquia", { id = id, lista = listaDeReliquias(estado) })
	Vfx.partida(run, "carta", { jogador = estado.player, cor = cor, raridade = reliquia.raridade })
	if reliquia.raridade == "Lendaria" then
		run:anunciar("🌟 " .. estado.player.DisplayName .. " achou uma relíquia LENDÁRIA: " .. reliquia.nome .. "!", COR_OURO)
	elseif reliquia.raridade == "Epica" then
		run:anunciar("💜 " .. estado.player.DisplayName .. " achou " .. reliquia.nome .. "!", Config.RARIDADES.Epica.cor)
	end
end

-- Abre um baú: cada jogador do grupo sorteia a própria relíquia (ou ganha uma poção de cura)
-- e todos ganham ouro
local function abrirBau(run, bau, player: Player?)
	if bau.aberto or bau.travado then
		return
	end
	Masmorra.abrirBauReliquia(bau)
	local chance = Config.EXPLORACAO.chanceReliquia[bau.tipo] or 0.3
	local base = (15 + run.numeroSala * 4) * (if bau.tipo == "chao" then 1 else 1.6)
	Vfx.partida(run, "moedas", { pos = bau.base.Position + Vector3.new(0, 2, 0), quantidade = if bau.tipo == "chao" then 10 else 20 })
	local nomeBau = if Reliquias.BAUS[bau.tipo] then Reliquias.BAUS[bau.tipo].nome else "Baú"
	run:anunciar("🗝️ " .. (if player then player.DisplayName else "O grupo") .. " abriu o " .. nomeBau .. "!", COR_OURO)
	for _, estado in run.jogadores do
		darOuro(run, estado, base)
		local id = if run.rng:NextNumber() < chance then sortearReliquia(run, estado, bau.tipo) else nil
		if id then
			darReliquia(run, estado, id)
		else
			local personagem = estado.player.Character
			local humanoid = personagem and personagem:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and estado.vivo and not estado.caido then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * 0.3)
			end
			run:enviar(estado.player, "aviso", { texto = "🧪 Só uma poção desta vez: +30% de vida e ouro" })
		end
	end
end

local function ligarBau(run, bau)
	bau.prompt.Triggered:Connect(function(player)
		local estado = run.jogadores[player]
		if estado and estado.vivo and not estado.caido then
			abrirBau(run, bau, player)
		end
	end)
end

-- Sala de exploração: três áreas que acordam conforme o grupo avança, baús espalhados (no chão,
-- nas sacadas e na torre), armadilhas e, em algumas salas, o mini-chefe guardando o relicário.
-- Retorna true quando todas as áreas foram limpas, false se o grupo inteiro caiu.
local function salaDeExploracao(run): boolean
	local sala = run.sala
	local numero = run.numeroSala
	local jogadores = run:quantidadeJogadores()
	local info = Config.EXPLORACAO
	run.inimigosPendentes = 0
	for _, bau in sala.baus do
		ligarBau(run, bau)
	end
	Armadilhas.iniciar(run, sala)
	run:anunciar("🗺️ Explore: suba nas sacadas e na torre atrás de relíquias!", COR_OURO)
	run:enviarTodos("aviso", { texto = "Cuidado com as armadilhas! Os inimigos acordam conforme você avança." })

	local total = math.min(math.floor((7 + numero * 1.1 + (jogadores - 1) * Config.INIMIGOS_POR_JOGADOR_EXTRA) * info.inimigosMult), 48)
	local maximoVivos = math.min(8 + numero // 3 + (jogadores - 1) * Config.VIVOS_POR_JOGADOR_EXTRA, 18)
	local porArea = { math.floor(total * 0.3 + 0.5), math.floor(total * 0.35 + 0.5) }
	porArea[3] = math.max(2, total - porArea[1] - porArea[2])
	local acordada = { false, false, false }
	local terminou = { false, false, false }
	local miniChefe = nil

	local function acordar(indice: number)
		acordada[indice] = true
		if indice > 1 then
			run:enviarTodos("aviso", { texto = "⚔️ Inimigos à frente!" })
		end
		task.spawn(function()
			if indice == 3 and sala.miniChefe and sala.posMiniChefe then
				run:anunciar("💀 MINI-CHEFE: o Carcereiro Esmeralda guarda o relicário!", Color3.fromRGB(110, 255, 160))
				miniChefe = run:invocar("ceifadorEsmeralda", sala.posMiniChefe, "Carcereiro", true)
				task.wait(1.4)
			end
			local criados = 0
			while run.ativa and run.sala == sala and criados < porArea[indice] do
				if run:quantidadeInimigos() + run.inimigosPendentes < maximoVivos then
					local tipoInimigo = sortearDaTabela(run.rng, tabelaDaSala(sala.tema.inimigos, numero))
					local grupo = Inimigos.TIPOS[tipoInimigo].grupo or 1
					local base = Masmorra.posicaoNaArea(sala, run.rng, indice)
					for g = 1, grupo do
						local pos = if g == 1 then base else base + Vector3.new(run.rng:NextNumber(-3, 3), 0, run.rng:NextNumber(-3, 3))
						run:invocar(tipoInimigo, pos, if g == 1 then sortearElite(run, numero) else nil)
					end
					criados += grupo
					task.wait(0.35)
				else
					task.wait(0.3)
				end
			end
			terminou[indice] = true
		end)
	end

	task.wait(1.5)
	acordar(1)
	while run.ativa do
		if run:jogadoresAtivos() == 0 then
			return false
		end
		-- a próxima área acorda quando alguém chega perto dela
		for indice = 2, 3 do
			if not acordada[indice] then
				local limite = sala.areas[indice].inicio - info.distanciaArea
				for _, estado in run.jogadores do
					local personagem = estado.player.Character
					local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
					if estado.vivo and raiz and raiz:IsA("BasePart") and (raiz.Position - sala.origem).Z > limite then
						acordar(indice)
						break
					end
				end
			end
		end
		if miniChefe and not miniChefe.vivo then
			miniChefe = nil
			Masmorra.destravarRelicario(sala)
			run:anunciar("🔓 O Carcereiro caiu! O relicário se abriu.", COR_OURO)
		end
		if terminou[1] and terminou[2] and terminou[3] and run.inimigosPendentes == 0 and run:quantidadeInimigos() == 0 then
			return true
		end
		task.wait(0.25)
	end
	return false
end

-- Retorna true se a sala foi limpa, false se o grupo inteiro caiu
local function salaDeCombate(run, tipo: string): boolean
	local sala = run.sala
	if sala.exploracao then
		return salaDeExploracao(run)
	end
	local numero = run.numeroSala
	local jogadores = run:quantidadeJogadores()
	run.inimigosPendentes = 0
	local terminouDeInvocar = false

	if tipo == "chefe" then
		local chefe = Inimigos.TIPOS[sala.tema.chefe]
		run:enviarTodos("introChefe", { nome = chefe.nome, titulo = chefe.titulo or "" })
		task.wait(1.2)
		-- sem o portal: o chefe tem a própria entrada (sobe da tumba enquanto o nome aparece)
		run:invocar(sala.tema.chefe, sala.origem, nil, true) -- no centro da sala, de frente para a entrada
		terminouDeInvocar = true
	else
		-- salas maiores: mais inimigos, chegando em ondas
		local total = math.min(7 + math.floor(numero * 1.1) + (jogadores - 1) * Config.INIMIGOS_POR_JOGADOR_EXTRA, 42)
		local maximoVivos = math.min(8 + numero // 3 + (jogadores - 1) * Config.VIVOS_POR_JOGADOR_EXTRA, 18)
		task.spawn(function()
			local criados = 0
			while run.ativa and run.sala == sala and criados < total do
				if run:quantidadeInimigos() + run.inimigosPendentes < maximoVivos then
					local tipoInimigo = sortearDaTabela(run.rng, tabelaDaSala(sala.tema.inimigos, numero))
					local grupo = Inimigos.TIPOS[tipoInimigo].grupo or 1
					local base = Masmorra.posicaoInimigo(sala, run.rng)
					for g = 1, grupo do
						local pos = if g == 1 then base else base + Vector3.new(run.rng:NextNumber(-3, 3), 0, run.rng:NextNumber(-3, 3))
						run:invocar(tipoInimigo, pos, if g == 1 then sortearElite(run, numero) else nil)
					end
					criados += grupo
					task.wait(0.4)
				else
					task.wait(0.3)
				end
			end
			terminouDeInvocar = true
		end)
	end

	while run.ativa do
		if run:jogadoresAtivos() == 0 then
			return false
		end
		if terminouDeInvocar and run.inimigosPendentes == 0 and run:quantidadeInimigos() == 0 then
			return true
		end
		task.wait(0.25)
	end
	return false
end

local function salaDoTesouro(run): boolean
	local sala = run.sala
	local aberto = false

	local function abrir()
		if aberto then
			return
		end
		aberto = true
		sala.promptBau.Enabled = false
		Masmorra.abrirBau(sala)
		local base = 25 + run.numeroSala * 6
		for _, estado in run.jogadores do
			darOuro(run, estado, base)
		end
		Vfx.partida(run, "moedas", { pos = sala.bau.Position + Vector3.new(0, 2, 0), quantidade = 30 })
		run:anunciar("💰 Baú aberto! Ouro para todos!", COR_OURO)
	end

	run:anunciar("🎁 Sala do Tesouro!", COR_OURO)
	run:enviarTodos("aviso", { texto = "Abra o baú: as cartas daqui são raras ou melhores!" })
	local conexao = sala.promptBau.Triggered:Connect(function(player)
		if run.jogadores[player] then
			abrir()
		end
	end)
	local limite = os.clock() + 45
	while run.ativa and not aberto and os.clock() < limite do
		task.wait(0.25)
	end
	conexao:Disconnect()
	abrir()
	task.wait(1)
	return true
end

-- Ao limpar a sala, quem caiu levanta e quem morreu volta
local function reviverTodos(run)
	local sala = run.sala
	for _, estado in run.jogadores do
		if estado.caido then
			Combate.levantar(run, estado, 1)
		elseif not estado.vivo then
			task.spawn(reviver, run, estado, sala.spawn)
		end
	end
	task.wait(0.5)
end

------------------------------------------------------------------------
-- Cartas
------------------------------------------------------------------------

local function indiceRaridade(raridade: string): number
	return table.find(Config.ORDEM_RARIDADES, raridade) or 1
end

local function sortearCartas(estado, quantidade: number, raridadeMinima: string?)
	local sorte = estado.perfil.Melhorias.Sorte or 0
	local minimo = if raridadeMinima then indiceRaridade(raridadeMinima) else 1
	local disponiveis = {}
	for _, carta in Cartas.lista do
		local daClasse = carta.classe == estado.classe
		local permitida = carta.classe == nil or daClasse
		if permitida and (estado.cartas[carta.id] or 0) < carta.maxPilha and indiceRaridade(carta.raridade) >= minimo then
			local raridade = Config.RARIDADES[carta.raridade]
			local peso = math.max(0.5, raridade.peso + Config.SORTE_POR_NIVEL[carta.raridade] * sorte)
			if daClasse then
				peso *= Config.PESO_EXTRA_CARTA_DE_CLASSE
			end
			table.insert(disponiveis, { id = carta.id, peso = peso })
		end
	end

	local escolhidas = {}
	for _ = 1, quantidade do
		if #disponiveis == 0 then
			break
		end
		local total = 0
		for _, item in disponiveis do
			total += item.peso
		end
		local sorteio = math.random() * total
		local escolhido = #disponiveis
		for i, item in disponiveis do
			sorteio -= item.peso
			if sorteio <= 0 then
				escolhido = i
				break
			end
		end
		table.insert(escolhidas, disponiveis[escolhido].id)
		table.remove(disponiveis, escolhido)
	end
	return escolhidas
end

local function aplicarCarta(run, estado, id: string)
	estado.opcoesCartas = nil
	estado.cartas[id] = (estado.cartas[id] or 0) + 1
	Combate.calcularStats(estado)
	Combate.aplicarStats(estado, id == "coracao")
	if Cartas.porId[id].efeitos.escudo then
		estado.escudoAtivo = true
	end
	Combate.enviarStats(estado)
	run:enviar(estado.player, "minhasCartas", { cartas = estado.cartas })
	local carta = Cartas.porId[id]
	local cor = Config.RARIDADES[carta.raridade].cor
	Vfx.partida(run, "carta", { jogador = estado.player, cor = cor, raridade = carta.raridade })
	if carta.raridade == "Lendaria" then
		run:anunciar("🌟 " .. estado.player.DisplayName .. " pegou uma LENDÁRIA: " .. carta.nome .. "!", COR_OURO)
	end
end

local function oferecerCartas(run, raridadeMinima: string?)
	for player, estado in run.jogadores do
		local opcoes = sortearCartas(estado, 3, raridadeMinima)
		if #opcoes > 0 then
			estado.opcoesCartas = opcoes
			run:enviar(player, "cartas", { opcoes = opcoes, tempo = Config.TEMPO_ESCOLHER_CARTA, classe = estado.classe })
		end
	end

	local limite = os.clock() + Config.TEMPO_ESCOLHER_CARTA + 1
	while run.ativa and os.clock() < limite do
		local falta = false
		for _, estado in run.jogadores do
			if estado.opcoesCartas then
				falta = true
			end
		end
		if not falta then
			break
		end
		task.wait(0.2)
	end

	for player, estado in run.jogadores do
		if estado.opcoesCartas then
			aplicarCarta(run, estado, estado.opcoesCartas[math.random(#estado.opcoesCartas)])
			run:enviar(player, "cartasFechar", {})
		end
	end
end

function Partida.escolherCarta(player: Player, indice: any)
	local run = partidaDoJogador[player]
	local estado = run and run.jogadores[player]
	if not estado or not estado.opcoesCartas or type(indice) ~= "number" then
		return
	end
	local id = estado.opcoesCartas[indice]
	if id then
		aplicarCarta(run, estado, id)
	end
end

------------------------------------------------------------------------
-- Elevador (depois de cada chefe)
------------------------------------------------------------------------

local function elevador(run)
	for player, estado in run.jogadores do
		estado.escolhaElevador = "pendente"
		run:enviar(player, "elevador", { ouro = estado.ouro, tempo = Config.TEMPO_ELEVADOR, proximaSala = run.numeroSala + 1 })
	end

	local limite = os.clock() + Config.TEMPO_ELEVADOR + 1
	while run.ativa and os.clock() < limite do
		local falta = false
		for _, estado in run.jogadores do
			if estado.escolhaElevador == "pendente" then
				falta = true
			end
		end
		if not falta then
			break
		end
		task.wait(0.2)
	end

	local saindo, ficando = {}, 0
	for _, estado in run.jogadores do
		if estado.escolhaElevador == "continuar" then
			ficando += 1
		else
			table.insert(saindo, estado) -- quem não respondeu sobe e guarda o ouro
		end
		estado.escolhaElevador = nil
	end
	for _, estado in saindo do
		finalizarJogador(run, estado, "saiu")
		if ficando > 0 then
			run:anunciar("⬆️ " .. estado.player.DisplayName .. " subiu com o ouro!", COR_OURO)
		end
	end
	if ficando > 0 then
		run:anunciar("⬇️ Descendo mais fundo...", COR_VERMELHO)
	end
end

function Partida.escolherElevador(player: Player, escolha: any)
	local run = partidaDoJogador[player]
	local estado = run and run.jogadores[player]
	if estado and estado.escolhaElevador == "pendente" and (escolha == "sair" or escolha == "continuar") then
		estado.escolhaElevador = escolha
	end
end

local function aguardarPorta(run)
	local porta = Masmorra.abrirPorta(run.sala)
	run:enviarTodos("aviso", { texto = "A grade subiu! Entre na porta para seguir ➜" })
	local passou = false
	local conexao = porta.Touched:Connect(function(peca)
		local player = Players:GetPlayerFromCharacter(peca.Parent)
		local estado = player and run.jogadores[player]
		if estado and estado.vivo and not estado.caido then
			passou = true
		end
	end)
	local limite = os.clock() + Config.TEMPO_PORTA_AUTOMATICA
	while run.ativa and not passou and os.clock() < limite do
		task.wait(0.15)
	end
	conexao:Disconnect()
end

------------------------------------------------------------------------
-- Loop principal de uma partida
------------------------------------------------------------------------

local function encerrar(run)
	run.ativa = false
	partidasAtivas[run] = nil
	for _, estado in run.jogadores do
		finalizarJogador(run, estado, "morreu")
	end
	Inimigos.limparTodos(run)
	Projeteis.limpar(run)
	run.pasta:Destroy()
end

local function loopDaPartida(run)
	local aliados = {}
	for player, estado in run.jogadores do
		table.insert(aliados, { userId = player.UserId, nome = player.DisplayName, classe = estado.classe })
	end
	run:enviarTodos("inicioPartida", { aliados = aliados })

	local numero = 1
	while run.ativa do
		local tipo = escolherTipoSala(run, numero)
		prepararSala(run, numero, tipo)
		if not run.ativa then
			break
		end

		local venceu = if tipo == "tesouro" then salaDoTesouro(run) else salaDeCombate(run, tipo)
		if not run.ativa then
			break
		end
		if not venceu then
			run:anunciar("💀 O grupo inteiro caiu...", COR_VERMELHO)
			task.wait(2.5)
			break
		end

		local bauDoChefe = nil
		if tipo == "chefe" then
			run:anunciar("🏆 CHEFE DERROTADO!", COR_OURO)
			-- o tesouro do chefe: relíquia épica ou lendária para cada um
			bauDoChefe = Masmorra.criarBauReliquia(run.sala, run.sala.origem + Vector3.new(0, 0, 6), "chefe")
			ligarBau(run, bauDoChefe)
			run:enviarTodos("aviso", { texto = "👑 Abra o tesouro do chefe no meio da sala!" })
		elseif tipo == "combate" then
			run:anunciar("✨ Sala limpa!", COR_VERDE)
		end
		reviverTodos(run)

		local raridadeMinima = if tipo == "tesouro" then "Rara" elseif tipo == "chefe" then "Epica" else nil
		oferecerCartas(run, raridadeMinima)
		if not run.ativa then
			break
		end

		if tipo == "chefe" then
			-- dá um tempo para alguém abrir o tesouro; se ninguém abrir, ele abre sozinho
			local limite = os.clock() + 15
			while run.ativa and bauDoChefe and not bauDoChefe.aberto and os.clock() < limite do
				task.wait(0.25)
			end
			if bauDoChefe and run.ativa then
				abrirBau(run, bauDoChefe, nil)
				task.wait(1.5)
			end
			elevador(run)
			if run:quantidadeJogadores() == 0 then
				break
			end
		end

		aguardarPorta(run)
		numero += 1
	end
end

------------------------------------------------------------------------
-- API pública
------------------------------------------------------------------------

function Partida.emPartida(player: Player): boolean
	return partidaDoJogador[player] ~= nil
end

function Partida.iniciar(lista: { Player })
	contadorPartidas += 1
	local pasta = Instance.new("Folder")
	pasta.Name = "Partida" .. contadorPartidas
	pasta.Parent = workspace

	local run = setmetatable({
		id = contadorPartidas,
		origemBase = Vector3.new(2000 + (contadorPartidas % 20) * 700, 0, 0),
		jogadores = {},
		inimigos = {},
		projeteis = {},
		inimigosPendentes = 0,
		sala = nil,
		numeroSala = 0,
		mult = { vida = 1, dano = 1 },
		ativa = true,
		rng = Random.new(),
		pasta = pasta,
		usarSegundoEspaco = false,
		ultimoTesouro = nil,
		acumulador = 0,
	}, Run)

	for _, player in lista do
		local perfil = Dados.obter(player)
		if player.Parent and perfil and not partidaDoJogador[player] then
			local estado = {
				player = player,
				perfil = perfil,
				classe = perfil.Classe,
				cartas = {},
				reliquias = {}, -- [id] = true (achadas nos baús; shared/Reliquias.luau)
				vivo = false, -- todos "renascem" na primeira sala
				caido = false,
				ouro = 0,
				abates = 0,
				danoCausado = 0,
				combo = 0,
				ultimoAtaque = 0,
				ultimoFoiFinal = false,
				habilidadeProntaEm = 0,
				esquivaProntaEm = 0,
				carga = 0,
				cargaEnviada = 0,
				progressoReviver = 0,
				escudoAtivo = false,
				invulneravelAte = 0,
				conexoes = {},
			}
			Combate.calcularStats(estado)
			run.jogadores[player] = estado
			partidaDoJogador[player] = run
		end
	end

	if run:quantidadeJogadores() == 0 then
		pasta:Destroy()
		return
	end
	partidasAtivas[run] = true
	task.spawn(function()
		-- Se algo der erro no meio da partida, os jogadores voltam ao lobby em vez de ficarem presos
		local ok, erro = pcall(loopDaPartida, run)
		if not ok then
			warn("[Partida] Erro na partida " .. run.id .. ": " .. tostring(erro))
		end
		encerrar(run)
	end)
end

function Partida.removerJogador(player: Player)
	local run = partidaDoJogador[player]
	local estado = run and run.jogadores[player]
	if estado then
		finalizarJogador(run, estado, "desconectou")
		if run:quantidadeJogadores() == 0 then
			run.ativa = false
		end
	end
end

-- No lobby os ataques são só para exibir a classe: os outros jogadores veem a animação
local cargaNoLobby = {} -- [Player] = momento em que começou a carregar

local function animacaoNoLobby(player: Player, tipo: string, extra: any, ativo: any)
	local dados = { jogador = player, classe = player:GetAttribute("Classe") or "cavaleiro" }
	if tipo == "atacar" then
		dados.acao = "ataque"
		dados.combo = if type(extra) == "number" then math.clamp(math.floor(extra), 1, 3) else 1
	elseif tipo == "carregar" then
		cargaNoLobby[player] = os.clock()
		dados.acao = "carregar"
	elseif tipo == "soltar" then
		local inicio = cargaNoLobby[player]
		cargaNoLobby[player] = nil
		if not inicio then
			return
		end
		dados.acao = "soltar"
		dados.fracao = math.clamp((os.clock() - inicio - Config.CARGA_ATAQUE_MIN) / (Config.CARGA_ATAQUE_MAX - Config.CARGA_ATAQUE_MIN), 0, 1)
	elseif tipo == "cancelar" then
		cargaNoLobby[player] = nil
		dados.acao = "cancelar"
	elseif tipo == "esquiva" then
		dados.acao = "esquiva"
	elseif tipo == "correr" then
		-- no acampamento também dá para correr
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16 * (if ativo == true then Config.VELOCIDADE_CORRIDA else 1)
		end
		player:SetAttribute("Correndo", ativo == true)
		return
	elseif tipo == "defender" then
		if dados.classe ~= "cavaleiro" then
			return
		end
		dados.acao = if ativo == true then "defender" else "pararDefesa"
	else
		return
	end
	Vfx.todos("anim", dados)
end

-- Ações de combate vindas do jogador
function Partida.acaoDeCombate(player: Player, tipo: string, direcao: any, extra: any)
	local run = partidaDoJogador[player]
	local estado = run and run.jogadores[player]
	if not estado then
		animacaoNoLobby(player, tipo, extra, direcao)
		return
	end
	if tipo == "atacar" then
		Combate.atacar(run, estado, direcao)
	elseif tipo == "carregar" then
		Combate.carregar(run, estado)
	elseif tipo == "soltar" then
		Combate.soltar(run, estado, direcao)
	elseif tipo == "cancelar" then
		Combate.cancelarCarga(run, estado)
	elseif tipo == "defender" then
		Combate.defender(run, estado, direcao == true)
	elseif tipo == "habilidade" then
		Combate.habilidade(run, estado, direcao)
	elseif tipo == "esquiva" then
		Combate.esquiva(run, estado, direcao)
	elseif tipo == "supremo" then
		Combate.supremo(run, estado)
	elseif tipo == "correr" then
		Combate.correr(estado, direcao == true)
	end
end

Players.PlayerRemoving:Connect(function(player)
	cargaNoLobby[player] = nil
end)

-- Inteligência dos inimigos e projéteis a cada frame; o resto a cada 0,25s
RunService.Heartbeat:Connect(function(dt)
	local agora = os.clock()
	for run in partidasAtivas do
		if run.ativa then
			Inimigos.atualizar(run, agora)
			Projeteis.atualizar(run, dt)
			run.acumulador += dt
			if run.acumulador >= 0.25 then
				Combate.tick(run, run.acumulador)
				run.acumulador = 0
			end
		end
	end
end)

return Partida
