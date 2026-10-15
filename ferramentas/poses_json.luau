-- Exporta as poses de uma classe (Poses.luau) em JSON, amostradas no tempo.
-- Usado por ferramentas/ver_poses.py para desenhar o personagem fora do Roblox.
-- Uso: luau ferramentas/poses_json.luau -a cavaleiro

local Poses = require("../src/client/Poses")

local classe = ... or "cavaleiro"
local PASSO = 0.02

local function json(valor): string
	local tipo = type(valor)
	if tipo == "number" then
		if valor ~= valor or valor == math.huge or valor == -math.huge then
			return "0"
		end
		return string.format("%.5f", valor)
	elseif tipo == "string" then
		return '"' .. valor .. '"'
	elseif tipo == "boolean" then
		return tostring(valor)
	elseif tipo == "table" then
		if #valor > 0 then
			local partes = {}
			for _, v in ipairs(valor) do
				table.insert(partes, json(v))
			end
			return "[" .. table.concat(partes, ",") .. "]"
		end
		local partes = {}
		for k, v in valor do
			if type(v) ~= "function" then
				table.insert(partes, '"' .. tostring(k) .. '":' .. json(v))
			end
		end
		return "{" .. table.concat(partes, ",") .. "}"
	end
	return "null"
end

local flutuar = Poses.FLUTUAR and Poses.FLUTUAR[classe]
local saida = {
	flutuar = if flutuar then { altura = flutuar.altura, pernas = flutuar.pernas(0, 0), pernasMovendo = flutuar.pernas(0, 1) } else nil,
	postura = Poses.POSTURAS[classe] or {},
	parado = if Poses.PARADO[classe] then Poses.PARADO[classe](0) else {},
	acoes = {},
}

local function amostrarAcao(nome: string, definicao, duracaoPadrao: number?)
	local quadros = {}
	if definicao.continuo then
		local duracao = definicao.duracao or duracaoPadrao or 1
		local t = 0
		while t <= duracao + 1e-6 do
			table.insert(quadros, { t = t, pose = definicao.continuo(t, {}) })
			t += PASSO
		end
		saida.acoes[nome] = { duracao = duracao, continuo = true, quadros = quadros }
		return
	end
	Poses.preparar(definicao)
	local duracao = definicao.duracao or 0.6
	if definicao.manter then
		duracao = 0
		for _, q in definicao.quadros do
			duracao = math.max(duracao, q.t)
		end
		duracao += 0.3
	end
	local t = 0
	while t <= duracao + 1e-6 do
		table.insert(quadros, { t = t, pose = Poses.amostrar(definicao, t, {}) })
		t += PASSO
	end
	saida.acoes[nome] = { duracao = duracao, manter = definicao.manter == true, quadros = quadros }
end

for nome, definicao in Poses.ACOES[classe] or {} do
	amostrarAcao(nome, definicao, 1.2)
end
if Poses.ESQUIVAS[classe] then
	amostrarAcao("esquiva", Poses.ESQUIVAS[classe])
end
if Poses.ANDAR and Poses.ANDAR[classe] then
	-- um ciclo de passada inteiro, andando para a frente na velocidade máxima
	local andar = Poses.ANDAR[classe]
	amostrarAcao("andar", {
		duracao = 1,
		continuo = function(t)
			return andar(t * 2 * math.pi, 1, 0, 1)
		end,
	})
end
amostrarAcao("atingido", Poses.ATINGIDO)
amostrarAcao("bloqueio", Poses.BLOQUEIO)

print(json(saida))
